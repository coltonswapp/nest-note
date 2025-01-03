import UIKit

enum DateTimeControlStyle {
    case date
    case time
    case both
}

enum DateTimeControlType {
    case start
    case end
}

final class NNDateTimeControl: UIStackView {
    
    // MARK: - Properties
    var date: Date = Date() {
        didSet {
            let formatter = DateFormatter()
            
            // Update dateText if we're showing the date
            if style == .both || style == .date {
                formatter.dateFormat = "MMM d, yyyy"
                dateText = formatter.string(from: date)
            }
            
            // Always update timeText
            formatter.dateFormat = "h:mm a"
            timeText = formatter.string(from: date)
        }
    }
    
    var style: DateTimeControlStyle {
        didSet {
            updateLayout()
        }
    }
    
    private let controlType: DateTimeControlType
    
    private lazy var dateControl: DateTimeButton = {
        let control = DateTimeButton()
        control.addTarget(self, action: #selector(dateButtonTapped), for: .touchUpInside)
        return control
    }()
    
    private lazy var timeControl: DateTimeButton = {
        let control = DateTimeButton()
        control.addTarget(self, action: #selector(timeButtonTapped), for: .touchUpInside)
        return control
    }()
    
    var onDateTapped: (() -> Void)?
    var onTimeTapped: (() -> Void)?
    
    var dateText: String {
        get { dateControl.text }
        set { dateControl.text = newValue }
    }
    
    var timeText: String {
        get { timeControl.text }
        set { timeControl.text = newValue }
    }
    
    // MARK: - Initialization
    init(style: DateTimeControlStyle = .both, type: DateTimeControlType = .start) {
        self.style = style
        self.controlType = type
        super.init(frame: .zero)
        setupView()
        setupInitialDate()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupView() {
        spacing = 8
        axis = .horizontal
        distribution = .fill
        updateLayout()
    }
    
    private func updateLayout() {
        // Remove all existing arranged subviews
        arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add appropriate controls based on style
        switch style {
        case .date:
            addArrangedSubview(dateControl)
        case .time:
            addArrangedSubview(timeControl)
        case .both:
            addArrangedSubview(dateControl)
            addArrangedSubview(timeControl)
        }
        
        // Reset alpha values for non-animated updates
        arrangedSubviews.forEach { $0.alpha = 1 }
        
        // Force layout update
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    // MARK: - Actions
    @objc private func dateButtonTapped() {
        onDateTapped?()
    }
    
    @objc private func timeButtonTapped() {
        onTimeTapped?()
    }
    
    func setStyle(_ newStyle: DateTimeControlStyle, animated: Bool = false) {
        // Add both controls if they aren't already in the view hierarchy
        if dateControl.superview == nil {
            addArrangedSubview(dateControl)
        }
        if timeControl.superview == nil {
            addArrangedSubview(timeControl)
        }
        
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
                switch newStyle {
                case .date:
                    self.dateControl.alpha = 1
                    self.timeControl.alpha = 0
                case .time:
                    self.dateControl.alpha = 0
                    self.timeControl.alpha = 1
                case .both:
                    self.dateControl.alpha = 1
                    self.timeControl.alpha = 1
                }
            }
        } else {
            switch newStyle {
            case .date:
                dateControl.alpha = 1
                timeControl.alpha = 0
            case .time:
                dateControl.alpha = 0
                timeControl.alpha = 1
            case .both:
                dateControl.alpha = 1
                timeControl.alpha = 1
            }
        }
        
        self.style = newStyle
    }
    
    private func setupInitialDate() {
        let calendar = Calendar.current
        let now = Date()
        
        // Round up to the next hour
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        components.hour = (components.hour ?? 0) + 1
        components.minute = 0
        components.second = 0
        
        guard var roundedDate = calendar.date(from: components) else { return }
        
        // For end time, add additional hours
        if controlType == .end {
            roundedDate = calendar.date(byAdding: .hour, value: 2, to: roundedDate) ?? roundedDate
        }
        
        // Set the date which will trigger the didSet observer
        self.date = roundedDate
        
        // Ensure the date text is set even if it's not visible
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        dateText = formatter.string(from: roundedDate)
        
        formatter.dateFormat = "h:mm a"
        timeText = formatter.string(from: roundedDate)
    }
}

// MARK: - DateTimeButton
private final class DateTimeButton: UIControl {
    private let label: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        return label
    }()
    
    var text: String {
        get { label.text ?? "" }
        set { label.text = newValue }
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.backgroundColor = self.isHighlighted ? .systemGray2 : .systemGroupedBackground
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        backgroundColor = .systemGroupedBackground
        layer.cornerRadius = 8
        
        addSubview(label)
        
        let verticalPadding: CGFloat = 6.0
        let horizontalPadding: CGFloat = 10.0
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalPadding),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalPadding),
            label.topAnchor.constraint(equalTo: topAnchor, constant: verticalPadding),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -verticalPadding),
        ])
    }
    
    @objc func tapped() {
        HapticsHelper.superLightHaptic()
    }
}
