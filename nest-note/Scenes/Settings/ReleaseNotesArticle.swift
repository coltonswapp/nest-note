//
//  ReleaseNotesArticle.swift
//  nest-note
//
//  Loads in-app release notes from Resources/release-notes.md.
//  Update that markdown file with each App Store release.
//

import Foundation

enum ReleaseNotesArticle {

    private static let resourceName = "release-notes"

    static var markdown: String {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Logger.log(
                level: .error,
                category: .general,
                message: "Failed to load bundled markdown: \(resourceName).md"
            )
            return fallbackMarkdown
        }
        return injectingAppVersion(into: text)
    }

    private static func injectingAppVersion(into text: String) -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        return text.replacingOccurrences(of: "{{APP_VERSION}}", with: version)
    }

    private static let fallbackMarkdown = """
    # Release Notes

    We couldn't load release notes right now. Please try again, or contact support@nestnoteapp.com for help.
    """
}
