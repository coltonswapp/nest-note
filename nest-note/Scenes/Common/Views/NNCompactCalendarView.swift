import UIKit

protocol NNCompactCalendarViewDelegate: AnyObject {
    func calendarView(_ calendarView: NNCompactCalendarView, didSelectDate date: Date)
}

final class NNCompactCalendarView: UIView {
    
    // MARK: - Properties
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.sectionInset = .zero
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.decelerationRate = .fast
        cv.isPagingEnabled = true
        cv.contentInset = .zero
        cv.alwaysBounceHorizontal = true
        return cv
    }()
    
    private let monthLabel: UILabel = {
        let label = UILabel()
        label.textColor = .label
        label.font = .bodyS
        label.textAlignment = .center
        label.text = "DEC"
        return label
    }()
    
    private let yearLabel: UILabel = {
        let label = UILabel()
        label.textColor = .secondaryLabel
        label.font = UIFont.h5
        label.textAlignment = .center
        label.text = "2025"
        return label
    }()
    
    private let monthYearStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 2
        return stackView
    }()
    
    private let separatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .separator
        return view
    }()
    
    private var dateRange: DateInterval
    private var weeks: [[Date]] = []
    private var selectedDate: Date?
    weak var delegate: NNCompactCalendarViewDelegate?
    private var currentWeekIndex: Int = 0
    private var eventsByDate: [Date: [SessionEvent]] = [:]
    
    // MARK: - Initialization
    init(dateRange: DateInterval, events: [SessionEvent]) {
        self.dateRange = dateRange
        self.eventsByDate = events.reduce(into: [Date: [SessionEvent]]()) { dict, event in
            let startOfDay = Calendar.current.startOfDay(for: event.startDate)
            dict[startOfDay, default: []].append(event)
        }   
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setup() {
        collectionView.layoutMargins = .zero
        setupCollectionView()
        calculateWeeks()
        
        // Set initial month/year labels
        if let firstDate = weeks.first?.first {
            updateMonthYearLabels(for: firstDate)
        }
    }
    
    private func setupCollectionView() {
        addSubview(collectionView)
        addSubview(monthYearStackView)
        addSubview(separatorView)
        
        monthYearStackView.addArrangedSubview(monthLabel)
        monthYearStackView.addArrangedSubview(yearLabel)
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(CompactCalendarDateCell.self, forCellWithReuseIdentifier: "DateCell")
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: separatorView.trailingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            monthYearStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            monthYearStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            // Separator constraints
            separatorView.leadingAnchor.constraint(equalTo: monthYearStackView.trailingAnchor, constant: 10),
            separatorView.centerYAnchor.constraint(equalTo: centerYAnchor),
            separatorView.widthAnchor.constraint(equalToConstant: 0.5),
            separatorView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.8)
        ])
    }
    
    private func calculateWeeks() {
        let calendar = Calendar.current
        
        // Find the start of the week containing the start date
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: dateRange.start))!
        
        // Find the end of the week containing the end date
        var endComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: dateRange.end)
        endComponents.weekday = 7
        let endOfWeek = calendar.date(from: endComponents)!
        
        var currentDate = startOfWeek
        var currentWeek: [Date] = []
        
        while currentDate <= endOfWeek {
            currentWeek.append(currentDate)
            
            if calendar.component(.weekday, from: currentDate) == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        if !currentWeek.isEmpty {
            weeks.append(currentWeek)
        }
    }
    
    private func updateMonthYearLabels(for date: Date) {
        let formatter = DateFormatter()
        
        // Set month format
        formatter.dateFormat = "MMM"
        monthLabel.text = formatter.string(from: date).uppercased()
        
        // Set year format
        formatter.dateFormat = "yyyy"
        yearLabel.text = formatter.string(from: date)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateVisibleDateLabels()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateVisibleDateLabels()
        }
    }
    
    private func updateVisibleDateLabels() {
        // Calculate which week is visible based on content offset
        let visibleX = collectionView.contentOffset.x
        let weekWidth = collectionView.bounds.width
        let weekIndex = Int(round(visibleX / weekWidth))
        
        // Check if we've moved to a new week
        if weekIndex != currentWeekIndex {
            HapticsHelper.superLightHaptic()
            currentWeekIndex = weekIndex
        }
        
        // Get the first date of the visible week
        if weekIndex < weeks.count, !weeks[weekIndex].isEmpty {
            let visibleDate = weeks[weekIndex][0]
            updateMonthYearLabels(for: visibleDate)
        }
    }
    
    func updateEvents(_ events: [Date: [SessionEvent]]) {
        self.eventsByDate = events
        collectionView.reloadData()
    }
    
    // MARK: - Public Methods
    func scrollToWeek(containing date: Date, animated: Bool = true) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // Find the week index that contains this date
        let allDates = weeks.flatMap { $0 }
        guard let dateIndex = allDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: startOfDay) }) else { return }
        
        // Calculate which week this date belongs to
        let weekIndex = dateIndex / 7
        
        // Calculate the x offset for this week
        let weekWidth = collectionView.bounds.width
        let xOffset = CGFloat(weekIndex) * weekWidth
        
        // Scroll to the week
        collectionView.setContentOffset(CGPoint(x: xOffset, y: 0), animated: animated)
        
        // Update the month/year labels
        if let firstDateOfWeek = weeks[weekIndex].first {
            updateMonthYearLabels(for: firstDateOfWeek)
        }
        
        // Update current week index
        currentWeekIndex = weekIndex
    }
}

// MARK: - UICollectionView DataSource & Delegate
extension NNCompactCalendarView: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return weeks.flatMap { $0 }.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DateCell", for: indexPath) as! CompactCalendarDateCell
        let date = weeks.flatMap { $0 }[indexPath.item]
        
        let isSelected = selectedDate?.isSameDay(as: date) ?? false
        let isInRange = dateRange.contains(date)
        
        // Check if there are events for this date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let hasEvents = eventsByDate[startOfDay]?.isEmpty == false
        
        cell.configure(with: date, isSelected: isSelected, isEnabled: isInRange, dateRange: dateRange, hasEvents: hasEvents)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width / 7
        return CGSize(width: width, height: 50)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let date = weeks.flatMap { $0 }[indexPath.item]
        let calendar = Calendar.current
        
        // Use the same range check as in configure
        let isInRange = date >= calendar.startOfDay(for: dateRange.start) &&
                        date <= calendar.endOfDay(for: dateRange.end)
        
        if isInRange {
            selectedDate = date
            delegate?.calendarView(self, didSelectDate: date)
            HapticsHelper.lightHaptic()
            collectionView.reloadData()
        }
    }
}

// MARK: - Date Cell
private class CompactCalendarDateCell: UICollectionViewCell {
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        return stack
    }()
    
    private let dayLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .captionBoldS
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .bodyL
        return label
    }()
    
    private var dateRange: DateInterval?
    
    // Add event indicator view
    private let eventIndicatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = NNColors.primary
        view.layer.cornerRadius = 2  // Will make it a 4x4 circle
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 0
        contentView.layer.maskedCorners = []
    }
    
    private func setup() {
        contentView.addSubview(stackView)
        stackView.addArrangedSubview(dayLabel)
        stackView.addArrangedSubview(dateLabel)
        
        contentView.addSubview(eventIndicatorView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            // Event indicator constraints
            eventIndicatorView.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 0),
            eventIndicatorView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            eventIndicatorView.widthAnchor.constraint(equalToConstant: 4),
            eventIndicatorView.heightAnchor.constraint(equalToConstant: 4)
        ])
    }
    
    func configure(with date: Date, isSelected: Bool, isEnabled: Bool, dateRange: DateInterval, hasEvents: Bool) {
        self.dateRange = dateRange
        let calendar = Calendar.current
        dateLabel.text = String(calendar.component(.day, from: date))
        dayLabel.text = calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
        
        // Show/hide event indicator
        eventIndicatorView.isHidden = !hasEvents
        
        let isToday = calendar.isDateInToday(date)
        let isInRange = date >= calendar.startOfDay(for: dateRange.start) &&
                        date <= calendar.endOfDay(for: dateRange.end)
        
        // Determine if this is the start or end date of the range
        let isStartDate = calendar.isDate(date, inSameDayAs: dateRange.start)
        let isEndDate = calendar.isDate(date, inSameDayAs: dateRange.end)
        
        // Reset corner radius mask
        contentView.layer.maskedCorners = []
        
        if isSelected {
            // Selected state styling
            dateLabel.textColor = .systemBackground
            dayLabel.textColor = .systemBackground
            dateLabel.font = .h4
            contentView.backgroundColor = .label.withAlphaComponent(0.8)
            
            if isStartDate && isEndDate {
                // Single day - round all corners
                contentView.layer.cornerRadius = 16
                contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            } else if isStartDate {
                contentView.layer.cornerRadius = 16
                contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner] // Left corners
            } else if isEndDate {
                contentView.layer.cornerRadius = 16
                contentView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner] // Right corners
            }
            
        } else {
            // Normal state styling
            dateLabel.font = .bodyL
            
            if isInRange {
                contentView.backgroundColor = NNColors.paletteGray
                contentView.layer.cornerRadius = 0 // Reset corner radius
                
                // Apply rounded corners for start and end dates
                if isStartDate && isEndDate {
                    // Single day - round all corners
                    contentView.layer.cornerRadius = 16
                    contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
                } else if isStartDate {
                    contentView.layer.cornerRadius = 16
                    contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner] // Left corners
                } else if isEndDate {
                    contentView.layer.cornerRadius = 16
                    contentView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner] // Right corners
                }
                
                dateLabel.textColor = isToday ? NNColors.primary : .label
                dayLabel.textColor = isToday ? NNColors.primary : .secondaryLabel
            } else {
                contentView.backgroundColor = .clear
                dateLabel.textColor = .tertiaryLabel
                dayLabel.textColor = .tertiaryLabel
            }
            
            if isToday {
                dateLabel.font = .h4
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.masksToBounds = true
        layer.cornerRadius = isSelected ? min(bounds.width, bounds.height) / 2 : 0
    }
}

// MARK: - Date Extension
private extension Date {
    func isSameDay(as other: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, inSameDayAs: other)
    }
}
