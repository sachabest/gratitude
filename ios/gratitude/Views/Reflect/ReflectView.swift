import SwiftUI
import SwiftData
import MessageUI

struct ReflectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var memory: HighlightedMemory?
    @State private var shownDates: Set<Date> = []

    @State private var isSendingSmile = false
    @State private var messagePresenter: MessageComposePresenter?
    @State private var showMessagingUnavailableAlert = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header

                if let memory {
                    ScrollView {
                        VStack(spacing: 20) {
                            HighlightedMemoryView(memory: memory)

                            if let personName = memory.evening?.taggedPersonName {
                                sendSmileButton(personName: personName)
                            }
                        }
                        .padding(20)
                    }
                } else {
                    Spacer()
                    emptyState
                    Spacer()
                }
            }

            if isSendingSmile {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView("Preparing your smile…")
                    .padding(24)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .background(Color(.systemBackground))
        .task { loadMemory() }
        .alert("Messages isn't available", isPresented: $showMessagingUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device can't send text messages, so your smile wasn't sent.")
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close")

            Spacer()

            if memory != nil {
                Button {
                    Haptic.selection()
                    loadMemory()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Show me another")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf")
                .font(.largeTitle)
                .foregroundStyle(Theme.reflect)
            Text("Nothing to look back on yet")
                .font(.headline)
            Text("Come back after a few check-ins — this will fill up with days to revisit.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func sendSmileButton(personName: String) -> some View {
        Button {
            sendAnotherSmile(to: personName)
        } label: {
            Label("Send a smile to \(personName)", systemImage: "face.smiling")
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.smile)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isSendingSmile)
    }

    private func loadMemory() {
        guard let picked = MemoryEngine.highlightedMemory(in: modelContext, excluding: shownDates) else {
            memory = nil
            return
        }
        shownDates.insert(picked.date)
        memory = picked
    }

    /// The "one-click" resend: no composer, no contact picker — reuse the
    /// person already tagged for this memory and a message generated from
    /// that evening's own "positive thing" answer, straight to a ready-to-send
    /// Messages sheet.
    private func sendAnotherSmile(to personName: String) {
        guard let evening = memory?.evening, let phoneNumber = evening.taggedPersonPhoneNumber else { return }

        Haptic.selection()
        isSendingSmile = true
        let message = defaultResendMessage(for: evening)
        let senderName = UserProfile.displayName

        Task {
            let prepared = await SmileService.prepareMessage(message: message, senderName: senderName, recipientPhoneNumber: phoneNumber)

            isSendingSmile = false

            let presenter = MessageComposePresenter { result in
                messagePresenter = nil
                guard result == .sent else { return }
                SmileService.recordSent(personName: personName, message: message, cloudRecordName: prepared.cloudRecordName, context: modelContext)
                Haptic.success()
            }
            if presenter.present(recipients: [phoneNumber], body: prepared.body) {
                messagePresenter = presenter
            } else {
                showMessagingUnavailableAlert = true
            }
        }
    }

    private func defaultResendMessage(for evening: CheckIn) -> String {
        if let positive = evening.firstAnswerText(matching: "evening.positive") {
            return "Thinking back to \(positive.lowercased()) — thank you again."
        }
        return "Thinking of you today — thank you."
    }
}

#Preview {
    ReflectView()
        .modelContainer(for: [CheckIn.self, QuestionResponse.self, Smile.self], inMemory: true)
}
