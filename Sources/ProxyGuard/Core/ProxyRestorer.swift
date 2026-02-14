import Foundation

struct ProxyRestorer {

    func restore(with config: ProxyConfig) -> Result<Void, ProxyRestoreError> {
        let servicesResult = listNetworkServices()
        guard case .success(let services) = servicesResult else {
            return .failure(.cannotListServices)
        }

        var errors: [String] = []

        for service in services {
            if config.httpEnabled {
                let httpResult = ShellExecutor.run(
                    "/usr/sbin/networksetup",
                    arguments: [
                        "-setwebproxy", service,
                        "127.0.0.1", String(config.httpPort),
                    ]
                )
                if case .failure(let e) = httpResult {
                    errors.append("HTTP proxy for \(service): \(e)")
                }
                ShellExecutor.run(
                    "/usr/sbin/networksetup",
                    arguments: ["-setwebproxystate", service, "on"]
                )
            }

            if config.httpsEnabled {
                let httpsResult = ShellExecutor.run(
                    "/usr/sbin/networksetup",
                    arguments: [
                        "-setsecurewebproxy", service,
                        "127.0.0.1", String(config.httpsPort),
                    ]
                )
                if case .failure(let e) = httpsResult {
                    errors.append("HTTPS proxy for \(service): \(e)")
                }
                ShellExecutor.run(
                    "/usr/sbin/networksetup",
                    arguments: ["-setsecurewebproxystate", service, "on"]
                )
            }

            if config.socksEnabled {
                let socksResult = ShellExecutor.run(
                    "/usr/sbin/networksetup",
                    arguments: [
                        "-setsocksfirewallproxy", service,
                        "127.0.0.1", String(config.socksPort),
                    ]
                )
                if case .failure(let e) = socksResult {
                    errors.append("SOCKS proxy for \(service): \(e)")
                }
                ShellExecutor.run(
                    "/usr/sbin/networksetup",
                    arguments: ["-setsocksfirewallproxystate", service, "on"]
                )
            }
        }

        if errors.isEmpty {
            return .success(())
        } else {
            return .failure(.partialFailure(errors))
        }
    }

    func disableAllProxy() -> Result<Void, ProxyRestoreError> {
        let servicesResult = listNetworkServices()
        guard case .success(let services) = servicesResult else {
            return .failure(.cannotListServices)
        }

        for service in services {
            ShellExecutor.run(
                "/usr/sbin/networksetup",
                arguments: ["-setwebproxystate", service, "off"]
            )
            ShellExecutor.run(
                "/usr/sbin/networksetup",
                arguments: ["-setsecurewebproxystate", service, "off"]
            )
            ShellExecutor.run(
                "/usr/sbin/networksetup",
                arguments: ["-setsocksfirewallproxystate", service, "off"]
            )
        }

        return .success(())
    }

    private func listNetworkServices() -> Result<[String], ProxyRestoreError> {
        let result = ShellExecutor.run(
            "/usr/sbin/networksetup",
            arguments: ["-listallnetworkservices"]
        )

        switch result {
        case .success(let output):
            let services = output
                .components(separatedBy: "\n")
                .dropFirst()
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("*") }
            return .success(services)

        case .failure(let error):
            return .failure(.shellError(error.localizedDescription))
        }
    }
}

enum ProxyRestoreError: LocalizedError {
    case cannotListServices
    case shellError(String)
    case partialFailure([String])

    var errorDescription: String? {
        switch self {
        case .cannotListServices:
            return "Cannot list network services"
        case .shellError(let msg):
            return "Shell error: \(msg)"
        case .partialFailure(let errors):
            return "Partial failure: \(errors.joined(separator: "; "))"
        }
    }
}
