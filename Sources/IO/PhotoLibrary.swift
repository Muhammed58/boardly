import Photos
import UIKit

/// Read access to the photo library for the "beautify my latest screenshot"
/// convenience.
enum PhotoLibrary {

    /// Whether we can read without prompting.
    static var isReadable: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// The most recent screenshot, requesting read access if needed.
    static func latestScreenshot(promptIfNeeded: Bool) async -> UIImage? {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined && promptIfNeeded {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        guard status == .authorized || status == .limited else { return nil }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "(mediaSubtype & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        options.fetchLimit = 1
        guard let asset = PHAsset.fetchAssets(with: .image, options: options).firstObject else { return nil }
        return await image(for: asset)
    }

    private static func image(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .none
            PHImageManager.default().requestImage(
                for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options
            ) { image, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !degraded { continuation.resume(returning: image) }
            }
        }
    }
}
