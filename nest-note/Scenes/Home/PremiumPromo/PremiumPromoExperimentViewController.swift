import UIKit

#if DEBUG
/// Debug lab for comparing premium promo banner variants and applying one to the owner home screen.
final class PremiumPromoExperimentViewController: NNViewController {

    private enum Section: Hashable {
        case intro
        case variant(PremiumPromoVariant)
    }

    private enum Item: Hashable {
        case intro
        case banner(PremiumPromoVariant)
    }

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    override func setup() {
        navigationItem.title = "Premium Promo Lab"
        view.backgroundColor = .systemGroupedBackground
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        configureDataSource()
        applySnapshot()
    }

    private func configureCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        view.addSubview(collectionView)
    }

    private func createLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self else { return nil }

            let sectionIdentifier = self.dataSource.snapshot().sectionIdentifiers[sectionIndex]
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(52)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )

            switch sectionIdentifier {
            case .intro:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(72)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 18, bottom: 8, trailing: 18)
                return section

            case .variant(let variant):
                let height = variant.preferredHeight
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(height)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 18, bottom: 20, trailing: 18)
                section.boundarySupplementaryItems = [header]
                return section
            }
        }
    }

    private func configureDataSource() {
        let introRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, _ in
            var content = cell.defaultContentConfiguration()
            content.text = "Compare banner styles"
            content.secondaryText = "Tap a banner to preview it on the owner home screen. Changes apply immediately in debug builds."
            content.secondaryTextProperties.color = .secondaryLabel
            content.secondaryTextProperties.numberOfLines = 0
            content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
            cell.contentConfiguration = content
        }

        let bannerRegistration = UICollectionView.CellRegistration<PremiumPromoExperimentBannerCell, Item> { cell, _, item in
            guard case .banner(let variant) = item else { return }
            cell.configure(
                variant: variant,
                isActive: variant == PremiumPromoVariant.active
            )
        }

        let headerRegistration = UICollectionView.SupplementaryRegistration<PremiumPromoExperimentHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] headerView, _, indexPath in
            guard let self,
                  case .variant(let variant) = self.dataSource.snapshot().sectionIdentifiers[indexPath.section] else { return }
            headerView.configure(
                title: variant.displayName,
                detail: variant.detail,
                isActive: variant == PremiumPromoVariant.active
            )
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .intro:
                return collectionView.dequeueConfiguredReusableCell(using: introRegistration, for: indexPath, item: item)
            case .banner:
                return collectionView.dequeueConfiguredReusableCell(using: bannerRegistration, for: indexPath, item: item)
            }
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            if kind == UICollectionView.elementKindSectionHeader {
                return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
            }
            return nil
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.intro])
        snapshot.appendItems([.intro], toSection: .intro)

        PremiumPromoVariant.allCases.forEach { variant in
            let section = Section.variant(variant)
            snapshot.appendSections([section])
            snapshot.appendItems([.banner(variant)], toSection: section)
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func selectVariant(_ variant: PremiumPromoVariant) {
        PremiumPromoVariant.active = variant
        HapticsHelper.lightHaptic()
        applySnapshot()
        showToast(text: "Home promo set to \(variant.displayName)")
    }
}

extension PremiumPromoExperimentViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard case .variant(let variant) = dataSource.snapshot().sectionIdentifiers[indexPath.section] else { return }
        selectVariant(variant)
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

private final class PremiumPromoExperimentHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "PremiumPromoExperimentHeaderView"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4
        label.textColor = .label
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyS
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let activeBadge: UILabel = {
        let label = UILabel()
        label.text = "On Home"
        label.font = .captionBoldS
        label.textColor = NNColors.primary
        label.backgroundColor = NNColors.primaryOpaque.withAlphaComponent(0.25)
        label.layer.cornerRadius = 8
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = true
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, detail: String, isActive: Bool) {
        titleLabel.text = title
        detailLabel.text = detail
        activeBadge.isHidden = !isActive
    }

    private func setupView() {
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(activeBadge)

        NSLayoutConstraint.activate([
            activeBadge.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            activeBadge.trailingAnchor.constraint(equalTo: trailingAnchor),
            activeBadge.heightAnchor.constraint(equalToConstant: 24),
            activeBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: activeBadge.leadingAnchor, constant: -8),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            detailLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            detailLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }
}

private final class PremiumPromoExperimentBannerCell: UICollectionViewCell {

    private let bannerView = PremiumPromoBannerView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(variant: PremiumPromoVariant, isActive: Bool) {
        bannerView.configure(variant: variant)
        contentView.layer.borderWidth = isActive ? 2 : 0
        contentView.layer.borderColor = isActive ? NNColors.primary.cgColor : nil
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if contentView.layer.borderWidth > 0 {
            contentView.layer.borderColor = NNColors.primary.cgColor
        }
    }

    private func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true

        bannerView.isUserInteractionEnabled = false
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bannerView)

        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bannerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        let selectedBgView = UIView()
        selectedBgView.backgroundColor = NNColors.primary.withAlphaComponent(0.06)
        selectedBgView.layer.cornerRadius = 16
        selectedBgView.layer.cornerCurve = .continuous
        selectedBackgroundView = selectedBgView
    }
}
#endif
