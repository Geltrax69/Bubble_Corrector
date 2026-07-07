//
//  WordPopLogger.swift
//  WordPop
//

import Foundation

enum WordPopLogger {
    private static let logURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/WordPop.log")

    static func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        print(line, terminator: "")

        guard let data = line.data(using: .utf8) else { return }

        do {
            try FileManager.default.createDirectory(
                at: logURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if FileManager.default.fileExists(atPath: logURL.path) {
                let handle = try FileHandle(forWritingTo: logURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: logURL)
            }
        } catch {
            print("WordPop log write failed: \(error)")
        }
    }
}
