import Foundation

struct ProxyState: Equatable, CustomStringConvertible {
    let httpEnabled: Bool
    let httpHost: String?
    let httpPort: Int?
    let httpsEnabled: Bool
    let httpsHost: String?
    let httpsPort: Int?
    let socksEnabled: Bool
    let socksHost: String?
    let socksPort: Int?

    static let empty = ProxyState(
        httpEnabled: false, httpHost: nil, httpPort: nil,
        httpsEnabled: false, httpsHost: nil, httpsPort: nil,
        socksEnabled: false, socksHost: nil, socksPort: nil
    )

    var isActive: Bool {
        httpEnabled || httpsEnabled || socksEnabled
    }

    var description: String {
        "ProxyState(http: \(httpEnabled):\(httpPort ?? 0), "
        + "https: \(httpsEnabled):\(httpsPort ?? 0), "
        + "socks: \(socksEnabled):\(socksPort ?? 0))"
    }
}

enum ProxyEventType: Equatable {
    case restored
    case restoredToProxyman
    case closedByClashDead
    case skippedClashClosed
    case skippedNoNeed
    case clearedButNoClash
    case retrying(Int)
    case restoreFailed(String)
}

struct ProxyEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: ProxyEventType
}
