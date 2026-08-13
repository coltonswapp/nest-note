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
        // Redraw the custom path whenever bounds change (critical when animating size).
        contentMode = .redraw
        backgroundColor = .clear
        isOpaque = false
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
    private var paperConstraints: [NSLayoutConstraint] = []
    /// Avoid rebuilding identical paper stacks on reconfigure (keeps hero handoff stable).
    private var configuredPaperKey: String?
    
//    private let frontColor: UIColor = UIColor(red: 229/255, green: 229/255, blue: 229/255, alpha: 1.0)
    private let frontColor: UIColor = NNColors.folderFront
//    private let backColor: UIColor = UIColor(red: 190/255, green: 190/255, blue: 190/255, alpha: 1.0)
    private let backColor: UIColor = NNColors.folderBack

    private struct PaperStyle {
        let rotation: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat
    }
    
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
        
        // Seed from folder identity so each folder gets a unique, stable paper stack.
        addPaper(num: data.itemCount, seed: data.fullPath.isEmpty ? data.title : data.fullPath)
    }
    
    func addPaper(num: Int, seed: String = "") {
        let paperCount = min(num, 3)
        let paperKey = "\(seed)#\(paperCount)"
        if configuredPaperKey == paperKey, paperCount == 0 || paper1View.superview != nil {
            return
        }
        configuredPaperKey = paperKey

        NSLayoutConstraint.deactivate(paperConstraints)
        paperConstraints.removeAll()
        paper1View.removeFromSuperview()
        paper2View.removeFromSuperview()
        paper3View.removeFromSuperview()

        guard paperCount > 0 else { return }

        let styles = Self.paperStyles(seed: seed, count: paperCount)
        let papers = [paper1View, paper2View, paper3View]

        for index in 0..<paperCount {
            let paper = papers[index]
            if index == 0 {
                contentView.insertSubview(paper, belowSubview: frontFolderView)
            } else {
                contentView.insertSubview(paper, aboveSubview: papers[index - 1])
            }
            setupPaperView(paper, style: styles[index])
        }
    }

    /// Stable per-folder paper layouts — unique across folders, unchanged on reconfigure.
    private static func paperStyles(seed: String, count: Int) -> [PaperStyle] {
        var hash: UInt64 = 1_469_598_103_934_663_603 // FNV offset basis
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        let baseX: [CGFloat] = [-12, 0, 12]
        let baseY: [CGFloat] = [-24, -21, -18]

        return (0..<count).map { index in
            var h = hash &+ UInt64(index &+ 1) &* 0x9E37_79B9_7F4A_7C15
            h ^= h >> 30
            h &*= 0xBF58_476D_1CE4_E5B9
            h ^= h >> 27

            // Distinct tilt per paper, folder-seeded (±6°).
            let rotation = CGFloat(Int(h % 13)) - 6
            // Keep the classic peek spread, with light per-folder jitter.
            let offsetX = baseX[index] + CGFloat(Int((h >> 8) % 7)) - 3
            let offsetY = baseY[index] + CGFloat(Int((h >> 16) % 5)) - 2
            return PaperStyle(rotation: rotation, offsetX: offsetX, offsetY: offsetY)
        }
    }
    
    private func setupPaperView(_ paperView: UIView, style: PaperStyle) {
        paperView.backgroundColor = NNColors.paperWhite
        paperView.layer.cornerRadius = 4
        paperView.layer.borderWidth = 0
        paperView.layer.borderColor = nil
        paperView.layer.shadowColor = UIColor.black.cgColor
        paperView.layer.shadowOffset = CGSize(width: 0, height: 2)
        paperView.layer.shadowOpacity = 0.3
        paperView.layer.shadowRadius = 3
        paperView.translatesAutoresizingMaskIntoConstraints = false
        
        let constraints = [
            // Position papers behind the front folder but above the back folder  
            paperView.topAnchor.constraint(equalTo: frontFolderView.topAnchor, constant: 10 + style.offsetY),
            paperView.leadingAnchor.constraint(equalTo: frontFolderView.leadingAnchor, constant: 16),
            paperView.trailingAnchor.constraint(equalTo: frontFolderView.trailingAnchor, constant: -16),
            paperView.bottomAnchor.constraint(equalTo: frontFolderView.bottomAnchor, constant: -15)
        ]
        NSLayoutConstraint.activate(constraints)
        paperConstraints.append(contentsOf: constraints)
        
        paperView.transform = CGAffineTransform(rotationAngle: style.rotation * .pi / 180)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        resetPressAppearance()
        configuredPaperKey = nil
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

    /// Clears pressed/highlight chrome immediately (no animation).
    func resetPressAppearance() {
        layer.removeAllAnimations()
        silhouetteView.layer.removeAllAnimations()
        silhouetteView.alpha = 0
        transform = .identity
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
