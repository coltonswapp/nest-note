//
//  HowItWorksArticle.swift
//  nest-note
//
//  Loads the in-app “How NestNote Works” guide from Resources/how-it-works.md.
//

import Foundation

enum HowItWorksArticle {

    private static let resourceName = "how-it-works"

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
        return text
    }

    private static let fallbackMarkdown = """
    # How NestNote Works

    We couldn't load this guide right now. Please try again, or contact support@nestnoteapp.com for help.
    """
}
