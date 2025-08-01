import UIKit

protocol NNSheetViewControllerDelegate: AnyObject {
    func sheetViewController(_ controller: NNSheetViewController, didDismissWithResult result: Any?)
}

class NNSheetViewController: NNViewController {
    
    // MARK: - Properties
    weak var delegate: NNSheetViewControllerDelegate?
    private let customTransitioningDelegate: NNSheetTransitioningDelegate?
    
    let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = NNColors.groupedBackground
        view.layer.cornerRadius = 34
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .secondaryLabel
        button.backgroundColor = .clear
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let infoButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        let image = UIImage(systemName: "ellipsis", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .tertiaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true // Hidden by default, subclasses enable if needed
        return button
    }()
    
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
    
    let gripView: UIGrabberView = {
        let view = UIGrabberView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Protected Properties (for subclasses)
    var containerBottomConstraint: NSLayoutConstraint?
    var itemsHiddenDuringTransition: [UIView] = []
    
    // MARK: - Private Properties
    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var initialContainerViewOrigin: CGPoint = .zero
    private let dragThreshold: CGFloat = 100.0
    private var hasFiredHaptic = false
    private let sourceFrame: CGRect?
    
    // MARK: - Initialization
    init(sourceFrame: CGRect? = nil) {
        self.sourceFrame = sourceFrame
        self.customTransitioningDelegate = NNSheetTransitioningDelegate(sourceFrame: sourceFrame)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
        transitioningDelegate = customTransitioningDelegate
        view.backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black.withAlphaComponent(0.5)
        setupPanGestureRecognizer()
        setupKeyboardObservers()
        setupInfoButton()
    }
    
    // MARK: - Setup Methods
    override func setup() {
        super.setup()
        closeButton.addTarget(self, action: #selector(dismissViewController), for: .touchUpInside)
    }
    
    override func addSubviews() {
        view.addSubview(containerView)
        containerView.addSubview(gripView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(closeButton)
        containerView.addSubview(infoButton)
        containerView.addSubview(titleField)
        containerView.addSubview(dividerView)
        
        // Allow subclasses to add their content
        addContentToContainer()
    }
    
    override func constrainSubviews() {
        containerBottomConstraint = containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerBottomConstraint!,
            
            gripView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            gripView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
            
            infoButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            infoButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            infoButton.widthAnchor.constraint(equalToConstant: 36),
            infoButton.heightAnchor.constraint(equalToConstant: 36),
            
            titleField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
//            titleField.topAnchor.constraint(greaterThanOrEqualTo: titleLabel.bottomAnchor, constant: 16),
            titleField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            dividerView.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 16),
            dividerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            dividerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            dividerView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }
    
    // MARK: - Methods for Subclasses to Override
    func addContentToContainer() {
        // Subclasses should override this to add their specific content
    }
    
    func setupInfoButton() {
        // Subclasses should override this to configure the info button
        // By default, the info button is hidden
        infoButton.isHidden = true
    }
    
    func handleDismissalResult() -> Any? {
        // Subclasses should override this to provide a result when dismissed
        return nil
    }
    
    // MARK: - Private Methods
    private func setupPanGestureRecognizer() {
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        containerView.addGestureRecognizer(panGestureRecognizer)
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        
        switch gesture.state {
        case .began:
            initialContainerViewOrigin = containerView.frame.origin
            hasFiredHaptic = false
            itemsHiddenDuringTransition.forEach { $0.alpha = 0 }
            view.endEditing(true)
            
        case .changed:
            let newY = max(0, translation.y)
            let maxTranslation: CGFloat = 500
            let scale = max(0.8, 1 - (newY / maxTranslation) * 0.2)
            containerView.transform = CGAffineTransform(scaleX: scale, y: scale)
            
            if newY > dragThreshold && !hasFiredHaptic {
                HapticsHelper.lightHaptic()
                hasFiredHaptic = true
            }
            
        case .ended, .cancelled:
            if translation.y > dragThreshold {
                dismissViewController()
            } else {
                UIView.animate(withDuration: 0.2) {
                    self.containerView.transform = .identity
                    self.containerView.frame.origin = self.initialContainerViewOrigin
                } completion: { _ in
                    UIView.animate(withDuration: 0.15) {
                        self.itemsHiddenDuringTransition.forEach { $0.alpha = 1 }
                    }
                }
            }
            
        default:
            break
        }
    }
    
    @objc private func keyboardWillShow(_ notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        UIView.animate(withDuration: 0.3) {
            self.containerBottomConstraint?.constant = -keyboardFrame.height + 24
            self.onKeyboardShow()
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(_ notification: NSNotification) {
        UIView.animate(withDuration: 0.3) {
            self.containerBottomConstraint?.constant = 0
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
