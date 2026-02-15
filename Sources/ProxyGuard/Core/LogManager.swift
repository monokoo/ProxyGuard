import Foundation

class LogManager {
    static let shared = LogManager()
    private let logQueue = DispatchQueue(label: "com.proxyguard.logger", qos: .utility)
    private var fileHandle: FileHandle?
    private let dateFormatter: DateFormatter
    private let logFileURL: URL?

    // Log limits
    private let maxLogSize: UInt64 = 10 * 1024 * 1024  // 10MB
    private let maxLogAge: TimeInterval = 7 * 24 * 3600 // 7 days
    private var lastCleanupCheck: Date = .distantPast

    // Batch write buffer
    private var buffer: [String] = []
    private let bufferLimit = 20
    private var flushTimer: Timer?

    // Log toggle (checked on main thread via ConfigStore)
    var isEnabled: Bool {
        ConfigStore.shared.config.loggingEnabled
    }

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        let fileManager = FileManager.default
        if let logsDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Logs/ProxyGuard") {
            try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
            logFileURL = logsDir.appendingPathComponent("proxyguard.log")
        } else {
            logFileURL = nil
        }

        setupLogFile()
        cleanupIfNeeded()
    }

    private func setupLogFile() {
        guard let url = logFileURL else { return }
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
        }

        try? fileHandle = FileHandle(forWritingTo: url)
        fileHandle?.seekToEndOfFile()
    }

    func log(_ message: String) {
        guard isEnabled else { return }

        logQueue.async { [weak self] in
            guard let self = self else { return }

            // Cleanup check (max every 5 minutes)
            if Date().timeIntervalSince(self.lastCleanupCheck) > 300 {
                self.cleanupIfNeeded()
            }

            let timestamp = self.dateFormatter.string(from: Date())
            let logEntry = "[\(timestamp)] \(message)\n"

            self.buffer.append(logEntry)

            if self.buffer.count >= self.bufferLimit {
                self.flush()
            } else {
                self.scheduleFlushIfNeeded()
            }
        }
    }

    // MARK: - Batch flush

    private func scheduleFlushIfNeeded() {
        guard flushTimer == nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.flushTimer == nil else { return }
            let timer = Timer(timeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.logQueue.async {
                    self?.flush()
                    self?.flushTimer = nil
                }
            }
            timer.tolerance = 1.0
            RunLoop.main.add(timer, forMode: .common)
            self.flushTimer = timer
        }
    }

    private func flush() {
        guard !buffer.isEmpty else { return }
        let combined = buffer.joined()
        buffer.removeAll()
        if let data = combined.data(using: .utf8) {
            fileHandle?.write(data)
        }
    }

    // MARK: - Cleanup

    private func cleanupIfNeeded() {
        lastCleanupCheck = Date()
        guard let url = logFileURL else { return }
        let fileManager = FileManager.default

        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path) else { return }

        let fileSize = attrs[.size] as? UInt64 ?? 0
        let modDate = attrs[.modificationDate] as? Date ?? Date()
        let fileAge = Date().timeIntervalSince(modDate)

        if fileSize > maxLogSize || fileAge > maxLogAge {
            let reason = fileSize > maxLogSize ? "超过10MB(\(fileSize / 1024 / 1024)MB)" : "超过7天"
            truncateLog(reason: reason)
        }
    }

    private func truncateLog(reason: String) {
        guard let url = logFileURL else { return }

        // Flush pending buffer first
        flush()

        fileHandle?.closeFile()
        fileHandle = nil

        let fileManager = FileManager.default
        let keepSize: UInt64 = 1024 * 1024 // 1MB

        do {
            let attrs = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = attrs[.size] as? UInt64 ?? 0

            if fileSize > keepSize {
                let readHandle = try FileHandle(forReadingFrom: url)
                let startOffset = fileSize - keepSize
                try readHandle.seek(toOffset: startOffset)
                let tailData = readHandle.readDataToEndOfFile()
                readHandle.closeFile()

                let tempURL = url.deletingLastPathComponent().appendingPathComponent("proxyguard.log.tmp")
                let header = "[日志自动清理] \(reason)，仅保留最近 1MB\n".data(using: .utf8) ?? Data()

                if fileManager.fileExists(atPath: tempURL.path) {
                    try? fileManager.removeItem(at: tempURL)
                }
                fileManager.createFile(atPath: tempURL.path, contents: nil)

                let writeHandle = try FileHandle(forWritingTo: tempURL)
                writeHandle.write(header)
                writeHandle.write(tailData)
                writeHandle.closeFile()

                _ = try? fileManager.removeItem(at: url)
                try fileManager.moveItem(at: tempURL, to: url)
            } else {
                if let existing = try? Data(contentsOf: url) {
                    let marker = "[日志自动清理] \(reason)\n".data(using: .utf8) ?? Data()
                    try (marker + existing).write(to: url)
                }
            }
        } catch {
            print("[ProxyGuard] Log truncation failed: \(error)")
        }

        setupLogFile()
        print("[ProxyGuard] 日志已自动清理: \(reason)")
    }
}
