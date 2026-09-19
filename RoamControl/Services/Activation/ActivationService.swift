import Foundation
import Network
import Observation

@MainActor
@Observable
final class ActivationService {
    private(set) var phase: ActivationPhase = .unactivated
    private(set) var credentials: ActivationCredentials?
    private(set) var errorMessage: String?
    private(set) var renewalContact = "请联系管理员续费"
    private(set) var isActivating = false
    private(set) var isRefreshing = false
    var onAuthorizationLost: (() -> Void)?

    @ObservationIgnored private let api: any ActivationServing
    @ObservationIgnored private let storage: any ActivationCredentialStorage
    @ObservationIgnored private let origin = ContinuousClock.now
    @ObservationIgnored private var lease: ActivationLease?
    @ObservationIgnored private var refreshTask: Task<Bool, Never>?
    @ObservationIgnored private var monitor: NWPathMonitor?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var networkAvailable = true

    init(api: any ActivationServing = ActivationAPI(), storage: (any ActivationCredentialStorage)? = nil, monitorNetwork: Bool = true) {
        self.api = api
        self.storage = storage ?? ActivationKeychain()
        do { credentials = try self.storage.load(); phase = credentials == nil ? .unactivated : .checking }
        catch { phase = .invalid; errorMessage = error.localizedDescription }
        if monitorNetwork {
            let monitor = NWPathMonitor()
            self.monitor = monitor
            monitor.pathUpdateHandler = { [weak self] path in
                let satisfied = path.status == .satisfied
                Task { @MainActor [weak self] in
                    self?.networkAvailabilityChanged(satisfied)
                }
            }
            monitor.start(queue: DispatchQueue(label: "com.catgo.activation.network"))
        }
    }

    func networkAvailabilityChanged(_ available: Bool) {
        networkAvailable = available
    }

    /// 离线时仅使用当前短期租约；网络变化本身不触发验证或状态变更。
    private func retainCurrentLeaseOrInvalidate() -> Bool {
        guard isAuthorized else {
            if phase != .expired && phase != .disabled && phase != .invalid {
                invalidate(.offline)
            }
            return false
        }
        return true
    }

    private var monotonicNow: TimeInterval {
        let duration = origin.duration(to: .now).components
        return Double(duration.seconds) + Double(duration.attoseconds) / 1e18
    }

    var isAuthorized: Bool { phase == .active && lease?.permits(at: monotonicNow) == true }
    var hasCredentials: Bool { credentials != nil }
    var expiryText: String {
        guard let credentials else { return "尚未激活" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: credentials.timezone)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: credentials.expiresAt)
    }
    var maskedCode: String {
        guard let code = credentials?.code else { return "未填写" }
        return "\(code.prefix(4)) ··· \(code.suffix(4))"
    }

    @discardableResult
    func refresh() async -> Bool {
        if isActivating { return isAuthorized }
        if let refreshTask { return await refreshTask.value }
        guard let credentials else { phase = .unactivated; return false }
        guard networkAvailable else { return retainCurrentLeaseOrInvalidate() }
        isRefreshing = true
        let expectedGeneration = generation
        let started = monotonicNow
        let task = Task { [weak self] () -> Bool in
            guard let self else { return false }
            do {
                let response = try await self.api.verify(token: credentials.deviceToken, deviceID: credentials.deviceID)
                guard self.generation == expectedGeneration, !Task.isCancelled else { return self.isAuthorized }
                guard response.authorized != nil else { throw ActivationError.invalidResponse }
                if !self.networkAvailable, response.status == .active, response.authorized == true {
                    return self.retainCurrentLeaseOrInvalidate()
                }
                let updated = ActivationCredentials(code: credentials.code, deviceToken: credentials.deviceToken, deviceID: credentials.deviceID, expiresAt: response.expiresAt, timezone: response.timezone)
                try self.storage.save(updated)
                self.credentials = updated
                self.apply(response, requestDuration: self.monotonicNow - started)
                return self.isAuthorized
            } catch {
                guard self.generation == expectedGeneration, !Task.isCancelled else { return self.isAuthorized }
                self.errorMessage = error.localizedDescription
                if let networkError = error as? URLError,
                   [.notConnectedToInternet, .networkConnectionLost, .timedOut,
                    .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed].contains(networkError.code) {
                    return self.retainCurrentLeaseOrInvalidate()
                }
                self.invalidate(error is DeviceAuthorizationRejected ? .invalid : .offline)
                return false
            }
        }
        refreshTask = task
        let result = await task.value
        if generation == expectedGeneration { refreshTask = nil; isRefreshing = false }
        return result
    }

    @discardableResult
    func activate(code: String) async -> Bool {
        guard !isActivating else { return false }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty, normalized.count <= 64 else { errorMessage = "请输入有效的激活码。"; return false }
        isActivating = true
        errorMessage = nil
        defer { isActivating = false }
        do {
            let deviceID = try storage.deviceID()
            let started = monotonicNow
            let response = try await api.activate(code: normalized, deviceID: deviceID)
            guard let token = response.deviceToken, token.count == 64, response.status == .active else { throw ActivationError.invalidResponse }
            let updated = ActivationCredentials(code: normalized, deviceToken: token, deviceID: deviceID, expiresAt: response.expiresAt, timezone: response.timezone)
            try storage.save(updated)
            generation += 1
            refreshTask?.cancel(); refreshTask = nil; isRefreshing = false
            credentials = updated
            apply(response, requestDuration: monotonicNow - started)
            return isAuthorized
        } catch {
            // 换码失败保留旧令牌与剩余授权，新码成功后才替换。
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func apply(_ response: ActivationResponse, requestDuration: TimeInterval) {
        if !networkAvailable, response.status == .active, response.authorized != false {
            _ = retainCurrentLeaseOrInvalidate()
            return
        }
        errorMessage = nil
        if let contact = response.renewalContact, !contact.isEmpty { renewalContact = contact }
        switch response.status {
        case .active:
            let newLease = ActivationLease(response: response, receivedAt: monotonicNow, requestDuration: requestDuration)
            guard newLease.validFor > 0 else { invalidate(response.authorized == false ? .invalid : .expired); return }
            lease = newLease
            phase = .active
        case .expired: invalidate(.expired)
        case .disabled: invalidate(.disabled)
        case .unused: invalidate(.invalid)
        }
    }

    private func invalidate(_ phase: ActivationPhase) {
        lease = nil
        self.phase = phase
        onAuthorizationLost?()
    }
}
