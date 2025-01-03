import UIKit

final class NNStepProgressView: UIView {
    enum StepState {
        case incomplete
        case inProgress(progress: Float)  // 0.0 to 1.0
        case complete
    }
    
    private let stepSize: CGFloat = 24
    private let lineHeight: CGFloat = 2
    private let spacing: CGFloat = 8
    
    private var stepViews: [NNCircularStepView] = []
    private var connectionLines: [UIView] = []
    private var labels: [UILabel] = []
    
    private let steps: [String]
    
    init(steps: [String]) {
        self.steps = steps
        super.init(frame: .zero)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Create horizontal stack view to hold all elements
        let horizontalStack = UIStackView()
        horizontalStack.translatesAutoresizingMaskIntoConstraints = false
        horizontalStack.axis = .horizontal
        horizontalStack.distribution = .equalSpacing  // This ensures equal spacing between elements
        horizontalStack.alignment = .center
        addSubview(horizontalStack)
        
        // Create step views and labels
        for (index, step) in steps.enumerated() {
            // Create vertical stack for each step
            let stepStack = UIStackView()
            stepStack.axis = .vertical
            stepStack.alignment = .center
            stepStack.spacing = spacing
            
            // Create circular step view
            let stepView = NNCircularStepView(size: stepSize)
            stepViews.append(stepView)
            stepStack.addArrangedSubview(stepView)
            
            // Create label
            let label = UILabel()
            label.text = step
            label.font = .systemFont(ofSize: 14, weight: index == 0 ? .semibold : .regular)
            label.textColor = index == 0 ? .label : .secondaryLabel
            label.textAlignment = .center
            labels.append(label)
            stepStack.addArrangedSubview(label)
            
            // Add step stack to horizontal stack
            horizontalStack.addArrangedSubview(stepStack)
            
            // Create and add connection line (except for last step)
            if index < steps.count - 1 {
                let line = UIView()
                line.backgroundColor = .systemGray5
                line.translatesAutoresizingMaskIntoConstraints = false
                horizontalStack.addArrangedSubview(line)
                connectionLines.append(line)
                
                // Set line height and width
                NSLayoutConstraint.activate([
                    line.heightAnchor.constraint(equalToConstant: lineHeight),
                    line.widthAnchor.constraint(equalToConstant: 40)
                ])
            }
        }
        
        // Constrain horizontal stack
        NSLayoutConstraint.activate([
            horizontalStack.topAnchor.constraint(equalTo: topAnchor),
            horizontalStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            horizontalStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            horizontalStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Set fixed size for step views
        stepViews.forEach { stepView in
            NSLayoutConstraint.activate([
                stepView.widthAnchor.constraint(equalToConstant: stepSize),
                stepView.heightAnchor.constraint(equalToConstant: stepSize)
            ])
        }
    }
    
    func updateState(_ state: StepState, forStep step: Int) {
        guard step < stepViews.count else { return }
        
        let stepView = stepViews[step]
        
        switch state {
        case .incomplete:
            stepView.setState(.incomplete)
            labels[step].font = .systemFont(ofSize: 14, weight: .regular)
            labels[step].textColor = .secondaryLabel
            
        case .inProgress(let progress):
            stepView.setState(.inProgress(progress: progress))
            labels[step].font = .systemFont(ofSize: 14, weight: .semibold)
            labels[step].textColor = .label
            
        case .complete:
            stepView.setState(.complete)
            labels[step].font = .systemFont(ofSize: 14, weight: .regular)
            labels[step].textColor = .secondaryLabel
            
            // Update connection line if there is one
            if step < connectionLines.count {
                connectionLines[step].backgroundColor = NNColors.primary
            }
        }
    }
}

// Helper view for the circular progress/checkmark
final class NNCircularStepView: UIView {
    private let size: CGFloat
    private let progressLayer = CAShapeLayer()
    private let checkmarkLayer = CAShapeLayer()
    
    enum State {
        case incomplete
        case inProgress(progress: Float)
        case complete
    }
    
    init(size: CGFloat) {
        self.size = size
        super.init(frame: .zero)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLayers() {
        layer.cornerRadius = size / 2
        backgroundColor = .systemGray5
        
        // Setup progress layer
        let path = UIBezierPath(arcCenter: CGPoint(x: size/2, y: size/2),
                               radius: size/2 - 2,
                               startAngle: -(.pi/2),
                               endAngle: .pi * 1.5,
                               clockwise: true)
        
        progressLayer.path = path.cgPath
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = NNColors.primary.cgColor
        progressLayer.lineWidth = 2
        progressLayer.strokeEnd = 0
        layer.addSublayer(progressLayer)
        
        // Setup checkmark layer
        let checkmarkPath = UIBezierPath()
        checkmarkPath.move(to: CGPoint(x: size * 0.3, y: size * 0.5))
        checkmarkPath.addLine(to: CGPoint(x: size * 0.45, y: size * 0.65))
        checkmarkPath.addLine(to: CGPoint(x: size * 0.7, y: size * 0.35))
        
        checkmarkLayer.path = checkmarkPath.cgPath
        checkmarkLayer.fillColor = UIColor.clear.cgColor
        checkmarkLayer.strokeColor = UIColor.white.cgColor
        checkmarkLayer.lineWidth = 2
        checkmarkLayer.lineCap = .round
        checkmarkLayer.lineJoin = .round
        checkmarkLayer.strokeEnd = 0
        layer.addSublayer(checkmarkLayer)
    }
    
    func setState(_ state: State) {
        switch state {
        case .incomplete:
            backgroundColor = .systemGray5
            progressLayer.strokeEnd = 0
            checkmarkLayer.strokeEnd = 0
            
        case .inProgress(let progress):
            backgroundColor = .systemGray5
            progressLayer.strokeEnd = CGFloat(progress)
            checkmarkLayer.strokeEnd = 0
            
        case .complete:
            backgroundColor = NNColors.primary
            progressLayer.strokeEnd = 0
            
            // Animate checkmark
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.duration = 0.2
            animation.fromValue = 0
            animation.toValue = 1
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            checkmarkLayer.strokeEnd = 1
            checkmarkLayer.add(animation, forKey: "checkmarkAnimation")
        }
    }
} 
