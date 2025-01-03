// ... paste the entire StepperProgressView code here ... 

import UIKit

class ProgressStep {
    let title: String
    var progress: CGFloat // 0 to 1
    
    init(title: String, progress: CGFloat = 0) {
        self.title = title
        self.progress = progress
    }
}

class StepperProgressView: UIView {
    private var steps: [ProgressStep] = []
    private var stepViews: [StepCircleView] = []
    private var connectors: [StepConnectorView] = []
    
    private let circleSize: CGFloat = 32
    private let connectorHeight: CGFloat = 2
    private let labelSpacing: CGFloat = 8
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .clear
    }
    
    func configure(with steps: [ProgressStep]) {
        self.steps = steps
        clearExistingViews()
        setupStepViews()
        setupConnectors()
        setNeedsLayout()
    }
    
    private func clearExistingViews() {
        stepViews.forEach { $0.removeFromSuperview() }
        connectors.forEach { $0.removeFromSuperview() }
        stepViews.removeAll()
        connectors.removeAll()
    }
    
    private func setupStepViews() {
        for (index, step) in steps.enumerated() {
            let stepView = StepCircleView(frame: .zero)
            stepView.progress = step.progress
            addSubview(stepView)
            stepViews.append(stepView)
            
            let label = UILabel()
            label.text = step.title
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 14)
            label.textColor = .gray
            addSubview(label)
            stepView.associatedLabel = label
        }
    }
    
    private func setupConnectors() {
        guard stepViews.count > 1 else { return }
        
        for i in 0..<(stepViews.count - 1) {
            let connector = StepConnectorView()
            addSubview(connector)
            connectors.append(connector)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let totalWidth = bounds.width
        let stepCount = CGFloat(stepViews.count)
        let spacing = (totalWidth - (circleSize * stepCount)) / (stepCount - 1)
        
        for (index, stepView) in stepViews.enumerated() {
            let x = CGFloat(index) * (circleSize + spacing)
            stepView.frame = CGRect(x: x, y: 0, width: circleSize, height: circleSize)
            
            if let label = stepView.associatedLabel {
                label.sizeToFit()
                label.frame = CGRect(
                    x: x + (circleSize - label.bounds.width) / 2,
                    y: circleSize + labelSpacing,
                    width: label.bounds.width,
                    height: label.bounds.height
                )
            }
            
            if index < connectors.count {
                let connector = connectors[index]
                connector.frame = CGRect(
                    x: x + circleSize,
                    y: (circleSize - connectorHeight) / 2,
                    width: spacing,
                    height: connectorHeight
                )
            }
        }
    }
    
    func updateProgress(at index: Int, progress: CGFloat) {
        guard index < steps.count else { return }
        steps[index].progress = progress
        stepViews[index].progress = progress
        
        // Update connector if needed
        if index < connectors.count {
            connectors[index].progress = progress
        }
    }
}

class StepCircleView: UIView {
    private let checkmarkImageView = UIImageView()
    private let progressLayer = CAShapeLayer()
    private let backgroundLayer = CAShapeLayer()
    var associatedLabel: UILabel?
    
    var progress: CGFloat = 0 {
        didSet {
            updateAppearance()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .clear
        
        // Setup background circle layer
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.strokeColor = UIColor.systemGray5.cgColor
        backgroundLayer.lineWidth = 4
        layer.addSublayer(backgroundLayer)
        
        // Setup progress layer
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = NNColors.primary.cgColor
        progressLayer.lineWidth = 4
        progressLayer.lineCap = .round
        layer.addSublayer(progressLayer)
        
        // Setup checkmark with bold configuration and circular mask
        let symbolConfig = UIImage.SymbolConfiguration(weight: .bold)
        checkmarkImageView.image = UIImage(systemName: "checkmark", withConfiguration: symbolConfig)
        checkmarkImageView.tintColor = .white
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.clipsToBounds = true
        addSubview(checkmarkImageView)
        checkmarkImageView.isHidden = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update circle paths
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - progressLayer.lineWidth) / 2
        
        // Background circle path (clockwise)
        let backgroundPath = UIBezierPath(arcCenter: center,
                                        radius: radius,
                                        startAngle: -.pi/2,
                                        endAngle: .pi * 1.5,
                                        clockwise: true)
        backgroundLayer.path = backgroundPath.cgPath
        
        // Progress circle path (counter-clockwise)
        let progressPath = UIBezierPath(arcCenter: center,
                                      radius: radius,
                                      startAngle: -.pi/2,
                                      endAngle: .pi * 1.5,
                                      clockwise: false)  // Changed to counter-clockwise
        progressLayer.path = progressPath.cgPath
        
        // Update checkmark frame and make it circular
        let padding: CGFloat = 8
        checkmarkImageView.frame = bounds.insetBy(dx: padding, dy: padding)
        checkmarkImageView.layer.cornerRadius = checkmarkImageView.bounds.width / 2
    }
    
    private func updateAppearance() {
        if progress >= 1 {
            // Show completed state
            backgroundColor = NNColors.primary
            progressLayer.isHidden = true
            backgroundLayer.isHidden = true
            checkmarkImageView.isHidden = false
            
            // Animate checkmark
            let animation = CABasicAnimation(keyPath: "transform.scale")
            animation.fromValue = 0
            animation.toValue = 1
            animation.duration = 0.2
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            checkmarkImageView.layer.add(animation, forKey: "scale")
        } else {
            // Show progress state
            backgroundColor = progress > 0 ? NNColors.primary.withAlphaComponent(0.2) : .clear
            progressLayer.isHidden = false
            backgroundLayer.isHidden = false
            checkmarkImageView.isHidden = true
            
            // Animate progress
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = progressLayer.strokeEnd
            animation.toValue = progress
            animation.duration = 0.2
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            progressLayer.strokeEnd = progress
            progressLayer.add(animation, forKey: "progress")
        }
    }
}

class StepConnectorView: UIView {
    var progress: CGFloat = 0 {
        didSet {
            updateProgress()
        }
    }
    
    private let backgroundLayer = CALayer()
    private let progressLayer = CALayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundLayer.backgroundColor = UIColor.systemGray5.cgColor
        progressLayer.backgroundColor = UIColor.systemGreen.cgColor
        
        layer.addSublayer(backgroundLayer)
        layer.addSublayer(progressLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundLayer.frame = bounds
        updateProgress()
    }
    
    private func updateProgress() {
        progressLayer.frame = CGRect(x: 0, y: 0, width: bounds.width * progress, height: bounds.height)
    }
}