//
//  NestNoteMarkdownTheme.swift
//  nest-note
//

import MarkdownUI
import SwiftUI
import UIKit

extension Theme {
    /// GitHub-style markdown with SF Rounded on headings (body stays default).
    static var nestNoteGitHub: Theme {
        Theme.gitHub
            // GitHub's dark background (#18191d) doesn't match `systemBackground` (near-black),
            // so the padded markdown content reads as a different-colored panel in dark mode.
            .text {
                ForegroundColor(Color(.label))
                BackgroundColor(Color(.systemBackground))
                FontSize(16)
            }
            .heading1 { configuration in
                VStack(alignment: .leading, spacing: 0) {
                    configuration.label
                        .relativePadding(.bottom, length: .em(0.3))
                        .relativeLineSpacing(.em(0.125))
                        .markdownMargin(top: 24, bottom: 16)
                        .markdownTextStyle {
                            FontFamily(.system(.rounded))
                            FontWeight(.semibold)
                            FontSize(.em(2))
                        }
                    Divider().overlay(Color(uiColor: .separator))
                }
            }
            .heading2 { configuration in
                VStack(alignment: .leading, spacing: 0) {
                    configuration.label
                        .relativePadding(.bottom, length: .em(0.3))
                        .relativeLineSpacing(.em(0.125))
                        .markdownMargin(top: 24, bottom: 16)
                        .markdownTextStyle {
                            FontFamily(.system(.rounded))
                            FontWeight(.semibold)
                            FontSize(.em(1.5))
                        }
                    Divider().overlay(Color(uiColor: .separator))
                }
            }
            .heading3 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 24, bottom: 16)
                    .markdownTextStyle {
                        FontFamily(.system(.rounded))
                        FontWeight(.semibold)
                        FontSize(.em(1.25))
                    }
            }
            .heading4 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 24, bottom: 16)
                    .markdownTextStyle {
                        FontFamily(.system(.rounded))
                        FontWeight(.semibold)
                    }
            }
            .heading5 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 24, bottom: 16)
                    .markdownTextStyle {
                        FontFamily(.system(.rounded))
                        FontWeight(.semibold)
                        FontSize(.em(0.875))
                    }
            }
            .heading6 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 24, bottom: 16)
                    .markdownTextStyle {
                        FontFamily(.system(.rounded))
                        FontWeight(.semibold)
                        FontSize(.em(0.85))
                        ForegroundColor(Color(UIColor.tertiaryLabel))
                    }
            }
    }
}
