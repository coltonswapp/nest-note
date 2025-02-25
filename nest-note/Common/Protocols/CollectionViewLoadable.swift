import UIKit

protocol CollectionViewLoadable: UIViewController {
    var loadingIndicator: UIActivityIndicatorView! { get set }
    var collectionView: UICollectionView! { get }
    var refreshControl: UIRefreshControl! { get set }
    
    func handleLoadedData()
    func loadData(showLoadingIndicator: Bool) async
}

extension CollectionViewLoadable {
    func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    func setupRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    func loadData(showLoadingIndicator: Bool = true) async {
        do {
            if showLoadingIndicator {
                await MainActor.run {
                    loadingIndicator.startAnimating()
                }
            }
            
            await MainActor.run {
                handleLoadedData()
                loadingIndicator.stopAnimating()
            }
            
        } catch {
            await MainActor.run {
                loadingIndicator.stopAnimating()
                Logger.log(level: .error, category: .general, message: "Error loading data: \(error.localizedDescription)")
            }
        }
    }
    
    func refreshData() async {
        await loadData(showLoadingIndicator: false)
    }
}

extension UIViewController {
    @objc func handleRefresh(_ sender: UIRefreshControl) {
        guard let loadableVC = self as? CollectionViewLoadable else { return }
        
        Task {
            await loadableVC.refreshData()
            sender.endRefreshing()
        }
    }
} 