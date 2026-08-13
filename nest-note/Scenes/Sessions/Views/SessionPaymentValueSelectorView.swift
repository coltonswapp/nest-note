import UIKit

final class SessionPaymentValueSelectorView: UIView {
    private let collectionView: UICollectionView
    private let selectionBar = UIView()
    private let decrementButton = GlassIconButton(systemName: "chevron.left", size: 36)
    private let incrementButton = GlassIconButton(systemName: "chevron.right", size: 36)

    private var valueRange: ClosedRange<Int> = 0...100
    private var currentValue: Int = 0
    private var isUpdatingFromProgrammaticScroll = false
    private var increment: Int = 1
    private var chevronStepAmount: Int = 0
    private var decelerationRate: UIScrollView.DecelerationRate = .normal
    private let feedbackGenerator = UISelectionFeedbackGenerator()

    static let markerWidth: CGFloat = 3.5
    static let markerCornerRadius: CGFloat = 2
    static let tickSpacing: CGFloat = 8
    static let tickSize: (CGFloat, CGFloat) = (22, 12) // (major, minor)
    static let selectionBarHeight: CGFloat = 34
    static let trackHeight: CGFloat = 44
    static let chevronHorizontalInset: CGFloat = 12

    private var majorTickFrequency: Int = 10

    var onValueChanged: ((Int) -> Void)?

    override init(frame: CGRect) {
        let layout = SessionPaymentValueCollectionViewLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        let layout = SessionPaymentValueCollectionViewLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = .clear
        feedbackGenerator.prepare()

        decrementButton.addTarget(self, action: #selector(decrementTapped), for: .touchUpInside)
        incrementButton.addTarget(self, action: #selector(incrementTapped), for: .touchUpInside)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.decelerationRate = decelerationRate
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(
            SessionPaymentValueCell.self,
            forCellWithReuseIdentifier: SessionPaymentValueCell.reuseIdentifier
        )

        selectionBar.translatesAutoresizingMaskIntoConstraints = false
        selectionBar.backgroundColor = NNColors.primary
        selectionBar.layer.cornerRadius = Self.markerCornerRadius
        selectionBar.isUserInteractionEnabled = false

        addSubview(collectionView)
        addSubview(selectionBar)
        addSubview(decrementButton)
        addSubview(incrementButton)

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),

            selectionBar.centerXAnchor.constraint(equalTo: centerXAnchor),
            selectionBar.centerYAnchor.constraint(equalTo: centerYAnchor),
            selectionBar.widthAnchor.constraint(equalToConstant: Self.markerWidth),
            selectionBar.heightAnchor.constraint(equalToConstant: Self.selectionBarHeight),

            decrementButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.chevronHorizontalInset),
            decrementButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            decrementButton.widthAnchor.constraint(equalToConstant: decrementButton.buttonSize),
            decrementButton.heightAnchor.constraint(equalToConstant: decrementButton.buttonSize),

            incrementButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.chevronHorizontalInset),
            incrementButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            incrementButton.widthAnchor.constraint(equalToConstant: incrementButton.buttonSize),
            incrementButton.heightAnchor.constraint(equalToConstant: incrementButton.buttonSize)
        ])
    }

    func configure(
        range: ClosedRange<Int>,
        initialValue: Int,
        increment: Int = 1,
        chevronStepAmount: Int? = nil,
        majorTickFrequency: Int? = nil,
        decelerationRate: UIScrollView.DecelerationRate? = nil
    ) {
        valueRange = range
        self.increment = increment
        self.chevronStepAmount = chevronStepAmount ?? increment

        if let majorTickFrequency {
            self.majorTickFrequency = majorTickFrequency
        } else {
            self.majorTickFrequency = increment == 5 ? 25 : 10
        }

        if let decelerationRate {
            self.decelerationRate = decelerationRate
        } else {
            self.decelerationRate = increment == 1 ? .fast : .normal
        }
        collectionView.decelerationRate = self.decelerationRate

        currentValue = roundToNearestIncrement(initialValue)
        collectionView.reloadData()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            scrollToValue(currentValue, animated: false)
        }
    }

    func scrollToValue(_ value: Int, animated: Bool) {
        let roundedValue = roundToNearestIncrement(value)
        guard valueRange.contains(roundedValue) else { return }

        currentValue = roundedValue
        let indexPath = IndexPath(item: indexForValue(roundedValue), section: 0)
        guard itemCount() > 0, collectionView.bounds.width > 0 else { return }

        collectionView.layoutIfNeeded()

        guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
            isUpdatingFromProgrammaticScroll = animated
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
            if !animated {
                isUpdatingFromProgrammaticScroll = false
            }
            return
        }

        let targetX = attributes.center.x - collectionView.bounds.width / 2
        let maxOffsetX = max(0, collectionView.contentSize.width - collectionView.bounds.width)
        let clampedX = min(max(0, targetX), maxOffsetX)
        let targetOffset = CGPoint(x: clampedX, y: 0)

        isUpdatingFromProgrammaticScroll = animated
        collectionView.setContentOffset(targetOffset, animated: animated)
        if !animated {
            isUpdatingFromProgrammaticScroll = false
        }
    }

    @objc private func decrementTapped() {
        adjustValue(by: -chevronStepAmount)
    }

    @objc private func incrementTapped() {
        adjustValue(by: chevronStepAmount)
    }

    private func adjustValue(by delta: Int) {
        let newValue = roundToNearestIncrement(currentValue + delta)
        guard valueRange.contains(newValue), newValue != currentValue else { return }

        scrollToValue(newValue, animated: true)
        onValueChanged?(newValue)
        feedbackGenerator.selectionChanged()
        feedbackGenerator.prepare()
    }

    private func updateValueFromCenter() {
        let centerPoint = CGPoint(
            x: collectionView.contentOffset.x + collectionView.bounds.width / 2,
            y: collectionView.frame.midY
        )
        guard let indexPath = collectionView.indexPathForItem(at: centerPoint) else { return }

        let newValue = valueForIndex(indexPath.item)
        if newValue != currentValue {
            currentValue = newValue
            onValueChanged?(currentValue)
            feedbackGenerator.selectionChanged()
            feedbackGenerator.prepare()
        }
    }

    private func roundToNearestIncrement(_ value: Int) -> Int {
        let remainder = (value - valueRange.lowerBound) % increment
        if remainder == 0 {
            return value
        }

        let lowerBound = value - remainder
        let upperBound = lowerBound + increment

        if remainder < increment / 2 {
            return max(lowerBound, valueRange.lowerBound)
        }
        return min(upperBound, valueRange.upperBound)
    }

    private func indexForValue(_ value: Int) -> Int {
        (value - valueRange.lowerBound) / increment
    }

    private func valueForIndex(_ index: Int) -> Int {
        valueRange.lowerBound + (index * increment)
    }

    private func itemCount() -> Int {
        ((valueRange.upperBound - valueRange.lowerBound) / increment) + 1
    }
}

extension SessionPaymentValueSelectorView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        itemCount()
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: SessionPaymentValueCell.reuseIdentifier,
            for: indexPath
        ) as? SessionPaymentValueCell else {
            return UICollectionViewCell()
        }

        let value = valueForIndex(indexPath.item)
        let isMajorTick = value % majorTickFrequency == 0
        cell.configure(isMajorTick: isMajorTick)
        return cell
    }
}

extension SessionPaymentValueSelectorView: UICollectionViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isUpdatingFromProgrammaticScroll = false
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if isUpdatingFromProgrammaticScroll { return }

        if scrollView.isDragging || scrollView.isDecelerating {
            updateValueFromCenter()
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateValueFromCenter()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateValueFromCenter()
        isUpdatingFromProgrammaticScroll = false
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if isUpdatingFromProgrammaticScroll {
            isUpdatingFromProgrammaticScroll = false
            return
        }
        updateValueFromCenter()
    }
}
