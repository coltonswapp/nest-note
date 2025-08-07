//
//  Logger.swift
//  nest-note
//
//  Created by Colton Swapp on 11/2/24.
//

import Foundation
import Combine

public protocol LogProvider {

    func log(level: Logger.Level, category: Logger.Category?, message: String)

}

public struct LogLine: CustomStringConvertible {
    let timestamp: String
    let level: Logger.Level
    let category: String
    let content: String
    
    public var description: String {
        if category.isEmpty {
            return content
        }
        return "[\(category)] \(content)"
    }
}

public final class Logger {

    public static let shared = Logger()

    private var providers: [LogProvider] = []
    private let appendQueue = DispatchQueue(label: "com.nest-note.loggerQueue")

    @Published public private(set) var lines: [LogLine] = []

    private let maxLogLines = 5000

    private init() {
        register(SystemProvider())
    }

    public static func register(_ provider: LogProvider) {
        self.shared.providers.append(provider)
    }

    private func register(_ provider: LogProvider) {
        providers.append(provider)
    }

    public static func log(level: Level, category: Category?, message: String) {
        self.shared.log(level: level, category: category, message: message)
    }

    public static func log(level: Level, message: String) {
        Self.log(level: level, category: .general, message: message)
    }

    private func log(level: Level, category: Category?, message: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        
        let logLine = LogLine(
            timestamp: dateFormatter.string(from: Date()),
            level: level,
            category: category?.rawValue ?? "",
            content: message
        )
        
        appendQueue.async { [weak self] in
            guard let self else { return }
            
            lines.append(logLine)
            
            if lines.count >= maxLogLines {
                lines.removeFirst()
            }
            
            for provider in providers {
                provider.log(level: level, category: category, message: "## \(logLine.description)")
            }
        }
    }
}

public extension Logger {

    enum Level: String {
        case notice
        case info
        case debug
        case error
    }

    enum Category: String {
        case general = "General"

        case launcher = "🚀 Launcher"
        case router = "🚦 Router"

        case auth = "🧑🏼‍🦯 Auth"
        case signup = "🥽 Signup"

        case userService = "🧍🏼 UserService"
        case nestService = "👨🏼‍🤝‍👨🏽 NestService"
        case sitterViewService = "🧘‍♂️ SitterViewService"
        case sessionService = "📅 SessionService"
        
        case firebaseItemRepo = "🔥 FirebaseItemRepo"
        
        case placesService = "🏙️ PlaceService"

        case cachedImageController = "🗾 CachedImageController"
        
        case routineStateManager = "🕒 RoutineStateManager"

        case purchases = "💰 Purchases"
        case subscription = "💵 Subscriptions"
        case migration = "🦣 Migrations"

        case testing = "🧪 Testing"
        case survey = "📝 Survey"
    }

}

import Foundation
import OSLog

final class SystemProvider: LogProvider {

    private var subsystem = Bundle.main.bundleIdentifier

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private var dateString: String {
        dateFormatter.string(from: Date())
    }

    func log(level: Logger.Level, category: Logger.Category?, message: String) {
        os_log("%{public}@", type: level.osLogType, "LinusLog: \(dateString) \(message)")
    }
}

private extension Logger.Level {

    var osLogType: OSLogType {
        switch self {
        case .notice:
            return .default
        case .info:
            return .info
        case .debug:
            return .debug
        case .error:
            return .error
        }
    }
}
