import UIKit

/// Collection view cell wrapping `PremiumPromoBannerView` for the owner home screen.
final class PremiumPromoCell: UICollectionViewCell {

    var onUpgradeTapped: (() -> Void)? {
        get { bannerView.onUpgradeTapped }
        set { bannerView.onUpgradeTapped = newValue }
    }

    var onDismissTapped: (() -> Void)?

    private let bannerView = PremiumPromoBannerView()

    private lazy var dismissButton = GlassDismissButton()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onUpgradeTapped = nil
        onDismissTapped = nil
        dismissButton.isHidden = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        bannerView.refreshIconShadows()
    }

    func configure(
        variant: PremiumPromoVariant = PremiumPromoVariant.active,
        ctaTitle: String = PremiumPromoCopy.learnMoreCTA,
        title: String? = nil,
        subtitle: String? = nil,
        contentVerticalPadding: CGFloat = 0,
        showsDismissButton: Bool = false
    ) {
        bannerView.configure(
            variant: variant,
            ctaTitle: ctaTitle,
            title: title,
            subtitle: subtitle,
            contentVerticalPadding: contentVerticalPadding
        )
        dismissButton.isHidden = !showsDismissButton
    }

    private func setupCell() {
        clipsToBounds = false
        backgroundColor = .clear
        contentView.clipsToBounds = false
        contentView.backgroundColor = .clear

        dismissButton.isHidden = true
        dismissButton.addTarget(self, action: #selector(handleDismissTapped), for: .touchUpInside)

        bannerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bannerView)
        contentView.addSubview(dismissButton)

        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bannerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            dismissButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            dismissButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            dismissButton.widthAnchor.constraint(equalToConstant: GlassDismissButton.size),
            dismissButton.heightAnchor.constraint(equalToConstant: GlassDismissButton.size),
        ])

        let selectedBgView = UIView()
        selectedBgView.backgroundColor = NNColors.primary.withAlphaComponent(0.08)
        selectedBgView.layer.cornerRadius = 16
        selectedBgView.layer.cornerCurve = .continuous
        selectedBgView.layer.masksToBounds = true
        selectedBackgroundView = selectedBgView
    }

    @objc private func handleDismissTapped() {
        HapticsHelper.lightHaptic()
        onDismissTapped?()
    }
}
