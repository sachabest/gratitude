import SwiftUI

struct CheckInDetailView: View {
    let checkIn: CheckIn

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    Image(systemName: checkIn.period.symbolName)
                        .foregroundStyle(checkIn.period.tint)
                    Text(checkIn.period.title)
                        .font(.headline)
                    Spacer()
                    Text(checkIn.date, format: .dateTime.month(.wide).day().year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let photoData = checkIn.photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                        .clipped()
                }

                ForEach(checkIn.sortedResponses) { response in
                    QuestionResponseRow(response: response)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(20)
        }
        .navigationTitle("\(checkIn.period.title) check-in")
        .navigationBarTitleDisplayMode(.inline)
    }
}
