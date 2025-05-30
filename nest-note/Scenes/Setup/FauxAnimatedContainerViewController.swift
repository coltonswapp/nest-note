//
//  OnboardingContainerViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 5/24/25.
//
import UIKit

class FauxAnimatedContainerViewController: UIViewController {
    private var childNavigationController: UINavigationController?
    private let scaleFactor: CGFloat
    
    init(scale: CGFloat = 0.7) {
        self.scaleFactor = scale
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.scaleFactor = 0.7
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDemoContent()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 36
        view.clipsToBounds = true
        
        // Apply scale transform to the entire view
        view.transform = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
    }
    
    func configureChildViewController(_ viewController: UIViewController) {
        if let existingChild = childNavigationController {
            existingChild.willMove(toParent: nil)
            existingChild.view.removeFromSuperview()
            existingChild.removeFromParent()
        }
        
        let navController = UINavigationController(rootViewController: viewController)
        navController.additionalSafeAreaInsets = .init(top: 24, left: 0, bottom: 0, right: 0)
        childNavigationController = navController
        
        addChild(navController)
        view.addSubview(navController.view)
        
        navController.view.translatesAutoresizingMaskIntoConstraints = false
        navController.view.clipsToBounds = true
        navController.view.isUserInteractionEnabled = false
        
        NSLayoutConstraint.activate([
            navController.view.topAnchor.constraint(equalTo: view.topAnchor),
            navController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        navController.didMove(toParent: self)
    }
    
    func startAnimation() {
        guard let demoVC = childNavigationController?.viewControllers.first as? FauxDemoCollectionViewController else { return }
        demoVC.startAnimationLoop()
    }
    
    private func setupDemoContent() {
        let demoViewController = FauxDemoCollectionViewController()
        configureChildViewController(demoViewController)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startAnimation()
        }
    }
}

class FauxDemoCollectionViewController: UIViewController {
    
    static let backgroundColor = NNColors.fauxSystemGrouped
    static let tableBackgroundColor = NNColors.fauxSystemGroupedBackground
    static let placeholderColor = NNColors.fauxPlaceholder
    
    private var collectionView: UICollectionView!
    private var animationTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
    }
    
    deinit {
        animationTimer?.invalidate()
    }
    
    private func setupUI() {
        title = "Settings"
        view.backgroundColor = FauxDemoCollectionViewController.backgroundColor
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        
        navigationController?.navigationBar.tintColor = .label
    }
    
    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            switch sectionIndex {
            case 0, 1: // Profile and Location cards
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(80))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 18, bottom: 20, trailing: 18)
                return section
                
            default: // List sections using .insetGrouped appearance
                var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
                config.headerMode = .supplementary
                config.backgroundColor = FauxDemoCollectionViewController.backgroundColor
                let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
                
                // Standardize header size
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(32))
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [header]
                return section
            }
        }
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // Register cells
        collectionView.register(FauxProfileCell.self, forCellWithReuseIdentifier: "ProfileCell")
        collectionView.register(FauxLocationCell.self, forCellWithReuseIdentifier: "LocationCell")
        collectionView.register(UICollectionViewListCell.self, forCellWithReuseIdentifier: "ListCell")
        collectionView.register(FauxSectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "HeaderView")
        
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func closeTapped() {
        // Placeholder action
    }
    
    func startAnimationLoop() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { [weak self] _ in
            self?.performAnimationSequence()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.performAnimationSequence()
        }
    }
    
    private func performAnimationSequence() {
        DispatchQueue.main.async {
            let indexPath = IndexPath(item: 0, section: 0) // Profile card in first section
            self.collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.collectionView.deselectItem(at: indexPath, animated: true)
                
                let detailVC = FauxDetailViewController()
                detailVC.itemName = "Profile"
                self.navigationController?.pushViewController(detailVC, animated: true)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.navigationController?.popViewController(animated: true)
                }
            }
        }
    }
}

extension FauxDemoCollectionViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 4 // Profile, Location, MY NEST, GENERAL
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0, 1: return 1 // Profile and Location cards
        case 2: return 6 // MY NEST section
        case 3: return 2 // GENERAL section
        default: return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch indexPath.section {
        case 0:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProfileCell", for: indexPath) as! FauxProfileCell
            return cell
        case 1:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LocationCell", for: indexPath) as! FauxLocationCell
            return cell
        default:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ListCell", for: indexPath) as! UICollectionViewListCell
            
            var content = cell.defaultContentConfiguration()
            content.text = ""
            
            // Create custom content view with icon and title rectangle
            let containerView = UIView()
            
            let iconView = UIView()
            iconView.backgroundColor = .systemGreen
            iconView.layer.cornerRadius = 8
            iconView.translatesAutoresizingMaskIntoConstraints = false
            
            let titleRect = UIView()
            titleRect.backgroundColor = .systemGray5
            titleRect.layer.cornerRadius = 3
            titleRect.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(iconView)
            containerView.addSubview(titleRect)
            
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 24),
                iconView.heightAnchor.constraint(equalToConstant: 24),
                
                titleRect.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
                titleRect.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                titleRect.widthAnchor.constraint(equalToConstant: 80),
                titleRect.heightAnchor.constraint(equalToConstant: 12),
                
                containerView.heightAnchor.constraint(equalToConstant: 44)
            ])

            cell.contentConfiguration = content
            
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "HeaderView", for: indexPath) as! FauxSectionHeaderView
        
        switch indexPath.section {
        case 2:
            header.configure(with: "MY NEST")
        case 3:
            header.configure(with: "GENERAL")
        default:
            header.configure(with: "")
        }
        
        return header
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        let detailVC = FauxDetailViewController()
        detailVC.itemName = "Settings Item"
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Custom Cells

class FauxProfileCell: UICollectionViewCell {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isSelected: Bool {
        didSet {
            animateSelection()
        }
    }
    
    private func setupCell() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 12
        
        let avatarView = UIView()
        avatarView.backgroundColor = FauxDemoCollectionViewController.placeholderColor
        avatarView.layer.cornerRadius = 20
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        
        let nameRect = UIView()
        nameRect.backgroundColor = FauxDemoCollectionViewController.placeholderColor
        nameRect.layer.cornerRadius = 4
        nameRect.translatesAutoresizingMaskIntoConstraints = false
        
        let emailRect = UIView()
        emailRect.backgroundColor = FauxDemoCollectionViewController.placeholderColor
        emailRect.layer.cornerRadius = 3
        emailRect.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(avatarView)
        addSubview(nameRect)
        addSubview(emailRect)
        
        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            avatarView.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 40),
            avatarView.heightAnchor.constraint(equalToConstant: 40),
            
            nameRect.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            nameRect.topAnchor.constraint(equalTo: centerYAnchor, constant: -12),
            nameRect.widthAnchor.constraint(equalToConstant: 80),
            nameRect.heightAnchor.constraint(equalToConstant: 12),
            
            emailRect.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            emailRect.topAnchor.constraint(equalTo: nameRect.bottomAnchor, constant: 4),
            emailRect.widthAnchor.constraint(equalToConstant: 120),
            emailRect.heightAnchor.constraint(equalToConstant: 10)
        ])
    }
    
    private func animateSelection() {
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseInOut]) {
            if self.isSelected {
                self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                self.backgroundColor = .systemGray4
            } else {
                self.transform = .identity
                self.backgroundColor = .secondarySystemGroupedBackground
            }
        }
    }
}

class FauxLocationCell: UICollectionViewCell {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 12
        
        let titleRect = UIView()
        titleRect.backgroundColor = FauxDemoCollectionViewController.placeholderColor
        titleRect.layer.cornerRadius = 4
        titleRect.translatesAutoresizingMaskIntoConstraints = false
        
        let addressRect = UIView()
        addressRect.backgroundColor = FauxDemoCollectionViewController.placeholderColor
        addressRect.layer.cornerRadius = 3
        addressRect.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIView()
        iconView.backgroundColor = FauxDemoCollectionViewController.placeholderColor
        iconView.layer.cornerRadius = 4
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(titleRect)
        addSubview(addressRect)
        addSubview(iconView)
        
        NSLayoutConstraint.activate([
            titleRect.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleRect.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),
            titleRect.widthAnchor.constraint(equalToConstant: 100),
            titleRect.heightAnchor.constraint(equalToConstant: 14),
            
            addressRect.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            addressRect.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 8),
            addressRect.widthAnchor.constraint(equalToConstant: 140),
            addressRect.heightAnchor.constraint(equalToConstant: 10),
            
            iconView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
}

class FauxSectionHeaderView: UICollectionReusableView {
    private let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        titleLabel.font = .bodyS
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with title: String) {
        titleLabel.text = title
    }
}

class FauxDetailViewController: UIViewController {
    var itemName: String = ""
    private var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = itemName
        view.backgroundColor = FauxDemoCollectionViewController.backgroundColor
        
        setupCollectionView()
        
        // Start the feedback animation after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.animateFeedbackTap()
        }
        
        navigationController?.navigationItem.backButtonDisplayMode = .minimal
//        navigationItem.backButtonDisplayMode = .minimal
    }
    
    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            config.headerMode = .supplementary
            config.backgroundColor = FauxDemoCollectionViewController.backgroundColor
            let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
            
            // Add section header
            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(32))
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [header]
            
            return section
        }
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // Register cells
        collectionView.register(UICollectionViewListCell.self, forCellWithReuseIdentifier: "ListCell")
        collectionView.register(FauxSectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "HeaderView")
        
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func animateFeedbackTap() {
        let feedbackIndexPath = IndexPath(item: 1, section: 1) // "Give Feedback" row in ACTIONS section
        
        // Select the cell
        collectionView.selectItem(at: feedbackIndexPath, animated: true, scrollPosition: [])
        
        // Deselect after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.collectionView.deselectItem(at: feedbackIndexPath, animated: true)
        }
    }
}

extension FauxDetailViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 3 // ACCOUNT INFORMATION, ACTIONS, DANGER ZONE
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0: return 4 // ACCOUNT INFORMATION: Name, Email, Role, Member Since
        case 1: return 2 // ACTIONS: Sign Out, Give Feedback
        case 2: return 1 // DANGER ZONE: Delete Account
        default: return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ListCell", for: indexPath) as! UICollectionViewListCell
        
        var content = cell.defaultContentConfiguration()
        
        switch indexPath.section {
        case 0: // ACCOUNT INFORMATION - All blank
            content.text = ""
            
        case 1: // ACTIONS
            if indexPath.item == 1 {
                // Only "Give Feedback" has real text with icon
                content.text = "Give Feedback"
                content.textProperties.color = .label
                cell.accessories = [.disclosureIndicator()]
            } else {
                // "Sign Out" is blank
                content.text = ""
            }
            
        case 2: // DANGER ZONE - Blank
            content.text = ""
            
        default:
            break
        }
        
        cell.contentConfiguration = content
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "HeaderView", for: indexPath) as! FauxSectionHeaderView
        
        switch indexPath.section {
        case 0: header.configure(with: "ACCOUNT INFORMATION")
        case 1: header.configure(with: "ACTIONS")
        case 2: header.configure(with: "DANGER ZONE")
        default: header.configure(with: "")
        }
        
        return header
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
    }
}
