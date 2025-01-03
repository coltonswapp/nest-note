import UIKit

protocol NestLoadable: UIViewController {
    var loadingIndicator: UIActivityIndicatorView! { get set }
    var hasLoadedInitialData: Bool { get set }
    var collectionView: UICollectionView! { get }
    var refreshControl: UIRefreshControl! { get set }
    
    func handleLoadedEntries(_ groupedEntries: [String: [BaseEntry]])
    func loadEntries(showLoadingIndicator: Bool) async
}

extension NestLoadable {
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
        refreshControl.addTarget(self, action: #selector(UIViewController.handleRefresh(_:)), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    func loadEntries(showLoadingIndicator: Bool = true) async {
        do {
            if showLoadingIndicator {
                await MainActor.run {
                    loadingIndicator.startAnimating()
                }
            }
            
            let groupedEntries = try await NestService.shared.fetchEntries()
            
            await MainActor.run {
                handleLoadedEntries(groupedEntries)
                hasLoadedInitialData = true
                loadingIndicator.stopAnimating()
            }
            
        } catch {
            await MainActor.run {
                loadingIndicator.stopAnimating()
                Logger.log(level: .error, category: .nestService, message: "Error loading entries: \(error.localizedDescription)")
            }
        }
    }
    
    func refreshEntries() async {
        do {
            let groupedEntries = try await NestService.shared.refreshEntries()
            await MainActor.run {
                handleLoadedEntries(groupedEntries)
            }
        } catch {
            Logger.log(level: .error, category: .nestService, message: "Error refreshing entries: \(error.localizedDescription)")
        }
    }
}

extension UIViewController {
    @objc func handleRefresh(_ sender: UIRefreshControl) {
        guard let loadableVC = self as? NestLoadable else { return }
        
        Task {
            await loadableVC.refreshEntries()
            sender.endRefreshing()
        }
    }
} 
