import SwiftUI
import PhotosUI

struct CheckInSummaryView: View {
    let period: Period
    let budget: TimeBudget
    let questions: [Question]
    let drafts: [AnswerDraft]
    let morningCheckIn: CheckIn?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let photoPreview: UIImage?
    let isPhotoLoading: Bool
    let onRemovePhoto: () -> Void
    @Binding var smileContactName: String?
    @Binding var smilePhoneNumber: String?
    @Binding var smileMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.positive)
                Text("Nice work.")
                    .font(.title2.weight(.semibold))
                Text("Here's what you shared.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                    if case .scale = question.answerKind {
                        EmptyView()
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(question.resolvedPrompt(morningCheckIn: morningCheckIn))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(summaryText(for: drafts[index]))
                                .font(.body.weight(.medium))
                        }
                    }
                }
            }

            PhotoAttachmentView(
                selectedItem: $selectedPhotoItem,
                previewImage: photoPreview,
                isLoading: isPhotoLoading,
                onRemove: onRemovePhoto
            )

            if period == .evening {
                SmileComposerView(
                    contactName: $smileContactName,
                    phoneNumber: $smilePhoneNumber,
                    message: $smileMessage,
                    defaultMessage: defaultSmileMessage
                )
            }

            Spacer()
        }
    }

    private func summaryText(for draft: AnswerDraft) -> String {
        if draft.isTextMode, !draft.freeText.isEmpty { return draft.freeText }
        if let selectedOption = draft.selectedOption { return selectedOption }
        if !draft.freeText.isEmpty { return draft.freeText }
        return "—"
    }

    private var defaultSmileMessage: String {
        if let index = questions.firstIndex(where: { $0.id == "evening.positive" }) {
            let text = summaryText(for: drafts[index])
            if text != "—" {
                return "Thank you for \(text.lowercased()) today — it meant a lot."
            }
        }
        return "Thank you for being part of my day today."
    }
}
