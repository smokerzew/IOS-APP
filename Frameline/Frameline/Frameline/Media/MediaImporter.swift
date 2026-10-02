import AVFoundation
import CoreTransferable
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// A movie file received from the system picker. It is transferred as a file,
/// so a long video is never loaded into memory.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let url = try ImportStorage.adopt(received.file)
            return PickedMovie(url: url)
        }
    }
}

/// An image file received from the system picker, kept in its original format.
struct PickedImage: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let url = try ImportStorage.adopt(received.file)
            return PickedImage(url: url)
        }
    }
}

enum MediaImportError: LocalizedError {
    case unsupported
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unsupported: return "That item is not a photo or video Frameline can open."
        case .unreadable: return "That item could not be read. It may be damaged or still downloading."
        }
    }
}

/// Turns a picker selection into a local file and describes it.
/// The system picker runs outside the app, so no library permission is needed
/// and the app only ever sees the item the user chose.
enum MediaImporter {
    static func load(_ item: PhotosPickerItem) async throws -> ImportedMedia {
        let types = item.supportedContentTypes

        if types.contains(where: { $0.conforms(to: .movie) }) {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                throw MediaImportError.unreadable
            }
            return try await describeVideo(at: movie.url)
        }

        if types.contains(where: { $0.conforms(to: .image) }) {
            if let image = try await item.loadTransferable(type: PickedImage.self) {
                return try describeImage(at: image.url)
            }
            // Some items only offer their bytes; write them out once.
            if let data = try await item.loadTransferable(type: Data.self) {
                let fileExtension = types.first?.preferredFilenameExtension ?? "img"
                let url = try ImportStorage.directory()
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(fileExtension)
                try data.write(to: url, options: .atomic)
                return try describeImage(at: url)
            }
            throw MediaImportError.unreadable
        }

        throw MediaImportError.unsupported
    }

    /// Rebuilds the description of a file saved by an earlier session.
    static func describe(fileAt url: URL) async throws -> ImportedMedia {
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .movie) {
            return try await describeVideo(at: url)
        }
        return try describeImage(at: url)
    }

    private static func describeImage(at url: URL) throws -> ImportedMedia {
        guard let size = ImagePipeline.displaySize(ofImageAt: url) else {
            ImportStorage.remove(url)
            throw MediaImportError.unreadable
        }
        return ImportedMedia(id: UUID(), kind: .photo, url: url, pixelSize: size, duration: 0)
    }

    private static func describeVideo(at url: URL) async throws -> ImportedMedia {
        let asset = AVURLAsset(url: url)
        do {
            guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                throw MediaImportError.unreadable
            }
            let naturalSize = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let duration = try await asset.load(.duration)
            let displayed = naturalSize.applying(transform)
            let size = CGSize(width: abs(displayed.width), height: abs(displayed.height))
            guard size.width > 0, size.height > 0, duration.seconds.isFinite, duration.seconds > 0 else {
                throw MediaImportError.unreadable
            }
            return ImportedMedia(id: UUID(), kind: .video, url: url, pixelSize: size, duration: duration.seconds)
        } catch {
            ImportStorage.remove(url)
            throw MediaImportError.unreadable
        }
    }
}
