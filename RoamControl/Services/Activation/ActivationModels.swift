import Foundation

enum ActivationStatus: String, Codable, Sendable {
    case unused, active, expired, disabled
}

struct ActivationResponse: Decodable, Sendable {
    let deviceToken: String?
    let authorized: Bool?
    let status: ActivationStatus
    let expiresAt: Date
    let serverTime: Date
    let timezone: String
    let renewalContact: String?
}

struct ActivationCredentials: Codable, Sendable {
    let code: String
    let deviceToken: String
    let deviceID: String
    let expiresAt: Date
    let timezone: String
}

/// 授权只由在线结果产生；计时使用单调时钟，不依赖手机日期。
struct ActivationLease: Sendable {
    static let maximumAge: TimeInterval = 25
    let receivedAt: TimeInterval
    let validFor: TimeInterval

    init(response: ActivationResponse, receivedAt: TimeInterval, requestDuration: TimeInterval) {
        self.receivedAt = receivedAt
        validFor = response.status == .active && response.authorized != false
            ? max(0, min(Self.maximumAge, response.expiresAt.timeIntervalSince(response.serverTime) - requestDuration))
            : 0
    }

    func permits(at instant: TimeInterval) -> Bool {
        instant >= receivedAt && instant < receivedAt + validFor
    }
}

enum ActivationPhase: Equatable {
    case unactivated, checking, active, expired, disabled, offline, invalid

    var title: String {
        switch self {
        case .unactivated: "未激活"
        case .checking: "正在验证激活状态"
        case .active: "已激活"
        case .expired: "激活已到期"
        case .disabled: "激活码已禁用"
        case .offline: "无法在线验证"
        case .invalid: "设备授权已失效"
        }
    }

    var guidance: String {
        switch self {
        case .unactivated: "请先填写激活码，激活后才能配对此 iPhone 和使用定位功能。"
        case .checking: "正在向服务器验证授权，请稍候。"
        case .active: "续费由管理员修改当前激活码的到期时间，无需换码。"
        case .expired: "请联系管理员续费，或填写新的激活码。续费后刷新状态即可恢复使用。"
        case .disabled: "请联系管理员处理或填写新的激活码。修改到期时间不会自动解除禁用。"
        case .offline: "无法连接授权服务器，暂时不能配对或修改定位。请检查网络后重试。"
        case .invalid: "请填写新的激活码。激活码只能激活一次，更换设备需要新码。"
        }
    }
}

enum ActivationError: LocalizedError {
    case server(String)
    case invalidResponse
    case invalidAddress
    case storage

    var errorDescription: String? {
        switch self {
        case .server(let message): message
        case .invalidResponse: "授权服务器响应异常，请联系管理员。"
        case .invalidAddress: "激活服务器地址配置无效，请联系管理员。"
        case .storage: "无法保存设备授权。若激活码已使用，请联系管理员发放新码。"
        }
    }
}
