import UIKit

final class SessionPaymentTotalCell: UICollectionViewListCell {
    private let breakdownLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let breakdownAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let divider: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let totalTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4
        label.textColor = .label
        label.text = "Total"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let totalAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .h4
        label.textColor = .label
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(breakdownLabel)
        contentView.addSubview(breakdownAmountLabel)
        contentView.addSubview(divider)
        contentView.addSubview(totalTitleLabel)
        contentView.addSubview(totalAmountLabel)

        NSLayoutConstraint.activate([
            breakdownLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 16),
            breakdownLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            breakdownLabel.trailingAnchor.constraint(lessThanOrEqualTo: breakdownAmountLabel.leadingAnchor, constant: -12),

            breakdownAmountLabel.centerYAnchor.constraint(equalTo: breakdownLabel.centerYAnchor),
            breakdownAmountLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),

            divider.topAnchor.constraint(equalTo: breakdownLabel.bottomAnchor, constant: 12),
            divider.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            totalTitleLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 12),
            totalTitleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            totalTitleLabel.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -16),

            totalAmountLabel.centerYAnchor.constraint(equalTo: totalTitleLabel.centerYAnchor),
            totalAmountLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)
        ])
    }

    func configure(breakdownText: String, breakdownAmount: String, totalAmount: String) {
        breakdownLabel.text = breakdownText
        breakdownAmountLabel.text = breakdownAmount
        totalAmountLabel.text = totalAmount
    }
}
