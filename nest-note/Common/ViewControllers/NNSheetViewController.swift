import UIKit

protocol NNSheetViewControllerDelegate: AnyObject {
    func sheetViewController(_ controller: NNSheetViewController, didDismissWithResult result: Any?)
}

class NNSheetViewController: NNViewController {
    
    static let ctaBottomPadding: CGFloat = 24
    private static let navigationBarHeight: CGFloat = 44
    private static let navigationBarTopInset: CGFloat = 12
    
    // MARK: - Properties
    weak var delegate: NNSheetViewControllerDelegate?

    /// Fired once after the sheet finishes dismissing (close button or swipe).
    var onSheetDidDismiss: (() -> Void)?
    
    /// Whether close / swipe-dismiss should confirm before discarding in-progress work.
    /// Create/edit subclasses override this when the user has entered or changed content.
    var hasDiscardableContent: Bool { false }
    
    /// Set before calling `dismiss` so keyboard/layout callbacks during the dismiss
    /// animation don't fight the transition.
    private var isDismissingSheet = false
    
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
    /// Appears to the left of the close button (index 0 of this array is closest to close).
    private var trailingBarButtonItems: [UIBarButtonItem] = []
    
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

    // MARK: - Setup Methods
    override func addSubviews() {
        view.addSubview(containerView)
        containerView.addSubview(titleField)
        containerView.addSubview(dividerView)
        
        addContentToContainer()

        // Chrome lives on `view`, above `containerView`, so form/CTA/blur/attachment
        // siblings can never cover bar buttons.
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
        // Clear chrome so glass close controls sit on the sheet background
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

    /// Sets bar buttons shown immediately to the left of the system close control.
    func setTrailingBarButtonItems(_ items: [UIBarButtonItem]) {
        trailingBarButtonItems = items
        refreshNavigationBarItems()
    }

    func refreshNavigationBarItems() {
        sheetNavigationItem.titleView = nil
        sheetNavigationItem.title = titleLabel.text

        let closeItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissViewController)
        )
        // First item is rightmost; close stays outermost, trailing items sit beside it.
        sheetNavigationItem.rightBarButtonItems = [closeItem] + trailingBarButtonItems

        if !showsLeadingBarButton {
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

    private func notifySheetDidDismiss() {
        let callback = onSheetDidDismiss
        onSheetDidDismiss = nil
        callback?()
    }

    /// Call at the start of save/update, then finish with `dismissSheet()`.
    /// Pair with `cancelSaveAndDismiss()` if the save fails and the sheet stays open.
    func prepareToSaveAndDismiss() {}

    /// Called after a failed save/update when the sheet stays open.
    func cancelSaveAndDismiss() {}

    private func prepareForSheetDismissal() {
        guard !isDismissingSheet else { return }
        isDismissingSheet = true

        // keyboardLayoutGuide can collapse during a page-sheet dismiss, zeroing the
        // container height (and clipping content when clipsToBounds is set). Pin to the
        // view bottom before the transition so layout stays stable.
        unpinContainerFromKeyboardLayoutGuide()
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
    
    /// Shows the discard confirmation; `proceed` runs only if the user chooses to discard.
    func confirmDiscardIfNeeded(
        title: String = "Discard Changes?",
        message: String = "You have unsaved changes. Are you sure you want to discard them?",
        discardActionTitle: String = "Discard Changes",
        proceed: @escaping () -> Void
    ) {
        // Avoid stacking alerts if the user taps close repeatedly.
        if presentedViewController is UIAlertController { return }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Keep Editing", style: .cancel))
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
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.selectedDetentIdentifier = .large
            sheet.prefersGrabberVisible = false
            // Nested scroll views (e.g. icon grids) must own the drag; otherwise
            // scrolling at the edge is treated as a sheet dismiss gesture.
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
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
        dismissSheet()
    }

    /// Dismisses the sheet and fires `onSheetDidDismiss`. Prefer this over raw `dismiss(animated:)`
    /// so contextual UI (e.g. collection-view highlight) can clear after save/delete.
    func dismissSheet(animated: Bool = true, completion: (() -> Void)? = nil) {
        // Freeze layout before endEditing so keyboard hide can't collapse the container.
        prepareForSheetDismissal()
        view.endEditing(true)
        let result = handleDismissalResult()
        delegate?.sheetViewController(self, didDismissWithResult: result)
        dismiss(animated: animated) { [weak self] in
            self?.notifySheetDidDismiss()
            completion?()
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
        // willDismiss fires as soon as the interactive swipe begins — even a slight
        // pull. Defer prepare/endEditing until the gesture commits so a cancelled
        // drag doesn't dismiss the keyboard or leave isDismissingSheet stuck true.
        guard let coordinator = transitionCoordinator else {
            prepareForSheetDismissal()
            view.endEditing(true)
            return
        }

        coordinator.notifyWhenInteractionChanges { [weak self] context in
            guard let self else { return }
            if context.isCancelled {
                self.isDismissingSheet = false
                return
            }
            // Finger up (or interaction ended) and dismiss will finish.
            guard !context.isInteractive else { return }
            self.prepareForSheetDismissal()
            self.view.endEditing(true)
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // Interactive swipe-dismiss only (not called after `dismiss(animated:)`).
        let result = handleDismissalResult()
        delegate?.sheetViewController(self, didDismissWithResult: result)
        notifySheetDidDismiss()
    }
}
