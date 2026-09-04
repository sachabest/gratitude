import SwiftUI
import SwiftData

struct SmilesView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Smile.date, order: .reverse) private var smiles: [Smile]

    @State private var selectedDirection: SmileDirection = .sent

    private var filtered: [Smile] {
        smiles.filter { $0.direction == selectedDirection }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Direction", selection: $selectedDirection) {
                    Text("Sent").tag(SmileDirection.sent)
                    Text("Received").tag(SmileDirection.received)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 12)

                if filtered.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    List {
                        ForEach(filtered) { smile in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(smile.personName)
                                        .font(.headline)
                                    Spacer()
                                    Text(smile.date, format: .dateTime.month(.abbreviated).day())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(smile.message)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Smiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "face.smiling")
                .font(.largeTitle)
                .foregroundStyle(Theme.smile)
            Text(selectedDirection == .sent ? "No smiles sent yet" : "No smiles received yet")
                .font(.headline)
            Text(
                selectedDirection == .sent
                    ? "Tag someone during an evening check-in to send one."
                    : "When someone sends you a smile and you have Gratitude installed, it'll show up here."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    SmilesView()
        .modelContainer(for: [CheckIn.self, QuestionResponse.self, Smile.self], inMemory: true)
}
