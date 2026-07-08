import UIKit

final class SessionPaymentValueCell: UICollectionViewCell {
    static let reuseIdentifier = "SessionPaymentValueCell"

    private let markerView = UIView()
    private var markerHeightConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        markerView.translatesAutoresizingMaskIntoConstraints = false
        markerView.backgroundColor = .label
        markerView.alpha = 0.2
        contentView.addSubview(markerView)

        markerHeightConstraint = markerView.heightAnchor.constraint(equalToConstant: SessionPaymentValueSelectorView.tickSize.1)

        NSLayoutConstraint.activate([
            markerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            markerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            markerView.widthAnchor.constraint(equalToConstant: SessionPaymentValueSelectorView.markerWidth),
            markerHeightConstraint!
        ])

        markerView.layer.cornerRadius = SessionPaymentValueSelectorView.markerCornerRadius
    }

    func configure(isMajorTick: Bool) {
        markerHeightConstraint?.constant = isMajorTick
            ? SessionPaymentValueSelectorView.tickSize.0
            : SessionPaymentValueSelectorView.tickSize.1
    }
}
