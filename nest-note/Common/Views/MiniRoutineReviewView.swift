import UIKit

final class MiniRoutineReviewView: UIView {
    private let container = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let divider = UIView()
    private let actionsStack = UIStackView()
    private let timestampLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 4, height: 8)
        layer.shadowRadius = 8

        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .label
        iconImageView.image = UIImage(systemName: "checklist")

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .h3
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2

        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = .quaternaryLabel

        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        actionsStack.axis = .vertical
        actionsStack.spacing = 12

        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.font = .bodyL
        timestampLabel.textColor = .secondaryLabel

        [iconImageView, titleLabel, divider, actionsStack, timestampLabel].forEach { container.addSubview($0) }
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            iconImageView.topAnchor.constraint(equalTo: container.topAnchor),
            iconImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            divider.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 12),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            actionsStack.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 12),
            actionsStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            actionsStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            timestampLabel.topAnchor.constraint(greaterThanOrEqualTo: actionsStack.bottomAnchor, constant: 12),
            timestampLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            timestampLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            timestampLabel.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor)
        ])
    }
    
    func configure(with routine: RoutineItem) {
        
        let numberOfActionsToDisplay: Int = 5
        
        titleLabel.text = routine.title
        timestampLabel.text = "Last modified: \(routine.updatedAt.formatted(date: .abbreviated, time: .omitted))"
        
        // Clear previous
        actionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let previewActions = Array(routine.routineActions.prefix(numberOfActionsToDisplay))
        for action in previewActions {
            // Use a plain container view to avoid UIStackView alignment overriding our constraints
            let row = UIView()
            row.translatesAutoresizingMaskIntoConstraints = false
            
            let bullet = UIView()
            bullet.translatesAutoresizingMaskIntoConstraints = false
            bullet.backgroundColor = .tertiaryLabel
            bullet.layer.cornerRadius = 4
            
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .bodyXL
            label.textColor = .secondaryLabel
            label.text = action
            label.numberOfLines = 2
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            
            row.addSubview(bullet)
            row.addSubview(label)
            actionsStack.addArrangedSubview(row)
            
            let spacing: CGFloat = 12
            let bulletSize: CGFloat = 8
            let capOffset = -label.font.capHeight / 2.0
            
            NSLayoutConstraint.activate([
                // Row should stretch horizontally within the stack
                row.leadingAnchor.constraint(equalTo: actionsStack.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: actionsStack.trailingAnchor),

                // Bullet size and leading
                bullet.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                bullet.widthAnchor.constraint(equalToConstant: bulletSize),
                bullet.heightAnchor.constraint(equalToConstant: bulletSize),

                // Label placement - fix the row height issue
                label.leadingAnchor.constraint(equalTo: bullet.trailingAnchor, constant: spacing),
                label.topAnchor.constraint(equalTo: row.topAnchor),
                label.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                label.bottomAnchor.constraint(equalTo: row.bottomAnchor),

                // Align bullet center with the first text line center using cap-height
                bullet.centerYAnchor.constraint(equalTo: label.firstBaselineAnchor, constant: capOffset)
            ])
        }
        
        if routine.routineActions.count > numberOfActionsToDisplay {
            let more = UILabel()
            more.font = .bodyS
            more.textColor = .tertiaryLabel
            more.text = "+\(routine.routineActions.count - numberOfActionsToDisplay) more"
            actionsStack.addArrangedSubview(more)
        }
    }
}
