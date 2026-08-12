//
//  OBFolderPreviewViewController.swift
//  nest-note
//
//  Two-state animated onboarding screen: folder grid → folder detail preview.
//

import UIKit

final class OBFolderPreviewViewController: NNOnboardingViewController {

    // MARK: - Types

    enum DisplayState: Equatable {
        case folderGrid
        case folderDetail
    }

    private struct PreviewItem {
        enum Kind {
            case note
            case routine
            case place
        }

        let title: String
        let content: String
        let kind: Kind
        /// Asset name for place cards (`map-placeholder1`…`5`).
        let mapPlaceholderName: String?
    }

    /// Tappable wrapper so folder cells get press chrome outside a collection view.
    private final class FolderGridItemView: UIControl {
        let folderCell: FolderCollectionViewCell
        let folderIndex: Int

        init(folder: FolderData, index: Int) {
            self.folderIndex = index
            self.folderCell = OBFolderPreviewViewController.makeStandaloneFolderCell()
            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = false
            folderCell.isUserInteractionEnabled = false
            folderCell.configure(with: folder)
            folderCell.resetPressAppearance()

            // Animate the wrapper, not the cell — cell stays fully opaque inside.
            alpha = 0
            transform = CGAffineTransform(scaleX: 0.55, y: 0.55)

            addSubview(folderCell)
            NSLayoutConstraint.activate([
                folderCell.topAnchor.constraint(equalTo: topAnchor),
                folderCell.leadingAnchor.constraint(equalTo: leadingAnchor),
                folderCell.trailingAnchor.constraint(equalTo: trailingAnchor),
                folderCell.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var isHighlighted: Bool {
            didSet { folderCell.isHighlighted = isHighlighted }
        }
    }

    // MARK: - Public

    /// Called when Continue is tapped (experiment / coordinator wiring).
    var onContinue: (() -> Void)?

    /// Returns `true` when back was consumed by collapsing detail → grid.
    @discardableResult
    func handleBackIfNeeded() -> Bool {
        guard displayState == .folderDetail, !isAnimatingTransition else { return false }
        collapseToGrid(animated: true)
        return true
    }

    var displayState: DisplayState { state }

    // MARK: - State

    private var state: DisplayState = .folderGrid
    private var folders: [FolderData]
    private var selectedFolder: FolderData?
    private var selectedFolderIndex: Int?
    private var previewItems: [PreviewItem] = []
    private var isAnimatingTransition = false
    private var hasPlayedFolderEntrance = false
    private var hasCascadedItems = false
    private var hasFocusedFolder = false

    private var folderItems: [FolderGridItemView] = []
    private let sizingCell = WaterfallGridCell(frame: .zero)
    private var waterfallHeightCache: [IndexPath: CGFloat] = [:]
    private let folderEntranceFeedback = UIImpactFeedbackGenerator(style: .light)

    // MARK: - UI

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
        return scrollView
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let folderGridContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Hosts a snapshot of the selected folder so papers/tab stay pixel-identical after focus.
    private let heroFolderContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.alpha = 0
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var waterfallCollectionView: UICollectionView = {
        let layout = WaterfallCollectionLayout()
        layout.delegate = self
        layout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 16, right: 16)
        layout.columnSpacing = 12
        layout.rowSpacing = 12
        layout.sectionSpacing = 0

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.allowsSelection = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            WaterfallGridCell.self,
            forCellWithReuseIdentifier: WaterfallGridCell.reuseIdentifier
        )
        collectionView.isHidden = true
        collectionView.alpha = 0
        return collectionView
    }()

    private lazy var backButton: GlassIconButton = {
        let button = GlassIconButton(
            systemName: "chevron.left",
            pointSize: 15,
            weight: .semibold,
            tintColor: .label,
            size: Self.backButtonSize,
            accessibilityLabel: "Back"
        )
        button.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        button.alpha = 0
        button.isUserInteractionEnabled = false
        return button
    }()

    private let editabilityFooterLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Folders can be added to and edited later."
        label.font = .bodyS
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private var folderGridHeightConstraint: NSLayoutConstraint!
    private var heroFolderWidthConstraint: NSLayoutConstraint!
    private var heroFolderHeightConstraint: NSLayoutConstraint!
    private var waterfallHeightConstraint: NSLayoutConstraint!
    private var folderBottomToContentConstraint: NSLayoutConstraint!
    private var waterfallBottomToContentConstraint: NSLayoutConstraint!
    /// Centers the back button under the hero (hidden “behind” the folder).
    private var backButtonCenterXConstraint: NSLayoutConstraint!
    /// Parks the back button to the leading side of the hero.
    private var backButtonTrailingToHeroConstraint: NSLayoutConstraint!

    // MARK: - Constants

    private static let folderCellHeight: CGFloat = 144
    private static let heroFolderHeight: CGFloat = 144
    private static let folderRowSpacing: CGFloat = 16
    private static let folderColumnSpacing: CGFloat = 16
    private static let folderGridHorizontalInset: CGFloat = 18
    private static let maxFolderCount = 5
    private static let backButtonSize: CGFloat = 40
    private static let backButtonSpacing: CGFloat = 12
    /// Extra space below the header before the folder grid (scroll content inset).
    private static let gridContentTopPadding: CGFloat = 36

    // MARK: - Init

    init(folders: [FolderData]) {
        self.folders = Array(folders.prefix(Self.maxFolderCount))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        shouldHandleKeyboard = false

        let isSingleFolder = folders.count == 1
        setupOnboarding(
            title: isSingleFolder
                ? "Your folder has been created!"
                : "Your folders have been created!",
            subtitle: isSingleFolder
                ? "Select your folder to preview what yours could look like."
                : "Select a folder to preview what yours could look like."
        )
        setupContent()
        setupBackButton()
        buildFolderGrid()
        addCTAButton(title: "Continue")
        ctaButton?.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        setupEditabilityFooter()
        setContinueButtonVisible(false, animated: false)

        updateFolderGridHeight()
        installScrollEdgeInteractions(for: scrollView)
        folderEntranceFeedback.prepare()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Detail collapse is back-button only — no edge-swipe pop on this screen.
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        // Keep CTA chrome above the scroll view; footer sits above that.
        if let ctaButton { view.bringSubviewToFront(ctaButton) }
        if let bottom = bottomEdgeContainerView { view.bringSubviewToFront(bottom) }
        view.bringSubviewToFront(editabilityFooterLabel)
        playFolderEntranceIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateFolderGridHeight()
        if state == .folderDetail {
            updateWaterfallHeight()
        }
    }

    // MARK: - Setup

    override func setupContent() {
        view.insertSubview(scrollView, belowSubview: headerContainerView)
        scrollView.addSubview(contentView)
        contentView.addSubview(folderGridContainer)
        // Back button sits under the hero so it can start “behind” the folder.
        contentView.addSubview(backButton)
        contentView.addSubview(heroFolderContainer)
        contentView.addSubview(waterfallCollectionView)

        folderGridHeightConstraint = folderGridContainer.heightAnchor.constraint(equalToConstant: 0)
        heroFolderWidthConstraint = heroFolderContainer.widthAnchor.constraint(equalToConstant: 170)
        heroFolderHeightConstraint = heroFolderContainer.heightAnchor.constraint(equalToConstant: 0)
        waterfallHeightConstraint = waterfallCollectionView.heightAnchor.constraint(equalToConstant: 0)

        folderBottomToContentConstraint = folderGridContainer.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -16
        )
        waterfallBottomToContentConstraint = waterfallCollectionView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -24
        )
        waterfallBottomToContentConstraint.isActive = false

        backButtonCenterXConstraint = backButton.centerXAnchor.constraint(
            equalTo: heroFolderContainer.centerXAnchor
        )
        backButtonTrailingToHeroConstraint = backButton.trailingAnchor.constraint(
            equalTo: heroFolderContainer.leadingAnchor,
            constant: -Self.backButtonSpacing
        )
        backButtonTrailingToHeroConstraint.isActive = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            folderGridContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            folderGridContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            folderGridContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            folderGridHeightConstraint,
            folderBottomToContentConstraint,

            heroFolderContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            heroFolderContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            heroFolderWidthConstraint,
            heroFolderHeightConstraint,

            backButton.centerYAnchor.constraint(equalTo: heroFolderContainer.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: Self.backButtonSize),
            backButton.heightAnchor.constraint(equalToConstant: Self.backButtonSize),
            backButtonCenterXConstraint,

            waterfallCollectionView.topAnchor.constraint(equalTo: heroFolderContainer.bottomAnchor, constant: 20),
            waterfallCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            waterfallCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            waterfallHeightConstraint
        ])

        updateScrollContentInset()
        scrollView.contentInset.bottom = 130
        scrollView.verticalScrollIndicatorInsets.bottom = 130
    }

    private func setupEditabilityFooter() {
        view.addSubview(editabilityFooterLabel)

        let bottomAnchor: NSLayoutYAxisAnchor
        if let ctaButton {
            bottomAnchor = ctaButton.topAnchor
        } else {
            bottomAnchor = view.safeAreaLayoutGuide.bottomAnchor
        }

        NSLayoutConstraint.activate([
            editabilityFooterLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            editabilityFooterLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
            editabilityFooterLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    private func buildFolderGrid() {
        folderItems.forEach { $0.removeFromSuperview() }
        folderItems = folders.enumerated().map { index, folder in
            let item = FolderGridItemView(folder: folder, index: index)
            item.addTarget(self, action: #selector(folderItemTapped(_:)), for: .touchUpInside)
            folderGridContainer.addSubview(item)
            return item
        }

        // 2-column grid with equal widths; a lone folder on a row is centered.
        for (index, item) in folderItems.enumerated() {
            let row = index / 2
            let column = index % 2
            let isSoloOnRow = column == 0 && index == folderItems.count - 1 && folderItems.count % 2 == 1

            item.heightAnchor.constraint(equalToConstant: Self.folderCellHeight).isActive = true

            if row == 0 {
                item.topAnchor.constraint(equalTo: folderGridContainer.topAnchor).isActive = true
            } else {
                let above = folderItems[index - 2]
                item.topAnchor.constraint(
                    equalTo: above.bottomAnchor,
                    constant: Self.folderRowSpacing
                ).isActive = true
            }

            if isSoloOnRow {
                item.centerXAnchor.constraint(equalTo: folderGridContainer.centerXAnchor).isActive = true
                // Match the width of a normal half-row cell:
                // (container - 2*inset - columnSpacing) / 2
                item.widthAnchor.constraint(
                    equalTo: folderGridContainer.widthAnchor,
                    multiplier: 0.5,
                    constant: -(Self.folderGridHorizontalInset + Self.folderColumnSpacing / 2)
                ).isActive = true
            } else if column == 0 {
                item.leadingAnchor.constraint(
                    equalTo: folderGridContainer.leadingAnchor,
                    constant: Self.folderGridHorizontalInset
                ).isActive = true
            } else {
                let leading = folderItems[index - 1]
                item.leadingAnchor.constraint(
                    equalTo: leading.trailingAnchor,
                    constant: Self.folderColumnSpacing
                ).isActive = true
                item.trailingAnchor.constraint(
                    equalTo: folderGridContainer.trailingAnchor,
                    constant: -Self.folderGridHorizontalInset
                ).isActive = true
                item.widthAnchor.constraint(equalTo: leading.widthAnchor).isActive = true
            }
        }
    }

    private func updateScrollContentInset(for displayState: DisplayState? = nil) {
        let resolvedState = displayState ?? state
        view.layoutIfNeeded()

        // Prefer the laid-out header bottom; fall back when the header is mid-fade.
        let headerBottom = headerContainerView.convert(labelStack.frame, to: view).maxY
        let absoluteTop: CGFloat
        if resolvedState == .folderGrid {
            let measured = headerBottom > 0
                ? headerBottom + Self.gridContentTopPadding
                : view.safeAreaInsets.top + 120
            absoluteTop = max(measured, view.safeAreaInsets.top + Self.gridContentTopPadding)
        } else {
            absoluteTop = view.safeAreaInsets.top + 8
        }

        scrollView.contentInset.top = absoluteTop
        scrollView.verticalScrollIndicatorInsets.top = absoluteTop
        if resolvedState == .folderGrid, !scrollView.isDragging {
            scrollView.setContentOffset(CGPoint(x: 0, y: -absoluteTop), animated: false)
        }
    }

    private func applyDetailLayoutConstraints() {
        folderBottomToContentConstraint.isActive = false
        waterfallBottomToContentConstraint.isActive = true
    }

    private func applyGridLayoutConstraints() {
        waterfallBottomToContentConstraint.isActive = false
        folderBottomToContentConstraint.isActive = true
    }

    private func setupBackButton() {
        // Installed in `setupContent` under the hero folder; starts hidden behind it.
        resetBackButtonToHiddenPosition()
    }

    private func setContinueButtonVisible(_ visible: Bool, animated: Bool) {
        let updates = {
            self.ctaButton?.alpha = visible ? 1 : 0
            self.ctaButton?.isUserInteractionEnabled = visible
            self.bottomEdgeContainerView?.alpha = visible ? 1 : 0
        }
        if animated {
            UIView.animate(withDuration: 0.28, delay: 0.05, options: [.curveEaseOut], animations: updates)
        } else {
            updates()
        }
    }

    private func resetBackButtonToHiddenPosition() {
        backButtonTrailingToHeroConstraint.isActive = false
        backButtonCenterXConstraint.isActive = true
        backButton.alpha = 0
        backButton.isUserInteractionEnabled = false
        backButton.transform = .identity
        contentView.insertSubview(backButton, belowSubview: heroFolderContainer)
    }

    private func revealBackButtonBesideFolder() {
        contentView.insertSubview(backButton, belowSubview: heroFolderContainer)
        backButton.alpha = 1
        backButton.isUserInteractionEnabled = false
        backButtonCenterXConstraint.isActive = true
        backButtonTrailingToHeroConstraint.isActive = false
        contentView.layoutIfNeeded()

        // Slide out from behind the folder to its leading edge.
        backButtonCenterXConstraint.isActive = false
        backButtonTrailingToHeroConstraint.isActive = true
        UIView.animate(
            withDuration: 0.32,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.6,
            options: [.curveEaseOut],
            animations: {
                self.contentView.layoutIfNeeded()
            },
            completion: { _ in
                self.backButton.isUserInteractionEnabled = true
                // Keep tappable above scroll content once parked beside the folder.
                self.contentView.bringSubviewToFront(self.backButton)
            }
        )
    }

    private func hideBackButton(animated: Bool) {
        backButton.isUserInteractionEnabled = false
        backButton.layer.removeAllAnimations()

        // Fade in place only — don't slide constraints during collapse or it lags the folder.
        let finishHide = {
            self.resetBackButtonToHiddenPosition()
        }

        guard animated, backButton.alpha > 0.01 else {
            finishHide()
            return
        }

        UIView.animate(
            withDuration: 0.12,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState],
            animations: {
                self.backButton.alpha = 0
                self.backButton.transform = CGAffineTransform(scaleX: 0.86, y: 0.86)
            },
            completion: { _ in
                finishHide()
            }
        )
    }

    // MARK: - Actions

    @objc private func backButtonTapped() {
        if handleBackIfNeeded() { return }
        navigationController?.popViewController(animated: true)
    }

    @objc private func continueTapped() {
        if let onContinue {
            onContinue()
            return
        }
        (coordinator as? OnboardingCoordinator)?.next()
    }

    @objc private func folderItemTapped(_ sender: FolderGridItemView) {
        expandFolder(at: sender.folderIndex, from: sender)
    }

    // MARK: - Folder → Detail Transition

    private func expandFolder(at index: Int, from item: FolderGridItemView) {
        guard state == .folderGrid, !isAnimatingTransition else { return }
        guard folders.indices.contains(index) else { return }

        isAnimatingTransition = true
        HapticsHelper.lightHaptic()

        let folder = folders[index]
        selectedFolder = folder
        selectedFolderIndex = index
        previewItems = Self.previewItems(for: folder.title)
        waterfallHeightCache.removeAll()

        let cell = item.folderCell
        item.isHighlighted = false
        cell.resetPressAppearance()

        let startFrame = cell.convert(cell.bounds, to: view)
        let snapshot = cell.snapshotView(afterScreenUpdates: true) ?? {
            let fallback = Self.makeStandaloneFolderCell()
            fallback.translatesAutoresizingMaskIntoConstraints = true
            fallback.frame = startFrame
            fallback.configure(with: folder)
            return fallback
        }()
        snapshot.frame = startFrame
        item.alpha = 0
        view.addSubview(snapshot)

        // Preserve the grid cell's aspect ratio so the snapshot scales uniformly (no text stretch).
        let aspectRatio = startFrame.width / max(startFrame.height, 1)
        let targetHeight = Self.heroFolderHeight
        let targetWidth = targetHeight * aspectRatio
        let detailTopInset = view.safeAreaInsets.top + 8
        let targetFrame = CGRect(
            x: (view.bounds.width - targetWidth) / 2,
            y: detailTopInset + 8,
            width: targetWidth,
            height: targetHeight
        )

        heroFolderContainer.isHidden = false
        heroFolderContainer.alpha = 0
        heroFolderWidthConstraint.constant = targetWidth
        heroFolderHeightConstraint.constant = targetHeight
        heroFolderContainer.subviews.forEach { $0.removeFromSuperview() }
        resetBackButtonToHiddenPosition()

        waterfallCollectionView.isHidden = false
        waterfallCollectionView.alpha = 0
        hasCascadedItems = false
        waterfallCollectionView.reloadData()
        view.layoutIfNeeded()
        updateWaterfallHeight()

        for other in folderItems where other !== item {
            other.isHighlighted = false
            other.folderCell.resetPressAppearance()
            UIView.animate(withDuration: 0.2) {
                other.alpha = 0
                other.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            }
        }

        UIView.animate(
            withDuration: 0.34,
            delay: 0,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.75,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: {
                self.titleLabel.alpha = 0
                self.subtitleLabel.alpha = 0
                self.titleLabel.transform = CGAffineTransform(translationX: 0, y: -18)
                self.subtitleLabel.transform = CGAffineTransform(translationX: 0, y: -12)
                self.headerContainerView.alpha = 0
                self.headerContainerView.isUserInteractionEnabled = false
                self.folderGridContainer.alpha = 0
                self.editabilityFooterLabel.alpha = 0
                snapshot.frame = targetFrame
            },
            completion: { _ in
                snapshot.removeFromSuperview()
                snapshot.translatesAutoresizingMaskIntoConstraints = false
                self.heroFolderContainer.addSubview(snapshot)
                NSLayoutConstraint.activate([
                    snapshot.topAnchor.constraint(equalTo: self.heroFolderContainer.topAnchor),
                    snapshot.leadingAnchor.constraint(equalTo: self.heroFolderContainer.leadingAnchor),
                    snapshot.trailingAnchor.constraint(equalTo: self.heroFolderContainer.trailingAnchor),
                    snapshot.bottomAnchor.constraint(equalTo: self.heroFolderContainer.bottomAnchor)
                ])
                self.heroFolderContainer.alpha = 1

                self.folderGridHeightConstraint.constant = 0
                self.folderGridContainer.isHidden = true
                self.folderGridContainer.alpha = 1
                self.applyDetailLayoutConstraints()
                self.view.layoutIfNeeded()
                self.updateWaterfallHeight()

                self.scrollView.contentInset.top = detailTopInset
                self.scrollView.verticalScrollIndicatorInsets.top = detailTopInset
                self.scrollView.setContentOffset(
                    CGPoint(x: 0, y: -detailTopInset),
                    animated: false
                )

                self.state = .folderDetail
                self.isAnimatingTransition = false
                self.cascadeInWaterfallItems()
                self.revealBackButtonBesideFolder()

                if !self.hasFocusedFolder {
                    self.hasFocusedFolder = true
                    self.setContinueButtonVisible(true, animated: true)
                }
            }
        )
    }

    private func collapseToGrid(animated: Bool) {
        guard state == .folderDetail, !isAnimatingTransition else { return }
        isAnimatingTransition = true
        // Hide immediately so the button doesn't trail the returning folder.
        hideBackButton(animated: false)

        let index = selectedFolderIndex ?? 0
        let heroStartFrame = heroFolderContainer.convert(heroFolderContainer.bounds, to: view)
        let flyingSnapshot = heroFolderContainer.subviews.first

        let finish: (UIView?) -> Void = { snapshot in
            snapshot?.removeFromSuperview()
            self.heroFolderContainer.isHidden = true
            self.heroFolderContainer.alpha = 0
            self.heroFolderContainer.transform = .identity
            self.heroFolderContainer.subviews.forEach { $0.removeFromSuperview() }
            self.heroFolderHeightConstraint.constant = 0
            self.waterfallCollectionView.isHidden = true
            self.waterfallCollectionView.alpha = 0
            self.waterfallCollectionView.transform = .identity
            self.waterfallHeightConstraint.constant = 0
            self.resetBackButtonToHiddenPosition()

            for item in self.folderItems {
                item.isHighlighted = false
                item.folderCell.resetPressAppearance()
                item.alpha = 1
                item.transform = .identity
            }

            self.titleLabel.alpha = 1
            self.subtitleLabel.alpha = 1
            self.titleLabel.transform = .identity
            self.subtitleLabel.transform = .identity
            self.headerContainerView.alpha = 1
            self.headerContainerView.isUserInteractionEnabled = true
            self.editabilityFooterLabel.alpha = 1

            self.selectedFolder = nil
            self.selectedFolderIndex = nil
            self.previewItems = []
            self.state = .folderGrid
            // Restore grid inset after state flips — otherwise folders sit under the title.
            self.view.layoutIfNeeded()
            self.updateScrollContentInset(for: .folderGrid)
            self.isAnimatingTransition = false
            self.hasCascadedItems = false
        }

        applyGridLayoutConstraints()
        folderGridContainer.isHidden = false
        folderGridContainer.alpha = 1
        updateFolderGridHeight()
        // Collapse still has state == .folderDetail here; force grid inset for the return flight.
        updateScrollContentInset(for: .folderGrid)
        view.layoutIfNeeded()

        for item in folderItems {
            item.isHighlighted = false
            item.folderCell.resetPressAppearance()
            if item.folderIndex == index {
                item.alpha = 0
                item.transform = .identity
            } else {
                item.alpha = 0
                item.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            }
        }

        guard animated else {
            finish(flyingSnapshot)
            return
        }

        let targetFrame: CGRect
        if folderItems.indices.contains(index) {
            targetFrame = folderItems[index].convert(folderItems[index].bounds, to: view)
        } else {
            targetFrame = heroStartFrame
        }

        if let snapshot = flyingSnapshot {
            snapshot.removeFromSuperview()
            snapshot.translatesAutoresizingMaskIntoConstraints = true
            snapshot.autoresizingMask = []
            snapshot.frame = heroStartFrame
            view.addSubview(snapshot)
        }
        heroFolderContainer.alpha = 0

        titleLabel.transform = CGAffineTransform(translationX: 0, y: -18)
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: -12)

        UIView.animate(
            withDuration: 0.45,
            delay: 0,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 0.4,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: {
                self.titleLabel.alpha = 1
                self.subtitleLabel.alpha = 1
                self.titleLabel.transform = .identity
                self.subtitleLabel.transform = .identity
                self.headerContainerView.alpha = 1
                self.headerContainerView.isUserInteractionEnabled = true
                self.editabilityFooterLabel.alpha = 1
                self.waterfallCollectionView.alpha = 0
                self.waterfallCollectionView.transform = CGAffineTransform(translationX: 0, y: 20)
                flyingSnapshot?.frame = targetFrame

                for item in self.folderItems where item.folderIndex != index {
                    item.alpha = 1
                    item.transform = .identity
                }
            },
            completion: { _ in
                finish(flyingSnapshot)
            }
        )
    }

    private func playFolderEntranceIfNeeded() {
        guard !hasPlayedFolderEntrance else { return }
        guard !folderItems.isEmpty else {
            hasPlayedFolderEntrance = true
            return
        }

        hasPlayedFolderEntrance = true
        folderGridContainer.layoutIfNeeded()
        folderEntranceFeedback.prepare()

        for (index, item) in folderItems.enumerated() {
            item.folderCell.resetPressAppearance()
            item.alpha = 0
            item.transform = CGAffineTransform(scaleX: 0.55, y: 0.55)

            let delay = 0.06 * Double(index)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.folderEntranceFeedback.impactOccurred(intensity: 0.7)
            }

            UIView.animate(
                withDuration: 0.5,
                delay: delay,
                usingSpringWithDamping: 0.72,
                initialSpringVelocity: 0.55,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: {
                    item.alpha = 1
                    item.transform = .identity
                }
            )
        }
    }

    private func cascadeInWaterfallItems() {
        waterfallCollectionView.layoutIfNeeded()
        waterfallCollectionView.alpha = 1

        let cells = waterfallCollectionView.visibleCells
            .sorted { $0.frame.minY < $1.frame.minY || ($0.frame.minY == $1.frame.minY && $0.frame.minX < $1.frame.minX) }

        for (index, cell) in cells.enumerated() {
            cell.alpha = 0
            cell.transform = CGAffineTransform(translationX: 0, y: 28)
            UIView.animate(
                withDuration: 0.42,
                delay: 0.04 * Double(index),
                usingSpringWithDamping: 0.88,
                initialSpringVelocity: 0.35,
                options: [.curveEaseOut],
                animations: {
                    cell.alpha = 1
                    cell.transform = .identity
                },
                completion: { _ in
                    if index == cells.count - 1 {
                        self.hasCascadedItems = true
                    }
                }
            )
        }

        if cells.isEmpty {
            hasCascadedItems = true
        }
    }

    // MARK: - Layout Helpers

    private func updateFolderGridHeight() {
        guard state == .folderGrid || folderGridContainer.isHidden == false else { return }
        let rows = max(1, Int(ceil(Double(folderItems.count) / 2.0)))
        let height = CGFloat(rows) * Self.folderCellHeight
            + CGFloat(max(0, rows - 1)) * Self.folderRowSpacing
        folderGridHeightConstraint.constant = height
    }

    private func updateWaterfallHeight() {
        waterfallCollectionView.layoutIfNeeded()
        let height = waterfallCollectionView.collectionViewLayout.collectionViewContentSize.height
        waterfallHeightConstraint.constant = max(height, 0)
    }

    // MARK: - Factory

    static func folders(fromCareResponsibilities responsibilities: [String]) -> [FolderData] {
        var categories: [NestCategory] = [
            NestCategory(name: "Household", symbolName: "house.fill", isDefault: true, isPinned: true)
        ]

        for responsibility in responsibilities {
            let category: NestCategory?
            switch responsibility {
            case "Children", "Kids":
                category = NestCategory(name: "Children", symbolName: "figure.child")
            case "Pets":
                category = NestCategory(name: "Pets", symbolName: "pawprint.fill")
            case "Plants":
                category = NestCategory(name: "Plants", symbolName: "leaf.fill")
            case "Household", "House", "Other Home Care", "Emergency":
                category = nil
            default:
                category = NestCategory(name: responsibility, symbolName: "folder.fill")
            }

            if let category, !categories.contains(where: { $0.name == category.name }) {
                categories.append(category)
            }
        }

        return Array(categories.prefix(maxFolderCount)).map { category in
            let itemCount = previewItems(for: category.name).count
            return FolderData(
                title: category.name,
                image: UIImage(systemName: category.symbolName),
                itemCount: itemCount,
                fullPath: category.name,
                category: category
            )
        }
    }

    private static func previewItems(for folderTitle: String) -> [PreviewItem] {
        switch folderTitle {
        case "Children", "Kids":
            return childrenPreviewItems
        case "Pets":
            return petsPreviewItems
        case "Plants":
            return plantsPreviewItems
        default:
            return householdPreviewItems
        }
    }

    private static let householdPreviewItems: [PreviewItem] = [
        PreviewItem(title: "WiFi Password", content: "SuperStrongPassword", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "Garage Code", content: "8005", kind: .note, mapPlaceholderName: nil),
        PreviewItem(
            title: "Leaving House",
            content: WaterfallGridCell.routinePreviewText(for: [
                "Check all doors", "Turn off lights", "Set thermostat", "Lock windows", "Arm security system"
            ]),
            kind: .routine,
            mapPlaceholderName: nil
        ),
        PreviewItem(title: "Trash Day", content: "Bins out Tuesday night. Recycling every other week (blue bin).", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "Alarm Code", content: "4321 — disarm within 30 seconds of opening the door.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(
            title: "Coming Home",
            content: WaterfallGridCell.routinePreviewText(for: [
                "Disarm alarm", "Hang keys by door", "Unpack bags", "Wash hands"
            ]),
            kind: .routine,
            mapPlaceholderName: nil
        ),
        PreviewItem(title: "Thermostat", content: "Keep around 68°F. Away mode is fine overnight.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "Water Shutoff", content: "Basement, north wall — red valve.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "Neighbor Help", content: "Mrs. Wilson — (555) 234-5678", kind: .place, mapPlaceholderName: "map-placeholder2")
    ]

    private static let childrenPreviewItems: [PreviewItem] = [
        PreviewItem(title: "Allergies", content: "Peanuts and penicillin. EpiPen on the top shelf in the pantry.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(
            title: "Bedtime Routine",
            content: WaterfallGridCell.routinePreviewText(for: [
                "Brush teeth", "Put on pajamas", "Read a story", "Turn on nightlight", "Close door halfway"
            ]),
            kind: .routine,
            mapPlaceholderName: nil
        ),
        PreviewItem(title: "School Office", content: "(555) 111-2222 — ask for the front desk.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(
            title: "After School",
            content: WaterfallGridCell.routinePreviewText(for: [
                "Hang up backpack", "Wash hands", "Have a snack", "Start homework"
            ]),
            kind: .routine,
            mapPlaceholderName: nil
        ),
        PreviewItem(title: "Pediatrician", content: "Dr. Smith — (555) 987-6543", kind: .note, mapPlaceholderName: nil),
        PreviewItem(
            title: "Bath Time",
            content: WaterfallGridCell.routinePreviewText(for: [
                "Fill tub to marked line", "Wash hair", "Rinse thoroughly", "Dry off and lotion"
            ]),
            kind: .routine,
            mapPlaceholderName: nil
        ),
        PreviewItem(title: "Screen Time", content: "45 minutes max after homework. Keep volume reasonable.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "School", content: "Lincoln Elementary — drop-off at the main loop.", kind: .place, mapPlaceholderName: "map-placeholder1"),
        PreviewItem(title: "Soccer Practice", content: "Thursday 4:30pm at Rec Center Field 2.", kind: .place, mapPlaceholderName: "map-placeholder4")
    ]

    private static let petsPreviewItems: [PreviewItem] = [
        PreviewItem(title: "Pet Names", content: "Dog: Max · Cat: Luna · Fish: Bubbles", kind: .note, mapPlaceholderName: nil),
        PreviewItem(
            title: "Pet Care",
            content: WaterfallGridCell.routinePreviewText(for: [
                "Fill water bowl", "Give food", "Let outside / litter check", "Play for 10 minutes"
            ]),
            kind: .routine,
            mapPlaceholderName: nil
        ),
        PreviewItem(title: "Dog Food", content: "1 cup morning and evening. Food is in the pantry bin.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "Treat Rules", content: "Max 2 treats per day — no chocolate, ever.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "Leash Location", content: "Hanging by the front door with the poop bags.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "No-Go Areas", content: "Keep pets out of the formal dining room and guest bedroom.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "Veterinarian", content: "Animal Hospital — (555) 789-4561", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "Pet Sitter", content: "Emily — (555) 222-3333", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "Favorite Park", content: "Sunrise Meadow Park — Max's usual walk loop.", kind: .place, mapPlaceholderName: "map-placeholder3")
    ]

    private static let plantsPreviewItems: [PreviewItem] = [
        PreviewItem(title: "Watering Schedule", content: "Most houseplants: every 7–10 days. Check soil first — if damp, wait.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(
            title: "Plant Care",
            content: WaterfallGridCell.routinePreviewText(for: [
                "Check soil moisture", "Water until it drains", "Empty saucers", "Rotate pots a quarter turn"
            ]),
            kind: .routine,
            mapPlaceholderName: nil
        ),
        PreviewItem(title: "Fiddle Leaf Fig", content: "Bright indirect light by the living room window. Water sparingly.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "Herbs on Sill", content: "Basil & mint — water when the top inch is dry. Snip often.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "Succulents", content: "Kitchen shelf. Water lightly every 2–3 weeks. No misting.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "Plant Food", content: "Liquid fertilizer under the sink. Use half-strength monthly in summer.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "Yard Service", content: "Every Monday, 11am–2pm. Leave the side gate unlocked.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "Outdoor Hose", content: "Spigot on the east side. Timer is set for early mornings.", kind: .note, mapPlaceholderName: nil),
        PreviewItem(title: "Garden Bed", content: "Backyard raised beds — tomatoes & peppers along the fence.", kind: .place, mapPlaceholderName: "map-placeholder5")
    ]

    private func thumbnail(for item: PreviewItem) -> UIImage? {
        guard let name = item.mapPlaceholderName else { return nil }
        return UIImage(named: name) ?? UIImage(systemName: "mappin.circle")
    }

    fileprivate static func makeStandaloneFolderCell() -> FolderCollectionViewCell {
        let cell = FolderCollectionViewCell(frame: .zero)
        cell.translatesAutoresizingMaskIntoConstraints = false
        // Outside a UICollectionView, contentView won't auto-fill — pin it explicitly.
        cell.contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cell.contentView.topAnchor.constraint(equalTo: cell.topAnchor),
            cell.contentView.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            cell.contentView.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            cell.contentView.bottomAnchor.constraint(equalTo: cell.bottomAnchor)
        ])
        return cell
    }
}

// MARK: - Waterfall UICollectionView

extension OBFolderPreviewViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        previewItems.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: WaterfallGridCell.reuseIdentifier,
            for: indexPath
        ) as! WaterfallGridCell

        let item = previewItems[indexPath.item]
        let layoutStyle: WaterfallGridCell.LayoutStyle = item.kind == .place ? .place : .standard
        cell.configure(
            title: item.title,
            content: item.content,
            thumbnail: thumbnail(for: item),
            layoutStyle: layoutStyle,
            appearance: .onboardingPreview,
            showsPlaceThumbnail: item.kind == .place,
            contentLineLimit: WaterfallGridCell.entryContentLineLimit
        )
        cell.updateThumbnailHeight(forColumnWidth: collectionView.bounds.width > 0
            ? floor((collectionView.bounds.width - 16 * 2 - 12) / 2)
            : 160)

        if state == .folderDetail, !hasCascadedItems {
            cell.alpha = 0
        }

        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard state == .folderDetail, !hasCascadedItems, cell.alpha < 1 else { return }

        cell.transform = CGAffineTransform(translationX: 0, y: 28)
        UIView.animate(
            withDuration: 0.42,
            delay: 0.04 * Double(indexPath.item),
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0.35,
            options: [.curveEaseOut]
        ) {
            cell.alpha = 1
            cell.transform = .identity
        }
    }
}

// MARK: - WaterfallCollectionLayoutDelegate

extension OBFolderPreviewViewController: WaterfallCollectionLayoutDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        layout: WaterfallCollectionLayout,
        heightForItemAt indexPath: IndexPath,
        columnWidth: CGFloat
    ) -> CGFloat {
        if let cached = waterfallHeightCache[indexPath] {
            return cached
        }

        let item = previewItems[indexPath.item]
        let layoutStyle: WaterfallGridCell.LayoutStyle = item.kind == .place ? .place : .standard
        sizingCell.configure(
            title: item.title,
            content: item.content,
            thumbnail: thumbnail(for: item),
            layoutStyle: layoutStyle,
            appearance: .onboardingPreview,
            showsPlaceThumbnail: item.kind == .place,
            contentLineLimit: WaterfallGridCell.entryContentLineLimit
        )

        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.size = CGSize(width: columnWidth, height: 0)
        let fitted = sizingCell.preferredLayoutAttributesFitting(attributes)
        waterfallHeightCache[indexPath] = fitted.size.height
        return fitted.size.height
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout: WaterfallCollectionLayout,
        shouldShowHeaderForSection section: Int
    ) -> Bool {
        false
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout: WaterfallCollectionLayout,
        heightForHeaderInSection section: Int
    ) -> CGFloat {
        0
    }
}
