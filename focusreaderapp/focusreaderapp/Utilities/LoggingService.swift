import Foundation
import os.log

/// Centralized logging service for the entire application
/// Provides consistent logging across all components with standardized categories and formatting
class LoggingService {
    // MARK: - Log Categories
    
    /// Standard log categories used across the application
    enum Category: String {
        case ui = "UI"
        case contentProcessing = "ContentProcessing"
        case fileSystem = "FileSystem"
        case parsing = "Parsing"
        case networking = "Networking"
        case performance = "Performance"
        case javascript = "JavaScript"
        case general = "General"
        
        /// Returns OSLog category name in lowercase
        var osLogCategory: String {
            return self.rawValue.lowercased()
        }
    }
    
    // MARK: - Log Levels
    
    /// Log levels aligned with OSLog severity levels
    enum Level {
        case debug
        case info
        case notice
        case warning
        case error
        case fault
        
        /// Maps LoggingService level to OSLog type
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .notice: return .default
            case .warning: return .error
            case .error: return .error
            case .fault: return .fault
            }
        }
    }
    
    // MARK: - Singleton Access
    
    /// Shared singleton instance
    static let shared = LoggingService()
    
    /// App subsystem identifier - should match the bundle identifier
    private let subsystem = "com.focusreaderapp"
    
    /// Cache of created loggers to avoid recreating them
    private var loggers: [String: Logger] = [:]
    
    private init() {}
    
    // MARK: - Core Logging Methods
    
    /// Logs a message with the specified category and level
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - level: The log severity level
    ///   - function: The calling function (auto-filled)
    ///   - file: The calling file (auto-filled)
    ///   - line: The calling line (auto-filled)
    func log(
        _ message: String,
        category: Category,
        level: Level,
        function: String = #function,
        file: String = #fileID,
        line: Int = #line
    ) {
        let logger = getLogger(for: category)
        
        // Format metadata for contextual information
        let metadata = "[\(file):\(line) \(function)]"
        
        // Log with appropriate level
        switch level {
        case .debug:
            logger.debug("\(metadata) \(message)")
        case .info:
            logger.info("\(metadata) \(message)")
        case .notice:
            logger.notice("\(metadata) \(message)")
        case .warning:
            logger.warning("\(metadata) \(message)")
        case .error:
            logger.error("\(metadata) \(message)")
        case .fault:
            logger.fault("\(metadata) \(message)")
        }
    }
    
    /// Gets or creates a logger for the specified category
    /// - Parameter category: The log category
    /// - Returns: An OSLog logger
    private func getLogger(for category: Category) -> Logger {
        let categoryKey = category.osLogCategory
        
        if let existingLogger = loggers[categoryKey] {
            return existingLogger
        }
        
        let newLogger = Logger(subsystem: subsystem, category: categoryKey)
        loggers[categoryKey] = newLogger
        return newLogger
    }
    
    // MARK: - Convenience Methods
    
    /// Logs a debug message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - function: The calling function (auto-filled)
    ///   - file: The calling file (auto-filled)
    ///   - line: The calling line (auto-filled)
    func debug(
        _ message: String,
        category: Category = .general,
        function: String = #function,
        file: String = #fileID,
        line: Int = #line
    ) {
        log(message, category: category, level: .debug, function: function, file: file, line: line)
    }
    
    /// Logs an info message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - function: The calling function (auto-filled)
    ///   - file: The calling file (auto-filled)
    ///   - line: The calling line (auto-filled)
    func info(
        _ message: String,
        category: Category = .general,
        function: String = #function,
        file: String = #fileID,
        line: Int = #line
    ) {
        log(message, category: category, level: .info, function: function, file: file, line: line)
    }
    
    /// Logs a warning message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - function: The calling function (auto-filled)
    ///   - file: The calling file (auto-filled)
    ///   - line: The calling line (auto-filled)
    func warning(
        _ message: String,
        category: Category = .general,
        function: String = #function,
        file: String = #fileID,
        line: Int = #line
    ) {
        log(message, category: category, level: .warning, function: function, file: file, line: line)
    }
    
    /// Logs an error message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - function: The calling function (auto-filled)
    ///   - file: The calling file (auto-filled)
    ///   - line: The calling line (auto-filled)
    func error(
        _ message: String,
        category: Category = .general,
        function: String = #function,
        file: String = #fileID,
        line: Int = #line
    ) {
        log(message, category: category, level: .error, function: function, file: file, line: line)
    }
    
    /// Logs a critical error message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The log category
    ///   - function: The calling function (auto-filled)
    ///   - file: The calling file (auto-filled)
    ///   - line: The calling line (auto-filled)
    func critical(
        _ message: String,
        category: Category = .general,
        function: String = #function,
        file: String = #fileID,
        line: Int = #line
    ) {
        log(message, category: category, level: .fault, function: function, file: file, line: line)
    }
    
    // MARK: - Feature-Specific Logging
    
    /// Logs service call information
    /// - Parameters:
    ///   - service: The name of the service being called
    ///   - method: The method being called
    ///   - parameters: Optional parameters to include in the log
    ///   - function: The calling function (auto-filled)
    ///   - file: The calling file (auto-filled)
    ///   - line: The calling line (auto-filled)
    func logServiceCall(
        service: String,
        method: String,
        parameters: [String: Any]? = nil,
        function: String = #function,
        file: String = #fileID,
        line: Int = #line
    ) {
        var message = "Calling service: \(service).\(method)"
        
        if let parameters = parameters {
            let paramString = parameters.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            message += " with parameters: [\(paramString)]"
        }
        
        log(message, category: .general, level: .debug, function: function, file: file, line: line)
    }
    
    /// Logs performance metrics
    /// - Parameters:
    ///   - operation: The operation being measured
    ///   - timeInMilliseconds: The time taken in milliseconds
    ///   - metadata: Additional contextual information
    ///   - function: The calling function (auto-filled)
    ///   - file: The calling file (auto-filled)
    ///   - line: The calling line (auto-filled)
    func logPerformance(
        operation: String,
        timeInMilliseconds: Double,
        metadata: [String: Any]? = nil,
        function: String = #function,
        file: String = #fileID,
        line: Int = #line
    ) {
        var message = "Performance: \(operation) took \(timeInMilliseconds)ms"
        
        if let metadata = metadata {
            let metadataString = metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            message += " [\(metadataString)]"
        }
        
        log(message, category: .performance, level: .debug, function: function, file: file, line: line)
    }
} 