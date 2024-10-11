//
//  UpcomingEventsHeaderView.swift
//  nest-note
//
//  Created by Colton Swapp on 10/5/24.
//

import UIKit

class UpcomingEventsHeaderView: UICollectionReusableView {
    let titleLabel = UILabel()
    let fullScheduleButton = UIButton(type: .system)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        titleLabel.font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
        titleLabel.text = "Upcoming Events"
        titleLabel.textColor = .secondaryLabel
        
        fullScheduleButton.setTitle("Full Schedule", for: .normal)
        fullScheduleButton.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
        fullScheduleButton.setTitleColor(NNColors.primary, for: .normal)
        
        // Underline the button text
        let attributedString = NSMutableAttributedString(string: "Full Schedule")
        attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: attributedString.length))
        fullScheduleButton.setAttributedTitle(attributedString, for: .normal)
        
        addSubview(titleLabel)
        addSubview(fullScheduleButton)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        fullScheduleButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            fullScheduleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
            fullScheduleButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
