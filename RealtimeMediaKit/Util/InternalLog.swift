//
//  InternalLog.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation
import Synchronization
import os

private final class BundleToken {}

final class InternalLog: Sendable {
    private let outputLogLevel: Mutex<Log.LogLevel>
    private let tag: String = "[REALTIME_MEDIA_KIT]"
    private let logger: Logger

    init() {
        self.outputLogLevel = Mutex<Log.LogLevel>(.trace)
        self.logger = Logger(
            subsystem: Bundle(for: BundleToken.self).bundleIdentifier ?? "RealtimeMediaKit",
            category: "RealtimeMediaKit"
        )
    }

    func setLogLevel(_ level: Log.LogLevel) {
        outputLogLevel.withLock { outputLogLevel in
            outputLogLevel = level
        }
    }

    func trace(_ text: String, functionName: String, fileName: String, line: Int) {
        if outputLogLevel.withLock({ $0.rawValue }) <= Log.LogLevel.trace.rawValue {
            let message: String = createLog(text, levelString: "TRACE", functionName: functionName, fileName: fileName, line: line)
            logger.trace("\(message)")
        }
    }

    func debug(_ text: String, functionName: String, fileName: String, line: Int) {
        if outputLogLevel.withLock({ $0.rawValue }) <= Log.LogLevel.debug.rawValue {
            let message: String = createLog(text, levelString: "DEBUG", functionName: functionName, fileName: fileName, line: line)
            logger.debug("\(message)")
        }
    }

    func info(_ text: String, functionName: String, fileName: String, line: Int) {
        if outputLogLevel.withLock({ $0.rawValue }) <= Log.LogLevel.info.rawValue {
            let message: String = createLog(text, levelString: "INFO", functionName: functionName, fileName: fileName, line: line)
            logger.info("\(message)")
        }
    }

    func warn(_ text: String, functionName: String, fileName: String, line: Int) {
        if outputLogLevel.withLock({ $0.rawValue }) <= Log.LogLevel.warn.rawValue {
            let message: String = createLog(text, levelString: "WARN", functionName: functionName, fileName: fileName, line: line)
            logger.warning("\(message)")
        }
    }

    func error(_ text: String, functionName: String, fileName: String, line: Int) {
        if outputLogLevel.withLock({ $0.rawValue }) <= Log.LogLevel.error.rawValue {
            let message: String = createLog(text, levelString: "ERROR", functionName: functionName, fileName: fileName, line: line)
            logger.fault("\(message)")
        }
    }

    func createLog(_ text: String, levelString: String, functionName: String, fileName: String, line: Int) -> String {
        let resolvedTag: String = tag.isEmpty ? "" : "\(tag) "
        return "\(resolvedTag)[\(levelString)] \(text) | \(functionName) \(fileName):\(line)"
    }
}
