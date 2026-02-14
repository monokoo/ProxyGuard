import Foundation

enum ShellExecutor {

    struct ShellError: LocalizedError {
        let exitCode: Int32
        let stderr: String
        var errorDescription: String? {
            "Exit code \(exitCode): \(stderr)"
        }
    }

    @discardableResult
    static func run(
        _ command: String,
        arguments: [String] = []
    ) -> Result<String, Error> {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failure(error)
        }

        let stdout = String(
            data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        let stderr = String(
            data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        if process.terminationStatus != 0 {
            return .failure(ShellError(
                exitCode: process.terminationStatus,
                stderr: stderr
            ))
        }

        return .success(stdout)
    }
}
