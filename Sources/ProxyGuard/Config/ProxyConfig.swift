import Foundation
import Observation

struct ProxyConfig: Codable, Equatable {
    var httpEnabled: Bool
    var httpPort: Int
    var httpsEnabled: Bool
    var httpsPort: Int
    var socksEnabled: Bool
    var socksPort: Int
    var autoRestoreEnabled: Bool
    var restoreDelaySeconds: Double
    var language: AppLanguage
    var proxymanPort: Int
    var clashConfigPath: String
    var clashEnableField: String
    var retryEnabled: Bool
    var maxRetryCount: Int
    var loggingEnabled: Bool

    static let `default` = ProxyConfig(
        httpEnabled: true,
        httpPort: 7897,
        httpsEnabled: true,
        httpsPort: 7897,
        socksEnabled: true,
        socksPort: 7897,
        autoRestoreEnabled: true,
        restoreDelaySeconds: 2.0,
        language: .auto,
        proxymanPort: 9090,
        clashConfigPath: "~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/verge.yaml",
        clashEnableField: "enable_system_proxy",
        retryEnabled: true,
        maxRetryCount: 3,
        loggingEnabled: true
    )
}

@Observable
final class ConfigStore {

    static let shared = ConfigStore()

    private static let storageKey = "proxyConfig"

    var config: ProxyConfig {
        didSet {
            save()
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(ProxyConfig.self, from: data) {
            self.config = decoded
        } else {
            self.config = .default
        }
    }

    var language: AppLanguage {
        get { config.language }
        set { config.language = newValue }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
