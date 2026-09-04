import SwiftUI

struct QuestionStepView: View {
    let prompt: String
    let answerKind: AnswerKind
    let tint: Color
    @Binding var draft: AnswerDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(prompt)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            switch answerKind {
            case .choiceOnly:
                ChipSelectorView(options: answerKind.options, tint: tint, selection: $draft.selectedOption)

            case .choiceOrText:
                if draft.isTextMode {
                    textEditor
                    Button("Choose from options instead") {
                        draft.isTextMode = false
                        draft.freeText = ""
                    }
                    .font(.subheadline)
                } else {
                    ChipSelectorView(options: answerKind.options, tint: tint, selection: $draft.selectedOption)
                    Button("Type your own instead") {
                        draft.isTextMode = true
                        draft.selectedOption = nil
                    }
                    .font(.subheadline)
                }

            case .textOnly:
                textEditor

            case .scale:
                MoodScaleView(rating: $draft.scaleRating)
            }

            Spacer()
        }
    }

    private var textEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $draft.freeText)
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            if draft.freeText.isEmpty {
                Text("Type, or tap the microphone on your keyboard to dictate.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
        }
    }
}
