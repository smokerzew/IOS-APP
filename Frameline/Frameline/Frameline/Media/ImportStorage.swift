import Foundation

/// Private folder holding the one imported file the app is working with.
/// Only the current item is kept; older copies are removed as soon as a new
/// import succeeds.
enum ImportStorage {
    private static let folderName = "Imports"

    static func directory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        var folder = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? folder.setResourceValues(values)
        }
        return folder
    }

    /// Copies a file handed over by the system picker into the app's storage.
    /// The picker's own copy is temporary and disappears when the transfer ends.
    static func adopt(_ source: URL) throws -> URL {
        let fileExtension = source.pathExtension.isEmpty ? "dat" : source.pathExtension
        let destination = try directory()
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    static func url(forFileNamed name: String) -> URL? {
        guard let folder = try? directory() else { return nil }
        let url = folder.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func removeAll(except keep: URL?) {
        guard let folder = try? directory(),
              let contents = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            return
        }
        for url in contents where url.lastPathComponent != keep?.lastPathComponent {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
