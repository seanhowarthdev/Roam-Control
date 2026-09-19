#!/usr/bin/env python3
"""Compile and exercise activation logic and HTTP contract without changing real codes."""
from pathlib import Path
import plistlib
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HARNESS = r'''
import Foundation

@MainActor final class MemoryVault: ActivationCredentialStorage {
    var value: ActivationCredentials?
    var failSave = false
    func deviceID() throws -> String { "test-device-identity-123456" }
    func load() throws -> ActivationCredentials? { value }
    func save(_ credentials: ActivationCredentials) throws {
        if failSave { throw ActivationError.storage }
        value = credentials
    }
}
actor FakeAPI: ActivationServing {
    var response: ActivationResponse
    var failActivation = false
    var failVerification = false
    var rejected = false
    var verifyCalls = 0
    var lastCode = ""
    init(_ response: ActivationResponse) { self.response = response }
    func setResponse(_ response: ActivationResponse) { self.response = response }
    func setActivationFailure(_ value: Bool) { failActivation = value }
    func setVerificationFailure(_ value: Bool) { failVerification = value }
    func setRejection(_ value: Bool) { rejected = value }
    func calls() -> Int { verifyCalls }
    func redeemedCode() -> String { lastCode }
    func activate(code: String, deviceID: String) async throws -> ActivationResponse {
        lastCode = code
        if failActivation { throw ActivationError.server("激活码已使用") }
        return response
    }
    func verify(token: String, deviceID: String) async throws -> ActivationResponse {
        verifyCalls += 1
        try await Task.sleep(for: .milliseconds(40))
        if rejected { throw DeviceAuthorizationRejected(message: "设备授权无效") }
        if failVerification { throw URLError(.notConnectedToInternet) }
        return response
    }
}
final class ProtocolStub: URLProtocol, @unchecked Sendable {
    static var lastRequest: URLRequest?
    static var httpStatus = 200
    static var body = ""
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.httpStatus, httpVersion: "HTTP/1.1", headerFields: ["Content-Type":"application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
@main struct ActivationTests {
    @MainActor static func main() async throws {
        let date = ISO8601DateFormatter().date(from: "2026-09-18T00:00:00Z")!
        func response(_ status: ActivationStatus = .active, authorized: Bool? = true, seconds: Double = 3600, token: String = String(repeating: "a", count: 64)) -> ActivationResponse {
            ActivationResponse(deviceToken: token, authorized: authorized, status: status, expiresAt: date.addingTimeInterval(seconds), serverTime: date, timezone: "Asia/Shanghai", renewalContact: "请联系测试管理员")
        }
        let grant = ActivationLease(response: response(), receivedAt: 100, requestDuration: 1)
        precondition(grant.permits(at: 100) && grant.permits(at: 124.99))
        precondition(!grant.permits(at: 125) && !grant.permits(at: 99))
        // 服务端只剩 3 秒，请求耗时 1 秒，客户端只能再使用 2 秒。
        let short = ActivationLease(response: response(seconds: 3), receivedAt: 10, requestDuration: 1)
        precondition(short.permits(at: 11.99) && !short.permits(at: 12))
        for state in [ActivationStatus.expired, .disabled, .unused] {
            precondition(!ActivationLease(response: response(state), receivedAt: 0, requestDuration: 0).permits(at: 0))
        }
        precondition(!ActivationLease(response: response(authorized: false), receivedAt: 0, requestDuration: 0).permits(at: 0))
        precondition(!ActivationLease(response: response(seconds: 0), receivedAt: 0, requestDuration: 0).permits(at: 0))

        let vault = MemoryVault(), api = FakeAPI(response()), service = ActivationService(api: api, storage: vault, monitorNetwork: false)
        precondition(!service.isAuthorized && !service.hasCredentials)
        let empty = await service.activate(code: " ")
        precondition(!empty && vault.value == nil)
        let activated = await service.activate(code: "  new-code  ")
        precondition(activated && service.isAuthorized)
        let code = await api.redeemedCode()
        precondition(code == "NEW-CODE" && service.credentials?.code == "NEW-CODE")
        precondition(service.expiryText == "2026-09-18 09:00")
        let restored = ActivationService(api: api, storage: vault, monitorNetwork: false)
        precondition(restored.hasCredentials && !restored.isAuthorized, "缓存凭据不能直接授予离线权限")
        let verified = await restored.refresh()
        precondition(verified && restored.isAuthorized)

        await api.setActivationFailure(true)
        let replaced = await service.activate(code: "USED-CODE")
        precondition(!replaced && service.isAuthorized && service.credentials?.code == "NEW-CODE")
        precondition(service.errorMessage == "激活码已使用")
        await api.setActivationFailure(false)
        vault.failSave = true
        let failedSave = await service.activate(code: "SECOND-CODE")
        precondition(!failedSave && service.credentials?.code == "NEW-CODE")
        vault.failSave = false

        let before = await api.calls()
        async let a = service.refresh()
        async let b = service.refresh()
        let both = await (a,b)
        let after = await api.calls()
        precondition(both.0 && both.1 && after - before == 1, "并发刷新应复用一个请求")
        var revocations = 0
        service.onAuthorizationLost = { revocations += 1 }
        await api.setVerificationFailure(true)
        let offline = await service.refresh()
        precondition(offline && service.isAuthorized && revocations == 0, "网络请求失败不得提前撤销有效短期授权")
        await api.setVerificationFailure(false)
        await api.setResponse(response(.expired, authorized: false, seconds: -1))
        let expired = await service.refresh()
        precondition(!expired && service.phase == .expired)
        await api.setResponse(response(.disabled, authorized: false))
        let disabled = await service.refresh()
        precondition(!disabled && service.phase == .disabled)
        await api.setResponse(response())
        let renewed = await service.refresh()
        precondition(renewed && service.isAuthorized && service.renewalContact == "请联系测试管理员")
        // 网络变化本身不得发起验证或撤销授权；只在用户操作时验证。
        let callsBeforeNetworkChange = await api.calls()
        let revocationsBeforeNetworkChange = revocations
        service.networkAvailabilityChanged(false)
        service.networkAvailabilityChanged(true)
        try await Task.sleep(for: .milliseconds(80))
        let callsAfterNetworkChange = await api.calls()
        precondition(callsAfterNetworkChange == callsBeforeNetworkChange, "网络变化不得自动验证")
        precondition(service.phase == .active && revocations == revocationsBeforeNetworkChange, "网络变化不得主动撤销当前状态")

        // 切换网络不提前撤销授权，迟到响应不能延长原有租约。
        async let pendingVerification = service.refresh()
        try await Task.sleep(for: .milliseconds(10))
        service.networkAvailabilityChanged(false)
        let staleResult = await pendingVerification
        precondition(staleResult && service.isAuthorized, "切换网络应保留原有有效租约")
        service.networkAvailabilityChanged(true)
        _ = await service.refresh()
        await api.setRejection(true)
        let rejected = await service.refresh()
        precondition(!rejected && service.phase == .invalid)
        await api.setRejection(false)
        await api.setResponse(response(seconds: 0.15))
        _ = await service.refresh()
        service.networkAvailabilityChanged(false)
        precondition(service.isAuthorized, "断网不应提前撤销未过期租约")
        let offlineRefresh = await service.refresh()
        precondition(offlineRefresh, "断网刷新只使用原有租约")
        try await Task.sleep(for: .milliseconds(200))
        precondition(!service.isAuthorized && service.phase == .active, "本地租约到期不得自动变更状态或触发停定位")

        let afterExpiry = await service.refresh()
        precondition(!afterExpiry && !service.isAuthorized, "断网不能延长已过期授权")
        let cold = ActivationService(api: api, storage: vault, monitorNetwork: false)
        cold.networkAvailabilityChanged(false)
        let coldRefresh = await cold.refresh()
        precondition(!coldRefresh && !cold.isAuthorized, "缓存凭据不能在离线启动时授权")

        await api.setResponse(response(seconds: 0.20))
        let switching = ActivationService(api: api, storage: vault, monitorNetwork: false)
        _ = await switching.refresh()
        async let late = switching.refresh()
        try await Task.sleep(for: .milliseconds(10))
        switching.networkAvailabilityChanged(false)
        _ = await late
        try await Task.sleep(for: .milliseconds(140))
        precondition(!switching.isAuthorized, "断网期间返回的成功响应不能延长原租约")
        await api.setResponse(response())
        let denial = ActivationService(api: api, storage: vault, monitorNetwork: false)
        _ = await denial.refresh()
        await api.setResponse(response(.disabled, authorized: false))
        async let pendingDenial = denial.refresh()
        try await Task.sleep(for: .milliseconds(10))
        denial.networkAvailabilityChanged(false)
        let denied = await pendingDenial
        precondition(!denied && denial.phase == .disabled, "网络切换期间收到禁用结果仍必须立即撤销")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let http = ActivationAPI(baseURL: URL(string: "https://unit.test")!, session: session)
        ProtocolStub.body = #"{"authorized":true,"status":"active","expiresAt":"2026-10-18T09:30:00.000Z","serverTime":"2026-09-18T09:30:00Z","timezone":"Asia/Shanghai","renewalContact":"联系管理员"}"#
        let decoded = try await http.verify(token: "secret-token", deviceID: "test-device-identity-123456")
        precondition(decoded.authorized == true && decoded.timezone == "Asia/Shanghai")
        precondition(ProtocolStub.lastRequest?.url?.absoluteString == "https://unit.test/api/device/verify")
        precondition(ProtocolStub.lastRequest?.httpMethod == "POST")
        precondition(ProtocolStub.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
        precondition(ProtocolStub.lastRequest?.httpShouldHandleCookies == false)
        ProtocolStub.httpStatus = 409
        ProtocolStub.body = #"{"error":{"code":"CODE_USED","message":"激活码已使用"}}"#
        do { _ = try await http.activate(code: "old-code", deviceID: "test-device-identity-123456"); preconditionFailure("重复激活必须失败") }
        catch { precondition(error.localizedDescription == "激活码已使用") }
        ProtocolStub.httpStatus = 401
        do { _ = try await http.verify(token: "bad-token", deviceID: "test-device-identity-123456"); preconditionFailure("无效令牌必须失败") }
        catch { precondition(error is DeviceAuthorizationRejected) }
#if !DEBUG
        let insecure = ActivationAPI(baseURL: URL(string: "http://unit.test")!, session: session)
        do { _ = try await insecure.verify(token: "token", deviceID: "device"); preconditionFailure("Release 必须拒绝 HTTP") }
        catch { precondition(error is ActivationError) }
#endif
        session.invalidateAndCancel()
        print("激活、缓存拒绝、换码失败、存储失败、并发刷新、离线、到期、禁用、续费和 HTTP 协议测试通过")
    }
}
'''

release = plistlib.loads((ROOT / "Configuration/RoamControl-Info.plist").read_bytes())
debug = plistlib.loads((ROOT / "Configuration/RoamControl-Debug-Info.plist").read_bytes())
assert "NSAppTransportSecurity" not in release
assert debug.pop("NSAppTransportSecurity") == {"NSAllowsArbitraryLoads": True}
assert debug == release, "调试与正式 Info.plist 除 ATS 外必须相同"
service_source = (ROOT / "RoamControl/Services/Activation/ActivationService.swift").read_text()
assert "startMonitoring" not in service_source
assert "heartbeatTask" not in service_source
assert "expiryTask" not in service_source
app_source = (ROOT / "RoamControl/App/AppModel.swift").read_text()
authorization_lost = app_source.split("activation.onAuthorizationLost =", 1)[1].split("deviceSession.canModifyLocation", 1)[0]
assert "stopLocationSession" not in authorization_lost, "授权失败必须保留当前旧位置"
for relative in [
    "RoamControl/App/RoamControlApp.swift",
    "RoamControl/Features/Home/HomeView.swift",
    "RoamControl/Features/Settings/SettingsView.swift",
    "RoamControl/Features/Pairing/PairingSetupView.swift",
]:
    assert "activation.refresh()" not in (ROOT / relative).read_text(), f"{relative} 不得自动验证授权"
with tempfile.TemporaryDirectory(prefix="catgo-activation-tests-") as directory:
    main = Path(directory) / "Tests.swift"
    main.write_text(HARNESS)
    sources = sorted((ROOT / "RoamControl/Services/Activation").glob("*.swift"))
    for build in ["Debug", "Release"]:
        binary = Path(directory) / build
        args = ["xcrun", "swiftc", "-swift-version", "5", "-parse-as-library"]
        if build == "Debug":
            args += ["-D", "DEBUG"]
        subprocess.run(args + [str(p) for p in sources] + [str(main), "-o", str(binary)], check=True)
        subprocess.run([str(binary)], check=True)
print("Debug / Release 激活与配置测试通过；没有兑换真实数据库激活码")
