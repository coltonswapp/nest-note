//
//  SessionInviteCardRepresentable.swift
//  nest-note
//

import SwiftUI
import UIKit

struct SessionInviteCardRepresentable: UIViewRepresentable {
    let session: SessionItem
    let invite: Invite
    let bannerTintColor: UIColor

    func makeUIView(context: Context) -> SessionInviteCardView {
        let card = SessionInviteCardView(displayStyle: .compact)
        card.configure(with: session, invite: invite, bannerTintColor: bannerTintColor)
        return card
    }

    func updateUIView(_ uiView: SessionInviteCardView, context: Context) {
        uiView.configure(with: session, invite: invite, bannerTintColor: bannerTintColor)
    }
}
