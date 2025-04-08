import UIKit

class NNSurveyOptionButton: UIControl {
    
    // MARK: - Properties
    private(set) var isOptionSelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    // MARK: - UI Elements
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        return stack
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.numberOfLines = 0
        label.textAlignment = .left
        label.textColor = .label
        return label
    }()
    
    private let iconImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.image = UIImage(systemName: "checkmark")
        view.isHidden = true
        view.tintColor = NNColors.primary
        return view
    }()
    
    // MARK: - Initialization
    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        // Setup cell appearance
        layer.borderWidth = 1.5
        layer.cornerRadius = 8
        clipsToBounds = true
        
        // Setup layout
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(iconImageView)
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(greaterThanOrEqualTo: trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Add touch handling
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: .touchUpInside)
        addTarget(self, action: #selector(touchCancel), for: [.touchUpOutside, .touchCancel])
        
        updateAppearance()
    }
    
    private func updateAppearance() {
        // Update cell appearance
        layer.borderColor = isOptionSelected ? NNColors.primary.cgColor : UIColor.tertiarySystemFill.cgColor
        backgroundColor = isOptionSelected ? NNColors.primaryOpaque.withAlphaComponent(0.5) : .clear

        // Add checkmark when selected
        iconImageView.isHidden = !isOptionSelected
    }
    
    // MARK: - Touch Handling
    @objc private func touchDown() {
        animate(transform: CGAffineTransform(scaleX: 0.98, y: 0.98))
    }
    
    @objc private func touchUp() {
        animate(transform: .identity)
        isOptionSelected.toggle()
        HapticsHelper.lightHaptic()
        sendActions(for: .valueChanged)
    }
    
    @objc private func touchCancel() {
        animate(transform: .identity)
    }
    
    private func animate(transform: CGAffineTransform) {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.transform = transform
        }
    }
    
    // MARK: - Public Methods
    func setSelected(_ selected: Bool) {
        isOptionSelected = selected
    }
} 
