import UIKit

class MiniEntryDetailView: UIView {
    // MARK: - Properties
    private let keyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let divider: UIView = {
        let view = UIView()
        view.backgroundColor = .quaternaryLabel
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let visibilityLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.text = "Comprehensive"  // Default text
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 4, height: 8)
        layer.shadowRadius = 8
        
        // Disable user interaction on all subviews
        [keyLabel, divider, valueLabel, visibilityLabel, timestampLabel].forEach { view in
            view.isUserInteractionEnabled = false
            addSubview(view)
        }
        
        NSLayoutConstraint.activate([
            keyLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            keyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            keyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            divider.topAnchor.constraint(equalTo: keyLabel.bottomAnchor, constant: 20),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            divider.heightAnchor.constraint(equalToConstant: 1),
            
            valueLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 20),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            visibilityLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            visibilityLabel.bottomAnchor.constraint(equalTo: timestampLabel.topAnchor, constant: -4),
            
            timestampLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            timestampLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            timestampLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Configuration
    func configure(key: String, value: String, lastModified: Date) {
        keyLabel.text = key
        valueLabel.text = value
        timestampLabel.text = "Last modified: \(lastModified.formatted(date: .abbreviated, time: .omitted))"
    }
} 
