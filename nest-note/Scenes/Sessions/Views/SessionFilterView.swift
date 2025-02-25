import UIKit

protocol SessionFilterViewDelegate: AnyObject {
    func sessionFilterView(_ filterView: SessionFilterView, didSelectFilter filter: SessionService.SessionBucket)
}

class SessionFilterView: UIView {
    
    weak var delegate: SessionFilterViewDelegate?
    
    private var activeFilter: SessionService.SessionBucket = .upcoming {
        didSet {
            updateSelection(animated: true)
            delegate?.sessionFilterView(self, didSelectFilter: activeFilter)
        }
    }
    
    private lazy var bottomStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var topStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 4
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = NNColors.primaryOpaque
        view.layer.cornerRadius = 18
        view.clipsToBounds = true
        view.layer.borderColor = NNColors.primary.cgColor
        view.layer.borderWidth = 1.5
        return view
    }()
    
    private lazy var tagMaskView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.cornerRadius = 18
        view.clipsToBounds = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(bottomStackView)
        addSubview(backgroundView)
        addSubview(topStackView)
        
        // Setup bottom stack (inactive state)
        let bottomButtons = createFilterButtons(foregroundColor: .tertiaryLabel)
        bottomButtons.forEach { bottomStackView.addArrangedSubview($0) }
        
        // Setup top stack (active state)
        let topButtons = createFilterButtons(foregroundColor: NNColors.primary)
        topButtons.forEach { topStackView.addArrangedSubview($0) }
        
        topStackView.mask = tagMaskView
        
        NSLayoutConstraint.activate([
            bottomStackView.topAnchor.constraint(equalTo: topAnchor),
            bottomStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            bottomStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            bottomStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            
            topStackView.topAnchor.constraint(equalTo: bottomStackView.topAnchor),
            topStackView.leadingAnchor.constraint(equalTo: bottomStackView.leadingAnchor),
            topStackView.trailingAnchor.constraint(equalTo: bottomStackView.trailingAnchor),
            topStackView.bottomAnchor.constraint(equalTo: bottomStackView.bottomAnchor)
        ])
        
        updateSelection(animated: false)
    }
    
    private func createFilterButtons(foregroundColor: UIColor) -> [UIButton] {
        let filters: [(String, SessionService.SessionBucket)] = [
            ("Upcoming", .upcoming),
            ("In-progress", .inProgress),
            ("Past", .past)
        ]
        
        return filters.map { title, filter in
            var config = UIButton.Configuration.plain()
            config.title = title
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 14, weight: .bold)
                return outgoing
            }
            
            let button = UIButton(configuration: config)
            button.configuration?.baseForegroundColor = foregroundColor
            button.tag = filter.rawValue
            button.addTarget(self, action: #selector(filterButtonTapped(_:)), for: .touchUpInside)
            return button
        }
    }
    
    private func updateSelection(animated: Bool = true) {
        let selectedButton = bottomStackView.arrangedSubviews[activeFilter.rawValue]
        
        let update = {
            let buttonFrame = selectedButton.convert(selectedButton.bounds, to: self)
            self.backgroundView.frame = buttonFrame
            self.tagMaskView.frame = buttonFrame
        }
        
        if animated {
            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                usingSpringWithDamping: 0.8,  // Less bouncy (1.0 is no bounce)
                initialSpringVelocity: 0.5,    // Initial velocity of the spring
                options: [.curveEaseOut],
                animations: update
            )
        } else {
            update()
        }
    }
    
    @objc private func filterButtonTapped(_ sender: UIButton) {
        guard let filter = SessionService.SessionBucket(rawValue: sender.tag) else { return }
        activeFilter = filter
        HapticsHelper.lightHaptic()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateSelection(animated: false)
    }
    
    func selectBucket(_ bucket: SessionService.SessionBucket) {
        activeFilter = bucket
    }
} 
