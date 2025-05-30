import UIKit

class ButtonPlayground: UIViewController {
    
    private lazy var loadingButton: NNLoadingButton = {
        let button = NNLoadingButton(title: "Login", titleColor: .white, fillStyle: .fill(NNColors.primary))
        button.addTarget(self, action: #selector(handleLoadingButtonTap), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var secondaryLoadingButton: NNLoadingButton = {
        let button = NNLoadingButton(title: "Create Account", titleColor: .white, fillStyle: .fill(.systemBlue), transitionStyle: .rightHide)
        button.addTarget(self, action: #selector(handleSecondaryButtonTap), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var tertiaryLoadingButton: NNLoadingButton = {
        let button = NNLoadingButton(title: "Send Invite", titleColor: .white, fillStyle: .fill(NNColors.offBlack), transitionStyle: .rightHide)
        button.addTarget(self, action: #selector(handleTertiaryButtonTap), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var regularButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Regular Button", image: UIImage(systemName: "star.fill"))
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var slowSpinner: NNLoadingSpinner = {
        let spinner = NNLoadingSpinner()
        spinner.setSpeed(duration: 0.9)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    private lazy var mediumSpinner: NNLoadingSpinner = {
        let spinner = NNLoadingSpinner()
        spinner.setSpeed(duration: 0.6)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    private lazy var fastSpinner: NNLoadingSpinner = {
        let spinner = NNLoadingSpinner()
        spinner.setSpeed(duration: 0.3)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    private lazy var stepperProgress: StepperProgressView = {
        let view = StepperProgressView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var glassButton: GlassyButton = {
        let button = GlassyButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Send", for: .normal)
        button.setTitleColor(NNColors.primary.darken(by: 0.5), for: .normal)
        button.backgroundColor = NNColors.primary
        button.titleLabel?.font = UIFont.bodyL
        return button
    }()
    
    private lazy var progressUpdateButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Update Progress", for: .normal)
        button.addTarget(self, action: #selector(updateProgress), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var currentStep = 0
    private var currentProgress: CGFloat = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // Configure stepper with initial steps
        let steps = [
            ProgressStep(title: "Setup"),
            ProgressStep(title: "Start"),
            ProgressStep(title: "In Progress"),
            ProgressStep(title: "Finish")
        ]
        stepperProgress.configure(with: steps)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Button Playground"
        
        // Add stepper and update button at the top
        view.addSubview(stepperProgress)
        view.addSubview(progressUpdateButton)
        
        // Add existing buttons below
        view.addSubview(loadingButton)
        view.addSubview(secondaryLoadingButton)
        view.addSubview(tertiaryLoadingButton)
        view.addSubview(glassButton)
        view.addSubview(regularButton)
        view.addSubview(slowSpinner)
        view.addSubview(mediumSpinner)
        view.addSubview(fastSpinner)
        
        NSLayoutConstraint.activate([
            // Stepper constraints
            stepperProgress.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stepperProgress.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stepperProgress.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stepperProgress.heightAnchor.constraint(equalToConstant: 60),
            
            progressUpdateButton.topAnchor.constraint(equalTo: stepperProgress.bottomAnchor, constant: 20),
            progressUpdateButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Existing constraints, but now relative to progressUpdateButton
            loadingButton.topAnchor.constraint(equalTo: progressUpdateButton.bottomAnchor, constant: 40),
            loadingButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            loadingButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            loadingButton.heightAnchor.constraint(equalToConstant: 55),
            
            secondaryLoadingButton.topAnchor.constraint(equalTo: loadingButton.bottomAnchor, constant: 20),
            secondaryLoadingButton.leadingAnchor.constraint(equalTo: loadingButton.leadingAnchor),
            secondaryLoadingButton.trailingAnchor.constraint(equalTo: loadingButton.trailingAnchor),
            secondaryLoadingButton.heightAnchor.constraint(equalToConstant: 55),
            
            tertiaryLoadingButton.topAnchor.constraint(equalTo: secondaryLoadingButton.bottomAnchor, constant: 20),
            tertiaryLoadingButton.leadingAnchor.constraint(equalTo: loadingButton.leadingAnchor),
            tertiaryLoadingButton.trailingAnchor.constraint(equalTo: loadingButton.trailingAnchor),
            tertiaryLoadingButton.heightAnchor.constraint(equalToConstant: 55),
            
            glassButton.topAnchor.constraint(equalTo: tertiaryLoadingButton.bottomAnchor, constant: 20),
            glassButton.leadingAnchor.constraint(equalTo: loadingButton.leadingAnchor),
            glassButton.trailingAnchor.constraint(equalTo: loadingButton.trailingAnchor),
            glassButton.heightAnchor.constraint(equalToConstant: 55),
            
            regularButton.topAnchor.constraint(equalTo: glassButton.bottomAnchor, constant: 20),
            regularButton.leadingAnchor.constraint(equalTo: loadingButton.leadingAnchor),
            regularButton.trailingAnchor.constraint(equalTo: loadingButton.trailingAnchor),
            regularButton.heightAnchor.constraint(equalToConstant: 55),
            
            slowSpinner.topAnchor.constraint(equalTo: regularButton.bottomAnchor, constant: 40),
            slowSpinner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 50),
            slowSpinner.widthAnchor.constraint(equalToConstant: 25),
            slowSpinner.heightAnchor.constraint(equalToConstant: 25),
            
            mediumSpinner.topAnchor.constraint(equalTo: slowSpinner.topAnchor),
            mediumSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mediumSpinner.widthAnchor.constraint(equalToConstant: 25),
            mediumSpinner.heightAnchor.constraint(equalToConstant: 25),
            
            fastSpinner.topAnchor.constraint(equalTo: slowSpinner.topAnchor),
            fastSpinner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
            fastSpinner.widthAnchor.constraint(equalToConstant: 25),
            fastSpinner.heightAnchor.constraint(equalToConstant: 25)
        ])
        glassButton.layer.cornerRadius = 55/2
    }
    
    @objc private func handleLoadingButtonTap() {
        loadingButton.startLoading()
        
        // Simulate an async task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.loadingButton.stopLoading()
        }
    }
    
    @objc private func handleSecondaryButtonTap() {
        secondaryLoadingButton.startLoading()
        
        // Simulate an async task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.secondaryLoadingButton.stopLoading(withSuccess: false)
        }
    }
    
    @objc private func handleTertiaryButtonTap() {
        tertiaryLoadingButton.startLoading()
        
        // Simulate an async task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.tertiaryLoadingButton.stopLoading(withSuccess: true)
        }
    }
    
    @objc private func updateProgress() {
        // Increment progress
        currentProgress += 0.33
        if currentProgress >= 1 {
            currentProgress = 0
            currentStep += 1
            if currentStep >= 4 {
                currentStep = 0
            }
        }
        
        // Update current step
        stepperProgress.updateProgress(at: currentStep, progress: currentProgress)
        
        // Update completed steps
        for i in 0..<currentStep {
            stepperProgress.updateProgress(at: i, progress: 1.0)
        }
        
        // Reset future steps
        for i in (currentStep + 1)..<4 {
            stepperProgress.updateProgress(at: i, progress: 0)
        }
    }
}


class GlassyButton: UIButton {
    private let blurEffect = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private let gradientLayer = CAGradientLayer()
    private let borderGradientLayer = CAGradientLayer()
    private let thinBorderGradientLayer = CAGradientLayer()
    private let innerBorderGradientLayer = CAGradientLayer()
    
    private(set) var mainBorderWidth: CGFloat = 5.0
    private(set) var thinBorderWidth: CGFloat = 1.5
    private(set) var innerBorderWidth: CGFloat = 1.5
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        // Set up basic button properties
        layer.cornerRadius = bounds.height / 2
        clipsToBounds = true
        
        // Add blur effect
        blurEffect.frame = bounds
        blurEffect.layer.cornerRadius = bounds.height / 2
        blurEffect.clipsToBounds = true
        insertSubview(blurEffect, at: 0)
        
        // Add gradient overlay for the glossy effect
        gradientLayer.frame = bounds
        gradientLayer.colors = [
            UIColor.white.withAlphaComponent(0.2).cgColor,
            UIColor.white.withAlphaComponent(0.5).cgColor,
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.cornerRadius = bounds.height / 2
        layer.addSublayer(gradientLayer)
        
        // Create main gradient border
        borderGradientLayer.frame = bounds
        borderGradientLayer.masksToBounds = true
        borderGradientLayer.cornerRadius = bounds.height / 2
        layer.addSublayer(borderGradientLayer)
        
        // Create thin gradient border
        thinBorderGradientLayer.frame = bounds
        thinBorderGradientLayer.masksToBounds = true
        thinBorderGradientLayer.cornerRadius = bounds.height / 2
        layer.addSublayer(thinBorderGradientLayer)
        
        // Create inner gradient border
        innerBorderGradientLayer.frame = bounds
        innerBorderGradientLayer.masksToBounds = true
        innerBorderGradientLayer.cornerRadius = bounds.height / 2
        layer.addSublayer(innerBorderGradientLayer)
        
        // Add shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
        
        updateBorderGradient()
    }
    
    func updateBorderGradient() {
        guard let backgroundColor = backgroundColor else { return }
        
        // Configure main gradient
        borderGradientLayer.frame = bounds
        borderGradientLayer.colors = [
            UIColor.white.withAlphaComponent(0.7).cgColor,
            backgroundColor.brighten(by: 0.2).withAlphaComponent(0.6).cgColor,
            backgroundColor.brighten(by: 0.3).withAlphaComponent(0.3).cgColor,
        ]
        borderGradientLayer.locations = [0.0, 0.5, 1.0]
        borderGradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        borderGradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        borderGradientLayer.cornerRadius = bounds.height / 2
        
        // Create main border mask
        let mainMaskLayer = CAShapeLayer()
        mainMaskLayer.lineWidth = mainBorderWidth
        mainMaskLayer.strokeColor = UIColor.white.cgColor
        mainMaskLayer.fillColor = UIColor.clear.cgColor
        mainMaskLayer.path = UIBezierPath(roundedRect: bounds.insetBy(dx: mainBorderWidth/2, dy: mainBorderWidth/2), 
                                        cornerRadius: bounds.height / 2).cgPath
        mainMaskLayer.lineCap = .round
        mainMaskLayer.lineJoin = .round
        
        // Configure thin gradient
        thinBorderGradientLayer.frame = bounds
        thinBorderGradientLayer.colors = [
            backgroundColor.darken(by: 0.3).withAlphaComponent(0.6).cgColor,
            backgroundColor.darken(by: 0.3).withAlphaComponent(0.3).cgColor
        ]
        thinBorderGradientLayer.locations = [0.0, 1.0]
        thinBorderGradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        thinBorderGradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        thinBorderGradientLayer.cornerRadius = bounds.height / 2
        
        // Create thin border mask
        let thinMaskLayer = CAShapeLayer()
        thinMaskLayer.lineWidth = thinBorderWidth
        thinMaskLayer.strokeColor = UIColor.white.cgColor
        thinMaskLayer.fillColor = UIColor.clear.cgColor
        thinMaskLayer.path = UIBezierPath(roundedRect: bounds.insetBy(dx: thinBorderWidth/2, dy: thinBorderWidth/2), 
                                        cornerRadius: bounds.height / 2).cgPath
        thinMaskLayer.lineCap = .round
        thinMaskLayer.lineJoin = .round
        
        // Configure inner gradient
        innerBorderGradientLayer.frame = bounds
        innerBorderGradientLayer.colors = [
            UIColor.white.withAlphaComponent(0.65).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        innerBorderGradientLayer.locations = [0.0, 0.7]
        innerBorderGradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        innerBorderGradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        innerBorderGradientLayer.cornerRadius = bounds.height / 2
        
        // Create inner border mask
        let innerMaskLayer = CAShapeLayer()
        innerMaskLayer.lineWidth = innerBorderWidth
        innerMaskLayer.strokeColor = UIColor.white.cgColor
        innerMaskLayer.fillColor = UIColor.clear.cgColor
        innerMaskLayer.path = UIBezierPath(roundedRect: bounds.insetBy(dx: mainBorderWidth, dy: mainBorderWidth), 
                                         cornerRadius: bounds.height / 2 - mainBorderWidth).cgPath
        innerMaskLayer.lineCap = .round
        innerMaskLayer.lineJoin = .round
        
        // Apply masks
        borderGradientLayer.mask = mainMaskLayer
        thinBorderGradientLayer.mask = thinMaskLayer
        innerBorderGradientLayer.mask = innerMaskLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = self.bounds
        blurEffect.frame = bounds
        gradientLayer.frame = bounds
        borderGradientLayer.frame = bounds
        thinBorderGradientLayer.frame = bounds
        innerBorderGradientLayer.frame = bounds
        borderGradientLayer.cornerRadius = bounds.height / 2
        thinBorderGradientLayer.cornerRadius = bounds.height / 2
        innerBorderGradientLayer.cornerRadius = bounds.height / 2
        updateBorderGradient()
    }
    
    override var backgroundColor: UIColor? {
        didSet {
            updateBorderGradient()
        }
    }
    
    func updateBorderWidths(main: CGFloat? = nil, thin: CGFloat? = nil, inner: CGFloat? = nil) {
        if let main = main {
            mainBorderWidth = main
        }
        if let thin = thin {
            thinBorderWidth = thin
        }
        if let inner = inner {
            innerBorderWidth = inner
        }
        updateBorderGradient()
    }
    
}

// Add these helper methods for color manipulation
extension UIColor {
    func brighten(by percentage: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return UIColor(hue: hue,
                      saturation: saturation,
                      brightness: min(brightness * (1 + percentage), 1.0),
                      alpha: alpha)
    }
    
    func darken(by percentage: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return UIColor(hue: hue,
                      saturation: saturation,
                      brightness: max(brightness * (1 - percentage), 0.0),
                      alpha: alpha)
    }
}
