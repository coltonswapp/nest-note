//
//  DateCell.swift
//  nest-note
//
//  Created by Colton Swapp on 12/31/24.
//

import UIKit

final class DateCell: UICollectionViewListCell {
    private var startControl: NNDateTimeControl!
    private var endControl: NNDateTimeControl!
    private var multiDayToggle: UISwitch!
    
    weak var delegate: DatePresentationDelegate?
    private var startDate: Date = Date()
    private var endDate: Date = Date()
    private var isMultiDay: Bool = false
    
    private var isReadOnly: Bool = false
    
    // Create labels
    let startLabel: UILabel = {
        let label = UILabel()
        label.text = "Starts"
        label.font = .bodyL
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let endLabel: UILabel = {
        let label = UILabel()
        label.text = "Ends"
        label.font = .bodyL
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    
    let multiDayLabel: UILabel = {
        let label = UILabel()
        label.text = "Multi-day session"
        label.font = .bodyL
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupControls()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupControls() {
        startControl = NNDateTimeControl(style: .both, type: .start)
        endControl = NNDateTimeControl(style: .time, type: .end)
        multiDayToggle = UISwitch()
        
        startControl.translatesAutoresizingMaskIntoConstraints = false
        endControl.translatesAutoresizingMaskIntoConstraints = false
        multiDayToggle.translatesAutoresizingMaskIntoConstraints = false

        // Setup callbacks
        startControl.onDateTapped = { [weak self] in
            self?.startDateTapped()
        }
        startControl.onTimeTapped = { [weak self] in
            self?.startTimeTapped()
        }
        endControl.onDateTapped = { [weak self] in
            self?.endDateTapped()
        }
        endControl.onTimeTapped = { [weak self] in
            self?.endTimeTapped()
        }
        multiDayToggle.addTarget(self, action: #selector(multiDayToggleTapped), for: .valueChanged)
        
        // Add to content view
        contentView.addSubview(startLabel)
        contentView.addSubview(startControl)
        contentView.addSubview(endLabel)
        contentView.addSubview(endControl)
        contentView.addSubview(multiDayLabel)
        contentView.addSubview(multiDayToggle)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Start label constraints
            startLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            startLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            // Start control constraints
            startControl.centerYAnchor.constraint(equalTo: startLabel.centerYAnchor),
            startControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            startControl.leadingAnchor.constraint(greaterThanOrEqualTo: startLabel.trailingAnchor, constant: 16),
            
            // End label constraints
            endLabel.topAnchor.constraint(equalTo: startLabel.bottomAnchor, constant: 24),
            endLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            endLabel.widthAnchor.constraint(equalTo: startLabel.widthAnchor),
            
            // End control constraints
            endControl.centerYAnchor.constraint(equalTo: endLabel.centerYAnchor),
            endControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            endControl.leadingAnchor.constraint(greaterThanOrEqualTo: endLabel.trailingAnchor, constant: 16),
            
            // Multi-day label constraints
            multiDayLabel.topAnchor.constraint(equalTo: endLabel.bottomAnchor, constant: 24),
            multiDayLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            multiDayLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            // Multi-day toggle constraints
            multiDayToggle.centerYAnchor.constraint(equalTo: multiDayLabel.centerYAnchor),
            multiDayToggle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    func configure(startDate: Date, endDate: Date, isMultiDay: Bool, isReadOnly: Bool = false) {
        self.startDate = startDate
        self.endDate = endDate
        self.isMultiDay = isMultiDay
        self.isReadOnly = isReadOnly
        
        startControl.date = startDate
        endControl.date = endDate
        multiDayToggle.isOn = isMultiDay
        endControl.setStyle(isMultiDay ? .both : .time, animated: false)
        
        startControl.isEnabled = !isReadOnly
        endControl.isEnabled = !isReadOnly
        multiDayToggle.isEnabled = !isReadOnly
        
        updateDateLabels()
    }
    
    private func updateDateLabels() {
        let formatter = DateFormatter()
        
        // Update start control
        formatter.dateFormat = "MMM d, yyyy"
        startControl.dateText = formatter.string(from: startDate)
        formatter.dateFormat = "h:mm a"
        startControl.timeText = formatter.string(from: startDate)
        
        // Update end control
        if isMultiDay {
            formatter.dateFormat = "MMM d, yyyy"
            endControl.dateText = formatter.string(from: endDate)
        }
        formatter.dateFormat = "h:mm a"
        endControl.timeText = formatter.string(from: endDate)
        
        endControl.setStyle(isMultiDay ? .both : .time, animated: true)
    }
    
    private func startDateTapped() {
        delegate?.presentDatePicker(for: .startDate, initialDate: startDate)
    }
    
    private func startTimeTapped() {
        delegate?.presentDatePicker(for: .startTime, initialDate: startDate)
    }
    
    private func endDateTapped() {
        delegate?.presentDatePicker(for: .endDate, initialDate: endDate)
    }
    
    private func endTimeTapped() {
        delegate?.presentDatePicker(for: .endTime, initialDate: endDate)
    }
    
    @objc private func multiDayToggleTapped() {
        isMultiDay = multiDayToggle.isOn
        endControl.setStyle(isMultiDay ? .both : .time, animated: true)
        
        if !isMultiDay {
            // Sync end date with start date
            let calendar = Calendar.current
            let startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
            let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endDate)
            
            var newComponents = DateComponents()
            newComponents.year = startComponents.year
            newComponents.month = startComponents.month
            newComponents.day = startComponents.day
            newComponents.hour = endTimeComponents.hour
            newComponents.minute = endTimeComponents.minute
            
            if let newDate = calendar.date(from: newComponents) {
                updateDates(newEndDate: newDate)
            }
        } else {
            // Just notify delegate of the toggle change
            delegate?.didToggleMultiDay(isMultiDay, startDate: startDate, endDate: endDate)
        }
    }
    
    private func updateDates(newStartDate: Date? = nil, newEndDate: Date? = nil) {
        if let newStartDate = newStartDate {
            startDate = newStartDate
        }
        if let newEndDate = newEndDate {
            endDate = newEndDate
        }
        
        // Update the UI
        updateDateLabels()
        
        // Notify delegate of the change
        delegate?.didToggleMultiDay(isMultiDay, startDate: startDate, endDate: endDate)
    }
}
