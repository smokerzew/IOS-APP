import Foundation
import Photos

/// Saves captures and exports using add-only access, the narrowest permission
/// that allows writing to the Photos library.
enum PhotoLibrarySaver {
    enum Outcome {
        case saved
        case denied
        case failed
    }

    static func savePhoto(_ data: Data, completion: @escaping (Outcome) -> Void) {
        authorize { granted in
            guard granted else {
                completion(.denied)
                return
            }
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }, completionHandler: { success, _ in
                completion(success ? .saved : .failed)
            })
        }
    }

    static func saveVideo(at url: URL, completion: @escaping (Outcome) -> Void) {
        authorize { granted in
            guard granted else {
                completion(.denied)
                return
            }
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .video, fileURL: url, options: nil)
            }, completionHandler: { success, _ in
                completion(success ? .saved : .failed)
            })
        }
    }

    private static func authorize(_ completion: @escaping (Bool) -> Void) {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                completion(status == .authorized || status == .limited)
            }
        default:
            completion(false)
        }
    }
}
