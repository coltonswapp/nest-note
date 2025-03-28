import UIKit

protocol NestLoadable: CollectionViewLoadable {
    var hasLoadedInitialData: Bool { get set }
    
    func handleLoadedEntries(_ groupedEntries: [String: [BaseEntry]])
}

extension NestLoadable {
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
