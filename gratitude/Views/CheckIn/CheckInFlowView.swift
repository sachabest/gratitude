import SwiftUI
import SwiftData
import PhotosUI

struct CheckInFlowView: View {
    let period: Period

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var budget: TimeBudget?
    @State private var questions: [Question] = []
    @State private var drafts: [AnswerDraft] = []
    /// -1 = choosing a time budget, 0..<questions.count = a question, questions.count = summary.
    @State private var stepIndex = -1
    @State private var morningCheckIn: CheckIn?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoPreview: UIImage?
    @State private var isPhotoLoading = false

    @State private var smileContactName: String?
    @State private var smilePhoneNumber: String?
    @State private var smileMessage = ""
    @State private var isPreparingSmile = false
    @State private var messagePresenter: MessageComposePresenter?
    @State private var showMessagingUnavailableAlert = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header

                ScrollView {
                    content
                        .padding(24)
                }

                footer
            }

            if isPreparingSmile {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView("Preparing your smile…")
                    .padding(24)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .background(Color(.systemBackground))
        .task { loadMorningCheckIn() }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            isPhotoLoading = true
            Task {
                defer { isPhotoLoading = false }
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let compressed = PhotoAttachment.downsizedJPEGData(from: data) else { return }
                photoData = compressed
                photoPreview = UIImage(data: compressed)
            }
        }
        .alert("Messages isn't available", isPresented: $showMessagingUnavailableAlert) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Your smile was saved, but this device can't send text messages, so it wasn't sent yet.")
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

            if stepIndex >= 0, stepIndex < questions.count {
                HStack(spacing: 6) {
                    ForEach(0..<questions.count, id: \.self) { index in
                        Capsule()
                            .fill(index <= stepIndex ? period.tint : Color(.secondarySystemBackground))
                            .frame(width: index == stepIndex ? 20 : 8, height: 8)
                    }
                }
            }

            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var content: some View {
        if stepIndex == -1 {
            TimeBudgetStepView(period: period) { selected in
                start(with: selected)
            }
        } else if stepIndex < questions.count {
            let question = questions[stepIndex]
            QuestionStepView(
                prompt: question.resolvedPrompt(morningCheckIn: morningCheckIn),
                answerKind: question.answerKind,
                tint: period.tint,
                draft: $drafts[stepIndex]
            )
        } else {
            CheckInSummaryView(
                period: period,
                budget: budget ?? .standard,
                questions: questions,
                drafts: drafts,
                morningCheckIn: morningCheckIn,
                selectedPhotoItem: $selectedPhotoItem,
                photoPreview: photoPreview,
                isPhotoLoading: isPhotoLoading,
                onRemovePhoto: {
                    selectedPhotoItem = nil
                    photoData = nil
                    photoPreview = nil
                },
                smileContactName: $smileContactName,
                smilePhoneNumber: $smilePhoneNumber,
                smileMessage: $smileMessage
            )
        }
    }

    @ViewBuilder
    private var footer: some View {
        if stepIndex >= 0 {
            HStack(spacing: 12) {
                if stepIndex > 0 {
                    Button("Back") { stepIndex -= 1 }
                        .buttonStyle(.bordered)
                }

                Spacer()

                if stepIndex < questions.count {
                    Button(stepIndex == questions.count - 1 ? "Review" : "Next") {
                        Haptic.selection()
                        stepIndex += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(period.tint)
                    .disabled(!drafts[stepIndex].isAnswered)
                } else {
                    Button("Save") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(period.tint)
                }
            }
            .padding(20)
        }
    }

    private func start(with budget: TimeBudget) {
        self.budget = budget
        questions = QuestionBank.questions(for: period, budget: budget)
        drafts = questions.map { _ in AnswerDraft() }
        stepIndex = 0
    }

    private func loadMorningCheckIn() {
        guard period == .evening else { return }
        let today = Calendar.current.startOfDay(for: .now)
        guard let all = try? modelContext.fetch(FetchDescriptor<CheckIn>()) else { return }
        morningCheckIn = all.first { $0.period == .morning && $0.date == today }
    }

    private func save() {
        guard let budget else { return }
        let today = Calendar.current.startOfDay(for: .now)
        let checkIn = CheckIn(date: today, period: period, timeBudget: budget)

        var moodRating: Int?
        for (index, question) in questions.enumerated() {
            let draft = drafts[index]
            let resolvedText = question.resolvedPrompt(morningCheckIn: morningCheckIn)

            if case .scale = question.answerKind {
                let response = QuestionResponse(
                    questionId: question.id,
                    questionText: resolvedText,
                    order: index,
                    answerKindTag: question.answerKind.tag,
                    selectedOption: draft.scaleRating.map(String.init)
                )
                checkIn.responses.append(response)
                moodRating = draft.scaleRating
                continue
            }

            let response = QuestionResponse(
                questionId: question.id,
                questionText: resolvedText,
                order: index,
                answerKindTag: question.answerKind.tag,
                selectedOption: draft.isTextMode ? nil : draft.selectedOption,
                freeText: draft.isTextMode ? draft.freeText : (question.answerKind == .textOnly ? draft.freeText : nil)
            )
            checkIn.responses.append(response)
        }
        checkIn.moodRating = moodRating
        checkIn.photoData = photoData

        let hasComposedSmile = smileContactName != nil
            && smilePhoneNumber != nil
            && !smileMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasComposedSmile {
            checkIn.taggedPersonName = smileContactName
            checkIn.taggedPersonPhoneNumber = smilePhoneNumber
        }

        modelContext.insert(checkIn)
        try? modelContext.save()

        if CloudBackupSettings.isEnabled {
            Task { try? await CloudBackupService.shared.backupAll(context: modelContext) }
        }

        guard hasComposedSmile,
              let contactName = smileContactName,
              let phoneNumber = smilePhoneNumber
        else {
            Haptic.success()
            dismiss()
            return
        }

        sendSmile(to: contactName, phoneNumber: phoneNumber)
    }

    private func sendSmile(to contactName: String, phoneNumber: String) {
        isPreparingSmile = true
        let senderName = UserProfile.displayName
        let message = smileMessage

        Task {
            let body = await SmileService.composeSentSmile(
                personName: contactName,
                message: message,
                senderName: senderName,
                context: modelContext
            )

            isPreparingSmile = false

            let presenter = MessageComposePresenter { _ in
                messagePresenter = nil
                Haptic.success()
                dismiss()
            }
            if presenter.present(recipients: [phoneNumber], body: body) {
                messagePresenter = presenter
            } else {
                showMessagingUnavailableAlert = true
            }
        }
    }
}
