import UIKit

extension UIImage {
    /// Returns a JPEG-recompressed copy no larger than `maxSizeMB` (best effort).
    func compressedTo(maxSizeMB: Double) -> UIImage {
        let maxBytes = maxSizeMB * 1024 * 1024
        var compression: CGFloat = 1.0
        var data = self.jpegData(compressionQuality: compression) ?? Data()
        while Double(data.count) > maxBytes && compression > 0.1 {
            compression -= 0.1
            data = self.jpegData(compressionQuality: compression) ?? Data()
        }
        return UIImage(data: data) ?? self
    }

    /// Downscales so the longest side is at most `maxDimension` points.
    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    /// Resized + JPEG-compressed data that fits under `maxBytes` (best effort).
    func jpegDataUnder(maxBytes: Int, maxDimension: CGFloat = 1080) -> Data? {
        let image = resized(maxDimension: maxDimension)
        var quality: CGFloat = 0.7
        var data = image.jpegData(compressionQuality: quality)
        while let current = data, current.count > maxBytes, quality > 0.2 {
            quality -= 0.1
            data = image.jpegData(compressionQuality: quality)
        }
        return data
    }
}
