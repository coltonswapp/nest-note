import UIKit

// MARK: - Duration

final class SessionPaymentDurationCell: UICollectionViewListCell {
    var onValueChanged: ((Int) -> Void)?

    private let valueLabelHost: SessionPaymentDurationLabelHost
    private let selectorView = SessionPaymentValueSelectorView()
    private var isSelectorConfigured = false

    override init(frame: CGRect) {
        valueLabelHost = SessionPaymentDurationLabelHost(minutes: 15)
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        selectorView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(valueLabelHost)
        contentView.addSubview(selectorView)

        NSLayoutConstraint.activate([
            valueLabelHost.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 4),
            valueLabelHost.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            valueLabelHost.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),

            selectorView.topAnchor.constraint(equalTo: valueLabelHost.bottomAnchor, constant: 4),
            selectorView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            selectorView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            selectorView.heightAnchor.constraint(equalToConstant: SessionPaymentValueSelectorView.trackHeight),
            selectorView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -4)
        ])
    }

    func configure(minutes: Int) {
        valueLabelHost.setMinutes(minutes, animated: false)

        if !isSelectorConfigured {
            isSelectorConfigured = true
            selectorView.configure(
                range: 15...1440,
                initialValue: minutes,
                increment: 15,
                chevronStepAmount: 60,
                majorTickFrequency: 60,
                decelerationRate: UIScrollView.DecelerationRate(rawValue: 0.9)
            )
            selectorView.onValueChanged = { [weak self] minutes in
                guard let self else { return }
                valueLabelHost.setMinutes(minutes, animated: true)
                onValueChanged?(minutes)
            }
        } else {
            selectorView.scrollToValue(minutes, animated: false)
            valueLabelHost.setMinutes(minutes, animated: false)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isSelectorConfigured = false
    }
}

// MARK: - Hourly Rate

final class SessionPaymentHourlyRateCell: UICollectionViewListCell {
    var onValueChanged: ((Int) -> Void)?

    private let hourlyRateSelector = HourlyRateSelectorView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        hourlyRateSelector.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hourlyRateSelector)

        NSLayoutConstraint.activate([
            hourlyRateSelector.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 4),
            hourlyRateSelector.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            hourlyRateSelector.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            hourlyRateSelector.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -4)
        ])
    }

    func configure(cents: Int) {
        hourlyRateSelector.onValueChanged = { [weak self] cents in
            self?.onValueChanged?(cents)
        }
        hourlyRateSelector.configure(cents: cents)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onValueChanged = nil
    }
}
