import SwiftUI

/// Evening-only: optionally tag tonight's reflection with a person and send
/// them a smile. Choosing a contact needs no permission prompt
/// (`ContactPickerPresenter` runs out-of-process, same privacy model as
/// `PhotosPicker`).
struct SmileComposerView: View {
    @Binding var contactName: String?
    @Binding var phoneNumber: String?
    @Binding var message: String
    let defaultMessage: String

    @State private var contactPickerPresenter: ContactPickerPresenter?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Send a smile (optional)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let contactName {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(contactName, systemImage: "person.fill")
                            .font(.body.weight(.medium))
                        Spacer()
                        Button {
                            self.contactName = nil
                            phoneNumber = nil
                            message = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Remove")
                    }

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $message)
                            .frame(minHeight: 90)
                            .scrollContentBackground(.hidden)
                    }
                }
                .padding(14)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Button {
                    choosePerson()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "face.smiling")
                            .font(.title3)
                        Text("Choose a person")
                            .font(.body.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func choosePerson() {
        let presenter = ContactPickerPresenter(
            onSelect: { contact in
                contactName = contact.displayName
                phoneNumber = contact.primaryPhoneNumber
                message = defaultMessage
                contactPickerPresenter = nil
            },
            onCancel: {
                contactPickerPresenter = nil
            }
        )
        contactPickerPresenter = presenter
        presenter.present()
    }
}
