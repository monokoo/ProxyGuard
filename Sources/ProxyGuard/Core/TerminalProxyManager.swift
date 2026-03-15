import Foundation
import AppKit

/// Manages terminal proxy environment variables via `~/.proxyguard_env`.
///
/// Static mode: writes export statements directly.
/// Live reload mode: writes exports to a separate file and uses SIGUSR1 to notify running shells.
enum TerminalProxyManager {

    // MARK: - File Paths

    /// Main env file that shell profiles source
    private static let envFilePath = (NSHomeDirectory() as NSString).appendingPathComponent(".proxyguard_env")
    /// Separate exports file used in live reload mode
    private static let exportsFilePath = (NSHomeDirectory() as NSString).appendingPathComponent(".proxyguard_env.exports")

    /// Shell config files to inject source line into
    private static let shellConfigs: [(name: String, path: String)] = [
        ("zsh", (NSHomeDirectory() as NSString).appendingPathComponent(".zshrc")),
        ("bash", (NSHomeDirectory() as NSString).appendingPathComponent(".bash_profile")),
    ]

    /// Marker comment used to identify ProxyGuard source lines in shell configs
    private static let sourceMarker = "# >>> ProxyGuard Shell Integration >>>"
    private static let sourceMarkerEnd = "# <<< ProxyGuard Shell Integration <<<"
    private static let sourceLine = "[ -f \"$HOME/.proxyguard_env\" ] && source \"$HOME/.proxyguard_env\""

    // MARK: - Env File Management

    /// Update the env file with proxy export statements.
    /// In live reload mode, also updates the exports file and sends SIGUSR1.
    static func updateEnvFile(port: Int, liveReload: Bool) {
        if liveReload {
            // Live reload mode: write exports to separate file, env file has trap
            let exports = generateExportsContent(port: port, enabled: true)
            writeFile(at: exportsFilePath, content: exports)
            let trapContent = generateLiveReloadEnvContent()
            writeFile(at: envFilePath, content: trapContent)
            notifyRunningShells()
        } else {
            // Static mode: write directly to env file
            let content = generateExportsContent(port: port, enabled: true)
            writeFile(at: envFilePath, content: content)
        }
    }

    /// Clear the env file (proxy disabled).
    static func clearEnvFile(liveReload: Bool) {
        let disabled = "# Managed by ProxyGuard — proxy disabled\n"
        if liveReload {
            let unsetContent = """
            # Managed by ProxyGuard — proxy disabled
            unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
            
            """
            writeFile(at: exportsFilePath, content: unsetContent)
            // Keep the trap in env file so shells can receive future updates
            let trapContent = generateLiveReloadEnvContent()
            writeFile(at: envFilePath, content: trapContent)
            notifyRunningShells()
        } else {
            writeFile(at: envFilePath, content: disabled)
        }
    }

    // MARK: - Shell Integration

    struct ShellStatus {
        let name: String
        let installed: Bool
        let fileExists: Bool
    }

    /// Check which shells have ProxyGuard integration installed.
    static func shellIntegrationStatus() -> [ShellStatus] {
        shellConfigs.map { config in
            let fileExists = FileManager.default.fileExists(atPath: config.path)
            guard fileExists,
                  let content = try? String(contentsOfFile: config.path, encoding: .utf8) else {
                return ShellStatus(name: config.name, installed: false, fileExists: fileExists)
            }
            let installed = content.contains(sourceMarker)
            return ShellStatus(name: config.name, installed: installed, fileExists: fileExists)
        }
    }

    /// Install shell integration into ~/.zshrc and ~/.bash_profile.
    /// Returns a summary of what was done.
    @discardableResult
    static func installShellIntegration(liveReload: Bool) -> [String] {
        var results: [String] = []

        // First, ensure the env file exists
        if liveReload {
            let trapContent = generateLiveReloadEnvContent()
            writeFile(at: envFilePath, content: trapContent)
        } else {
            // Write a placeholder if no proxy is active yet
            if !FileManager.default.fileExists(atPath: envFilePath) {
                writeFile(at: envFilePath, content: "# Managed by ProxyGuard — proxy disabled\n")
            }
        }

        for config in shellConfigs {
            let result = installIntoShellConfig(config.name, path: config.path)
            results.append(result)
        }
        return results
    }

    /// Uninstall shell integration from all shell configs and remove env files.
    @discardableResult
    static func uninstallShellIntegration() -> [String] {
        var results: [String] = []

        for config in shellConfigs {
            let result = uninstallFromShellConfig(config.name, path: config.path)
            results.append(result)
        }

        // Remove env files
        try? FileManager.default.removeItem(atPath: envFilePath)
        try? FileManager.default.removeItem(atPath: exportsFilePath)

        return results
    }

    // MARK: - Clipboard

    /// Copy the appropriate proxy command to clipboard.
    /// When proxy is enabled: copies `source ~/.proxyguard_env`
    /// When proxy is disabled: copies unset command
    static func copyProxyCommandToClipboard(enabled: Bool, port: Int) {
        let command: String
        if enabled {
            command = "source ~/.proxyguard_env"
        } else {
            command = "unset http_proxy https_proxy all_proxy"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }

    // MARK: - SIGUSR1 Notification

    /// Send SIGUSR1 to all running zsh/bash processes owned by current user.
    /// Only called when `terminalProxyLiveReload == true`.
    static func notifyRunningShells() {
        let result = ShellExecutor.run("/usr/bin/pgrep", arguments: ["-u", "\(getuid())", "zsh|bash"])
        guard case .success(let output) = result else { return }

        let pids = output
            .components(separatedBy: .newlines)
            .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }

        var signaled = 0
        for pid in pids {
            if kill(pid, SIGUSR1) == 0 {
                signaled += 1
            } else {
                let err = errno
                if err == ESRCH {
                    // Process exited between pgrep and kill, safe to ignore
                    continue
                } else if err == EPERM {
                    LogManager.shared.log("[TerminalProxy] Permission denied signaling PID \(pid)")
                } else {
                    LogManager.shared.log("[TerminalProxy] Error signaling PID \(pid): errno=\(err)")
                }
            }
        }

        if signaled > 0 {
            LogManager.shared.log("[TerminalProxy] Sent SIGUSR1 to \(signaled) shell(s)")
        }
    }

    // MARK: - Private Helpers

    private static func generateExportsContent(port: Int, enabled: Bool) -> String {
        if enabled {
            return """
            # Managed by ProxyGuard — DO NOT EDIT
            export http_proxy="http://127.0.0.1:\(port)"
            export https_proxy="http://127.0.0.1:\(port)"
            export all_proxy="socks5://127.0.0.1:\(port)"
            
            """
        } else {
            return """
            # Managed by ProxyGuard — proxy disabled
            unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
            
            """
        }
    }

    private static func generateLiveReloadEnvContent() -> String {
        return """
        # Managed by ProxyGuard — DO NOT EDIT (live reload mode)
        [ -f "$HOME/.proxyguard_env.exports" ] && source "$HOME/.proxyguard_env.exports"
        trap '[ -f "$HOME/.proxyguard_env.exports" ] && source "$HOME/.proxyguard_env.exports"' USR1
        
        """
    }

    private static func installIntoShellConfig(_ name: String, path: String) -> String {
        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }

        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return "\(name): failed to read"
        }

        // Already installed
        if content.contains(sourceMarker) {
            return "\(name): already installed"
        }

        // Append source line with markers
        let injection = """
        
        \(sourceMarker)
        \(sourceLine)
        \(sourceMarkerEnd)
        
        """
        let newContent = content + injection
        do {
            try newContent.write(toFile: path, atomically: true, encoding: .utf8)
            return "\(name): installed"
        } catch {
            return "\(name): failed (\(error.localizedDescription))"
        }
    }

    private static func uninstallFromShellConfig(_ name: String, path: String) -> String {
        guard FileManager.default.fileExists(atPath: path),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return "\(name): not found"
        }

        guard content.contains(sourceMarker) else {
            return "\(name): not installed"
        }

        // Remove the block between markers (inclusive)
        let lines = content.components(separatedBy: "\n")
        var newLines: [String] = []
        var skipping = false

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == sourceMarker {
                skipping = true
                continue
            }
            if line.trimmingCharacters(in: .whitespaces) == sourceMarkerEnd {
                skipping = false
                continue
            }
            if !skipping {
                newLines.append(line)
            }
        }

        // Clean up extra blank lines at the end
        while newLines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true
                && newLines.dropLast().last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            newLines.removeLast()
        }

        let newContent = newLines.joined(separator: "\n")
        do {
            try newContent.write(toFile: path, atomically: true, encoding: .utf8)
            return "\(name): uninstalled"
        } catch {
            return "\(name): failed (\(error.localizedDescription))"
        }
    }

    private static func writeFile(at path: String, content: String) {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            // Restrict permissions to owner-only (0600) for security
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: path
            )
        } catch {
            LogManager.shared.log("[TerminalProxy] Failed to write \(path): \(error)")
        }
    }
}
