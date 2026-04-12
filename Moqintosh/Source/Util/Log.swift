//
//  OSLogger.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2025/01/29.
//

import Foundation
import os

private final class BundleToken {}

public final class Log {

    public enum LogLevel: Int, Sendable {
        case none = 0
        case trace = 1
        case debug = 2
        case info = 3
        case warn = 4
        case error = 5
    }
    static let logger: InternalLog = InternalLog()

    static public func setLogLevel(_ level: LogLevel) {
        logger.setLogLevel(level)
    }

    static func trace(_ text: String, functionName: String = #function, fileName: String = #file, line: Int = #line) {
        logger.trace(text, functionName: functionName, fileName: fileName, line: line)
    }

    static func debug(_ text: String, functionName: String = #function, fileName: String = #file, line: Int = #line) {
        logger.debug(text, functionName: functionName, fileName: fileName, line: line)
    }

    static func info(_ text: String, functionName: String = #function, fileName: String = #file, line: Int = #line) {
        logger.info(text, functionName: functionName, fileName: fileName, line: line)
    }

    static func warn(_ text: String, functionName: String = #function, fileName: String = #file, line: Int = #line) {
        logger.warn(text, functionName: functionName, fileName: fileName, line: line)
    }

    static func error(_ text: String, functionName: String = #function, fileName: String = #file, line: Int = #line) {
        logger.error(text, functionName: functionName, fileName: fileName, line: line)
    }
}

typealias OSLogger = Log
