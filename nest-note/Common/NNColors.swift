//
//  NNColors.swift
//  nest-note
//
//  Created by Colton Swapp on 10/5/24.
//

import UIKit.UIColor

class NNColors {
    static let primary = UIColor(named: "NNPrimary")!
    static let primaryLighter = UIColor(named: "NNPrimaryLighter")!
    static let primaryAlt = UIColor(named: "NNPrimaryAltDark")!
    static let primaryOpaque = UIColor(named: "NNPrimaryOpaque")!
    static let offBlack = UIColor(red: 37/255, green: 37/255, blue: 37/255, alpha: 1.0)
    
    static let paletteGray = UIColor(named: "NNPaletteGray")!
    static let groupedBackground = UIColor(named: "NNGroupedBackground")!
    static let NNSystemBackground4 = UIColor(named: "NNSystemBackground4")!
    
    /// Light is the same as .systemGray6, dark is slightly lighter than .systemGray6
    static let NNSystemBackground6 = UIColor(named: "NNSystemBackground6")!
    
    // Faux Colors
    static let fauxPlaceholder = UIColor(named: "FauxPlaceholder")!
    static let fauxSystemGrouped = UIColor(named: "FauxSystemGrouped")!
    static let fauxSystemGroupedBackground = UIColor(named: "FauxSystemGroupedBackground")!
    
    struct NNColorPair: Hashable {
        let fill: UIColor
        let border: UIColor
    }
    
    struct EventColors {
        static let all: [NNColorPair] = [blue, lightBlue, green, yellow, red, orange, black, gray]
        
        static let coreFour: [NNColorPair] = [blue, green, red, orange]
        
        enum ColorType: String, Codable, CaseIterable {
            case blue
            case lightBlue
            case green
            case yellow
            case red
            case orange
            case black
            case gray
            
            var colorPair: NNColorPair {
                switch self {
                case .blue: return EventColors.blue
                case .lightBlue: return EventColors.lightBlue
                case .green: return EventColors.green
                case .yellow: return EventColors.yellow
                case .red: return EventColors.red
                case .orange: return EventColors.orange
                case .black: return EventColors.black
                case .gray: return EventColors.gray
                }
            }
        }
        
        static let blue = NNColorPair(
            fill: UIColor(
                red: 125/255,
                green: 187/255,
                blue: 255/255,
                alpha: 1.00
            ),
            border: UIColor(
                red: 8/255,
                green: 117/255,
                blue: 235/255,
                alpha: 1.0
            )
        )
        static let lightBlue = NNColorPair(
            fill: UIColor(
                red: 176/255,
                green: 239/255,
                blue: 255/255,
                alpha: 1.0
            ),
            border: UIColor(
                red: 46/255,
                green: 211/255,
                blue: 252/255,
                alpha: 1.0
            )
        )
        static let green = NNColorPair(
            fill: UIColor(
                red: 107/255,
                green: 244/255,
                blue: 166/255,
                alpha: 1.0
            ),
            border: UIColor(
                red: 37/255,
                green: 190/255,
                blue: 103/255,
                alpha: 1.0
            )
        )
        static let yellow = NNColorPair(
            fill: UIColor(
                red: 255/255,
                green: 253/255,
                blue: 154/255,
                alpha: 1.0
            ),
            border: UIColor(
                red: 244/255,
                green: 240/255,
                blue: 26/255,
                alpha: 1.0
            )
        )
        static let orange = NNColorPair(
            fill: UIColor(
                red: 255/255,
                green: 185/255,
                blue: 115/255,
                alpha: 1.0
            ),
            border: UIColor(
                red: 255/255,
                green: 145/255,
                blue: 55/255,
                alpha: 1.0
            )
        )
        static let red = NNColorPair(
            fill: UIColor(
                red: 255/255,
                green: 142/255,
                blue: 142/255,
                alpha: 1.0
            ),
            border: UIColor(
                red: 255/255,
                green: 6/255,
                blue: 6/255,
                alpha: 1.0
            )
        )
        static let black = NNColorPair(
            fill: UIColor(
                red: 77/255,
                green: 77/255,
                blue: 77/255,
                alpha: 1.0
            ),
            border: UIColor(
                red: 0/255,
                green: 0/255,
                blue: 0/255,
                alpha: 1.0
            )
        )
        static let gray = NNColorPair(
            fill: UIColor(
                red: 193/255,
                green: 193/255,
                blue: 193/255,
                alpha: 1.0
            ),
            border: UIColor(
                red: 123/255,
                green: 123/255,
                blue: 123/255,
                alpha: 1.0
            )
        )
    }
}
