import UIKit

class FeedbackDetailViewController: NNViewController {
    
    // MARK: - Properties
    private let surveyService = SurveyService.shared
    private let metrics: FeedbackMetrics
    private var feedbackSubmissions: [Feedback] = []
    
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Feedback>!
    
    // MARK: - Initialization
    init(metrics: FeedbackMetrics) {
        self.metrics = metrics
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        configureDataSource()
        
        Task {
            await loadFeedback()
        }
    }
    
    override func setupNavigationBarButtons() {
        title = "User Feedback"
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        backButton.tintColor = .label
        navigationItem.leftBarButtonItem = backButton
    }
    
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func configureCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        view.addSubview(collectionView)
        
        // Register cells
        collectionView.register(FeedbackCell.self, forCellWithReuseIdentifier: FeedbackCell.reuseIdentifier)
        
        // Add refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        return UICollectionViewCompositionalLayout.list(using: config)
    }
    
    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<FeedbackCell, Feedback> { cell, indexPath, feedback in
            cell.configure(with: feedback)
        }
        
        dataSource = UICollectionViewDiffableDataSource<Section, Feedback>(collectionView: collectionView) { collectionView, indexPath, feedback in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: feedback)
        }
    }
    
    @objc private func refreshData() {
        Task {
            await loadFeedback()
            collectionView.refreshControl?.endRefreshing()
        }
    }
    
    private func loadFeedback() async {
        do {
            let submissions = try await surveyService.getFeedbackSubmissions()
            
            await MainActor.run {
                self.feedbackSubmissions = submissions
                applySnapshot()
            }
        } catch {
            Logger.log(level: .error, category: .general, message: "Error loading feedback: \(error.localizedDescription)")
            await MainActor.run {
                showToast(text: "Failed to load feedback")
            }
        }
    }
    
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Feedback>()
        snapshot.appendSections([.feedback])
        snapshot.appendItems(feedbackSubmissions, toSection: .feedback)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}

// MARK: - UICollectionViewDelegate
extension FeedbackDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let feedback = dataSource.itemIdentifier(for: indexPath) else { return }
        
        let feedbackVC = NNFeedbackViewController(feedback: feedback)
        present(feedbackVC, animated: true)
        
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

// MARK: - Types
extension FeedbackDetailViewController {
    enum Section {
        case feedback
    }
}

// MARK: - Feedback Cell
private class FeedbackCell: UICollectionViewListCell {
    
    static let reuseIdentifier: String = String(describing: FeedbackCell.self)
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyL
        label.numberOfLines = 2
        return label
    }()
    
    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.font = .bodyM
        label.textColor = .secondaryLabel
        label.numberOfLines = 3
        return label
    }()
    
    private let userInfoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        return label
    }()
    
    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.textAlignment = .right
        return label
    }()
    
    private lazy var topStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [titleLabel, timestampLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .top
        return stack
    }()
    
    private lazy var contentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [topStack, bodyLabel, userInfoLabel])
        stack.axis = .vertical
        stack.spacing = 6
        return stack
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -8),
            
            timestampLabel.widthAnchor.constraint(lessThanOrEqualTo: contentStack.widthAnchor, multiplier: 0.3)
        ])
    }
    
    func configure(with feedback: Feedback) {
        titleLabel.text = feedback.title
        bodyLabel.text = feedback.body
        userInfoLabel.text = "From: \(feedback.email) • Nest: \(String(feedback.nestId.prefix(8)))..."
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        timestampLabel.text = dateFormatter.string(from: feedback.timestamp)
    }
} 
