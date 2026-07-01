//
//  FolderCollectionViewCell.swift
//  nest-note
//
//  Created by Colton Swapp on 7/26/25.
//

import UIKit

enum FolderShape {
    static let designWidth: CGFloat = 170
    static let designHeight: CGFloat = 151
    static let cornerRadius: CGFloat = 18

    static func scaledCornerRadius(for height: CGFloat) -> CGFloat {
        cornerRadius * (height / designHeight)
    }

    static func backFolderPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let width = rect.width
        let height = rect.height

        let scaleX = width / designWidth
        let scaleY = height / designHeight

        path.move(to: CGPoint(x: 0, y: 18.4316 * scaleY))

        path.addCurve(to: CGPoint(x: 18 * scaleX, y: 0.431641 * scaleY),
                      control1: CGPoint(x: 0, y: 8.49052 * scaleY),
                      control2: CGPoint(x: 8.05888 * scaleX, y: 0.431641 * scaleY))

        path.addLine(to: CGPoint(x: 50.8316 * scaleX, y: 0.431641 * scaleY))

        path.addCurve(to: CGPoint(x: 59.0591 * scaleX, y: 2.42202 * scaleY),
                      control1: CGPoint(x: 53.6933 * scaleX, y: 0.431641 * scaleY),
                      control2: CGPoint(x: 56.5138 * scaleX, y: 1.11397 * scaleY))

        path.addLine(to: CGPoint(x: 79.3719 * scaleX, y: 12.861 * scaleY))

        path.addCurve(to: CGPoint(x: 87.5995 * scaleX, y: 14.8514 * scaleY),
                      control1: CGPoint(x: 81.9172 * scaleX, y: 14.1691 * scaleY),
                      control2: CGPoint(x: 84.7377 * scaleX, y: 14.8514 * scaleY))

        path.addLine(to: CGPoint(x: 152 * scaleX, y: 14.8514 * scaleY))

        path.addCurve(to: CGPoint(x: 170 * scaleX, y: 32.8514 * scaleY),
                      control1: CGPoint(x: 161.941 * scaleX, y: 14.8514 * scaleY),
                      control2: CGPoint(x: 170 * scaleX, y: 22.9103 * scaleY))

        // Bottom corners use y=151 in design space so the path reaches the full cell height.
        path.addLine(to: CGPoint(x: 170 * scaleX, y: 133 * scaleY))

        path.addCurve(to: CGPoint(x: 152 * scaleX, y: height),
                      control1: CGPoint(x: 170 * scaleX, y: 142.941 * scaleY),
                      control2: CGPoint(x: 161.941 * scaleX, y: height))

        path.addLine(to: CGPoint(x: 18 * scaleX, y: height))

        path.addCurve(to: CGPoint(x: 0, y: 133 * scaleY),
                      control1: CGPoint(x: 8.05887 * scaleX, y: height),
                      control2: CGPoint(x: 0, y: 142.941 * scaleY))

        path.closeSubpath()

        return path
    }
}

class CustomBackFolderView: UIView {

    var fillColor: UIColor

    init(color: UIColor) {
        self.fillColor = color
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.setFillColor(fillColor.cgColor)
        context.addPath(FolderShape.backFolderPath(in: rect))
        context.fillPath()
    }
}

class FolderCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "FolderCollectionViewCell"
    
    private let backFolderView: CustomBackFolderView
    private let frontFolderView = UIView()
    private let silhouetteView: CustomBackFolderView
    internal let iconImageView = UIImageView()
    internal let titleLabel = UILabel()
    private let chevronImageView = UIImageView()
    internal let subtitleLabel = UILabel()
    
    // paper stacks
    private let paper1View = UIView()
    private let paper2View = UIView()
    private let paper3View = UIView()
    
//    private let frontColor: UIColor = UIColor(red: 229/255, green: 229/255, blue: 229/255, alpha: 1.0)
    private let frontColor: UIColor = NNColors.folderFront
//    private let backColor: UIColor = UIColor(red: 190/255, green: 190/255, blue: 190/255, alpha: 1.0)
    private let backColor: UIColor = NNColors.folderBack
    
    override init(frame: CGRect) {
        backFolderView = CustomBackFolderView(color: backColor)
        silhouetteView = CustomBackFolderView(color: UIColor.black.withAlphaComponent(0.2))
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(backFolderView)
        contentView.addSubview(frontFolderView)
        contentView.addSubview(silhouetteView)
        
        // Back folder with custom drawing
        backFolderView.backgroundColor = UIColor.clear
        backFolderView.translatesAutoresizingMaskIntoConstraints = false
        
        // Front folder - corner radius scaled in layoutSubviews to match back flap
        frontFolderView.backgroundColor = frontColor
        frontFolderView.translatesAutoresizingMaskIntoConstraints = false
        
        // Silhouette view - initially hidden
        silhouetteView.backgroundColor = UIColor.clear
        silhouetteView.translatesAutoresizingMaskIntoConstraints = false
        silhouetteView.alpha = 0.0
        
        // Create a vertical stack view for the content
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 4
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        frontFolderView.addSubview(contentStack)
        
        // Icon
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = NNColors.folderForeground
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = .h4
        titleLabel.textColor = NNColors.folderForeground
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        
        // Subtitle
        subtitleLabel.font = .bodyS
        subtitleLabel.textColor = NNColors.folderForeground.withAlphaComponent(0.75)
        
        // Add views to stack
        contentStack.addArrangedSubview(iconImageView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            // Back folder - full size
            backFolderView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backFolderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backFolderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backFolderView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Front folder - offset from top to show back panel tab
            frontFolderView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            frontFolderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            frontFolderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            frontFolderView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Silhouette view - covers the entire cell
            silhouetteView.topAnchor.constraint(equalTo: contentView.topAnchor),
            silhouetteView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            silhouetteView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            silhouetteView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Content stack - positioned in bottom leading corner with trailing constraint
            contentStack.leadingAnchor.constraint(equalTo: frontFolderView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: frontFolderView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: frontFolderView.bottomAnchor, constant: -16),
            
            // Icon size
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        frontFolderView.layer.cornerRadius = FolderShape.scaledCornerRadius(for: contentView.bounds.height)
    }

    func configure(with data: FolderData) {
        iconImageView.image = data.image
        titleLabel.text = data.title
        
        // Show selection count if any entries are selected, otherwise show total item count
        if data.selectedCount > 0 {
            let entryText = data.selectedCount == 1 ? "selected" : "selected"
            subtitleLabel.text = "\(data.selectedCount) \(entryText)"
        } else {
            subtitleLabel.text = "\(data.itemCount) items"
        }
        
        addPaper(num: data.itemCount)
        
    }
    
    func addPaper(num: Int) {
        // Remove any existing paper views
        paper1View.removeFromSuperview()
        paper2View.removeFromSuperview()
        paper3View.removeFromSuperview()
        
        // Determine how many papers to show (max 3)
        let paperCount = min(num, 3)
        
        // Add papers based on count
        if paperCount >= 1 {
            contentView.insertSubview(paper1View, belowSubview: frontFolderView)
            setupPaperView(paper1View, rotation: CGFloat.random(in: -3...3) * 2, offsetX: -12, offsetY: -24)
        }
        
        if paperCount >= 2 {
            contentView.insertSubview(paper2View, aboveSubview: paper1View)
            setupPaperView(paper2View, rotation: CGFloat.random(in: -3...3) * 2, offsetX: 0, offsetY: -21)
        }
        
        if paperCount >= 3 {
            contentView.insertSubview(paper3View, aboveSubview: paper2View)
            setupPaperView(paper3View, rotation: CGFloat.random(in: -3...3) * 2, offsetX: 12, offsetY: -18)
        }
    }
    
    private func setupPaperView(_ paperView: UIView, rotation: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        paperView.backgroundColor = NNColors.paperWhite
        paperView.layer.cornerRadius = 4
        paperView.layer.shadowColor = UIColor.black.cgColor
        paperView.layer.shadowOffset = CGSize(width: 0, height: 2)
        paperView.layer.shadowOpacity = 0.3
        paperView.layer.shadowRadius = 3
        paperView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Position papers behind the front folder but above the back folder  
            paperView.topAnchor.constraint(equalTo: frontFolderView.topAnchor, constant: 10 + offsetY),
            paperView.leadingAnchor.constraint(equalTo: frontFolderView.leadingAnchor, constant: 16),
            paperView.trailingAnchor.constraint(equalTo: frontFolderView.trailingAnchor, constant: -16),
            paperView.bottomAnchor.constraint(equalTo: frontFolderView.bottomAnchor, constant: -15)
        ])
        
        // Apply rotation after constraints are set
        paperView.transform = CGAffineTransform(rotationAngle: rotation * .pi / 180)
    }
    
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                showSilhouette()
            } else {
                hideSilhouette()
            }
        }
    }
    
    private func showSilhouette() {
        UIView.animate(withDuration: 0.15) {
            self.silhouetteView.alpha = 1.0
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    private func hideSilhouette() {
        UIView.animate(withDuration: 0.15) {
            self.silhouetteView.alpha = 0.0
            self.transform = CGAffineTransform.identity
        }
    }
}
