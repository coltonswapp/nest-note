//
//  PaywallFeatureListView.swift
//  nest-note
//

import UIKit

struct PaywallFeatureItem {
    let title: String
    let iconName: String?
}

final class PaywallFeatureListView: UIView {

    private let cardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 10
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 0
        stack.alignment = .fill
        return stack
    }()

    private var rowViews: [UIView] = []

    init(items: [PaywallFeatureItem]) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        setup(items: items)
    }

    convenience init(features: [String]) {
        self.init(items: features.map { PaywallFeatureItem(title: $0, iconName: nil) })
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(items: [PaywallFeatureItem]) {
        addSubview(cardView)
        cardView.addSubview(stackView)

        items.enumerated().forEach { index, item in
            let rowView = PaywallFeatureRowView(title: item.title, iconName: item.iconName)
            stackView.addArrangedSubview(rowView)
            rowViews.append(rowView)

            if index < items.count - 1 {
                stackView.addArrangedSubview(makeSeparator())
            }
        }

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.topAnchor.constraint(equalTo: cardView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor)
        ])
    }

    private func makeSeparator() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .clear

        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = .separator
        container.addSubview(line)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 52),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            line.topAnchor.constraint(equalTo: container.topAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    func prepareRowsForSlideIn(slideDistance: CGFloat = 24) {
        cardView.prepareForSlideIn(slideDistance: slideDistance)
        rowViews.forEach { $0.prepareForSlideIn(slideDistance: slideDistance) }
    }

    func animateRowsIn(
        duration: TimeInterval = 0.55,
        stagger: TimeInterval = 0.05,
        initialDelay: TimeInterval = 0,
        completion: (() -> Void)? = nil
    ) {
        cardView.animateSlideIn(duration: duration, delay: initialDelay)

        let rowInitialDelay = initialDelay + 0.03
        UIView.animateSlideIn(
            rowViews,
            duration: duration,
            stagger: stagger,
            initialDelay: rowInitialDelay,
            completion: completion
        )
    }
}

private final class PaywallFeatureRowView: UIView {

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = NNColors.primary
        return imageView
    }()

    private let iconSpacer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .captionBoldM
        label.textColor = .label
        return label
    }()

    init(title: String, iconName: String?) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title

        if let iconName {
            let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
            iconImageView.image = UIImage(systemName: iconName, withConfiguration: config)
        }

        setup(showsIcon: iconName != nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(showsIcon: Bool) {
        let leadingIconView = showsIcon ? iconImageView : iconSpacer
        addSubview(leadingIconView)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 48),

            leadingIconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            leadingIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            leadingIconView.widthAnchor.constraint(equalToConstant: 24),
            leadingIconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: leadingIconView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
