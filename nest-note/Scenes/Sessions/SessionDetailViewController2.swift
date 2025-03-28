//import UIKit
//
//class SessionDetailViewController: NNViewController {
//    private let session: SessionItem
//    
//    private let scrollView: UIScrollView = {
//        let scrollView = UIScrollView()
//        scrollView.translatesAutoresizingMaskIntoConstraints = false
//        return scrollView
//    }()
//    
//    private let contentView: UIView = {
//        let view = UIView()
//        view.translatesAutoresizingMaskIntoConstraints = false
//        return view
//    }()
//    
//    private let titleLabel: UILabel = {
//        let label = UILabel()
//        label.font = .systemFont(ofSize: 24, weight: .bold)
//        label.textColor = .label
//        label.numberOfLines = 0
//        label.translatesAutoresizingMaskIntoConstraints = false
//        return label
//    }()
//    
//    private let dateLabel: UILabel = {
//        let label = UILabel()
//        label.font = .systemFont(ofSize: 17)
//        label.textColor = .secondaryLabel
//        label.numberOfLines = 0
//        label.translatesAutoresizingMaskIntoConstraints = false
//        return label
//    }()
//    
//    private let statusLabel: UILabel = {
//        let label = UILabel()
//        label.font = .systemFont(ofSize: 15, weight: .medium)
//        label.textColor = .secondaryLabel
//        label.translatesAutoresizingMaskIntoConstraints = false
//        return label
//    }()
//    
//    init(session: SessionItem) {
//        self.session = session
//        super.init(nibName: nil, bundle: nil)
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        configureSession()
//    }
//    
//    override func setup() {
//        title = "Session Details"
//        view.backgroundColor = .systemBackground
//    }
//    
//    override func addSubviews() {
//        view.addSubview(scrollView)
//        scrollView.addSubview(contentView)
//        
//        contentView.addSubview(titleLabel)
//        contentView.addSubview(dateLabel)
//        contentView.addSubview(statusLabel)
//    }
//    
//    override func constrainSubviews() {
//        NSLayoutConstraint.activate([
//            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
//            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            
//            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
//            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
//            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
//            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
//            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
//            
//            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
//            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
//            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
//            
//            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
//            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
//            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
//            
//            statusLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 16),
//            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
//            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
//            statusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
//        ])
//    }
//    
//    private func configureSession() {
//        titleLabel.text = session.title
//        
//        // Format date range
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateStyle = .medium
//        dateFormatter.timeStyle = .short
//        
//        let startDateStr = dateFormatter.string(from: session.startDate)
//        let endDateStr = dateFormatter.string(from: session.endDate)
//        dateLabel.text = "\(startDateStr) - \(endDateStr)"
//        
//        // Configure status
//        let status = session.inferredStatus(at: Date())
//        var statusText = "Status: "
//        switch status {
//        case .upcoming:
//            statusText += "Upcoming"
//            statusLabel.textColor = .systemBlue
//        case .inProgress:
//            statusText += "In Progress"
//            statusLabel.textColor = .systemGreen
//        case .completed:
//            statusText += "Completed"
//            statusLabel.textColor = .systemGray
//        case .extended:
//            statusText += "Extended"
//            statusLabel.textColor = .systemOrange
//        }
//        statusLabel.text = statusText
//    }
//} 
