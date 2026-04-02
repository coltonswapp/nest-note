//
//  NestItemDetailRouter.swift
//  nest-note
//

import UIKit

/// Single place to open detail UI for any nest item type (reduces scattered `switch item.type` in VCs).
enum NestItemDetailRouter {

    static func presentDetail(
        for item: any BaseItem,
        from viewController: UIViewController,
        entryRepository: EntryRepository,
        category: String,
        sourceFrame: CGRect?,
        placeListDelegate: PlaceListViewControllerDelegate?,
        entryDelegate: EntryDetailViewControllerDelegate?,
        routineDelegate: RoutineDetailViewControllerDelegate?,
        contactDelegate: ContactDetailViewControllerDelegate? = nil
    ) {
        let isReadOnly = !(entryRepository is NestService)
        let frame = sourceFrame ?? .zero

        switch item.type {
        case .entry:
            guard let entry = item as? BaseEntry else { return }
            let vc = EntryDetailViewController(
                category: category,
                entry: entry,
                sourceFrame: frame,
                isReadOnly: isReadOnly
            )
            vc.entryDelegate = entryDelegate
            viewController.present(vc, animated: true)

        case .place:
            guard let place = item as? PlaceItem else { return }
            let vc = PlaceDetailViewController(
                place: place,
                thumbnail: nil,
                isReadOnly: isReadOnly,
                sourceFrame: frame
            )
            vc.placeListDelegate = placeListDelegate
            viewController.present(vc, animated: true)

        case .routine:
            guard let routine = item as? RoutineItem else { return }
            let vc = RoutineDetailViewController(
                category: category,
                routine: routine,
                sourceFrame: frame,
                isReadOnly: isReadOnly
            )
            vc.routineDelegate = routineDelegate
            viewController.present(vc, animated: true)

        case .contact:
            guard let contact = item as? ContactItem else { return }
            let vc = ContactDetailViewController(
                category: category,
                contact: contact,
                sourceFrame: frame,
                isReadOnly: isReadOnly
            )
            vc.contactDelegate = contactDelegate
            viewController.present(vc, animated: true)

        case .pilotCard:
            guard let pilot = item as? PilotCardItem else { return }
            let alert = UIAlertController(
                title: pilot.title,
                message: pilot.body,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            if !isReadOnly, entryRepository is NestService {
                alert.addAction(UIAlertAction(title: "Edit", style: .default) { _ in
                    let edit = UIAlertController(title: "Edit pilot card", message: nil, preferredStyle: .alert)
                    edit.addTextField { $0.text = pilot.title }
                    edit.addTextField { $0.text = pilot.body }
                    edit.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    edit.addAction(UIAlertAction(title: "Save", style: .default) { _ in
                        guard let t = edit.textFields?[0].text,
                              let b = edit.textFields?[1].text else { return }
                        Task {
                            var updated = pilot
                            updated.title = t
                            updated.body = b
                            updated.updatedAt = Date()
                            try? await NestService.shared.updateItem(updated)
                        }
                    })
                    viewController.present(edit, animated: true)
                })
            }
            viewController.present(alert, animated: true)

        case .unknownDocument:
            guard let unknown = item as? UnknownItem else { return }
            let alert = UIAlertController(
                title: unknown.title,
                message: "This item uses a newer type (\(unknown.originalTypeString)) that this version of Nest Note doesn’t fully support yet.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            viewController.present(alert, animated: true)
        }
    }
}
