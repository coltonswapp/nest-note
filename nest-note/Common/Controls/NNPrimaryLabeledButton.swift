//
//  NNPrimaryLabeledButton.swift
//  nest-note
//
//  Created by Colton Swapp on 10/20/24.
//
import UIKit

class NNBaseControl: UIControl {
    
    enum ControlTappedState {
        case touchDown, touchCancel, touchUp
    }
    
    override var isEnabled: Bool {
        didSet {
            UIView.animate(withDuration: 0.3) {
                self.backgroundColor = self.isEnabled ? self.originalBackgroundColor : .systemGray4
                self.titleLabel.textColor = self.isEnabled ? .white : .systemGray2
            }
        }
    }
    
    // MARK: - Properties
    private var touchDownTimestamp: TimeInterval?
    private let hapticThreshold: TimeInterval = 0.15
    private(set) var originalBackgroundColor: UIColor?
    
    // MARK: - UI Elements
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = .white
        label.font = .h4
        label.isUserInteractionEnabled = false
        return label
    }()
    
    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.isUserInteractionEnabled = false
        return imageView
    }()
    
    lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [imageView, titleLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.spacing = 8
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        return stack
    }()
    
    private var visualEffectView: UIVisualEffectView?
    
    // MARK: - Initialization
    init(title: String, image: UIImage? = nil) {
        super.init(frame: .zero)
        setupControl(title: title, image: image)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = 18
    }
    
    func setTitle(_ title: String) {
        self.titleLabel.text = title
    }
    
    // MARK: - Setup
    private func setupControl(title: String, image: UIImage?) {
        setupAppearance()
        setupTouchHandling()
        setupLayout()
        
        titleLabel.text = title
        imageView.image = image
        imageView.isHidden = image == nil
    }
    
    private func setupAppearance() {
        backgroundColor = NNColors.primary
        layer.cornerRadius = 18
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
        
        layer.borderWidth = 1
        layer.borderColor = backgroundColor?.lighter(by: 15).cgColor
    }
    
    private func setupLayout() {
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 20),
            imageView.widthAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    private func setupTouchHandling() {
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchDragExit), for: .touchDragExit)
        addTarget(self, action: #selector(touchUpOutside), for: .touchUpOutside)
        addTarget(self, action: #selector(touchUp), for: .touchUpInside)
    }
    
    // MARK: - Touch Handling
    @objc private func touchDown() {
        touchDownTimestamp = Date().timeIntervalSince1970
        HapticsHelper.superLightHaptic()
        standardControlAnimation(.touchDown)
    }
    
    @objc private func touchDragExit() {
        touchDownTimestamp = nil
        standardControlAnimation(.touchCancel)
    }
    
    @objc private func touchUpOutside() {
        guard !showsMenuAsPrimaryAction else { return }
        touchDownTimestamp = nil
        standardControlAnimation(.touchCancel)
    }
    
    @objc private func touchUp() {
        if let timestamp = touchDownTimestamp {
            let elapsed = Date().timeIntervalSince1970 - timestamp
            if elapsed > hapticThreshold {
                HapticsHelper.lightHaptic()
            }
        }
        standardControlAnimation(.touchUp)
        touchDownTimestamp = nil
    }
    
    private func standardControlAnimation(_ tappedState: ControlTappedState) {
        switch tappedState {
        case .touchDown:
            UIView.animate(withDuration: 0.075) {
                self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
                self.backgroundColor = self.backgroundColor?.darker(by: 15)
            }
        case .touchCancel, .touchUp:
            UIView.animate(withDuration: 0.075) {
                self.transform = .identity
                self.backgroundColor = self.originalBackgroundColor
            }
        }
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        originalBackgroundColor = backgroundColor
    }
    
    override var backgroundColor: UIColor? {
        didSet {
            layer.borderColor = backgroundColor?.lighter(by: 15).cgColor
        }
    }
    
    /// Pins the button to the bottom of the superview with standard insets and optionally adds a blur effect
    /// - Parameters:
    ///   - view: The view to pin the button to (usually the superview)
    ///   - useSafeArea: Whether to use the safe area layout guide (default is true)
    ///   - horizontalPadding: The padding from the leading and trailing edges (default is 20)
    ///   - bottomPadding: The padding from the bottom edge (default is 10)
    ///   - height: The height of the button (default is 55)
    ///   - addBlurEffect: Whether to add a blur effect view below the button (default is false)
    ///   - blurRadius: The radius of the blur effect (default is 16)
    ///   - blurMaskImage: The mask image for the blur effect (default is nil)
    func pinToBottom(of view: UIView,
                    useSafeArea: Bool = true,
                    horizontalPadding: CGFloat = 20,
                    bottomPadding: CGFloat = 10,
                    height: CGFloat = 55,
                    addBlurEffect: Bool = false,
                    blurRadius: Double = 16,
                    blurMaskImage: UIImage? = nil) {
        translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self)
        
        let bottomAnchor = useSafeArea ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor
        
        if addBlurEffect {
            setupVisualEffectView(in: view, useSafeArea: useSafeArea, blurRadius: blurRadius, blurMaskImage: blurMaskImage)
        }
        
        NSLayoutConstraint.activate([
            self.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: horizontalPadding),
            self.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -horizontalPadding),
            self.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomPadding),
            self.heightAnchor.constraint(equalToConstant: height)
        ])
    }
    
    private func setupVisualEffectView(in view: UIView, useSafeArea: Bool, blurRadius: Double, blurMaskImage: UIImage?) {
        visualEffectView = UIVisualEffectView()
        guard let visualEffectView = visualEffectView else { return }
        
        if let maskImage = blurMaskImage {
            visualEffectView.effect = UIBlurEffect.variableBlurEffect(radius: blurRadius, maskImage: maskImage)
        } else {
            visualEffectView.effect = UIBlurEffect(style: .regular)
        }
        
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(visualEffectView, belowSubview: self)
        
        let bottomAnchor = useSafeArea ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor
        
        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            visualEffectView.topAnchor.constraint(equalTo: bottomAnchor, constant: -self.frame.height - 80)
        ])
    }
}

// Now NNPrimaryLabeledButton can be much simpler
class NNPrimaryLabeledButton: NNBaseControl {
    
    override var isEnabled: Bool {
        didSet {
            UIView.animate(withDuration: 0.3) {
                self.backgroundColor = self.isEnabled ? NNColors.primary : .systemGray4
                self.titleLabel.textColor = self.isEnabled ? .white : .systemGray2
            }
        }
    }
}

// Add this enum at the top level
enum LoadingTransitionStyle {
    case verticalSlide  // Current style where label slides up and spinner slides down
    case rightHide      // Spinner slides in from the right while label stays in place
}

class NNLoadingButton: NNBaseControl {
    
    // MARK: - Properties
    private let transitionStyle: LoadingTransitionStyle
    private var spinnerTrailingConstraint: NSLayoutConstraint?
    
    private lazy var spinner: NNLoadingSpinner = {
        let spinner = NNLoadingSpinner()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isHidden = true
        return spinner
    }()
    
    override var isEnabled: Bool {
        didSet {
            UIView.animate(withDuration: 0.3) {
                self.backgroundColor = self.isEnabled ? self.primaryBackgroundColor : .systemGray4
                self.titleLabel.textColor = self.isEnabled ? .white : .systemGray2
            }
        }
    }
    
    private var primaryBackgroundColor: UIColor = NNColors.primary
    
    // MARK: - Initialization
    init(title: String, 
         titleColor: UIColor, 
         fillStyle: FillStyle, 
         transitionStyle: LoadingTransitionStyle = .verticalSlide) {
        self.transitionStyle = transitionStyle
        super.init(title: title)
        self.primaryBackgroundColor = fillStyle.backgroundColor
        self.titleLabel.textColor = titleColor
        self.imageView.tintColor = titleColor
        backgroundColor = primaryBackgroundColor
        setupSpinner()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        spinner.alpha = 1.0
        startSpinnerOffScreen()
    }
    
    private func setupSpinner() {
        addSubview(spinner)
        
        // Configure spinner color to match button style
        spinner.configure(with: .white) // Or any other color that matches your design
        
        switch transitionStyle {
        case .verticalSlide:
            setupVerticalSlideConstraints()
        case .rightHide:
            setupRightHideConstraints()
        }
    }
    
    private func setupVerticalSlideConstraints() {
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
            spinner.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5),
            spinner.widthAnchor.constraint(equalTo: spinner.heightAnchor)
        ])
    }
    
    private func setupRightHideConstraints() {
        
        NSLayoutConstraint.activate([
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
            spinner.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5),
            spinner.widthAnchor.constraint(equalTo: spinner.heightAnchor),
            spinner.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }
    
    private func startSpinnerOffScreen() {
        switch transitionStyle {
        case .verticalSlide:
            spinner.transform = CGAffineTransform(translationX: 0, y: frame.height)
        case .rightHide:
            spinner.transform = CGAffineTransform(translationX: 60, y: 0)
        }
    }
    
    // MARK: - Loading State
    func startLoading() {
        spinner.isHidden = false
        isUserInteractionEnabled = false

        switch transitionStyle {
        case .verticalSlide:
            animateVerticalSlideIn()
        case .rightHide:
            animateRightSlideIn()
        }
    }
    
    func stopLoading(withSuccess success: Bool? = nil) {
        
        
        if let success = success {
            // Animate success/failure state first
            spinner.animateState(success: success) { [weak self] in
                // After state animation completes, hide the spinner
                self?.hideSpinner()
                self?.isUserInteractionEnabled = true
            }
        } else {
            // Just hide the spinner without state animation
            isUserInteractionEnabled = true
            hideSpinner()
        }
    }
    
    private func hideSpinner() {
        switch transitionStyle {
        case .verticalSlide:
            let animator = UIViewPropertyAnimator(
                duration: 0.4,
                controlPoint1: CGPoint(x: 0.76, y: 0.0),
                controlPoint2: CGPoint(x: 0.24, y: 1.0)
            ) {
                self.spinner.transform = CGAffineTransform(translationX: 0, y: self.frame.height)
                self.stackView.transform = .identity
            }
            animator.addCompletion { _ in
                self.spinner.isHidden = true
                self.spinner.reset()  // Reset the spinner state
            }
            animator.startAnimation()
            
        case .rightHide:
            let animator = UIViewPropertyAnimator(
                duration: 0.4,
                controlPoint1: CGPoint(x: 0.76, y: 0.0),
                controlPoint2: CGPoint(x: 0.24, y: 1.0)
            ) {
                self.spinner.transform = CGAffineTransform(translationX: 60, y: 0)
            }
            animator.addCompletion { _ in
                self.spinner.isHidden = true
                self.spinner.reset()  // Reset the spinner state
            }
            animator.startAnimation()
        }
    }
    
    private func animateVerticalSlideIn() {
        let animator = UIViewPropertyAnimator(
            duration: 0.6,
            controlPoint1: CGPoint(x: 0.76, y: 0.0),
            controlPoint2: CGPoint(x: 0.24, y: 1.0)
        ) {
            self.spinner.transform = .identity
            self.stackView.transform = CGAffineTransform(translationX: 0, y: -self.frame.height)
        }
        animator.startAnimation()
    }
    
    private func animateVerticalSlideOut() {
        let animator = UIViewPropertyAnimator(
            duration: 0.4,
            controlPoint1: CGPoint(x: 0.76, y: 0.0),
            controlPoint2: CGPoint(x: 0.24, y: 1.0)
        ) {
            self.spinner.transform = CGAffineTransform(translationX: 0, y: self.frame.height)
            self.stackView.transform = .identity
        }
        animator.addCompletion { _ in
            self.spinner.isHidden = true
        }
        animator.startAnimation()
    }
    
    private func animateRightSlideIn() {
        let animator = UIViewPropertyAnimator(
            duration: 0.25,
            controlPoint1: CGPoint(x: 0.76, y: 0.0),
            controlPoint2: CGPoint(x: 0.24, y: 1.0)
        ) {
            self.spinner.transform = .identity
        }
        animator.startAnimation()
    }
    
    private func animateRightSlideOut() {
        let animator = UIViewPropertyAnimator(
            duration: 0.4,
            controlPoint1: CGPoint(x: 0.76, y: 0.0),
            controlPoint2: CGPoint(x: 0.24, y: 1.0)
        ) {
            self.spinner.transform = CGAffineTransform(translationX: 60, y: 0)
        }
        animator.addCompletion { _ in
            self.spinner.isHidden = true
        }
        animator.startAnimation()
    }
}

// Add these supporting types
enum FillStyle {
    case fill(UIColor)
    case gradient([UIColor])
    
    var backgroundColor: UIColor {
        switch self {
        case .fill(let color):
            return color
        case .gradient(let colors):
            return colors.first ?? .clear
        }
    }
}

// Add the UIColor extension for darker colors
extension UIColor {
    func darker(by percentage: CGFloat = 30.0) -> UIColor {
        return self.adjust(by: -1 * abs(percentage))
    }
    
    func adjust(by percentage: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return UIColor(
            red: min(red + percentage/100, 1.0),
            green: min(green + percentage/100, 1.0),
            blue: min(blue + percentage/100, 1.0),
            alpha: alpha
        )
    }
    
    func lighter(by percentage: CGFloat = 30.0) -> UIColor {
        return self.adjust(by: abs(percentage))
    }
}

// Add this after NNLoadingButton

class NNSmallPrimaryButton: UIButton {
    
    enum ImagePlacement {
        case left, right
    }
    
    var imagePlacement: ImagePlacement?
    var image: UIImage?
    var title: String
    var foregroundColor: UIColor
    
    // MARK: - Properties
    var originalBackgroundColor: UIColor?
    private var touchDownTimestamp: TimeInterval?
    private let hapticThreshold: TimeInterval = 0.15
    
    // MARK: - Initialization
    init(title: String, 
         image: UIImage? = nil, 
         imagePlacement: ImagePlacement = .left,
         backgroundColor: UIColor = NNColors.primary,
         foregroundColor: UIColor = .white) {
        self.title = title
        self.foregroundColor = foregroundColor
        self.image = image
        super.init(frame: .zero)
        self.backgroundColor = backgroundColor
        self.originalBackgroundColor = backgroundColor
        self.imagePlacement = imagePlacement
        configureButton(title: title, image: image, imagePlacement: imagePlacement, foregroundColor: foregroundColor)
    }
    
    init(image: UIImage,
         backgroundColor: UIColor = NNColors.primary,
         foregroundColor: UIColor = .white) {
        self.title = ""
        self.image = image
        self.foregroundColor = foregroundColor
        super.init(frame: .zero)
        self.backgroundColor = backgroundColor
        self.originalBackgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.imagePlacement = .left
        configureButton(title: title, image: image, imagePlacement: self.imagePlacement ?? .left, foregroundColor: foregroundColor)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = 18
    }
    
    override func setTitle(_ title: String?, for state: UIControl.State) {
        guard let title else { return }
        var container = AttributeContainer()
        container.font = .h4
        configuration?.attributedTitle = AttributedString(title, attributes: container)
    }
    
    func configureButton(title: String, image: UIImage?, imagePlacement: ImagePlacement, foregroundColor: UIColor) {
        var config = UIButton.Configuration.plain()
        
        // Ensure subviews don't intercept touches
        titleLabel?.isUserInteractionEnabled = false
        imageView?.isUserInteractionEnabled = false
        
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        config.baseForegroundColor = foregroundColor
        
        // Configure text attributes with explicit bold weight
        var container = AttributeContainer()
        container.font = .h4
        container.foregroundColor = foregroundColor
        config.attributedTitle = AttributedString(title, attributes: container)
        
        // Configure image if present
        if let image = image {
            config.image = image.withRenderingMode(.alwaysTemplate)
            config.imagePlacement = imagePlacement == .left ? .leading : .trailing
            config.imagePadding = 6
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
            var container = AttributeContainer()
            container.font = .h4
            config.attributedTitle = AttributedString(title, attributes: container)
        }
        
        container.font = .h4
        container.foregroundColor = foregroundColor
        config.attributedTitle = AttributedString(title, attributes: container)
        
        configuration = config
        
        // Basic setup
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true
        
        // Add stroke
        layer.borderWidth = 1
        layer.borderColor = backgroundColor?.lighter(by: 15).cgColor
        
        // Setup touch handling
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchDragExit), for: .touchDragExit)
        addTarget(self, action: #selector(touchUpOutside), for: .touchUpOutside)
        addTarget(self, action: #selector(touchUp), for: .touchUpInside)
    }
    
    // MARK: - Touch Handling
    @objc private func touchDown() {
        touchDownTimestamp = Date().timeIntervalSince1970
        HapticsHelper.superLightHaptic()
        standardControlAnimation(.touchDown)
    }
    
    @objc private func touchDragExit() {
        touchDownTimestamp = nil
        standardControlAnimation(.touchCancel)
    }
    
    @objc private func touchUpOutside() {
        guard !showsMenuAsPrimaryAction else { return }
        touchDownTimestamp = nil
        standardControlAnimation(.touchCancel)
    }
    
    @objc private func touchUp() {
        if let timestamp = touchDownTimestamp {
            let elapsed = Date().timeIntervalSince1970 - timestamp
            if elapsed > hapticThreshold {
                HapticsHelper.lightHaptic()
            }
        }
        standardControlAnimation(.touchUp)
        touchDownTimestamp = nil
    }
    
    private func standardControlAnimation(_ tappedState: NNBaseControl.ControlTappedState) {
        guard !showsMenuAsPrimaryAction else { return }
        switch tappedState {
        case .touchDown:
            UIView.animate(withDuration: 0.075) {
                self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
                self.backgroundColor = self.backgroundColor?.darker(by: 15)
            }
        case .touchCancel, .touchUp:
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
                self.backgroundColor = self.originalBackgroundColor
            }
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            UIView.animate(withDuration: 0.3) {
                self.backgroundColor = self.isEnabled ? self.originalBackgroundColor : .systemGray4
            }
        }
    }
    
    override var backgroundColor: UIColor? {
        didSet {
            layer.borderColor = backgroundColor?.lighter(by: 15).cgColor
        }
    }
}
