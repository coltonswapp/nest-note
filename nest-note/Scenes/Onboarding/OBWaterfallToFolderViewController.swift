//
//  OBWaterfallToFolderViewController.swift
//  nest-note
//
//  Dual-state onboarding screen: chaos waterfall → gather into a folder.
//

import UIKit

final class OBWaterfallToFolderViewController: NNOnboardingViewController {

    // MARK: - Types

    enum DisplayState: Equatable {
        case overview
        case detail
    }

    private struct PreviewItem {
        enum Kind {
            case note
            case routine
            case place
            case contact
        }

        let title: String
        let content: String
        let kind: Kind
        let mapPlaceholderName: String?
        /// When true, this card flies into the folder during the organize transition.
        let gathersIntoFolder: Bool
    }

    // MARK: - Public

    var onContinue: (() -> Void)?

    /// Returns `true` when back was consumed by collapsing detail → overview.
    @discardableResult
    func handleBackIfNeeded() -> Bool {
        guard displayState == .detail, !isAnimatingTransition else { return false }
        collapseToOverview(animated: true)
        return true
    }

    var displayState: DisplayState { state }

    // MARK: - State

    private var state: DisplayState = .overview
    private let previewItems: [PreviewItem]
    private let folder: FolderData
    private var isAnimatingTransition = false
    private var hasPlayedOverviewEntrance = false
    private var hasEnteredDetail = false
    private var waterfallHeightCache: [IndexPath: CGFloat] = [:]

    /// Frames of gather cards in view coordinates, captured at expand time for reverse flight.
    private var gatherHomeFramesInView: [Int: CGRect] = [:]
    private var flyingSnapshots: [UIView] = []

    private let sizingCell = WaterfallGridCell(frame: .zero)
    private let entranceFeedback = UIImpactFeedbackGenerator(style: .light)

    // MARK: - UI

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Scales the waterfall so more cards peek into the first viewport (chaos beat).
    private let gridScaleContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false
        return view
    }()

    private lazy var waterfallCollectionView: UICollectionView = {
        let layout = WaterfallCollectionLayout()
        layout.delegate = self
        layout.columnCount = Self.overviewColumnCount
        layout.sectionInset = Self.overviewSectionInset
        layout.columnSpacing = Self.overviewColumnSpacing
        layout.rowSpacing = Self.overviewRowSpacing
        layout.sectionSpacing = 0

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.allowsSelection = true
        collectionView.clipsToBounds = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(
            WaterfallGridCell.self,
            forCellWithReuseIdentifier: WaterfallGridCell.reuseIdentifier
        )
        return collectionView
    }()

    private let heroFolderContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.alpha = 0
        view.isUserInteractionEnabled = false
        return view
    }()

    private lazy var heroFolderCell: FolderCollectionViewCell = {
        Self.makeStandaloneFolderCell()
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

    private var gridHeightConstraint: NSLayoutConstraint!
    private var gridWidthConstraint: NSLayoutConstraint!
    private var heroFolderWidthConstraint: NSLayoutConstraint!
    private var heroFolderHeightConstraint: NSLayoutConstraint!
    private var heroFolderTopConstraint: NSLayoutConstraint!
    private var overviewBottomConstraint: NSLayoutConstraint!
    private var detailBottomConstraint: NSLayoutConstraint!
    private var backButtonCenterXConstraint: NSLayoutConstraint!
    private var backButtonTrailingToHeroConstraint: NSLayoutConstraint!

    // MARK: - Constants

    private static let overviewColumnCount = 3
    private static let overviewSectionInset = UIEdgeInsets(top: 4, left: 10, bottom: 8, right: 10)
    private static let overviewColumnSpacing: CGFloat = 8
    private static let overviewRowSpacing: CGFloat = 8
    /// Mild scale so cards bleed past the edges without fighting insets.
    private static let overviewGridScale: CGFloat = 0.94
    private static let overviewContentLineLimit = 4
    private static let compactCardCornerRadius: CGFloat = 14
    private static let heroFolderHeight: CGFloat = 168
    private static let backButtonSize: CGFloat = 40
    private static let backButtonSpacing: CGFloat = 12
    private static let overviewContentTopPadding: CGFloat = 16
    private static let gatherTargetScale: CGFloat = 0.18

    // MARK: - Init

    convenience init() {
        self.init(folder: Self.defaultHouseholdFolder, items: Self.defaultOverviewItems)
    }

    private init(folder: FolderData, items: [PreviewItem]) {
        self.folder = folder
        self.previewItems = items
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

        setupOnboarding(
            title: Self.overviewTitle,
            subtitle: Self.overviewSubtitle
        )
        setupContent()
        setupBackButton()
        configureHeroFolder()
        addCTAButton(title: "Continue")
        ctaButton?.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        // Proceed is gated: overview Continue organizes into the folder; only detail Continue leaves.
        updateCTAForCurrentState(animated: false)

        waterfallCollectionView.reloadData()
        installScrollEdgeInteractions(for: scrollView)
        entranceFeedback.prepare()
        updateScrollContentInset(for: .overview)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installPopGestureInterceptor()
        if let ctaButton { view.bringSubviewToFront(ctaButton) }
        if let bottom = bottomEdgeContainerView { view.bringSubviewToFront(bottom) }
        playOverviewEntranceIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateGridLayoutMetrics()
        if state == .overview {
            updateScrollContentInset(for: .overview)
        }
    }

    // MARK: - Setup

    override func setupContent() {
        view.insertSubview(scrollView, belowSubview: headerContainerView)
        scrollView.addSubview(contentView)
        contentView.addSubview(gridScaleContainer)
        gridScaleContainer.addSubview(waterfallCollectionView)
        contentView.addSubview(backButton)
        contentView.addSubview(heroFolderContainer)

        heroFolderContainer.addSubview(heroFolderCell)

        gridHeightConstraint = gridScaleContainer.heightAnchor.constraint(equalToConstant: 0)
        gridWidthConstraint = gridScaleContainer.widthAnchor.constraint(
            equalTo: contentView.widthAnchor,
            multiplier: 1 / Self.overviewGridScale
        )
        heroFolderWidthConstraint = heroFolderContainer.widthAnchor.constraint(equalToConstant: 170)
        heroFolderHeightConstraint = heroFolderContainer.heightAnchor.constraint(equalToConstant: 0)
        // Top + fixed height only — never also pin centerY/bottom or the folder stretches.
        heroFolderTopConstraint = heroFolderContainer.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: 48
        )

        overviewBottomConstraint = gridScaleContainer.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -16
        )
        detailBottomConstraint = heroFolderContainer.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -48
        )
        detailBottomConstraint.isActive = false

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

            gridScaleContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            gridScaleContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            gridWidthConstraint,
            gridHeightConstraint,
            overviewBottomConstraint,

            waterfallCollectionView.topAnchor.constraint(equalTo: gridScaleContainer.topAnchor),
            waterfallCollectionView.leadingAnchor.constraint(equalTo: gridScaleContainer.leadingAnchor),
            waterfallCollectionView.trailingAnchor.constraint(equalTo: gridScaleContainer.trailingAnchor),
            waterfallCollectionView.bottomAnchor.constraint(equalTo: gridScaleContainer.bottomAnchor),

            heroFolderTopConstraint,
            heroFolderContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            heroFolderWidthConstraint,
            heroFolderHeightConstraint,

            heroFolderCell.topAnchor.constraint(equalTo: heroFolderContainer.topAnchor),
            heroFolderCell.leadingAnchor.constraint(equalTo: heroFolderContainer.leadingAnchor),
            heroFolderCell.trailingAnchor.constraint(equalTo: heroFolderContainer.trailingAnchor),
            heroFolderCell.bottomAnchor.constraint(equalTo: heroFolderContainer.bottomAnchor),

            backButton.centerYAnchor.constraint(equalTo: heroFolderContainer.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: Self.backButtonSize),
            backButton.heightAnchor.constraint(equalToConstant: Self.backButtonSize),
            backButtonCenterXConstraint
        ])

        gridScaleContainer.transform = CGAffineTransform(
            scaleX: Self.overviewGridScale,
            y: Self.overviewGridScale
        )

        scrollView.contentInset.bottom = 120
        scrollView.verticalScrollIndicatorInsets.bottom = 120
    }

    private func configureHeroFolder() {
        heroFolderCell.configure(with: folder)
        heroFolderCell.resetPressAppearance()
    }

    private func setupBackButton() {
        resetBackButtonToHiddenPosition()
    }

    private func installPopGestureInterceptor() {
        navigationController?.interactivePopGestureRecognizer?.delegate = self
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    // MARK: - Copy

    private static let overviewTitle = "Families are complex"
    private static let overviewSubtitle = "Imagine trying to tell a sitter everything they need to know."
    private static let detailTitle = "NestNote offers flexible organization."
    private static let detailSubtitle = "Notes, contacts, routines, & places can easily be added to folders."

    private func applyCopy(for displayState: DisplayState) {
        switch displayState {
        case .overview:
            titleLabel.text = Self.overviewTitle
            subtitleLabel.text = Self.overviewSubtitle
        case .detail:
            titleLabel.text = Self.detailTitle
            subtitleLabel.text = Self.detailSubtitle
        }
    }

    // MARK: - Insets / Layout

    private func updateScrollContentInset(for displayState: DisplayState) {
        view.layoutIfNeeded()

        let headerBottom = headerContainerView.convert(labelStack.frame, to: view).maxY
        let absoluteTop: CGFloat
        switch displayState {
        case .overview:
            let measured = headerBottom > 0
                ? headerBottom + Self.overviewContentTopPadding
                : view.safeAreaInsets.top + 120
            absoluteTop = max(measured, view.safeAreaInsets.top + Self.overviewContentTopPadding)
        case .detail:
            absoluteTop = view.safeAreaInsets.top + 8
        }

        scrollView.contentInset.top = absoluteTop
        scrollView.verticalScrollIndicatorInsets.top = absoluteTop
        if displayState == .overview, !scrollView.isDragging {
            scrollView.setContentOffset(CGPoint(x: 0, y: -absoluteTop), animated: false)
        }
    }

    private func updateGridLayoutMetrics() {
        guard state == .overview || !gridScaleContainer.isHidden else { return }

        let layoutWidth = contentView.bounds.width / Self.overviewGridScale
        guard layoutWidth > 0 else { return }

        waterfallCollectionView.collectionViewLayout.invalidateLayout()
        waterfallCollectionView.layoutIfNeeded()
        let contentHeight = waterfallCollectionView.collectionViewLayout.collectionViewContentSize.height
        // Visual height after scale — keep scroll metrics honest.
        gridHeightConstraint.constant = contentHeight
    }

    private func applyDetailLayoutConstraints() {
        overviewBottomConstraint.isActive = false
        detailBottomConstraint.isActive = true
    }

    private func applyOverviewLayoutConstraints() {
        detailBottomConstraint.isActive = false
        overviewBottomConstraint.isActive = true
    }

    // MARK: - Back Button

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
                self.contentView.bringSubviewToFront(self.backButton)
            }
        )
    }

    private func hideBackButton(animated: Bool) {
        backButton.isUserInteractionEnabled = false
        backButton.layer.removeAllAnimations()

        let finishHide = { self.resetBackButtonToHiddenPosition() }

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
        guard !isAnimatingTransition else { return }
        if state == .overview {
            expandToDetail(animated: true)
            return
        }
        // Detail Continue is the only path that leaves the screen.
        guard hasEnteredDetail else { return }
        if let onContinue {
            onContinue()
            return
        }
        (coordinator as? OnboardingCoordinator)?.next()
    }

    private func updateCTAForCurrentState(animated: Bool) {
        let title = state == .overview ? "Organize" : "Continue"
        ctaButton?.setTitle(title)

        let updates = {
            self.ctaButton?.alpha = 1
            self.ctaButton?.isUserInteractionEnabled = true
            self.bottomEdgeContainerView?.alpha = 1
        }
        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut], animations: updates)
        } else {
            updates()
        }
    }

    // MARK: - Overview Entrance

    private func playOverviewEntranceIfNeeded() {
        guard !hasPlayedOverviewEntrance else { return }
        hasPlayedOverviewEntrance = true

        waterfallCollectionView.layoutIfNeeded()
        updateGridLayoutMetrics()
        entranceFeedback.prepare()

        let cells = sortedVisibleCells()
        guard !cells.isEmpty else { return }

        for (index, cell) in cells.enumerated() {
            cell.alpha = 0
            cell.transform = CGAffineTransform(scaleX: 0.55, y: 0.55)

            let delay = 0.045 * Double(index)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.entranceFeedback.impactOccurred(intensity: 0.55)
            }

            UIView.animate(
                withDuration: 0.48,
                delay: delay,
                usingSpringWithDamping: 0.74,
                initialSpringVelocity: 0.55,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: {
                    cell.alpha = 1
                    cell.transform = .identity
                },
                completion: { [weak self] _ in
                    guard let self, index == cells.count - 1 else { return }
                    self.pulseGatherItems()
                }
            )
        }
    }

    /// Soft pulse on the cards that will fly into the folder — guides the eye before Organize.
    private func pulseGatherItems() {
        guard state == .overview, !isAnimatingTransition else { return }

        let gatherIndices = previewItems.enumerated()
            .compactMap { $0.element.gathersIntoFolder ? $0.offset : nil }

        for (offset, index) in gatherIndices.enumerated() {
            let indexPath = IndexPath(item: index, section: 0)
            guard let cell = waterfallCollectionView.cellForItem(at: indexPath) as? WaterfallGridCell
            else { continue }

            UIView.animate(
                withDuration: 0.22,
                delay: 0.04 * Double(offset),
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: {
                    cell.transform = CGAffineTransform(scaleX: 1.04, y: 1.04)
                },
                completion: { _ in
                    UIView.animate(
                        withDuration: 0.28,
                        delay: 0,
                        usingSpringWithDamping: 0.8,
                        initialSpringVelocity: 0.4,
                        options: [.allowUserInteraction],
                        animations: {
                            cell.transform = .identity
                        }
                    )
                }
            )
        }
    }

    private func sortedVisibleCells() -> [UICollectionViewCell] {
        waterfallCollectionView.visibleCells.sorted {
            $0.frame.minY < $1.frame.minY
                || ($0.frame.minY == $1.frame.minY && $0.frame.minX < $1.frame.minX)
        }
    }

    // MARK: - Expand: Overview → Detail

    private func expandToDetail(animated: Bool) {
        guard state == .overview, !isAnimatingTransition else { return }
        isAnimatingTransition = true
        HapticsHelper.lightHaptic()

        waterfallCollectionView.layoutIfNeeded()
        let gatherIndices = Set(
            previewItems.enumerated().compactMap { $0.element.gathersIntoFolder ? $0.offset : nil }
        )

        let nonGatherCells = waterfallCollectionView.visibleCells.filter { cell in
            guard let indexPath = waterfallCollectionView.indexPath(for: cell) else { return true }
            return !gatherIndices.contains(indexPath.item)
        }

        let beginGather = {
            self.performHouseholdGather(
                gatherIndices: gatherIndices,
                animated: animated
            )
        }

        guard animated else {
            for cell in nonGatherCells {
                cell.alpha = 0
                cell.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            }
            beginGather()
            return
        }

        // Phase 1: clear the chaos — hide everything that isn't Household.
        UIView.animate(
            withDuration: 0.22,
            delay: 0,
            options: [.curveEaseIn, .allowUserInteraction],
            animations: {
                for cell in nonGatherCells {
                    cell.alpha = 0
                    cell.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                }
            },
            completion: { _ in
                beginGather()
            }
        )
    }

    /// Phase 2: fly only the Household cards into the folder.
    private func performHouseholdGather(gatherIndices: Set<Int>, animated: Bool) {
        gatherHomeFramesInView.removeAll()
        var snapshots: [(index: Int, view: UIView, start: CGRect)] = []

        for index in gatherIndices.sorted() {
            let indexPath = IndexPath(item: index, section: 0)
            guard let cell = waterfallCollectionView.cellForItem(at: indexPath) as? WaterfallGridCell
            else { continue }

            let startFrame = cell.convert(cell.bounds, to: view)
            gatherHomeFramesInView[index] = startFrame

            let snapshot = cell.snapshotView(afterScreenUpdates: true) ?? {
                let fallback = UIView(frame: startFrame)
                fallback.backgroundColor = UIColor(red: 248 / 255, green: 248 / 255, blue: 248 / 255, alpha: 1)
                fallback.layer.cornerRadius = Self.compactCardCornerRadius
                return fallback
            }()
            snapshot.frame = startFrame
            snapshot.layer.cornerRadius = Self.compactCardCornerRadius
            snapshot.clipsToBounds = true
            cell.alpha = 0
            view.addSubview(snapshot)
            snapshots.append((index, snapshot, startFrame))
        }

        flyingSnapshots = snapshots.map(\.view)

        // Flight target in view coordinates — commit Auto Layout in `finishExpand`
        // so the overview grid doesn't jump under the snapshots mid-flight.
        let aspectRatio = FolderShape.designWidth / FolderShape.designHeight
        let targetHeight = Self.heroFolderHeight
        let targetWidth = targetHeight * aspectRatio
        let detailTopInset = view.safeAreaInsets.top + 8
        let folderTargetFrame = CGRect(
            x: (view.bounds.width - targetWidth) / 2,
            y: view.bounds.midY - targetHeight * 0.12,
            width: targetWidth,
            height: targetHeight
        )

        heroFolderWidthConstraint.constant = targetWidth
        heroFolderHeightConstraint.constant = targetHeight
        configureHeroFolder()
        resetBackButtonToHiddenPosition()

        // Temporary folder at the exact resting frame so Auto Layout doesn't drift mid-flight.
        let folderFlight = Self.makeStandaloneFolderCell()
        folderFlight.translatesAutoresizingMaskIntoConstraints = true
        folderFlight.autoresizingMask = []
        folderFlight.frame = folderTargetFrame
        folderFlight.configure(with: folder)
        folderFlight.resetPressAppearance()
        folderFlight.alpha = 0
        folderFlight.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        view.addSubview(folderFlight)
        folderFlight.layoutIfNeeded()

        let animations = {
            self.titleLabel.alpha = 0
            self.subtitleLabel.alpha = 0
            self.titleLabel.transform = CGAffineTransform(translationX: 0, y: -14)
            self.subtitleLabel.transform = CGAffineTransform(translationX: 0, y: -10)
            self.gridScaleContainer.alpha = 0

            for entry in snapshots {
                // Preserve each card's aspect ratio while shrinking into the folder.
                let aspect = entry.start.width / max(entry.start.height, 1)
                let endHeight = max(entry.start.height * Self.gatherTargetScale, 28)
                let endWidth = endHeight * aspect
                entry.view.frame = CGRect(
                    x: folderTargetFrame.midX - endWidth / 2,
                    y: folderTargetFrame.midY - endHeight / 2,
                    width: endWidth,
                    height: endHeight
                )
                entry.view.alpha = 0.12
                entry.view.transform = CGAffineTransform(rotationAngle: Self.flightTilt(for: entry.index))
            }

            folderFlight.alpha = 1
            folderFlight.transform = .identity
        }

        let finishExpand = {
            self.flyingSnapshots.forEach { $0.removeFromSuperview() }
            self.flyingSnapshots.removeAll()

            // Snapshot handoff keeps the resting folder pixel-identical (no live-cell stretch).
            let folderSnapshot = folderFlight.snapshotView(afterScreenUpdates: true)
            folderFlight.removeFromSuperview()

            self.gridScaleContainer.isHidden = true
            self.gridScaleContainer.alpha = 1
            self.gridScaleContainer.transform = CGAffineTransform(
                scaleX: Self.overviewGridScale,
                y: Self.overviewGridScale
            )

            self.heroFolderWidthConstraint.constant = targetWidth
            self.heroFolderHeightConstraint.constant = targetHeight
            // Match the flight resting frame once scroll insets settle.
            self.heroFolderTopConstraint.constant = max(24, folderTargetFrame.minY - detailTopInset)

            self.applyDetailLayoutConstraints()
            self.heroFolderContainer.isHidden = false
            self.heroFolderContainer.alpha = 1
            self.heroFolderContainer.transform = .identity

            self.heroFolderContainer.subviews.forEach { $0.removeFromSuperview() }
            if let folderSnapshot {
                folderSnapshot.translatesAutoresizingMaskIntoConstraints = false
                self.heroFolderContainer.addSubview(folderSnapshot)
                NSLayoutConstraint.activate([
                    folderSnapshot.topAnchor.constraint(equalTo: self.heroFolderContainer.topAnchor),
                    folderSnapshot.leadingAnchor.constraint(equalTo: self.heroFolderContainer.leadingAnchor),
                    folderSnapshot.trailingAnchor.constraint(equalTo: self.heroFolderContainer.trailingAnchor),
                    folderSnapshot.bottomAnchor.constraint(equalTo: self.heroFolderContainer.bottomAnchor)
                ])
            } else {
                self.heroFolderContainer.addSubview(self.heroFolderCell)
                NSLayoutConstraint.activate([
                    self.heroFolderCell.topAnchor.constraint(equalTo: self.heroFolderContainer.topAnchor),
                    self.heroFolderCell.leadingAnchor.constraint(equalTo: self.heroFolderContainer.leadingAnchor),
                    self.heroFolderCell.trailingAnchor.constraint(equalTo: self.heroFolderContainer.trailingAnchor),
                    self.heroFolderCell.bottomAnchor.constraint(equalTo: self.heroFolderContainer.bottomAnchor)
                ])
                self.configureHeroFolder()
            }

            self.applyCopy(for: .detail)
            self.titleLabel.alpha = 1
            self.subtitleLabel.alpha = 1
            self.titleLabel.transform = .identity
            self.subtitleLabel.transform = .identity

            self.scrollView.contentInset.top = detailTopInset
            self.scrollView.verticalScrollIndicatorInsets.top = detailTopInset
            self.scrollView.setContentOffset(CGPoint(x: 0, y: -detailTopInset), animated: false)
            self.view.layoutIfNeeded()

            self.state = .detail
            self.hasEnteredDetail = true
            self.updateCTAForCurrentState(animated: true)
            self.isAnimatingTransition = false
            self.revealBackButtonBesideFolder()
        }

        guard animated else {
            animations()
            finishExpand()
            return
        }

        UIView.animate(
            withDuration: 0.34,
            delay: 0.02,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.75,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: animations,
            completion: { _ in
                // Settle detail copy after the gather so the folder reads first.
                self.applyCopy(for: .detail)
                self.titleLabel.alpha = 0
                self.subtitleLabel.alpha = 0
                self.titleLabel.transform = CGAffineTransform(translationX: 0, y: 12)
                self.subtitleLabel.transform = CGAffineTransform(translationX: 0, y: 8)

                UIView.animate(
                    withDuration: 0.28,
                    delay: 0,
                    usingSpringWithDamping: 0.86,
                    initialSpringVelocity: 0.4,
                    options: [.curveEaseOut],
                    animations: {
                        self.titleLabel.alpha = 1
                        self.subtitleLabel.alpha = 1
                        self.titleLabel.transform = .identity
                        self.subtitleLabel.transform = .identity
                    },
                    completion: { _ in
                        finishExpand()
                    }
                )
            }
        )
    }

    // MARK: - Collapse: Detail → Overview

    private func collapseToOverview(animated: Bool) {
        guard state == .detail, !isAnimatingTransition else { return }
        isAnimatingTransition = true
        hideBackButton(animated: false)

        let gatherIndices = previewItems.enumerated()
            .compactMap { $0.element.gathersIntoFolder ? $0.offset : nil }

        let folderStartFrame = heroFolderContainer.convert(heroFolderContainer.bounds, to: view)

        applyOverviewLayoutConstraints()
        gridScaleContainer.isHidden = false
        gridScaleContainer.alpha = 1
        gridScaleContainer.transform = CGAffineTransform(
            scaleX: Self.overviewGridScale,
            y: Self.overviewGridScale
        )
        updateGridLayoutMetrics()
        updateScrollContentInset(for: .overview)
        view.layoutIfNeeded()

        // Reset cells under the flying snapshots.
        for cell in waterfallCollectionView.visibleCells {
            guard let indexPath = waterfallCollectionView.indexPath(for: cell) else { continue }
            if gatherIndices.contains(indexPath.item) {
                cell.alpha = 0
                cell.transform = .identity
            } else {
                cell.alpha = 0
                cell.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            }
        }

        // Spawn reverse-flight card snapshots from the folder.
        var reverseSnapshots: [(index: Int, view: UIView, target: CGRect)] = []
        for index in gatherIndices {
            let target = gatherHomeFramesInView[index]
                ?? waterfallCollectionView.cellForItem(at: IndexPath(item: index, section: 0))
                .map { $0.convert($0.bounds, to: view) }
                ?? folderStartFrame

            let aspect = target.width / max(target.height, 1)
            let startHeight = max(target.height * Self.gatherTargetScale, 28)
            let startWidth = startHeight * aspect
            let snapshot = UIView(frame: CGRect(
                x: folderStartFrame.midX - startWidth / 2,
                y: folderStartFrame.midY - startHeight / 2,
                width: startWidth,
                height: startHeight
            ))
            snapshot.backgroundColor = UIColor(red: 248 / 255, green: 248 / 255, blue: 248 / 255, alpha: 1)
            snapshot.layer.cornerRadius = WaterfallGridCell.cornerRadius
            snapshot.clipsToBounds = true
            snapshot.alpha = 0.35
            snapshot.transform = CGAffineTransform(rotationAngle: Self.flightTilt(for: index))
            view.addSubview(snapshot)
            reverseSnapshots.append((index, snapshot, target))
        }
        flyingSnapshots = reverseSnapshots.map(\.view)

        let finish: () -> Void = {
            self.flyingSnapshots.forEach { $0.removeFromSuperview() }
            self.flyingSnapshots.removeAll()

            self.heroFolderContainer.isHidden = true
            self.heroFolderContainer.alpha = 0
            self.heroFolderContainer.transform = .identity
            self.heroFolderHeightConstraint.constant = 0
            self.heroFolderTopConstraint.constant = 48
            self.heroFolderContainer.subviews.forEach { $0.removeFromSuperview() }
            if self.heroFolderCell.superview == nil {
                self.heroFolderContainer.addSubview(self.heroFolderCell)
                NSLayoutConstraint.activate([
                    self.heroFolderCell.topAnchor.constraint(equalTo: self.heroFolderContainer.topAnchor),
                    self.heroFolderCell.leadingAnchor.constraint(equalTo: self.heroFolderContainer.leadingAnchor),
                    self.heroFolderCell.trailingAnchor.constraint(equalTo: self.heroFolderContainer.trailingAnchor),
                    self.heroFolderCell.bottomAnchor.constraint(equalTo: self.heroFolderContainer.bottomAnchor)
                ])
            }
            self.resetBackButtonToHiddenPosition()

            for cell in self.waterfallCollectionView.visibleCells {
                cell.alpha = 1
                cell.transform = .identity
            }

            self.applyCopy(for: .overview)
            self.titleLabel.alpha = 1
            self.subtitleLabel.alpha = 1
            self.titleLabel.transform = .identity
            self.subtitleLabel.transform = .identity

            self.state = .overview
            self.updateCTAForCurrentState(animated: false)
            self.view.layoutIfNeeded()
            self.updateScrollContentInset(for: .overview)
            self.isAnimatingTransition = false
        }

        guard animated else {
            finish()
            return
        }

        applyCopy(for: .overview)
        titleLabel.alpha = 0
        subtitleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: -14)
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: -10)

        UIView.animate(
            withDuration: 0.42,
            delay: 0,
            usingSpringWithDamping: 0.84,
            initialSpringVelocity: 0.4,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: {
                self.titleLabel.alpha = 1
                self.subtitleLabel.alpha = 1
                self.titleLabel.transform = .identity
                self.subtitleLabel.transform = .identity

                self.heroFolderContainer.alpha = 0
                self.heroFolderContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)

                for entry in reverseSnapshots {
                    entry.view.frame = entry.target
                    entry.view.alpha = 1
                    entry.view.transform = .identity
                }

                for cell in self.waterfallCollectionView.visibleCells {
                    guard let indexPath = self.waterfallCollectionView.indexPath(for: cell) else { continue }
                    if !gatherIndices.contains(indexPath.item) {
                        cell.alpha = 1
                        cell.transform = .identity
                    }
                }
            },
            completion: { _ in
                // Crossfade gather cells back under returning cards.
                for entry in reverseSnapshots {
                    let indexPath = IndexPath(item: entry.index, section: 0)
                    if let cell = self.waterfallCollectionView.cellForItem(at: indexPath) {
                        cell.alpha = 1
                        cell.transform = .identity
                    }
                }
                finish()
            }
        )
    }

    // MARK: - Helpers

    private static func flightTilt(for index: Int) -> CGFloat {
        let tilts: [CGFloat] = [-0.12, 0.08, -0.05, 0.14, -0.09, 0.06]
        return tilts[index % tilts.count]
    }

    private static func columnWidth(for collectionWidth: CGFloat) -> CGFloat {
        guard collectionWidth > 0 else { return 80 }
        let inset = overviewSectionInset.left + overviewSectionInset.right
        let spacing = overviewColumnSpacing * CGFloat(overviewColumnCount - 1)
        return floor((collectionWidth - inset - spacing) / CGFloat(overviewColumnCount))
    }

    private func thumbnail(for item: PreviewItem) -> UIImage? {
        guard let name = item.mapPlaceholderName else { return nil }
        return UIImage(named: name) ?? UIImage(systemName: "mappin.circle")
    }

    fileprivate static func makeStandaloneFolderCell() -> FolderCollectionViewCell {
        let cell = FolderCollectionViewCell(frame: .zero)
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cell.contentView.topAnchor.constraint(equalTo: cell.topAnchor),
            cell.contentView.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            cell.contentView.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            cell.contentView.bottomAnchor.constraint(equalTo: cell.bottomAnchor)
        ])
        return cell
    }

    // MARK: - Sample Content

    private static var defaultHouseholdFolder: FolderData {
        let category = NestCategory(name: "Household", symbolName: "house.fill", isDefault: true, isPinned: true)
        let gatherCount = defaultOverviewItems.filter(\.gathersIntoFolder).count
        return FolderData(
            title: category.name,
            image: UIImage(systemName: category.symbolName),
            itemCount: gatherCount,
            fullPath: category.name,
            category: category
        )
    }

    private static let defaultOverviewItems: [PreviewItem] = [
        PreviewItem(title: "Neighborhood Park", content: "452 Oak Street", kind: .place, mapPlaceholderName: "map-placeholder3", gathersIntoFolder: false),
        PreviewItem(
            title: "Bath Routine",
            content: WaterfallGridCell.routinePreviewText(for: [
                "Bathe after walk", "Towels under sink", "Lavender soap only"
            ]),
            kind: .routine,
            mapPlaceholderName: nil,
            gathersIntoFolder: true
        ),
        PreviewItem(title: "Grandma", content: "(555) 014-2291", kind: .contact, mapPlaceholderName: nil, gathersIntoFolder: true),
        PreviewItem(title: "Garage Code", content: "118 Birch Lane", kind: .place, mapPlaceholderName: "map-placeholder2", gathersIntoFolder: true),
        PreviewItem(title: "Netflix Pin", content: "2025", kind: .note, mapPlaceholderName: nil, gathersIntoFolder: true),
        PreviewItem(title: "Alarm Code", content: "8005 — disarm in 30s", kind: .note, mapPlaceholderName: nil, gathersIntoFolder: true),
        PreviewItem(title: "WiFi Password", content: "NestNoteGuest!", kind: .note, mapPlaceholderName: nil, gathersIntoFolder: false),
        PreviewItem(title: "Trash Day", content: "Bins out Tuesday night", kind: .note, mapPlaceholderName: nil, gathersIntoFolder: false),
        PreviewItem(title: "Thermostat", content: "Keep around 68°F", kind: .note, mapPlaceholderName: nil, gathersIntoFolder: false),
        PreviewItem(
            title: "Leaving House",
            content: WaterfallGridCell.routinePreviewText(for: [
                "Check doors", "Lights off", "Arm alarm"
            ]),
            kind: .routine,
            mapPlaceholderName: nil,
            gathersIntoFolder: false
        ),
        PreviewItem(title: "Pediatrician", content: "Dr. Smith — (555) 987-6543", kind: .contact, mapPlaceholderName: nil, gathersIntoFolder: false),
        PreviewItem(title: "School", content: "Lincoln Elementary", kind: .place, mapPlaceholderName: "map-placeholder1", gathersIntoFolder: false),
        PreviewItem(title: "Spare Key", content: "Under the blue planter", kind: .note, mapPlaceholderName: nil, gathersIntoFolder: false),
        PreviewItem(title: "Dog Walker", content: "Alex — (555) 222-0188", kind: .contact, mapPlaceholderName: nil, gathersIntoFolder: false),
        PreviewItem(title: "Mail Box", content: "Code 4410 on the cluster box", kind: .note, mapPlaceholderName: nil, gathersIntoFolder: false),
        PreviewItem(
            title: "Bedtime",
            content: WaterfallGridCell.routinePreviewText(for: [
                "Pajamas", "Brush teeth", "One story"
            ]),
            kind: .routine,
            mapPlaceholderName: nil,
            gathersIntoFolder: false
        ),
        PreviewItem(title: "Pharmacy", content: "Westside Rx on Maple", kind: .place, mapPlaceholderName: "map-placeholder4", gathersIntoFolder: false),
        PreviewItem(title: "Gate Code", content: "0921#", kind: .note, mapPlaceholderName: nil, gathersIntoFolder: false),
        PreviewItem(title: "Allergies", content: "Peanuts — EpiPen in pantry", kind: .note, mapPlaceholderName: nil, gathersIntoFolder: false),
        PreviewItem(title: "Neighbor Pat", content: "(555) 441-7780", kind: .contact, mapPlaceholderName: nil, gathersIntoFolder: false),
        PreviewItem(title: "Water Shutoff", content: "Basement, north wall", kind: .note, mapPlaceholderName: nil, gathersIntoFolder: false),
        PreviewItem(title: "Soccer Practice", content: "Thu 4:30pm, Field 2", kind: .place, mapPlaceholderName: "map-placeholder5", gathersIntoFolder: false),
        PreviewItem(title: "Cat Food", content: "½ cup morning & night", kind: .note, mapPlaceholderName: nil, gathersIntoFolder: false),
        PreviewItem(
            title: "Coming Home",
            content: WaterfallGridCell.routinePreviewText(for: [
                "Disarm alarm", "Hang keys", "Wash hands"
            ]),
            kind: .routine,
            mapPlaceholderName: nil,
            gathersIntoFolder: false
        ),
        PreviewItem(title: "Streaming PIN", content: "Hulu — 4488", kind: .note, mapPlaceholderName: nil, gathersIntoFolder: false),
        PreviewItem(title: "Vet Clinic", content: "Sunrise Animal — (555) 300-1212", kind: .contact, mapPlaceholderName: nil, gathersIntoFolder: false),
        PreviewItem(title: "Library", content: "Oak Branch — Tue story time", kind: .place, mapPlaceholderName: "map-placeholder1", gathersIntoFolder: false),
        PreviewItem(title: "Plant Watering", content: "Fiddle leaf every 10 days", kind: .note, mapPlaceholderName: nil, gathersIntoFolder: false),
        PreviewItem(title: "Emergency Contact", content: "Mom — (555) 019-3344", kind: .contact, mapPlaceholderName: nil, gathersIntoFolder: false),
        PreviewItem(title: "Guest Wi‑Fi", content: "NestVisitors / cozyhome", kind: .note, mapPlaceholderName: nil, gathersIntoFolder: false)
    ]
}

// MARK: - UICollectionView

extension OBWaterfallToFolderViewController: UICollectionViewDataSource, UICollectionViewDelegate {
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
            appearance: .onboardingCompact,
            showsPlaceThumbnail: item.kind == .place,
            contentLineLimit: Self.overviewContentLineLimit
        )

        cell.updateThumbnailHeight(forColumnWidth: Self.columnWidth(for: collectionView.bounds.width))

        if !hasPlayedOverviewEntrance {
            cell.alpha = 0
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard state == .overview, !isAnimatingTransition else { return }
        guard previewItems.indices.contains(indexPath.item),
              previewItems[indexPath.item].gathersIntoFolder
        else { return }
        expandToDetail(animated: true)
    }
}

// MARK: - WaterfallCollectionLayoutDelegate

extension OBWaterfallToFolderViewController: WaterfallCollectionLayoutDelegate {
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
            appearance: .onboardingCompact,
            showsPlaceThumbnail: item.kind == .place,
            contentLineLimit: Self.overviewContentLineLimit
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

// MARK: - Interactive Pop

extension OBWaterfallToFolderViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === navigationController?.interactivePopGestureRecognizer else {
            return true
        }
        if handleBackIfNeeded() {
            return false
        }
        return navigationController?.viewControllers.count ?? 0 > 1
    }
}
