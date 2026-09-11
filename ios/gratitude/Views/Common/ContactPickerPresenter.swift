import ContactsUI

/// Presents `CNContactPickerViewController` via `ModalPresenter` (see that
/// file for why not `.sheet`). Like `PhotosPicker`, this needs no
/// `NSContactsUsageDescription` or system permission — it runs out-of-process
/// and only ever hands the app the one contact you tap. `CNContactPickerViewController`
/// dismisses itself once a contact is picked or the picker is cancelled — we
/// don't dismiss it ourselves, just release this presenter.
final class ContactPickerPresenter: NSObject, CNContactPickerDelegate {
    private let onSelect: (CNContact) -> Void
    private let onCancel: () -> Void

    init(onSelect: @escaping (CNContact) -> Void, onCancel: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    func present() {
        let picker = CNContactPickerViewController()
        picker.delegate = self
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        ModalPresenter.present(picker)
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        onSelect(contact)
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        onCancel()
    }
}

extension CNContact {
    var displayName: String {
        let name = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Someone" : name
    }

    var primaryPhoneNumber: String? {
        phoneNumbers.first?.value.stringValue
    }
}
