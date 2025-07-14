
# Reworking Invite flow

## Objectives
- Simplify the sitter invite flow
- Make the invite code more accessible

## Steps
- InviteSitterRegistration needs reworking
    - New custom `InviteSitterCell`
    - Ignore the `inviteStatus`
    - No `disclosureIndicator` on cell
    - Display Sitter name on left
    - Display Invite code on right
        - 000-000 in a .secondaryLabel color if invite doesn't yet exist
    - If no sitter selected, display "Invite a Sitter"
    - Footer for this cell displays "Tap for invite details"
- InviteDetailViewController needs reworking
    - Add UICollectionView with the following
        - SitterCell to display the selected sitter for the session
            - Tapping on SitterCell brings up a modal of `SitterListViewController` allowing user to select a sitter
            - Use NNSectionHeaderView titled "SITTER" for cell
        - CodeCell which displays the invite code
            - 000-000 in a .secondaryLabel color if invite doesn't yet exist
            - Use NNSectionHeaderView titled "INVITE CODE" for cell
            - Footer for this cell displays "Invite code becomes available once the session has been created."
        - CodeActionCell which has the following buttons stacked horizontally (NNCircularIconButtonWithLabel)
            - Copy
            - Message
            - Share
            - Delete
        - Use existing logic from `InviteDetailViewController` for the action buttons (including delete modal)
        
    - Add an `NNLoadingButton` utilizing the `pinToBottom` method
        - button title dependant on invite existing or not
            - "Create Invite"
            - "Update Invite"
