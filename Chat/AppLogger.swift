import Foundation

private nonisolated func garnetUncaughtExceptionHandler(_ exception: NSException) {
    AppLogger.recordSynchronously(
        "crash",
        "uncaught_objc_exception",
        metadata: [
            "name": exception.name.rawValue,
            "reason": exception.reason ?? "unknown",
            "stack": exception.callStackSymbols.prefix(24).joined(separator: " <- ")
        ]
    )
}

/// A small, privacy-safe rolling diagnostic log that survives app restarts.
/// Message text and image data are deliberately never written to this file.
enum AppLogger {
    private nonisolated static let ioQueue = DispatchQueue(label: "nb.chat.diagnostics", qos: .utility)
    private nonisolated static let maximumFileSize = 1_500_000
    private nonisolated static let retainedFileSize = 750_000
    private nonisolated(unsafe) static var hasStartedSession = false

    nonisolated static let fileURL: URL = {
        let manager = FileManager.default
        let baseURL = (try? manager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? manager.temporaryDirectory
        let directory = baseURL.appendingPathComponent("GarnetChat", isDirectory: true)
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("garnet-diagnostics.log")
    }()

    private nonisolated static var sessionMarkerURL: URL {
        fileURL.deletingLastPathComponent().appendingPathComponent("session.active")
    }

    nonisolated static func startSession() {
        ioQueue.sync {
            guard !hasStartedSession else { return }
            hasStartedSession = true

            let previousSessionEndedUnexpectedly = FileManager.default.fileExists(atPath: sessionMarkerURL.path)
            FileManager.default.createFile(atPath: sessionMarkerURL.path, contents: Data())
            writeImmediately(makeLine(
                category: "lifecycle",
                event: "session_started",
                metadata: [
                    "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                    "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "previousUnexpectedEnd": String(previousSessionEndedUnexpectedly)
                ]
            ))
        }

        NSSetUncaughtExceptionHandler(garnetUncaughtExceptionHandler)
    }

    nonisolated static func record(
        _ category: String,
        _ event: String,
        metadata: [String: String] = [:]
    ) {
        let line = makeLine(category: category, event: event, metadata: metadata)
        ioQueue.async {
            writeImmediately(line)
        }
    }

    nonisolated static func recordSynchronously(
        _ category: String,
        _ event: String,
        metadata: [String: String] = [:]
    ) {
        let line = makeLine(category: category, event: event, metadata: metadata)
        ioQueue.sync {
            writeImmediately(line)
        }
    }

    nonisolated static func markCleanTermination() {
        recordSynchronously("lifecycle", "clean_termination")
        try? FileManager.default.removeItem(at: sessionMarkerURL)
    }

    nonisolated static func flush() {
        ioQueue.sync {}
    }

    nonisolated static func clear() {
        ioQueue.sync {
            try? FileManager.default.removeItem(at: fileURL)
            writeImmediately(makeLine(category: "diagnostics", event: "log_cleared", metadata: [:]))
        }
    }

    nonisolated static func shortID(_ id: UUID) -> String {
        String(id.uuidString.prefix(8))
    }

    private nonisolated static func makeLine(
        category: String,
        event: String,
        metadata: [String: String]
    ) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let details = metadata
            .sorted(by: { $0.key < $1.key })
            .map { "\(sanitize($0.key))=\(sanitize($0.value))" }
            .joined(separator: " ")
        return "\(timestamp) [\(sanitize(category))] \(sanitize(event))\(details.isEmpty ? "" : " \(details)")\n"
    }

    private nonisolated static func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .prefix(2_000)
            .description
    }

    private nonisolated static func writeImmediately(_ line: String) {
        let manager = FileManager.default
        if !manager.fileExists(atPath: fileURL.path) {
            manager.createFile(atPath: fileURL.path, contents: Data())
        }

        if let attributes = try? manager.attributesOfItem(atPath: fileURL.path),
           let size = attributes[.size] as? NSNumber,
           size.intValue > maximumFileSize,
           let data = try? Data(contentsOf: fileURL) {
            let suffix = data.suffix(retainedFileSize)
            var rotated = Data("--- older diagnostics truncated ---\n".utf8)
            rotated.append(suffix)
            try? rotated.write(to: fileURL, options: .atomic)
        }

        guard let data = line.data(using: .utf8),
              let handle = try? FileHandle(forWritingTo: fileURL)
        else { return }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.synchronize()
        } catch {
            // Diagnostics must never affect the app itself.
        }
    }
}
