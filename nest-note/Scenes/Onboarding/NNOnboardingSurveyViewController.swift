import UIKit

// MARK: - Survey Option
struct SurveyOption {
    let title: String
    let subtitle: String?
    var isSelected: Bool = false

    init(title: String, subtitle: String? = nil, isSelected: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
    }
}

// MARK: - Survey Option Cell
class SurveyOptionCell: UICollectionViewCell {
    static let reuseIdentifier = "SurveyOptionCell"
    
    // MARK: - UI Elements
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let checkboxView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.borderWidth = 1.5
        view.layer.cornerRadius = 4
        view.backgroundColor = .clear
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyS
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        return label
    }()
    
    // MARK: - Properties
    var isOptionSelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    var isMultiSelect: Bool = true {
        didSet {
            if oldValue != isMultiSelect {
                setupLayout()
            }
        }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        contentView.addSubview(stackView)

        // Setup cell appearance
        contentView.layer.borderWidth = 1.5
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true

        // Initial layout setup - will be updated in configure
        setupLayout()
        updateAppearance()
    }
    
    private var labelStackConstraints: [NSLayoutConstraint] = []

    private func setupLayout() {
        // Remove all arranged subviews and deactivate previous constraints
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        NSLayoutConstraint.deactivate(labelStackConstraints)
        labelStackConstraints.removeAll()

        if isMultiSelect {
            stackView.axis = .horizontal
            titleLabel.textAlignment = .left
            subtitleLabel.textAlignment = .left

            // Create a vertical stack for title and subtitle
            let labelStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
            labelStack.axis = .vertical
            labelStack.spacing = 4
            labelStack.alignment = .leading
            labelStack.distribution = .fill
            labelStack.translatesAutoresizingMaskIntoConstraints = false

            stackView.addArrangedSubview(labelStack)
            stackView.addArrangedSubview(checkboxView)

            let constraints = [
                stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
                stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

                checkboxView.widthAnchor.constraint(equalToConstant: 24),
                checkboxView.heightAnchor.constraint(equalToConstant: 24),

                // Minimum height for consistent sizing
                contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
            ]

            labelStackConstraints = constraints
            NSLayoutConstraint.activate(constraints)
        } else {
            stackView.axis = .vertical
            titleLabel.textAlignment = .center
            subtitleLabel.textAlignment = .center

            stackView.addArrangedSubview(titleLabel)
            stackView.addArrangedSubview(subtitleLabel)
            stackView.spacing = 4

            let constraints = [
                stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
                stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

                // Minimum height for consistent sizing
                contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
            ]

            labelStackConstraints = constraints
            NSLayoutConstraint.activate(constraints)
        }
    }
    
    private func updateAppearance() {
        // Update cell appearance
        contentView.layer.borderColor = isOptionSelected ? NNColors.primary.cgColor : UIColor.tertiarySystemFill.cgColor
        contentView.backgroundColor = isOptionSelected ? NNColors.primaryOpaque.withAlphaComponent(0.5) : .clear
        
        if isMultiSelect {
            checkboxView.layer.borderColor = isOptionSelected ? NNColors.primary.cgColor : UIColor.systemGray3.cgColor
            checkboxView.backgroundColor = isOptionSelected ? NNColors.primary : .clear
            
            // Add checkmark when selected
            if isOptionSelected {
                let checkmark = UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold))?
                    .withTintColor(.white, renderingMode: .alwaysOriginal)
                let imageView = UIImageView(image: checkmark)
                imageView.contentMode = .scaleAspectFit
                imageView.translatesAutoresizingMaskIntoConstraints = false
                
                checkboxView.subviews.forEach { $0.removeFromSuperview() }
                checkboxView.addSubview(imageView)
                
                NSLayoutConstraint.activate([
                    imageView.centerXAnchor.constraint(equalTo: checkboxView.centerXAnchor),
                    imageView.centerYAnchor.constraint(equalTo: checkboxView.centerYAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: 16),
                    imageView.heightAnchor.constraint(equalToConstant: 16)
                ])
            } else {
                checkboxView.subviews.forEach { $0.removeFromSuperview() }
            }
        }
    }
    
    func configure(with option: SurveyOption, isMultiSelect: Bool) {
        titleLabel.text = option.title
        subtitleLabel.text = option.subtitle
        subtitleLabel.isHidden = option.subtitle == nil
        
        self.isMultiSelect = isMultiSelect
        self.isOptionSelected = option.isSelected

        // Force layout update after configuration
        setupLayout()
    }
}

// MARK: - Survey View Controller
class NNOnboardingSurveyViewController: NNOnboardingViewController {

    // MARK: - Properties
    private var collectionView: UICollectionView!
    private var options: [SurveyOption] = []
    private var isMultiSelect: Bool = true
    private var currentQuestion: SurveyQuestion?

    // Store the last touch location for explosions
    private var lastTouchLocation: CGPoint = .zero

    private lazy var nextButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Next")
        button.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()

    // Store pending configuration
    private struct PendingConfiguration {
        let question: SurveyQuestion
    }
    private var pendingConfiguration: PendingConfiguration?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        ctaButton?.isHidden = true
        
        // Apply any pending configuration
        if let pending = pendingConfiguration {
            configure(with: pending.question)
            pendingConfiguration = nil
        }
        
        // Add Next button with blur
        nextButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateScrollingBehavior()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
//        updateScrollingBehavior()
    }
    
    override func setupOnboarding(title: String, subtitle: String? = nil) {
        super.setupOnboarding(title: title, subtitle: subtitle)
        // Set subtitle color to secondary for survey screens, but only if we have a subtitle
        if subtitle != nil {
            subtitleLabel.textColor = .secondaryLabel
        }
    }
    
    // MARK: - Setup
    private func setupCollectionView() {
        let layout = createLayout()

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(SurveyOptionCell.self, forCellWithReuseIdentifier: SurveyOptionCell.reuseIdentifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        // Add tap gesture to capture touch location
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(collectionViewTapped(_:)))
        tapGesture.cancelsTouchesInView = false // Allow collection view to still receive touches
        collectionView.addGestureRecognizer(tapGesture)
        
        view.addSubview(collectionView)
        
        // Add bottom inset to accommodate the pinned button
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 24),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(56)  // Minimum height with dynamic sizing for longer content
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(56)  // Match item height
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12  // Increased spacing between cells
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24)

        return UICollectionViewCompositionalLayout(section: section)
    }
    
    // MARK: - Public Methods
    func configure(with question: SurveyQuestion) {
        // If collection view isn't ready, store configuration for later
        if collectionView == nil {
            pendingConfiguration = PendingConfiguration(question: question)
            return
        }
        
        currentQuestion = question
        setupOnboarding(title: question.title, subtitle: question.subtitle)
        
        self.options = question.createSurveyOptions()
        self.isMultiSelect = question.isMultiSelect
        collectionView.reloadData()
    }
    
    func getSelectedOptions() -> [String] {
        return options.filter { $0.isSelected }.map { $0.title }
    }
    
    func getCurrentQuestionResponse() -> (questionId: String, answers: [String])? {
        guard let question = currentQuestion else { return nil }
        return (question.id, getSelectedOptions())
    }

    #if DEBUG
    func setTestOptions(_ testOptions: [SurveyOption], isMultiSelect: Bool = true) {
        print("🔍 [Survey VC] Setting test options:")
        for (index, option) in testOptions.enumerated() {
            print("  [\(index)] '\(option.title)' - subtitle: '\(option.subtitle ?? "nil")'")
        }
        self.options = testOptions
        self.isMultiSelect = isMultiSelect
        collectionView?.reloadData()
        print("🔍 [Survey VC] Reloaded collection view")
    }
    #endif
    
    // MARK: - Private Methods
    private func updateScrollingBehavior() {
        // Calculate if content fits without scrolling
        let contentHeight = collectionView.collectionViewLayout.collectionViewContentSize.height
        let frameHeight = collectionView.frame.height
        let bottomInset = collectionView.adjustedContentInset.bottom
        
        // Disable scrolling if content fits within the frame, accounting for the bottom inset
        collectionView.isScrollEnabled = contentHeight > (frameHeight - bottomInset)
    }
    
    @objc private func collectionViewTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: collectionView)
        // Convert to window coordinates for explosion (matches ExplosionManager's coordinate system)
        if let window = view.window {
            lastTouchLocation = collectionView.convert(location, to: window)
        } else {
            // Fallback to view coordinates
            lastTouchLocation = collectionView.convert(location, to: view)
        }
    }

    @objc private func nextButtonTapped() {
        guard let response = getCurrentQuestionResponse(),
              !response.answers.isEmpty else {
            showToast(text: "Please select an option", sentiment: .negative)
            return
        }

        // Save response and continue
        if let coordinator = coordinator as? OnboardingCoordinator {
            coordinator.updateSurveyResponses([response.questionId: response.answers])
            coordinator.next()
        }
    }
}

// MARK: - UICollectionView DataSource & Delegate
extension NNOnboardingSurveyViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return options.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SurveyOptionCell.reuseIdentifier, for: indexPath) as! SurveyOptionCell
        cell.configure(with: options[indexPath.item], isMultiSelect: isMultiSelect)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Use the captured touch location, with fallback to cell center
        let explosionLocation: CGPoint

        if lastTouchLocation != .zero {
            explosionLocation = lastTouchLocation
        } else if let cell = collectionView.cellForItem(at: indexPath), let window = view.window {
            // Fallback to cell center in window coordinates
            explosionLocation = collectionView.convert(cell.center, to: window)
        } else if let window = view.window {
            // Final fallback to screen center in window coordinates
            let viewCenter = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            explosionLocation = view.convert(viewCenter, to: window)
        } else {
            // Absolute fallback
            explosionLocation = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
        }

        if !isMultiSelect {
            // For single select, deselect all other options
            for i in 0..<options.count {
                options[i].isSelected = (i == indexPath.item)
            }
            collectionView.reloadData()

            // Trigger explosion for single selection
            ExplosionManager.trigger(.tiny, at: explosionLocation)
        } else {
            // For multi-select, toggle the selected option
            options[indexPath.item].isSelected.toggle()
            if let cell = collectionView.cellForItem(at: indexPath) as? SurveyOptionCell {
                cell.isOptionSelected = options[indexPath.item].isSelected
            }

            // Trigger explosion for multi-selection (only when selecting, not deselecting)
            if options[indexPath.item].isSelected {
                ExplosionManager.trigger(.tiny, at: explosionLocation)
            }
        }

        // Reset touch location after use
        lastTouchLocation = .zero

        HapticsHelper.lightHaptic()

        // Check the current state of selected options
        let hasSelectedOptions = !getSelectedOptions().isEmpty

        // Only update isEnabled if the state is different from current state
        if nextButton.isEnabled != hasSelectedOptions {
            nextButton.isEnabled = hasSelectedOptions
        }
    }
}

// MARK: - Bullet Onboarding View Controller
class NNOnboardingBulletViewController: NNOnboardingViewController {

    // MARK: - Properties
    private var bulletStack: NNBulletStack?
    private var bulletItems: [NNBulletItem] = []

    private lazy var nextButton: NNPrimaryLabeledButton = {
        let button = NNPrimaryLabeledButton(title: "Continue")
        button.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBulletStack()
        ctaButton?.isHidden = true

        // Add Continue button with blur
        nextButton.pinToBottom(of: view, addBlurEffect: true, blurRadius: 16, blurMaskImage: UIImage(named: "testBG3"))
    }

    override func setupOnboarding(title: String, subtitle: String? = nil) {
        super.setupOnboarding(title: title, subtitle: subtitle)
        // Set subtitle color to secondary for consistency
        if subtitle != nil {
            subtitleLabel.textColor = .secondaryLabel
        }
    }

    // MARK: - Setup
    private func setupBulletStack() {
        guard !bulletItems.isEmpty else { return }

        bulletStack = NNBulletStack(items: bulletItems, animated: true)
        guard let bulletStack = bulletStack else { return }

        bulletStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bulletStack)

        NSLayoutConstraint.activate([
            bulletStack.topAnchor.constraint(equalTo: labelStack.bottomAnchor, constant: 32),
            bulletStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            bulletStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
            bulletStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -120)
        ])
    }

    // MARK: - Public Methods
    func configure(title: String, subtitle: String? = nil, bullets: [NNBulletItem]) {
        self.bulletItems = bullets
        setupOnboarding(title: title, subtitle: subtitle)

        // If view is already loaded, setup bullet stack
        if isViewLoaded {
            setupBulletStack()
        }
    }

    #if DEBUG
    func setTestBullets(_ testBullets: [NNBulletItem]) {
        self.bulletItems = testBullets

        // Remove existing bullet stack if it exists
        bulletStack?.removeFromSuperview()
        bulletStack = nil

        // Setup new bullet stack
        setupBulletStack()
    }
    #endif

    // MARK: - Actions
    @objc private func nextButtonTapped() {
        // Handle next button action - could be customized by coordinator
        if let coordinator = coordinator as? OnboardingCoordinator {
            coordinator.next()
        }
    }
} 
