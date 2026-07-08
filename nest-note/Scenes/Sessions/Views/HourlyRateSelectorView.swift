import UIKit

final class HourlyRateSelectorView: UIView {
    var onValueChanged: ((Int) -> Void)?

    private let valueLabelHost: SessionPaymentRateLabelHost
    private let selectorView = SessionPaymentValueSelectorView()
    private var isSelectorConfigured = false

    init(cents: Int = SessionPaymentCalculator.defaultHourlyRateCents) {
        valueLabelHost = SessionPaymentRateLabelHost(cents: cents)
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private enum Layout {
        static let valueLabelTopInset: CGFloat = 8
        static let valueLabelToSelectorSpacing: CGFloat = 8
    }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false
        selectorView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(valueLabelHost)
        addSubview(selectorView)

        NSLayoutConstraint.activate([
            valueLabelHost.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor, constant: Layout.valueLabelTopInset),
            valueLabelHost.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            valueLabelHost.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),

            selectorView.topAnchor.constraint(equalTo: valueLabelHost.bottomAnchor, constant: Layout.valueLabelToSelectorSpacing),
            selectorView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            selectorView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            selectorView.heightAnchor.constraint(equalToConstant: 58),
            selectorView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
    }

    func applyFilledFieldStyle() {
        backgroundColor = NNColors.NNSystemBackground6
        layer.cornerRadius = 18
        clipsToBounds = true
        directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0)
    }

    func configure(cents: Int) {
        valueLabelHost.setCents(cents, animated: false)

        if !isSelectorConfigured {
            isSelectorConfigured = true
            selectorView.configure(
                range: 0...SessionPaymentCalculator.maximumHourlyRateCents,
                initialValue: cents,
                increment: 200,
                chevronStepAmount: 600,
                majorTickFrequency: 1000,
                decelerationRate: .normal
            )
            selectorView.onValueChanged = { [weak self] cents in
                guard let self else { return }
                valueLabelHost.setCents(cents, animated: true)
                onValueChanged?(cents)
            }
        } else {
            selectorView.scrollToValue(cents, animated: false)
            valueLabelHost.setCents(cents, animated: false)
        }
    }

    func resetToDefault() {
        configure(cents: SessionPaymentCalculator.defaultHourlyRateCents)
    }
}
