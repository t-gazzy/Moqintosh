//
//  OSLogger.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2025/01/29.
//

import Foundation
import os

private final class BundleToken {}

final class OSLogger {

    enum LogLevel: Int, Sendable {
        case none = 0
        case trace = 1
        case debug = 2
        case info = 3
        case warn = 4
        case error = 5
    }

    static let tag: String = "[🍎MOQINTOSH]"
    // Default log level is set to .trace for maximum verbosity. Adjust as needed.
    // nonisolated(unsafe) is used here to allow changing the log level from any thread without synchronization,
    // since it's expected to be set once at startup.
    nonisolated(unsafe) static var outputLogLevel: LogLevel = .trace

    private static let logger: Logger = Logger(
        subsystem: Bundle(for: BundleToken.self).bundleIdentifier ?? "Moqintosh",
        category: "Moqintosh"
    )

    static func trace(_ text: String, functionName: String = #function, fileName: String = #file, line: Int = #line) {
        if outputLogLevel.rawValue <= LogLevel.trace.rawValue {
            let message: String = createLog(text, levelString: "TRACE", functionName: functionName, fileName: fileName, line: line)
            logger.trace("\(message)")
        }
    }

    static func debug(_ text: String, functionName: String = #function, fileName: String = #file, line: Int = #line) {
        if outputLogLevel.rawValue <= LogLevel.debug.rawValue {
            let message: String = createLog(text, levelString: "DEBUG", functionName: functionName, fileName: fileName, line: line)
            logger.debug("\(message)")
        }
    }

    static func info(_ text: String, functionName: String = #function, fileName: String = #file, line: Int = #line) {
        if outputLogLevel.rawValue <= LogLevel.info.rawValue {
            let message: String = createLog(text, levelString: "INFO", functionName: functionName, fileName: fileName, line: line)
            logger.info("\(message)")
        }
    }

    static func warn(_ text: String, functionName: String = #function, fileName: String = #file, line: Int = #line) {
        if outputLogLevel.rawValue <= LogLevel.warn.rawValue {
            let message: String = createLog(text, levelString: "WARN", functionName: functionName, fileName: fileName, line: line)
            logger.warning("\(message)")
        }
    }

    static func error(_ text: String, functionName: String = #function, fileName: String = #file, line: Int = #line) {
        if outputLogLevel.rawValue <= LogLevel.error.rawValue {
            let message: String = createLog(text, levelString: "ERROR", functionName: functionName, fileName: fileName, line: line)
            logger.fault("\(message)")
        }
    }

    private static func createLog(_ text: String, levelString: String, functionName: String, fileName: String, line: Int) -> String {
        let _tag = tag.isEmpty ? "" : "\(tag) "
        return "\(_tag)[\(levelString)] \(text) | \(functionName) \(fileName):\(line)"
    }
}
