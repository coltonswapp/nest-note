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
        nestItemRepository: NestItemRepository,
        category: String,
        sourceFrame: CGRect?,
        placeListDelegate: PlaceListViewControllerDelegate?,
        noteDelegate: NoteDetailViewControllerDelegate?,
        routineDelegate: RoutineDetailViewControllerDelegate?,
        contactDelegate: ContactDetailViewControllerDelegate? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        let isReadOnly = !(nestItemRepository is NestService)
        let frame = sourceFrame ?? .zero

        switch item.type {
        case .entry:
            guard let entry = item as? NoteItem else { return }
            let vc = NoteDetailViewController(
                category: category,
                entry: entry,
                sourceFrame: frame,
                isReadOnly: isReadOnly
            )
            vc.noteDelegate = noteDelegate
            vc.onSheetDidDismiss = onDismiss
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
            vc.onSheetDidDismiss = onDismiss
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
            vc.onSheetDidDismiss = onDismiss
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
            vc.onSheetDidDismiss = onDismiss
            viewController.present(vc, animated: true)

        case .unknownDocument:
            guard let unknown = item as? UnknownItem else { return }
            let alert = UIAlertController(
                title: unknown.title,
                message: "This item uses a newer type (\(unknown.originalTypeString)) that this version of Nest Note doesn’t fully support yet.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                onDismiss?()
            })
            viewController.present(alert, animated: true)
        }
    }
}
