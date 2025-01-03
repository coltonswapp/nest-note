import UIKit

class NNSearchBarView: UIView {
    
    let searchBar: UISearchBar = {
        let bar = UISearchBar()
        bar.placeholder = "Search for a sitter"
        bar.showsCancelButton = false
        bar.keyboardType = .emailAddress
        bar.autocorrectionType = .no
        bar.autocapitalizationType = .none
        return bar
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        
        let textFieldInsideSearchBar = searchBar.value(forKey: "searchField") as? UITextField
        let imageV = textFieldInsideSearchBar?.leftView as! UIImageView
        imageV.image = imageV.image?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
        imageV.tintColor = NNColors.primary
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        let padding: CGFloat = 20.0
        addSubview(searchBar)
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            searchBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            searchBar.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
} 
