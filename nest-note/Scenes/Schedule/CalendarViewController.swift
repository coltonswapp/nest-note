//
//  CalendarViewController.swift
//  nest-note
//
//  Created by Colton Swapp on 10/10/24.
//


import UIKit

class CalendarViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = CalendarContentView()
    
    // Static properties for layout and drawing
    static let verticalBuffer: CGFloat = 40
    static let hours: Int = 18
    static let startHour: Int = 6
    static let eventLeftMargin: CGFloat = 55.0
    static let eventRightMargin: CGFloat = 10.0
    static let lineWidth: CGFloat = 2.0
    static let timeLabelFontSize: CGFloat = 12.0
    static let hourLabelForegroundColor: UIColor = .label.withAlphaComponent(0.3)
    static let hourLineForegroundColor: UIColor = .label.withAlphaComponent(0.1)
    static let hourHeight: CGFloat = 80.0
    static let hourLineLeftMargin: CGFloat = 48.0
    
    private var currentTimeLineLayer: CAShapeLayer?
    
    override func loadView() {
        super.loadView()
        view.backgroundColor = .systemBackground
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Oct 13, 2024"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        setupScrollView()
        setupNavigationBarButtons()
        setupCurrentTimeLine()
    }
    
    private func setupScrollView() {
        view.addSubview(scrollView)
        
        let safeArea = view.safeAreaLayoutGuide
        scrollView.frame = safeArea.layoutFrame
        
        let totalContentHeight = (CalendarViewController.hourHeight * CGFloat(CalendarViewController.hours)) + (2 * CalendarViewController.verticalBuffer) + 100
        let contentSize = CGSize(width: safeArea.layoutFrame.width, height: totalContentHeight)
        scrollView.contentSize = contentSize
        
        contentView.frame = CGRect(origin: .zero, size: contentSize)
        scrollView.addSubview(contentView)
        
        contentView.backgroundColor = .systemBackground
    }

    private func setupNavigationBarButtons() {
        let debugButton = UIBarButtonItem(image: UIImage(systemName: "ladybug.fill"), style: .plain, target: self, action: #selector(debugEventsButtonTapped))
        let randomButton = UIBarButtonItem(image: UIImage(systemName: "dice.fill"), style: .plain, target: self, action: #selector(randomEventsButtonTapped))
        
        navigationItem.rightBarButtonItems = [randomButton, debugButton]
    }
    
    private func addRandomEvents() {
        let eventNames = ["Meeting", "Lunch", "Gym", "Study", "Coffee Break", "Phone Call", "Dentist", "Grocery Shopping", "Yoga Class", "Team Building"]
        let numberOfEvents = 6
        let possibleMinutes = [0, 30]

        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = calendar.component(.year, from: Date())
        dateComponents.month = calendar.component(.month, from: Date())
        dateComponents.day = calendar.component(.day, from: Date())
        
        var eventViews: [EventView] = []
        
        for _ in 0..<numberOfEvents {
            dateComponents.hour = Int.random(in: 9...20)
            dateComponents.minute = possibleMinutes.randomElement()!
            guard let startTime = calendar.date(from: dateComponents) else { continue }
            
            let durationInMinutes = Int.random(in: 2...8) * 15
            let duration = TimeInterval(durationInMinutes * 60)
            
            let title = eventNames.randomElement() ?? "Event"
            
            let eventView = EventView(startTime: startTime, duration: duration, title: title)
            eventViews.append(eventView)
        }
        
        eventViews.sort { $0.startTime < $1.startTime }
        addEvents(eventViews)
    }
    
    private func addDebugEvents() {
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = calendar.component(.year, from: Date())
        dateComponents.month = calendar.component(.month, from: Date())
        dateComponents.day = calendar.component(.day, from: Date())
        
        let debugEvents = [
            (hour: 6, minute: 30, title: "Standup Meeting", durationMinutes: 105),
            (hour: 6, minute: 30, title: "Doctor Appt", durationMinutes: 105),
            (hour: 6, minute: 45, title: "Commute", durationMinutes: 30),
            (hour: 7, minute: 00, title: "Donuts", durationMinutes: 30),
            (hour: 10, minute: 30, title: "Sprint Planning", durationMinutes: 60),
            (hour: 12, minute: 0, title: "Lunch", durationMinutes: 60),
            (hour: 12, minute: 15, title: "Dentist Appt", durationMinutes: 60),
            (hour: 14, minute: 30, title: "Kids out of school", durationMinutes: 15),
            (hour: 16, minute: 0, title: "Softball Game", durationMinutes: 120),
            (hour: 18, minute: 30, title: "Dinner", durationMinutes: 45),
            (hour: 20, minute: 0, title: "Oilers Game", durationMinutes: 90)
        ]
        
        var eventViews: [EventView] = []
        
        for event in debugEvents {
            dateComponents.hour = event.hour
            dateComponents.minute = event.minute
            
            guard let startTime = calendar.date(from: dateComponents) else { continue }
            
            let duration = TimeInterval(event.durationMinutes * 60)
            let eventView = EventView(startTime: startTime, duration: duration, title: event.title)
            eventViews.append(eventView)
        }
        
        addEvents(eventViews)
    }
    
    private func setupCurrentTimeLine() {
        currentTimeLineLayer = CAShapeLayer()
        currentTimeLineLayer?.strokeColor = UIColor.red.cgColor
        currentTimeLineLayer?.lineWidth = CalendarViewController.lineWidth
        currentTimeLineLayer?.lineCap = .round
        
        if let currentTimeLineLayer = currentTimeLineLayer {
            contentView.layer.addSublayer(currentTimeLineLayer)
        }
        
        updateCurrentTimeLine()
        
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateCurrentTimeLine()
        }
    }
    
    private func updateCurrentTimeLine() {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        let hoursPassed = CGFloat(hour - CalendarViewController.startHour) + CGFloat(minute) / 60.0
        let y = CalendarViewController.verticalBuffer + (hoursPassed * CalendarViewController.hourHeight)
        
        let path = UIBezierPath()
        
        let circleRadius: CGFloat = 1
        let circleCenter = CGPoint(x: 48, y: y)
        path.addArc(withCenter: circleCenter, radius: circleRadius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        
        path.move(to: CGPoint(x: 48 + circleRadius, y: y))
        path.addLine(to: CGPoint(x: contentView.bounds.width, y: y))
        
        currentTimeLineLayer?.path = path.cgPath
        currentTimeLineLayer?.zPosition = 999
    }

    private func resetContentView() {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        contentView.events.removeAll()
        contentView.eventGroups.removeAll()
        contentView.setNeedsDisplay()
    }

    @objc private func debugEventsButtonTapped() {
        resetContentView()
        addDebugEvents()
    }

    @objc private func randomEventsButtonTapped() {
        resetContentView()
        addRandomEvents()
    }

    private func addEvents(_ newEvents: [EventView]) {
        for event in newEvents {
            event.addTarget(self, action: #selector(eventTapped(_:)), for: .touchUpInside)
            contentView.addEvents([event])
        }
    }

    @objc private func eventTapped(_ sender: EventView) {
        print("Event tapped: \(sender.title)")
        // Handle the event tap here (e.g., show details, edit event, etc.)
    }
}

class CalendarContentView: UIView {
    var events: [EventView] = []
    var eventGroups: [[EventView]] = []

    static let minimumEventHeight: CGFloat = 30.0
    static let eventVerticalGap: CGFloat = 4.0

    func addEvents(_ newEvents: [EventView]) {
        events.append(contentsOf: newEvents)
        organizeEvents()
        layoutEventGroups()
    }

    private func organizeEvents() {
        events.sort { $0.startTime < $1.startTime }

        eventGroups = []
        var currentGroup: [EventView] = []

        for event in events {
            if currentGroup.isEmpty || event.startTime < currentGroup.last!.endTime {
                currentGroup.append(event)
            } else {
                eventGroups.append(currentGroup)
                currentGroup = [event]
            }
        }

        if !currentGroup.isEmpty {
            eventGroups.append(currentGroup)
        }
    }

    private func layoutEventGroups() {
        for group in eventGroups {
            layoutGroup(group)
        }
    }

    private func layoutGroup(_ group: [EventView]) {
        let columns = min(group.count, 3)
        let availableWidth = bounds.width - CalendarViewController.eventLeftMargin - CalendarViewController.eventRightMargin
        let columnWidth = availableWidth / CGFloat(columns)

        for (index, event) in group.enumerated() {
            let column = index % columns
            let x = CalendarViewController.eventLeftMargin + CGFloat(column) * columnWidth
            
            let maxWidth = availableWidth - (CGFloat(column) * columnWidth)
            let width = min(columnWidth + 12, maxWidth)

            let startMinutes = minutesSinceMidnight(for: event.startTime)
            let durationMinutes = event.duration / 60

            let adjustedStartMinutes = startMinutes - (CalendarViewController.startHour * 60)
            
            let rawYPosition = (CGFloat(adjustedStartMinutes) / 60.0) * CalendarViewController.hourHeight
            let yPosition = CalendarViewController.verticalBuffer + rawYPosition + 
                CalendarContentView.eventVerticalGap

            let calculatedHeight = (CGFloat(durationMinutes) / 60.0) * CalendarViewController.hourHeight
            let height = max(calculatedHeight - (2 * CalendarContentView.eventVerticalGap), CalendarContentView.minimumEventHeight)

            event.frame = CGRect(x: x, y: yPosition, width: width, height: height)
            event.layer.shadowOpacity = column > 0 ? 0.3 : 0.3

            addSubview(event)
        }
    }

    private func minutesSinceMidnight(for date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        drawHourLines(hourHeight: CalendarViewController.hourHeight)
        drawTimeLabels(hourHeight: CalendarViewController.hourHeight)
    }
    
    private func drawTimeLabels(hourHeight: CGFloat) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "ha"
        
        for i in 0...CalendarViewController.hours {
            let hour = (i + CalendarViewController.startHour) % 24
            let y = CalendarViewController.verticalBuffer + (CGFloat(i) * hourHeight)
            
            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            let date = Calendar.current.date(from: components)!
            
            let timeString = dateFormatter.string(from: date).uppercased()
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: CalendarViewController.timeLabelFontSize, weight: .bold),
                .foregroundColor: CalendarViewController.hourLabelForegroundColor
            ]
            
            let size = timeString.size(withAttributes: attributes)
            let labelY = y - (size.height / 2)
            
            let labelX = CalendarViewController.hourLineLeftMargin - 8 - size.width
            
            let rect = CGRect(x: labelX, y: labelY, width: size.width, height: size.height)
            
            timeString.draw(in: rect, withAttributes: attributes)
        }
    }
    
    private func drawHourLines(hourHeight: CGFloat) {
        let path = UIBezierPath()
        path.lineWidth = CalendarViewController.lineWidth
        path.lineCapStyle = .round

        for i in 0...CalendarViewController.hours {
            let y = CalendarViewController.verticalBuffer + (CGFloat(i) * hourHeight)
            path.move(to: CGPoint(x: CalendarViewController.hourLineLeftMargin, y: y))
            path.addLine(to: CGPoint(x: bounds.width, y: y))
        }
        
        CalendarViewController.hourLineForegroundColor.setStroke()
        path.stroke()
    }
}

class EventView: UIControl {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .captionBold
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let title: String
    let startTime: Date
    let duration: TimeInterval
    
    init(startTime: Date, duration: TimeInterval, title: String) {
        self.startTime = startTime
        self.duration = duration
        self.title = title
        super.init(frame: .zero)
        
        backgroundColor = .init(red: 161/255, green: 198/255, blue: 255/255, alpha: 1.0)
        layer.cornerRadius = 8
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0
        
        titleLabel.text = title
        titleLabel.textColor = .init(red: 0/255, green: 84/255, blue: 175/255, alpha: 1.0)
        titleLabel.font = .h5
        setupView()
        
        // Add this line to enable user interaction
        isUserInteractionEnabled = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(titleLabel)
        setupConstraints()
        setupTouches()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8)
        ])
    }
    
    private func setupTouches() {
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchDragExit), for: .touchUpOutside)
    }
    
    @objc func touchDown() {
        HapticsHelper.mediumHaptic()
        standardControlAnimation(.touchDown)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.standardControlAnimation(.touchUp)
        }
    }

    @objc func touchDragExit() {
        HapticsHelper.thwompHaptic()
        standardControlAnimation(.touchCancel)
    }

    func touchUpAction() {
    }

    @objc func touchUp() {
        HapticsHelper.lightHaptic()
        standardControlAnimation(.touchUp)
    }
    
    private func standardControlAnimation(_ tappedState: ControlTappedState) {
        switch tappedState {
        case .touchDown:
            UIView.animate(withDuration: 0.075) {
                self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
        case .touchCancel, .touchUp:
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
            }
        }
    }

    private enum ControlTappedState {
        case touchDown, touchCancel, touchUp
    }
}

extension EventView {
    var endTime: Date {
        return startTime.addingTimeInterval(duration)
    }
}

extension UIView {
    func smallButtonDownAnimation() {
        UIView.animate(withDuration: 0.07,
                       delay: 0,
                       options: .curveLinear,
                       animations: { [weak self] in
            self?.transform = CGAffineTransform.init(scaleX: 0.925, y: 0.925)
        })
    }
    
    func smallButtonUpAnimation() {
        UIView.animate(withDuration: 0.07,
                       delay: 0,
                       options: .curveLinear,
                       animations: { [weak self] in
            self?.transform = CGAffineTransform.init(scaleX: 1, y: 1)
        })
    }
    
    func smallButtonAnimation() {
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.07,
                       delay: 0,
                       options: .curveLinear,
                       animations: { [weak self] in
            self?.transform = CGAffineTransform.init(scaleX: 0.925, y: 0.925)
        }) {  (done) in
            UIView.animate(withDuration: 0.07,
                           delay: 0,
                           options: .curveLinear,
                           animations: { [weak self] in
                self?.transform = CGAffineTransform.init(scaleX: 1, y: 1)
            }) { [weak self] (_) in
                self?.isUserInteractionEnabled = true
            }
        }
    }
}
