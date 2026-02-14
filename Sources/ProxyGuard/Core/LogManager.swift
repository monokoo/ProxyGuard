import Foundation

class LogManager {
    static let shared = LogManager()
    private let logQueue = DispatchQueue(label: "com.proxyguard.logger", qos: .utility)
    private var fileHandle: FileHandle?
    private let dateFormatter: DateFormatter
    private let logFileURL: URL?

    // 日志限制常量
    private let maxLogSize: UInt64 = 10 * 1024 * 1024  // 10MB
    private let maxLogAge: TimeInterval = 7 * 24 * 3600 // 7天
    private var lastCleanupCheck: Date = .distantPast

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
        logQueue.async { [weak self] in
            guard let self = self else { return }

            // 每次写入前检查是否需要清理（最多每5分钟检查一次）
            if Date().timeIntervalSince(self.lastCleanupCheck) > 300 {
                self.cleanupIfNeeded()
            }

            let timestamp = self.dateFormatter.string(from: Date())
            let logEntry = "[\(timestamp)] \(message)\n"

            if let data = logEntry.data(using: .utf8) {
                self.fileHandle?.write(data)
            }
            print(logEntry.trimmingCharacters(in: .newlines))
        }
    }

    // MARK: - 日志清理

    private func cleanupIfNeeded() {
        lastCleanupCheck = Date()
        guard let url = logFileURL else { return }
        let fileManager = FileManager.default

        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path) else { return }

        let fileSize = attrs[.size] as? UInt64 ?? 0
        let modDate = attrs[.modificationDate] as? Date ?? Date()
        let fileAge = Date().timeIntervalSince(modDate)

        // 超过 10MB 或超过 7 天：截断日志
        if fileSize > maxLogSize || fileAge > maxLogAge {
            let reason = fileSize > maxLogSize ? "超过10MB(\(fileSize / 1024 / 1024)MB)" : "超过7天"
            truncateLog(reason: reason)
        }
    }

    private func truncateLog(reason: String) {
        guard let url = logFileURL else { return }
        
        // 关闭当前文件句柄
        fileHandle?.closeFile()
        fileHandle = nil
        
        let fileManager = FileManager.default
        let keepSize: UInt64 = 1024 * 1024 // 1MB
        
        do {
            let attrs = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = attrs[.size] as? UInt64 ?? 0
            
            if fileSize > keepSize {
                // 优化：使用 FileHandle seek 读取最后 1MB，避免加载整个大文件到内存
                let readHandle = try FileHandle(forReadingFrom: url)
                let startOffset = fileSize - keepSize
                try readHandle.seek(toOffset: startOffset)
                let tailData = readHandle.readDataToEndOfFile()
                readHandle.closeFile()
                
                // 写入临时文件
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
                
                // 原子替换
                _ = try? fileManager.removeItem(at: url)
                try fileManager.moveItem(at: tempURL, to: url)
            } else {
                // 文件较小（仅因过期触发清理），直接重写
                // 因为文件本身很小 (<1MB)，全量读取无内存风险
                if let existing = try? Data(contentsOf: url) {
                    let marker = "[日志自动清理] \(reason)\n".data(using: .utf8) ?? Data()
                    try (marker + existing).write(to: url)
                }
            }
        } catch {
            print("[ProxyGuard] Log truncation failed: \(error)")
        }
        
        // 重新打开文件句柄
        setupLogFile()
        print("[ProxyGuard] 日志已自动清理: \(reason)")
    }
}
