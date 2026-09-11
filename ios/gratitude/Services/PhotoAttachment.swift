import UIKit

/// Downsizes a picked photo before it's stored on a `CheckIn`. `PhotosPicker`
/// hands back the original-resolution asset (often several MB, HEIC), which is
/// both wasteful to store locally and pushes CloudKit backup records toward
/// their per-field size ceiling — so every attached photo is normalized to a
/// small JPEG first.
enum PhotoAttachment {
    private static let maxDimension: CGFloat = 1200
    private static let jpegQuality: CGFloat = 0.6

    static func downsizedJPEGData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return resized(image, maxDimension: maxDimension).jpegData(compressionQuality: jpegQuality)
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let largestSide = max(image.size.width, image.size.height)
        guard largestSide > maxDimension else { return image }

        let scale = maxDimension / largestSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
