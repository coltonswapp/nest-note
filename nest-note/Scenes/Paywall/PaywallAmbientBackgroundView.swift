//
//  PaywallAmbientBackgroundView.swift
//  nest-note
//

import UIKit

final class PaywallAmbientBackgroundView: UIView {

    private var imageViews: [UIImageView] = []
    private var activeCardID: String?

    private let imageContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        return view
    }()

    private let blurView: UIVisualEffectView = {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.isUserInteractionEnabled = false
        return blur
    }()

    private let darkOverlay: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        view.isUserInteractionEnabled = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        configure(with: paywallFeatureCarouselCards)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with cards: [PaywallFeatureCarouselCard]) {
        imageViews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()

        cards.forEach { card in
            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.image = UIImage(named: card.imageName)
            imageView.alpha = card.id == activeCardID ? 1 : 0
            imageContainer.addSubview(imageView)

            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            ])

            imageViews.append(imageView)
        }

        if activeCardID == nil, let first = cards.first {
            activeCardID = first.id
            imageViews.first?.alpha = 1
        }
    }

    func setActiveCard(_ card: PaywallFeatureCarouselCard, animated: Bool) {
        guard activeCardID != card.id else { return }
        activeCardID = card.id

        let updates = {
            for (index, carouselCard) in paywallFeatureCarouselCards.enumerated() {
                guard index < self.imageViews.count else { continue }
                self.imageViews[index].alpha = carouselCard.id == card.id ? 1 : 0
            }
        }

        if animated {
            UIView.transition(with: imageContainer, duration: 0.45, options: [.transitionCrossDissolve, .allowUserInteraction]) {
                updates()
            }
        } else {
            updates()
        }
    }

    private func setup() {
        clipsToBounds = true

        addSubview(imageContainer)
        addSubview(blurView)
        addSubview(darkOverlay)

        NSLayoutConstraint.activate([
            imageContainer.topAnchor.constraint(equalTo: topAnchor),
            imageContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            darkOverlay.topAnchor.constraint(equalTo: topAnchor),
            darkOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            darkOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            darkOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
