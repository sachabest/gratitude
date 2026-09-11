import SwiftUI
import SwiftData
import MessageUI

/// Send a smile anytime — not just tagged during an evening check-in.
/// Rate-limited per calendar week (`AdHocSmileLimiter`) so it stays an
/// occasional, deliberate gesture rather than something to spam; the weekly
/// limit itself is developer-configurable without a build via
/// `AppConfigService`. Reuses `SmileComposerView` for the contact/message
/// picking and the same `SmileService.composeSentSmile` +
/// `MessageComposePresenter` send path as the check-in flow and Reflect's
/// one-click resend.
struct AdHocSmileComposerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var contactName: String?
    @State private var phoneNumber: String?
    @State private var message = ""
    @State private var remainingThisWeek = AdHocSmileLimiter.remainingThisWeek
    @State private var isSending = false
    @State private var messagePresenter: MessageComposePresenter?
    @State private var showMessagingUnavailableAlert = false

    private var canSend: Bool {
        contactName != nil && phoneNumber != nil
            && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && remainingThisWeek > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(remainingLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        SmileComposerView(
                            contactName: $contactName,
                            phoneNumber: $phoneNumber,
                            message: $message,
                            defaultMessage: "Thinking of you today."
                        )
                        .disabled(remainingThisWeek == 0)
                    }
                    .padding(20)
                }

                if isSending {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView("Preparing your smile…")
                        .padding(24)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .navigationTitle("Send a Smile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { send() }
                        .disabled(!canSend || isSending)
                }
            }
            .task {
                await AppConfigService.refresh()
                remainingThisWeek = AdHocSmileLimiter.remainingThisWeek
            }
            .alert("Messages isn't available", isPresented: $showMessagingUnavailableAlert) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("This device can't send text messages, so your smile wasn't sent.")
            }
        }
    }

    private var remainingLabel: String {
        remainingThisWeek > 0
            ? "\(remainingThisWeek) of \(AdHocSmileLimiter.cachedWeeklyLimit) left this week"
            : "You've used this week's smiles — more free up next week."
    }

    private func send() {
        guard let contactName, let phoneNumber else { return }
        Haptic.selection()
        isSending = true
        let senderName = UserProfile.displayName
        let finalMessage = message

        Task {
            let prepared = await SmileService.prepareMessage(message: finalMessage, senderName: senderName, recipientPhoneNumber: phoneNumber)
            isSending = false

            let presenter = MessageComposePresenter { result in
                messagePresenter = nil
                guard result == .sent else { return }
                SmileService.recordSent(personName: contactName, message: finalMessage, cloudRecordName: prepared.cloudRecordName, context: modelContext)
                AdHocSmileLimiter.recordSend()
                remainingThisWeek = AdHocSmileLimiter.remainingThisWeek
                Haptic.success()
                dismiss()
            }
            if presenter.present(recipients: [phoneNumber], body: prepared.body) {
                messagePresenter = presenter
            } else {
                showMessagingUnavailableAlert = true
            }
        }
    }
}

#Preview {
    AdHocSmileComposerView()
        .modelContainer(for: [CheckIn.self, QuestionResponse.self, Smile.self], inMemory: true)
}
