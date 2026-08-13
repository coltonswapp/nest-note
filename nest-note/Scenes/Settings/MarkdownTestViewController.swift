//
//  MarkdownTestViewController.swift
//  nest-note
//

import MarkdownUI
import SwiftUI
import UIKit

final class MarkdownTestViewController: NNViewController {

    private let markdownBody: String
    private let showsShareButton: Bool

    /// Space below the markdown so the last lines stay above the floating share button.
    private static let markdownScrollBottomInset: CGFloat = 96

    /// - Parameters:
    ///   - markdown: Raw markdown string. Defaults to the built-in lorem preview.
    ///   - showsShareButton: When false, omits the floating share CTA (e.g. in-app help articles).
    init(markdown: String = MarkdownPreviewView.sampleMarkdown, showsShareButton: Bool = true) {
        self.markdownBody = markdown
        self.showsShareButton = showsShareButton
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var markdownHost: UIHostingController<MarkdownPreviewView> = {
        let bottomPadding = showsShareButton ? Self.markdownScrollBottomInset : 24
        let host = UIHostingController(
            rootView: MarkdownPreviewView(
                markdown: markdownBody,
                scrollBottomPadding: bottomPadding
            )
        )
        host.view.backgroundColor = .clear
        return host
    }()

    private lazy var shareNestNoteButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(
            title: String(localized: "Share NestNote"),
            image: UIImage(systemName: "square.and.arrow.up")
        )
        button.addTarget(self, action: #selector(shareNestNoteTapped), for: .touchUpInside)
        return button
    }()

    /// iOS 26+: liquid glass; earlier: material blur + fallback styling (matches `SelectItemsCountView` / `BlurBackgroundLabel`).
    private lazy var closeGlassView: UIVisualEffectView = {
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: .regular)
            glass.isInteractive = true
            effect = glass
        } else {
            effect = UIBlurEffect(style: .systemChromeMaterial)
        }
        let wrap = UIVisualEffectView(effect: effect)
        wrap.translatesAutoresizingMaskIntoConstraints = false
        wrap.layer.cornerRadius = 22
        wrap.clipsToBounds = true

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        button.tintColor = .label
        button.backgroundColor = .clear
        button.accessibilityLabel = String(localized: "Close")
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        wrap.contentView.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: wrap.contentView.topAnchor),
            button.leadingAnchor.constraint(equalTo: wrap.contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: wrap.contentView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: wrap.contentView.bottomAnchor),
        ])
        return wrap
    }()

    override func setup() {
        navigationItem.title = nil
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    override func addSubviews() {
        addChild(markdownHost)
        markdownHost.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(markdownHost.view)
        markdownHost.didMove(toParent: self)
        view.addSubview(closeGlassView)
        guard showsShareButton else { return }
        let blurImage = UIImage(named: "testBG3")
        shareNestNoteButton.pinToBottom(
            of: view,
            addBlurEffect: blurImage != nil,
            blurMaskImage: blurImage
        )
    }

    override func constrainSubviews() {
        NSLayoutConstraint.activate([
            markdownHost.view.topAnchor.constraint(equalTo: view.topAnchor),
            markdownHost.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            markdownHost.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            markdownHost.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            closeGlassView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeGlassView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            closeGlassView.widthAnchor.constraint(equalToConstant: 44),
            closeGlassView.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    @objc private func closeTapped() {
        // Dismiss when presented modally (e.g. as a sheet); pop when pushed onto a stack.
        if presentingViewController != nil || navigationController?.presentingViewController?.presentedViewController === navigationController {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    @objc private func shareNestNoteTapped() {
        let message = Self.nestNoteShareBlurb
        let activityVC = UIActivityViewController(
            activityItems: [message, Self.nestNoteAppStoreURL],
            applicationActivities: nil
        )
        HapticsHelper.lightHaptic()
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareNestNoteButton
            popover.sourceRect = shareNestNoteButton.bounds
        }
        present(activityVC, animated: true)
    }

    // https://apps.apple.com/us/app/sitting-guides-nestnote/id6744369370
    private static let nestNoteAppStoreURL = URL(string: "https://apps.apple.com/us/app/sitting-guides-nestnote/id6744369370")!

    private static let nestNoteShareBlurb = """
    NestNote is the babysitter binder app—a digital guide where families and sitters keep Wi‑Fi, codes, routines, contacts, and session details in one organized place instead of scattered texts and notes.
    """
}

// MARK: - SwiftUI

/// Flat `rectangle_pattern_small` strip, same pattern as `SessionStatusInfoViewController` (primary tint, modest opacity).
private struct MarkdownBrandBanner: View {
    /// Matches e.g. `SessionStatusInfoViewController` / login flows using `0.4`.
    private static let opacity: CGFloat = 0.4

    private var heightMultiplier: CGFloat { NNAssetType.rectanglePatternSmall.heightMultiplier }

    var body: some View {
        GeometryReader { geo in
            Image(NNAssetType.rectanglePatternSmall.rawValue)
                .resizable()
                .renderingMode(.template)
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.width * heightMultiplier)
                .clipped()
                .foregroundStyle(Color(NNColors.primary))
                .opacity(Double(Self.opacity))
        }
        .aspectRatio(1 / heightMultiplier, contentMode: .fit)
    }
}

private struct MarkdownPreviewView: View {
    let markdown: String
    var scrollBottomPadding: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MarkdownBrandBanner()
                Markdown(markdown)
                    .markdownTheme(.nestNoteGitHub)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .padding(.bottom, scrollBottomPadding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.clear)
        .ignoresSafeArea(edges: .top)
    }
}

private extension MarkdownPreviewView {
    static let sampleMarkdown = """
    # Lorem Markdown Preview

    **Bold lorem** and *italic ipsum* with ~~strikethrough dolor~~. Inline `codeSnippet()` sits mid-sentence.

    ## Second-level heading

    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.

    ### Third-level heading

    Try a [sample link](https://example.com) and more lorem: ut enim ad minim veniam, quis nostrud exercitation.

    ---

    ## Lists

    - Unordered lorem
    - Unordered ipsum
      - Nested dolor
      - Nested sit

    1. Ordered amet
    2. Ordered consectetur
    3. Ordered adipiscing

    ## Task list

    - [x] Preview **MarkdownUI** in NestNote
    - [ ] Replace lorem with real copy
    - [ ] Tune theme for brand colors

    ## Blockquote

    > Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur.

    ## Code block

    ```swift
    func greet(_ name: String) -> String {
        "Hello, \\(name) — lorem ipsum!"
    }
    ```

    ## Table

    | Column Lorem | Column Ipsum | Column Dolor |
    | --- | --- | --- |
    | Alpha | 10 | Sit |
    | Beta | 20 | Amet |
    | Gamma | 30 | Consectetur |
    """
}
