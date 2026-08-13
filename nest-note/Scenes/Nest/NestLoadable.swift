import UIKit

protocol NestLoadable: CollectionViewLoadable {
    var nestItemRepository: NestItemRepository { get }
    var hasLoadedInitialData: Bool { get set }
    func handleLoadedNotes(_ groupedNotes: [String: [NoteItem]])
}

extension NestLoadable {
    func loadNotes(showLoadingIndicator: Bool = true) async {
        do {
            if showLoadingIndicator {
                await MainActor.run {
                    loadingIndicator.startAnimating()
                }
            }
            
            let groupedNotes = try await NestService.shared.fetchNotes()
            
            await MainActor.run {
                handleLoadedNotes(groupedNotes)
                hasLoadedInitialData = true
                loadingIndicator.stopAnimating()
            }
            
        } catch {
            await MainActor.run {
                loadingIndicator.stopAnimating()
                Logger.log(level: .error, category: .nestService, message: "Error loading notes: \(error.localizedDescription)")
            }
        }
    }
    
    func refreshNotes() async {
        do {
            let groupedNotes = try await NestService.shared.refreshNotes()
            await MainActor.run {
                handleLoadedNotes(groupedNotes)
            }
        } catch {
            Logger.log(level: .error, category: .nestService, message: "Error refreshing notes: \(error.localizedDescription)")
        }
    }
}


//import RevenueCatUI
extension NNViewController {
    
}
