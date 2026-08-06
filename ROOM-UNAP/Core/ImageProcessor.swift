import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct ImageProcessor {
    static func jpegDataForUpload(from data: Data, maxDimension: CGFloat = 1600, compressionQuality: CGFloat = 0.78) throws -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else {
            throw AppError.imageConversionFailed
        }

        let resizedImage = image.resizedForUpload(maxDimension: maxDimension)
        guard let jpegData = resizedImage.jpegData(compressionQuality: compressionQuality) else {
            throw AppError.imageConversionFailed
        }

        return jpegData
        #else
        return data
        #endif
    }
}

#if canImport(UIKit)
private extension UIImage {
    func resizedForUpload(maxDimension: CGFloat) -> UIImage {
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else { return normalizedForUpload() }

        let scale = maxDimension / largestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            normalizedForUpload().draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func normalizedForUpload() -> UIImage {
        guard imageOrientation != .up else { return self }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
#endif
