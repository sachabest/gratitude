import SwiftUI
import PhotosUI

/// Lets you optionally attach one photo while recording a morning/evening
/// check-in. `PhotosPicker` runs out-of-process and needs no system
/// permission — nothing to grant, nothing to accidentally deny.
struct PhotoAttachmentView: View {
    @Binding var selectedItem: PhotosPickerItem?
    let previewImage: UIImage?
    let isLoading: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photo (optional)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let previewImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .clipped()

                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white, .black.opacity(0.55))
                    }
                    .padding(10)
                    .accessibilityLabel("Remove photo")
                }
            } else {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack(spacing: 10) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "photo.badge.plus")
                                .font(.title3)
                        }
                        Text(isLoading ? "Adding photo…" : "Add a photo")
                            .font(.body.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
        }
    }
}
