import UIKit

class NNCircularIconButtonWithLabel: UIView {
    
    // MARK: - Properties
    private(set) var button: NNCircularIconButton
    
    private let label: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    init(
        icon: UIImage?,
        title: String,
        backgroundColor: UIColor = .tertiarySystemGroupedBackground,
        foregroundColor: UIColor = .label,
        buttonSize: CGFloat = 60
    ) {
        self.button = NNCircularIconButton(
            icon: icon,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            size: buttonSize
        )
        
        super.init(frame: .zero)
        
        label.text = title.uppercased()
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupView() {
        addSubview(button)
        addSubview(label)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Button constraints
            button.topAnchor.constraint(equalTo: topAnchor),
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            // Label constraints
            label.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 8),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    // MARK: - Public Methods
    func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        button.addTarget(target, action: action, for: controlEvents)
    }
} 