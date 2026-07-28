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
    
    /// Hidden compatibility shim — subclasses set `.text`; synced to `navigationItem.title`.
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
        containerView.addSubview(navigationBar)
        containerView.addSubview(titleField)
        containerView.addSubview(dividerView)
        
        addContentToContainer()
    }
    
    override func constrainSubviews() {
        setupNavigationBar()

        containerTopConstraint = containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        containerBottomConstraint = containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)

        NSLayoutConstraint.activate([
            containerTopConstraint!,
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerBottomConstraint!,

            navigationBar.topAnchor.constraint(
                equalTo: containerView.topAnchor,
                constant: Self.navigationBarTopInset
            ),
            navigationBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            navigationBar.heightAnchor.constraint(equalToConstant: Self.navigationBarHeight),
            
            titleField.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 16),
            titleField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            dividerView.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 16),
            dividerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            dividerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            dividerView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func setupNavigationBar() {
        navigationBar.setItems([navigationItem], animated: false)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = NNColors.groupedBackground
        appearance.shadowColor = .clear
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
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

    func setLeadingDoneBarButton(title: String, target: Any, action: Selector) {
        leadingDoneBarButtonTitle = title
        leadingDoneTarget = target as AnyObject
        leadingDoneAction = action
        leadingBarButtonMenu = nil
        refreshNavigationBarItems()
    }

    func refreshNavigationBarItems() {
        navigationItem.title = titleLabel.text

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissViewController)
        )

        if !showsLeadingBarButton {
            navigationItem.leftBarButtonItem = nil
        } else if let title = leadingDoneBarButtonTitle,
                  let target = leadingDoneTarget,
                  let action = leadingDoneAction {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: title,
                style: .done,
                target: target,
                action: action
            )
        } else if let menu = leadingBarButtonMenu {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "ellipsis"),
                menu: menu
            )
        } else {
            navigationItem.leftBarButtonItem = nil
        }

        navigationBar.setItems([navigationItem], animated: false)
    }
    
    func setInfoButtonWidth(_ width: CGFloat) {
        // No-op: retained for subclass compatibility.
    }
    
    // MARK: - Methods for Subclasses to Override
    func addContentToContainer() {
        // Subclasses should override this to add their specific content
    }
    
    func setupInfoButton() {
        setLeadingBarButtonHidden(true)
    }
    
    func handleDismissalResult() -> Any? {
        return nil
    }
    
    // MARK: - Private Methods
    private func configureSheetPresentationIfNeeded() {
        containerView.layer.cornerRadius = 0

        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = false
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private var containerBottomReferenceInset: CGFloat {
        view.bounds.maxY - view.safeAreaLayoutGuide.layoutFrame.maxY
    }

    private func keyboardOverlap(from notification: NSNotification) -> CGFloat {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return 0
        }
        let keyboardFrameInView = view.convert(keyboardFrame, from: nil)
        return max(0, view.bounds.maxY - keyboardFrameInView.minY)
    }

    private func desiredKeyboardShift(for overlap: CGFloat) -> CGFloat {
        max(0, overlap - containerBottomReferenceInset - Self.ctaBottomPadding)
    }

    private func availableContainerTopTranslation() -> CGFloat {
        view.layoutIfNeeded()
        let topSlack = containerView.frame.minY - view.safeAreaLayoutGuide.layoutFrame.minY
        return max(0, topSlack)
    }

    private func keyboardAnimationOptions(from notification: NSNotification) -> UIView.AnimationOptions {
        let curveValue = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
        return UIView.AnimationOptions(rawValue: curveValue << 16)
    }

    @objc private func keyboardWillShow(_ notification: NSNotification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        let overlap = keyboardOverlap(from: notification)
        let desiredShift = desiredKeyboardShift(for: overlap)
        let topTranslation = min(desiredShift, availableContainerTopTranslation())

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [keyboardAnimationOptions(from: notification), .beginFromCurrentState]
        ) {
            self.containerBottomConstraint?.constant = -desiredShift
            self.containerTopConstraint?.constant = -topTranslation
            self.onKeyboardShow()
            self.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(_ notification: NSNotification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [keyboardAnimationOptions(from: notification), .beginFromCurrentState]
        ) {
            self.containerBottomConstraint?.constant = 0
            self.containerTopConstraint?.constant = 0
            self.onKeyboardHide()
            self.view.layoutIfNeeded()
        }
    }
    
    func onKeyboardShow() {
        
    }
    
    func onKeyboardHide() {
        
    }
    
    @objc func dismissViewController() {
        let result = handleDismissalResult()
        delegate?.sheetViewController(self, didDismissWithResult: result)
        dismiss(animated: true)
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
