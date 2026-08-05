//
//  Logger.swift
//  nest-note
//
//  Created by Colton Swapp on 11/2/24.
//

import Foundation
import Combine
import OSLog

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

    /// Observed on the main thread only. Mutations hop to the MainActor.
    @Published public private(set) var lines: [LogLine] = []

    private let maxLogLines = 5000

    /// Owned exclusively by `appendQueue` — never touch from caller threads.
    private let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private init() {
        register(SystemProvider())
    }

    public static func register(_ provider: LogProvider) {
        shared.register(provider)
    }

    private func register(_ provider: LogProvider) {
        appendQueue.sync {
            providers.append(provider)
        }
    }

    public static func log(level: Level, category: Category?, message: String) {
        shared.log(level: level, category: category, message: message)
    }

    public static func log(level: Level, message: String) {
        Self.log(level: level, category: .general, message: message)
    }

    private func log(level: Level, category: Category?, message: String) {
        // Capture value types on the caller, then do all formatting and mutation
        // on the serial queue so concurrent Swift-concurrency callers cannot race
        // DateFormatter / StringGuts / providers / lines.
        let categoryValue = category?.rawValue ?? ""
        let now = Date()

        appendQueue.async { [weak self] in
            guard let self else { return }

            let logLine = LogLine(
                timestamp: self.timestampFormatter.string(from: now),
                level: level,
                category: categoryValue,
                content: message
            )

            let providerMessage = "## \(logLine.description)"
            for provider in self.providers {
                provider.log(level: level, category: category, message: providerMessage)
            }

            DispatchQueue.main.async {
                self.lines.append(logLine)
                if self.lines.count >= self.maxLogLines {
                    self.lines.removeFirst()
                }
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
        case referral = "🎟️ Referral"
        case paywall = "🤑 Paywall"
    }

}

final class SystemProvider: LogProvider {

    private var subsystem = Bundle.main.bundleIdentifier

    /// Called only from Logger's serial `appendQueue`.
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    func log(level: Logger.Level, category: Logger.Category?, message: String) {
        let dateString = dateFormatter.string(from: Date())
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
