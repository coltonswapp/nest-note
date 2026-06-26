//
//  PaywallFeatureCarouselCardView.swift
//  nest-note
//

import UIKit

final class PaywallFeatureCarouselCardView: UIView {

    private static let cornerRadius: CGFloat = 20

    private let imageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        return view
    }()

    private let gradientView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }()

    private let iconContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        view.layer.cornerRadius = 14
        return view
    }()

    private let iconImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.tintColor = .white
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 1
        return label
    }()

    private let footerStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()

    private var gradientLayer: CAGradientLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer?.frame = gradientView.bounds
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: Self.cornerRadius
        ).cgPath
    }

    func configure(with card: PaywallFeatureCarouselCard) {
        imageView.image = UIImage(named: card.imageName)
        titleLabel.text = card.feature.displayName

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        iconImageView.image = UIImage(systemName: card.feature.iconName, withConfiguration: symbolConfig)
    }

    private func setup() {
        clipsToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.4
        layer.shadowOffset = CGSize(width: 1, height: 0)
        layer.shadowRadius = 10

        addSubview(imageView)
        addSubview(gradientView)
        addSubview(footerStack)

        iconContainer.addSubview(iconImageView)
        footerStack.addArrangedSubview(iconContainer)
        footerStack.addArrangedSubview(titleLabel)

        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.75).cgColor
        ]
        gradient.locations = [0.5, 1.0]
        gradientView.layer.addSublayer(gradient)
        gradientLayer = gradient

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            gradientView.topAnchor.constraint(equalTo: topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: bottomAnchor),

            footerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            footerStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
            footerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            iconContainer.widthAnchor.constraint(equalToConstant: 28),
            iconContainer.heightAnchor.constraint(equalToConstant: 28),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),
        ])
    }
}
