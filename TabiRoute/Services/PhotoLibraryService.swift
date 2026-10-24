import Photos
import UIKit
import RouteClusteringKit

struct TripPhotoData {
    let geoPoints: [GeoPoint]
    let missingLocationCount: Int
}

/// Wraps PhotoKit access needed to turn a trip's selected photos into
/// route data. Reads `PHAsset.location` / `creationDate` directly rather
/// than parsing EXIF manually — more robust across HEIC, edited, and
/// iCloud-backed photos.
enum PhotoLibraryService {
    static func requestReadAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return true
        default:
            return false
        }
    }

    static func loadTripPhotoData(assetIdentifiers: [String]) -> TripPhotoData {
        guard !assetIdentifiers.isEmpty else {
            return TripPhotoData(geoPoints: [], missingLocationCount: 0)
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIdentifiers, options: nil)
        var geoPoints: [GeoPoint] = []
        var missingCount = 0

        fetchResult.enumerateObjects { asset, _, _ in
            guard let location = asset.location, let creationDate = asset.creationDate else {
                missingCount += 1
                return
            }
            geoPoints.append(GeoPoint(id: asset.localIdentifier, coordinate: location.coordinate, date: creationDate))
        }

        return TripPhotoData(geoPoints: geoPoints, missingLocationCount: missingCount)
    }

    /// Resolves at most one callback — `.highQualityFormat` avoids the
    /// double-delivery behavior of `.opportunistic`, which would otherwise
    /// resume this continuation twice and crash.
    static func thumbnail(for assetIdentifier: String, targetSize: CGSize = CGSize(width: 200, height: 200)) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            let resumeLock = NSLock()
            var hasResumed = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                resumeLock.lock()
                defer { resumeLock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: image)
            }
        }
    }
}
