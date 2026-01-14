import UIKit

protocol NNSegmentedFilterViewDelegate: AnyObject {
    func segmentedFilterView(_ filterView: NNSegmentedFilterView, didSelectSegmentAtIndex index: Int)
}

final class NNSegmentedFilterView: UIView {
    // MARK: - Properties
    weak var delegate: NNSegmentedFilterViewDelegate?
    
    private let segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    // MARK: - Initialization
    init(items: [String]) {
        super.init(frame: .zero)
        segmentedControl.removeAllSegments()
        for (index, item) in items.enumerated() {
            segmentedControl.insertSegment(withTitle: item, at: index, animated: false)
        }
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setup() {
        addSubview(segmentedControl)
        
        segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged), for: .valueChanged)
        
        NSLayoutConstraint.activate([
            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            segmentedControl.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            segmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            segmentedControl.heightAnchor.constraint(equalToConstant: 32).with(priority: .defaultLow)
        ])
        
        // Height is set via frame, not constraint (matching NNCompactCalendarView pattern)
    }
    
    // MARK: - Public Methods
    var selectedSegmentIndex: Int {
        get { segmentedControl.selectedSegmentIndex }
        set { segmentedControl.selectedSegmentIndex = newValue }
    }
    
    var isEnabled: Bool {
        get { segmentedControl.isEnabled }
        set { segmentedControl.isEnabled = newValue }
    }
    
    // MARK: - Actions
    @objc private func segmentedControlValueChanged() {
        delegate?.segmentedFilterView(self, didSelectSegmentAtIndex: segmentedControl.selectedSegmentIndex)
    }
}
