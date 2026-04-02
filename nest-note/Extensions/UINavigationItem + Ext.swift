//
//  UINavigationItem + Ext.swift
//  nest-note
//
//  Created by Colton Swapp on 10/5/24.
//

import UIKit

extension UINavigationItem {

    var weeTitle: String? {
        get {
            return value(forKey: "weeTitle") as? String
        } set {
            perform(Selector(("_setWeeTitle:")), with: newValue)
        }
    }

    /// Home large title: main line is always “NestNote”; eyebrow reflects `appMode`.
    func configureHomeLargeTitleHeader(appMode: AppMode) {
        title = "NestNote"
        weeTitle = appMode.homeScreenWeeTitle
        largeTitleDisplayMode = .always
    }
}

extension UIViewController {

    /// Applies the shared home navigation bar style. Call from `setup()` and once from `viewDidLoad` via `DispatchQueue.main.async` so `navigationController` is non-nil and the large-title stack shows both lines reliably.
    func applyHomeScreenNavigationAppearance(appMode: AppMode) {
        navigationItem.configureHomeLargeTitleHeader(appMode: appMode)
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.tintColor = NNColors.primary
    }
}
