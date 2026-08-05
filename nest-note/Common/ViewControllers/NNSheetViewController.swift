import UIKit

protocol NNSheetViewControllerDelegate: AnyObject {
    func sheetViewController(_ controller: NNSheetViewController, didDismissWithResult result: Any?)
}

class NNSheetViewController: NNViewController {
    
    static let ctaBottomPadding: CGFloat = 24
    private static let navigationBarHeight: CGFloat = 44
    private static let navigationBarTopInset: CGFloat = 12
    private static let minimizedDetentIdentifier = UISheetPresentationController.Detent.Identifier("nnMinimized")
    /// Just taller than the nav-bar button row (inset + bar + a little breathing room).
    private static let minimizedDetentHeight: CGFloat =
        navigationBarTopInset + navigationBarHeight + 20
    /// Bottom-pinned CTAs collide with the nav chrome below this height — keep the form
    /// hidden while the sheet is in (or animating through) this band.
    private static let minimizedContentHideHeight: CGFloat = minimizedDetentHeight + 160
    
    // MARK: - Properties
    weak var delegate: NNSheetViewControllerDelegate?

    /// Fired once after the sheet finishes dismissing (close button, swipe, or nav-pop discard).
    var onSheetDidDismiss: (() -> Void)?
    
    /// When `true`, the sheet can be dragged (or toggled) down to a small docked detent
    /// so the presenting content stays interactive — similar to a Mail compose draft.
    /// Opt in from create/edit sheets only; read-only sheets keep normal dismiss behavior.
    var allowsMinimizedSheetDetent: Bool { false }
    
    /// Whether close / swipe-dismiss should confirm before discarding in-progress work.
    /// Create/edit subclasses override this when the user has entered or changed content.
    var hasDiscardableContent: Bool { false }
    
    /// Compact/minimize is only offered while there are pending changes to keep.
    private var canEnterCompactMode: Bool {
        allowsMinimizedSheetDetent && hasDiscardableContent
    }
    
    private var isSheetMinimized: Bool {
        sheetPresentationController?.selectedDetentIdentifier == Self.minimizedDetentIdentifier
            || isInCompactDraftMode
    }
    
    /// Explicit flag so compact mode stays reliable even if detent identity lags during animation.
    private var isInCompactDraftMode = false
    
    /// Set before calling `dismiss` so detent-change callbacks during the dismiss
    /// animation don't re-enter compact mode and hide sheet content mid-transition.
    private var isDismissingSheet = false
    
    /// Avoid treating the initial present animation (short → tall) as a compact transition.
    private var hasCompletedInitialPresentation = false
    
    /// After expand is requested, keep the form hidden until the sheet is tall enough
    /// that bottom CTAs won't sit in the chrome band.
    private var pendingCompactContentRestore = false
    
    /// Minimized create/edit sheet that would be lost if the presenting screen is popped.
    var isDraftWaiting: Bool { allowsMinimizedSheetDetent && isInCompactDraftMode }
    
    private weak var draftPopGuardedPresenter: UIViewController?
    private var draftPopGuardInstalled = false
    private var draftPopGuardPreviousInteractivePopEnabled = true
    /// Subviews we hid while compact so they can't overlap/steal taps from the nav chrome.
    private var viewsHiddenForCompactMode: [UIView] = []
    
    /// Centered draft subject for compact mode. Non-interactive so it can't cover bar buttons.
    private lazy var compactDraftTitleView: CompactDraftTitleView = {
        CompactDraftTitleView()
    }()
    
    let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = NNColors.groupedBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private(set) lazy var navigationBar: UINavigationBar = {
        let bar = UINavigationBar()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.prefersLargeTitles = false
        bar.tintColor = .label
        return bar
    }()

    /// Owned by the free-floating bar — never use `self.navigationItem` here.
    private let sheetNavigationItem = UINavigationItem()
    
    /// Hidden compatibility shim — subclasses set `.text`; synced to `sheetNavigationItem.title`.
    let titleLabel: UILabel = {
        let label = UILabel()
        label.isHidden = true
        return label
    }()
    
    private(set) var showsLeadingBarButton = false
    private var leadingBarButtonMenu: UIMenu?
    private var leadingDoneBarButtonTitle: String?
    private weak var leadingDoneTarget: AnyObject?
    private var leadingDoneAction: Selector?
    
    let titleField: UITextField = {
        let field = UITextField()
        field.font = .bodyXL
        field.returnKeyType = .done
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    let dividerView: UIView = {
        let view = UIView()
        view.backgroundColor = .quaternaryLabel
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Protected Properties (for subclasses)
    var containerBottomConstraint: NSLayoutConstraint?
    var containerTopConstraint: NSLayoutConstraint?
    var itemsHiddenDuringTransition: [UIView] = []
    /// Active while the keyboard is up; nil when pinned to `view.bottomAnchor`.
    private var containerKeyboardBottomConstraint: NSLayoutConstraint?
    
    // MARK: - Initialization
    init(sourceFrame: CGRect? = nil) {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        view.backgroundColor = NNColors.groupedBackground
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = NNColors.groupedBackground
        configureSheetPresentationIfNeeded()
        setupKeyboardObservers()
        setupInfoButton()
        refreshNavigationBarItems()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshNavigationBarItems()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        hasCompletedInitialPresentation = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        syncCompactContentWithSheetHeight()
    }

    // MARK: - Setup Methods
    override func addSubviews() {
        view.addSubview(containerView)
        containerView.addSubview(titleField)
        containerView.addSubview(dividerView)
        
        addContentToContainer()

        // Chrome lives on `view`, above `containerView`, so form/CTA/blur/attachment
        // siblings can never cover bar buttons — especially in the short undimmed detent.
        view.addSubview(navigationBar)
    }
    
    override func constrainSubviews() {
        setupNavigationBar()

        // Keep bottom CTAs above the keyboard; false preserves flush-to-bottom when dismissed.
        view.keyboardLayoutGuide.usesBottomSafeArea = false

        // Default pin to the view bottom. Only attach to keyboardLayoutGuide while the
        // keyboard is visible — staying pinned to the guide during sheet dismiss can
        // collapse the container and clip all content mid-transition.
        containerTopConstraint = containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        containerBottomConstraint = containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)

        NSLayoutConstraint.activate([
            containerTopConstraint!,
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerBottomConstraint!,

            navigationBar.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: Self.navigationBarTopInset
            ),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigationBar.heightAnchor.constraint(equalToConstant: Self.navigationBarHeight),
            
            titleField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            dividerView.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 16),
            dividerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            dividerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            dividerView.heightAnchor.constraint(equalToConstant: 1)
        ])

        if let header = contentAboveTitleField {
            if header.superview == nil {
                containerView.insertSubview(header, belowSubview: titleField)
            }
            NSLayoutConstraint.activate([
                header.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 16),
                titleField.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 16)
            ])
        } else {
            titleField.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 16).isActive = true
        }
    }

    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = nil
        navigationItem.rightBarButtonItems = nil
        navigationItem.title = nil
        navigationItem.titleView = nil

        navigationBar.setItems([sheetNavigationItem], animated: false)

        let appearance = UINavigationBarAppearance()
        // Clear chrome so glass close/minimize controls sit on the sheet background
        // instead of a flat nav-bar slab.
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor.label
        ]
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        sheetNavigationItem.standardAppearance = appearance
        sheetNavigationItem.scrollEdgeAppearance = appearance
        sheetNavigationItem.compactAppearance = appearance
    }

    func setLeadingBarButtonHidden(_ hidden: Bool) {
        showsLeadingBarButton = !hidden
        refreshNavigationBarItems()
    }

    func setLeadingBarButtonMenu(_ menu: UIMenu?) {
        leadingBarButtonMenu = menu
        leadingDoneBarButtonTitle = nil
        leadingDoneTarget = nil
        leadingDoneAction = nil
        refreshNavigationBarItems()
    }

    /// Called when the leading ellipsis menu is about to present. Override to collapse overlays, etc.
    func leadingMenuWillPresent() {}

    func setLeadingDoneBarButton(title: String, target: Any, action: Selector) {
        leadingDoneBarButtonTitle = title
        leadingDoneTarget = target as AnyObject
        leadingDoneAction = action
        leadingBarButtonMenu = nil
        refreshNavigationBarItems()
    }

    func refreshNavigationBarItems() {
        let minimized = isSheetMinimized

        if minimized {
            // Custom centered title — system `.title` shifts left with no leading item and
            // two trailing buttons. Title view is non-interactive so bar buttons stay tappable.
            compactDraftTitleView.text = draftSubjectText()
            sheetNavigationItem.titleView = compactDraftTitleView
            sheetNavigationItem.title = nil
        } else {
            sheetNavigationItem.titleView = nil
            sheetNavigationItem.title = titleLabel.text
        }

        // System items keep native Liquid Glass styling. Split close + chevron so iOS 26
        // doesn't merge them into one shared glass capsule.
        let closeItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissViewController)
        )
        if canEnterCompactMode || isInCompactDraftMode {
            let minimizeItem = makeMinimizeBarButtonItem()
            if #available(iOS 26.0, *) {
                sheetNavigationItem.rightBarButtonItems = [
                    closeItem,
                    .fixedSpace(),
                    minimizeItem
                ]
            } else {
                sheetNavigationItem.rightBarButtonItems = [closeItem, minimizeItem]
            }
        } else {
            sheetNavigationItem.rightBarButtonItems = [closeItem]
        }

        // Leading: ellipsis menu / Done. Hidden while docked compact.
        if minimized || !showsLeadingBarButton {
            sheetNavigationItem.leftBarButtonItem = nil
        } else if let title = leadingDoneBarButtonTitle,
                  let target = leadingDoneTarget,
                  let action = leadingDoneAction {
            sheetNavigationItem.leftBarButtonItem = UIBarButtonItem(
                title: title,
                style: .done,
                target: target,
                action: action
            )
        } else if let menu = leadingBarButtonMenu {
            // Deferred so subclasses can react (e.g. collapse attachment stacks) on open.
            sheetNavigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "ellipsis"),
                menu: UIMenu(
                    title: menu.title,
                    image: menu.image,
                    identifier: menu.identifier,
                    options: menu.options,
                    children: [
                        UIDeferredMenuElement.uncached { [weak self] completion in
                            self?.leadingMenuWillPresent()
                            completion(menu.children)
                        }
                    ]
                )
            )
        } else {
            sheetNavigationItem.leftBarButtonItem = nil
        }

        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = nil
        navigationItem.rightBarButtonItems = nil
        navigationItem.title = nil
        navigationItem.titleView = nil

        navigationBar.setItems([sheetNavigationItem], animated: false)
    }

    private func makeMinimizeBarButtonItem() -> UIBarButtonItem {
        let imageName = isSheetMinimized ? "chevron.up" : "chevron.down"
        let item = UIBarButtonItem(
            image: UIImage(systemName: imageName),
            style: .plain,
            target: self,
            action: #selector(toggleMinimizedDetent)
        )
        item.accessibilityLabel = isSheetMinimized ? "Expand sheet" : "Minimize sheet"
        if #available(iOS 26.0, *) {
            item.sharesBackground = false
        }
        return item
    }
    
    /// Subject line for the docked draft: the field text, or the sheet title (e.g. "New Note").
    private func draftSubjectText() -> String {
        let trimmed = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        let fallback = titleLabel.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fallback.isEmpty ? "Untitled" : fallback
    }
    
    private func updateMinimizedAppearance(compact: Bool? = nil, animated: Bool = true) {
        // While the sheet is dismissing, UIKit can pass through the minimized detent
        // as height shrinks — ignore that so content stays visible for the transition.
        guard !isDismissingSheet else { return }

        let wasCompact = isInCompactDraftMode
        if let compact {
            isInCompactDraftMode = compact
        } else if let selected = sheetPresentationController?.selectedDetentIdentifier {
            isInCompactDraftMode = selected == Self.minimizedDetentIdentifier
        }
        let minimized = isInCompactDraftMode

        // Drop attachment overlays before the first hide pass so we don't restore
        // orphaned tap zones when expanding again.
        if minimized && !wasCompact {
            prepareForCompactDraftMode()
        }

        if minimized {
            pendingCompactContentRestore = false
            applyCompactFormHidden(true, animated: animated)
        } else if isSheetHeightInCompactBand {
            // Expand requested while still short — restore chrome now, form later.
            pendingCompactContentRestore = true
            applyCompactFormHidden(true, animated: false)
        } else {
            pendingCompactContentRestore = false
            applyCompactFormHidden(false, animated: animated)
        }

        refreshNavigationBarItems()
        refreshDraftNavigationPopGuard()
    }

    /// Collapse overlays (e.g. attachment accordion siblings) before docking.
    /// Subclasses with floating chrome should override and clean it up here.
    func prepareForCompactDraftMode() {}

    private var isSheetHeightInCompactBand: Bool {
        let height = view.bounds.height
        guard height > 0 else { return false }
        return height <= Self.minimizedContentHideHeight
    }

    /// Keep form visibility tied to live sheet height so drag-minimize and chevron-expand
    /// don't flash bottom-pinned CTAs (frequency/save) through the chrome band.
    ///
    /// Does **not** flip `isInCompactDraftMode` — that still comes from the detent callback
    /// / chevron toggle. Height only drives form hide/show so a cancelled drag can't stick
    /// us in logical compact mode.
    private func syncCompactContentWithSheetHeight() {
        guard hasCompletedInitialPresentation, !isDismissingSheet, allowsMinimizedSheetDetent else {
            return
        }

        if isSheetHeightInCompactBand {
            // Dragging toward compact (or animating through the band): hide CTAs/fields now.
            if canEnterCompactMode || isInCompactDraftMode || pendingCompactContentRestore {
                // Collapse attachment overlays on first hide; logical compact still waits
                // for the detent callback / chevron so a cancelled drag can recover.
                if canEnterCompactMode && !isInCompactDraftMode && viewsHiddenForCompactMode.isEmpty {
                    prepareForCompactDraftMode()
                }
                applyCompactFormHidden(true, animated: false)
            }
            return
        }

        if isInCompactDraftMode {
            // Still docked logically — keep form hidden even if height briefly grew.
            applyCompactFormHidden(true, animated: false)
            return
        }

        if pendingCompactContentRestore || containerView.alpha < 1 || !viewsHiddenForCompactMode.isEmpty {
            // Expand finished, or a drag toward compact was cancelled before settle.
            pendingCompactContentRestore = false
            applyCompactFormHidden(false, animated: true)
        }
    }

    private func applyCompactFormHidden(_ hidden: Bool, animated: Bool) {
        if hidden {
            suppressOverlappingContentForCompactMode()
        } else {
            restoreViewsHiddenForCompactMode()
        }
        containerView.isUserInteractionEnabled = !hidden
        view.bringSubviewToFront(navigationBar)

        let updates = {
            self.containerView.alpha = hidden ? 0 : 1
        }
        if animated {
            UIView.animate(
                withDuration: 0.2,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction],
                animations: updates
            )
        } else {
            containerView.layer.removeAllAnimations()
            updates()
        }
    }

    /// Hide `containerView` subviews while compact so they aren't visible under the chrome.
    private func suppressOverlappingContentForCompactMode() {
        for subview in containerView.subviews {
            guard !viewsHiddenForCompactMode.contains(where: { $0 === subview }) else {
                subview.isHidden = true
                continue
            }
            guard !subview.isHidden else { continue }
            subview.isHidden = true
            viewsHiddenForCompactMode.append(subview)
        }
    }
    
    /// Call from the presenting screen's `viewWillAppear` so edge-swipe stays disabled
    /// after pushing/popping under a minimized draft.
    func refreshDraftNavigationPopGuard() {
        guard allowsMinimizedSheetDetent,
              let nav = resolvedPresentingNavigationController() else {
            removeDraftNavigationPopGuard()
            return
        }

        let presenter = resolvedPresentingContentViewController()
        let shouldGuard = isInCompactDraftMode && (presenter == nil || nav.topViewController === presenter)
        if shouldGuard {
            installDraftNavigationPopGuard(navigationController: nav)
        } else {
            removeDraftNavigationPopGuard()
        }
    }
    
    private func resolvedPresentingContentViewController() -> UIViewController? {
        guard let presenting = presentingViewController else { return nil }
        if let nav = presenting as? UINavigationController {
            return nav.topViewController
        }
        return presenting
    }
    
    private func resolvedPresentingNavigationController() -> UINavigationController? {
        if let nav = presentingViewController as? UINavigationController {
            return nav
        }
        return presentingViewController?.navigationController
    }
    
    private func installDraftNavigationPopGuard(navigationController nav: UINavigationController) {
        if !draftPopGuardInstalled {
            draftPopGuardedPresenter = resolvedPresentingContentViewController()
            draftPopGuardPreviousInteractivePopEnabled = nav.interactivePopGestureRecognizer?.isEnabled ?? true
            draftPopGuardInstalled = true
        }
        // Back button is intercepted by NNNavigationController; disable edge-swipe here.
        nav.interactivePopGestureRecognizer?.isEnabled = false
    }
    
    private func removeDraftNavigationPopGuard() {
        guard draftPopGuardInstalled else { return }

        draftPopGuardedPresenter?.navigationController?.interactivePopGestureRecognizer?.isEnabled =
            draftPopGuardPreviousInteractivePopEnabled
        resolvedPresentingNavigationController()?.interactivePopGestureRecognizer?.isEnabled =
            draftPopGuardPreviousInteractivePopEnabled

        draftPopGuardedPresenter = nil
        draftPopGuardPreviousInteractivePopEnabled = true
        draftPopGuardInstalled = false
    }
    
    /// Used by `NNNavigationController` when the user tries to leave while a draft is docked.
    func confirmDiscardForNavigationPop(proceed: @escaping () -> Void) {
        confirmDiscardIfNeeded(
            title: "Discard Draft?",
            message: "You have a draft in progress. Leaving will discard it.",
            discardActionTitle: "Discard Draft",
            proceed: proceed
        )
    }
    
    /// Dismisses the draft sheet, then runs `completion` (typically a nav pop).
    func dismissForNavigationPop(completion: @escaping () -> Void) {
        prepareForSheetDismissal()
        let result = handleDismissalResult()
        delegate?.sheetViewController(self, didDismissWithResult: result)
        dismiss(animated: true) { [weak self] in
            self?.notifySheetDidDismiss()
            completion()
        }
    }

    private func notifySheetDidDismiss() {
        let callback = onSheetDidDismiss
        onSheetDidDismiss = nil
        callback?()
    }

    private func prepareForSheetDismissal() {
        guard !isDismissingSheet else { return }
        isDismissingSheet = true
        removeDraftNavigationPopGuard()

        // keyboardLayoutGuide can collapse during a page-sheet dismiss, zeroing the
        // container height (and clipping content when clipsToBounds is set). Pin to the
        // view bottom before the transition so layout stays stable.
        unpinContainerFromKeyboardLayoutGuide()

        // Drop the compact detent so dismiss doesn't step through it and hide content.
        if let sheet = sheetPresentationController, allowsMinimizedSheetDetent {
            sheet.detents = [.large()]
            sheet.largestUndimmedDetentIdentifier = nil
            sheet.prefersGrabberVisible = false
        }
        restoreViewsHiddenForCompactMode()
        isInCompactDraftMode = false
        pendingCompactContentRestore = false
        containerView.isUserInteractionEnabled = true

        // Kill any in-flight compact-mode fade so content can't finish at alpha 0 mid-dismiss.
        containerView.layer.removeAllAnimations()
        containerView.alpha = 1
        view.layoutIfNeeded()
    }

    private func pinContainerToKeyboardLayoutGuide() {
        guard containerKeyboardBottomConstraint == nil else { return }
        containerBottomConstraint?.isActive = false
        let keyboardBottom = containerView.bottomAnchor.constraint(
            equalTo: view.keyboardLayoutGuide.topAnchor,
            constant: 16
        )
        keyboardBottom.isActive = true
        containerKeyboardBottomConstraint = keyboardBottom
        containerBottomConstraint = keyboardBottom
    }

    private func unpinContainerFromKeyboardLayoutGuide() {
        guard containerKeyboardBottomConstraint != nil else { return }
        containerKeyboardBottomConstraint?.isActive = false
        containerKeyboardBottomConstraint = nil
        let bottom = containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        bottom.isActive = true
        containerBottomConstraint = bottom
    }
    
    private func restoreViewsHiddenForCompactMode() {
        for subview in viewsHiddenForCompactMode {
            subview.layer.removeAllAnimations()
            subview.isHidden = false
        }
        viewsHiddenForCompactMode.removeAll()
        containerView.layer.removeAllAnimations()
        containerView.alpha = 1
        containerView.isUserInteractionEnabled = true
    }
    
    /// Shows the discard confirmation; `proceed` runs only if the user chooses to discard.
    func confirmDiscardIfNeeded(
        title: String = "Discard Changes?",
        message: String = "You have unsaved changes. Are you sure you want to discard them?",
        discardActionTitle: String = "Discard Changes",
        proceed: @escaping () -> Void
    ) {
        // Avoid stacking alerts if the user taps back repeatedly.
        if presentedViewController is UIAlertController { return }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Keep Editing", style: .cancel) { [weak self] _ in
            guard let self, self.isInCompactDraftMode else { return }
            // Bring the draft back up so it's obvious what they're keeping.
            self.toggleMinimizedDetent()
        })
        alert.addAction(UIAlertAction(title: discardActionTitle, style: .destructive) { _ in
            proceed()
        })
        present(alert, animated: true)
    }
    
    func setInfoButtonWidth(_ width: CGFloat) {
        // No-op: retained for subclass compatibility.
    }
    
    // MARK: - Methods for Subclasses to Override
    func addContentToContainer() {
        // Subclasses should override this to add their specific content
    }

    /// Optional view pinned between the navigation bar and the title field.
    /// Subclasses should add the view to `containerView` in `addContentToContainer()`.
    var contentAboveTitleField: UIView? { nil }
    
    func setupInfoButton() {
        setLeadingBarButtonHidden(true)
    }
    
    func handleDismissalResult() -> Any? {
        return nil
    }
    
    // MARK: - Private Methods
    private func configureSheetPresentationIfNeeded() {
        containerView.layer.cornerRadius = 0
        presentationController?.delegate = self
        applyCompactDetentConfiguration(forceLargeSelection: true)
        sheetPresentationController?.prefersScrollingExpandsWhenScrolledToEdge = true
        titleField.addTarget(
            self,
            action: #selector(titleFieldEditingChangedForCompactDetent),
            for: .editingChanged
        )
    }
    
    /// Call from subclasses whenever form content may have gained/lost pending changes
    /// so the compact detent and chevron stay in sync.
    func refreshCompactDetentAvailability() {
        guard allowsMinimizedSheetDetent else { return }
        applyCompactDetentConfiguration(forceLargeSelection: false)
        refreshNavigationBarItems()
    }
    
    private func applyCompactDetentConfiguration(forceLargeSelection: Bool) {
        guard let sheet = sheetPresentationController else { return }

        guard allowsMinimizedSheetDetent else {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = false
            sheet.largestUndimmedDetentIdentifier = nil
            if forceLargeSelection {
                sheet.selectedDetentIdentifier = .large
            }
            return
        }

        if canEnterCompactMode {
            let minimized = UISheetPresentationController.Detent.custom(
                identifier: Self.minimizedDetentIdentifier
            ) { _ in
                Self.minimizedDetentHeight
            }
            sheet.detents = [minimized, .large()]
            sheet.prefersGrabberVisible = true
            // Keep the presenter interactive only while docked; full height dims as usual.
            sheet.largestUndimmedDetentIdentifier = Self.minimizedDetentIdentifier
            if forceLargeSelection {
                sheet.selectedDetentIdentifier = .large
            }
        } else {
            // Pending changes cleared — leave compact if needed, then remove the detent.
            if isInCompactDraftMode || sheet.selectedDetentIdentifier == Self.minimizedDetentIdentifier {
                sheet.animateChanges {
                    sheet.selectedDetentIdentifier = .large
                }
                updateMinimizedAppearance(compact: false)
            }
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = false
            sheet.largestUndimmedDetentIdentifier = nil
        }
    }
    
    @objc private func titleFieldEditingChangedForCompactDetent() {
        refreshCompactDetentAvailability()
    }
    
    @objc private func toggleMinimizedDetent() {
        guard allowsMinimizedSheetDetent,
              let sheet = sheetPresentationController else { return }

        let currentlyCompact = isInCompactDraftMode
            || sheet.selectedDetentIdentifier == Self.minimizedDetentIdentifier
        let minimizing = !currentlyCompact

        // Only dock when there's something pending to keep as a draft.
        if minimizing && !hasDiscardableContent { return }

        let target: UISheetPresentationController.Detent.Identifier = minimizing
            ? Self.minimizedDetentIdentifier
            : .large

        if minimizing {
            view.endEditing(true)
        }

        sheet.animateChanges {
            sheet.selectedDetentIdentifier = target
        }
        // Pass compact explicitly — selectedDetentIdentifier can lag during animation.
        updateMinimizedAppearance(compact: minimizing)
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func keyboardAnimationOptions(from notification: NSNotification) -> UIView.AnimationOptions {
        let curveValue = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
        return UIView.AnimationOptions(rawValue: curveValue << 16)
    }

    @objc private func keyboardWillShow(_ notification: NSNotification) {
        guard !isDismissingSheet else { return }

        pinContainerToKeyboardLayoutGuide()

        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            onKeyboardShow()
            view.layoutIfNeeded()
            return
        }

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [keyboardAnimationOptions(from: notification), .beginFromCurrentState]
        ) {
            self.onKeyboardShow()
            self.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(_ notification: NSNotification) {
        guard !isDismissingSheet else { return }

        unpinContainerFromKeyboardLayoutGuide()

        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            onKeyboardHide()
            view.layoutIfNeeded()
            return
        }

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [keyboardAnimationOptions(from: notification), .beginFromCurrentState]
        ) {
            self.onKeyboardHide()
            self.view.layoutIfNeeded()
        }
    }
    
    func onKeyboardShow() {
        
    }
    
    func onKeyboardHide() {
        
    }
    
    @objc func dismissViewController() {
        attemptDismiss()
    }
    
    private func attemptDismiss() {
        guard hasDiscardableContent else {
            performDismiss()
            return
        }
        // Dismiss keyboard before the alert; container stays pinned until discard confirms.
        view.endEditing(true)
        confirmDiscardIfNeeded { [weak self] in
            self?.performDismiss()
        }
    }
    
    private func performDismiss() {
        // Freeze layout before endEditing so keyboard hide can't collapse the container.
        prepareForSheetDismissal()
        view.endEditing(true)
        let result = handleDismissalResult()
        delegate?.sheetViewController(self, didDismissWithResult: result)
        dismiss(animated: true) { [weak self] in
            self?.notifySheetDidDismiss()
        }
    }
    
    func shakeContainerView() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.6
        animation.values = [-20.0, 20.0, -20.0, 20.0, -10.0, 10.0, -5.0, 5.0, 0.0]
        containerView.layer.add(animation, forKey: "shake")
        HapticsHelper.mediumHaptic()
    }
}

// MARK: - UISheetPresentationControllerDelegate
extension NNSheetViewController: UISheetPresentationControllerDelegate {
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        guard hasDiscardableContent else { return true }
        view.endEditing(true)
        confirmDiscardIfNeeded { [weak self] in
            self?.performDismiss()
        }
        return false
    }

    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        // Covers interactive swipe-dismiss (bypasses performDismiss).
        prepareForSheetDismissal()
        view.endEditing(true)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // Interactive swipe-dismiss only (not called after `dismiss(animated:)`).
        let result = handleDismissalResult()
        delegate?.sheetViewController(self, didDismissWithResult: result)
        notifySheetDidDismiss()
    }

    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
        _ sheetPresentationController: UISheetPresentationController
    ) {
        guard !isDismissingSheet else { return }

        if sheetPresentationController.selectedDetentIdentifier == Self.minimizedDetentIdentifier {
            // Compact is only valid while there are pending changes.
            guard hasDiscardableContent else {
                sheetPresentationController.animateChanges {
                    sheetPresentationController.selectedDetentIdentifier = .large
                }
                updateMinimizedAppearance(compact: false)
                refreshCompactDetentAvailability()
                return
            }
            view.endEditing(true)
        }
        updateMinimizedAppearance()
    }
}

// MARK: - CompactDraftTitleView

/// Centered draft subject for the docked sheet. Non-interactive so a wide title can't
/// cover close / expand hit targets (especially with an undimmed compact detent).
private final class CompactDraftTitleView: UIView {
    private let label: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    var text: String? {
        get { label.text }
        set {
            label.text = newValue
            invalidateIntrinsicContentSize()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let labelSize = label.intrinsicContentSize
        // Cap width so the title stays visually centered between the bar buttons
        // without extending under them.
        return CGSize(width: min(max(labelSize.width, 40), 200), height: 44)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
}
