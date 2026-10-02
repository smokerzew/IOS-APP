import Combine
import PhotosUI
import SwiftUI
import UIKit

enum ImportOutcome {
    case imported(ImportedMedia.Kind)
    case cancelled
    case failed(String)
}

/// Holds the one imported item and everything derived from it: the image shown
/// on the stage, its thumbnail and the look previews.
@MainActor
final class MediaStore: ObservableObject {
    enum Phase: Equatable {
        case empty
        case loading
        case ready
    }

    @Published private(set) var phase: Phase = .empty
    @Published private(set) var media: ImportedMedia?
    @Published private(set) var stagePhoto: StagePhoto?
    @Published private(set) var thumbnail: UIImage?
    @Published private(set) var lookPreviews: [String: UIImage] = [:]

    let video = VideoController()
    let renderer = LookRenderer()

    private let preferences: Preferences
    private var baseImage: CGImage?
    private var previewSeed: CGImage?
    private var appearance = Appearance.neutral
    private var isInteractive = false
    private var isRendering = false
    private var displayPixelLimit: CGFloat
    /// Width, in points, at which every version of the current still is shown.
    private var stagePointWidth: CGFloat = 1
    /// What the stage is showing now, so identical renders are skipped.
    private var shownAppearance: Appearance?
    private var shownIsDraft = false

    init(preferences: Preferences) {
        self.preferences = preferences
        let screen = UIScreen.main
        let longestSide = max(screen.bounds.width, screen.bounds.height) * screen.scale
        displayPixelLimit = min(longestSide * Metrics.Media.displayOversample, Metrics.Media.maxDisplayPixel)
    }

    // MARK: - Import

    /// Loads a picker selection. The previous item stays on screen until the new
    /// one is fully ready, so the stage never shows a blank frame.
    func importItem(_ item: PhotosPickerItem) async -> ImportOutcome {
        let fallback: Phase = media == nil ? .empty : .ready
        phase = .loading
        do {
            let imported = try await MediaImporter.load(item)
            if Task.isCancelled {
                ImportStorage.remove(imported.url)
                phase = fallback
                return .cancelled
            }
            guard await present(imported) else {
                ImportStorage.remove(imported.url)
                phase = fallback
                return .failed(MediaImportError.unreadable.localizedDescription)
            }
            preferences.lastMediaFileName = imported.url.lastPathComponent
            ImportStorage.removeAll(except: imported.url)
            return .imported(imported.kind)
        } catch is CancellationError {
            phase = fallback
            return .cancelled
        } catch {
            phase = fallback
            return .failed(error.localizedDescription)
        }
    }

    /// Brings back the item from the previous session, if its file still exists.
    func restoreLastMedia() async {
        guard media == nil, phase == .empty,
              let name = preferences.lastMediaFileName,
              let url = ImportStorage.url(forFileNamed: name) else { return }
        phase = .loading
        guard let described = try? await MediaImporter.describe(fileAt: url), await present(described) else {
            preferences.lastMediaFileName = nil
            ImportStorage.removeAll(except: nil)
            phase = .empty
            return
        }
    }

    func clear() {
        video.unload()
        media = nil
        stagePhoto = nil
        thumbnail = nil
        lookPreviews = [:]
        baseImage = nil
        previewSeed = nil
        phase = .empty
        preferences.lastMediaFileName = nil
        ImportStorage.removeAll(except: nil)
        renderer.clearCaches()
    }

    private func present(_ item: ImportedMedia) async -> Bool {
        let seed: CGImage?
        switch item.kind {
        case .photo:
            let limit = displayPixelLimit
            let url = item.url
            let decoded = await Task.detached(priority: .userInitiated) {
                ImagePipeline.downsample(url: url, maxPixel: limit)
            }.value
            guard let decoded else { return false }
            seed = await Task.detached(priority: .utility) {
                ImagePipeline.downsample(url: url, maxPixel: Metrics.Media.lookPreviewPixel)
            }.value
            video.unload()
            baseImage = decoded
            stagePointWidth = CGFloat(decoded.width)
            stagePhoto = StagePhoto(mediaID: item.id, image: UIImageBox(UIImage(cgImage: decoded)), crossfade: false)
            shownAppearance = .neutral
            shownIsDraft = false
        case .video:
            seed = await ImagePipeline.poster(forVideoAt: item.url, maxPixel: Metrics.Media.lookPreviewPixel)
            baseImage = nil
            stagePhoto = nil
            video.load(item, appearance: appearance)
        }

        previewSeed = seed
        thumbnail = seed.map { UIImage(cgImage: $0) }
        media = item
        phase = .ready
        rebuildLookPreviews()
        renderIfNeeded()
        return true
    }

    // MARK: - Appearance

    /// - Parameter interactive: True while a slider is moving; stills are then
    ///   drawn as quick drafts and refined when the gesture ends.
    func setAppearance(_ newValue: Appearance, interactive: Bool) {
        guard newValue != appearance || interactive != isInteractive else { return }
        appearance = newValue
        isInteractive = interactive
        guard let media else { return }
        switch media.kind {
        case .photo: renderIfNeeded()
        case .video: video.setAppearance(newValue)
        }
    }

    /// Renders are coalesced: only one runs at a time, and when it finishes the
    /// newest requested appearance is rendered next.
    private func renderIfNeeded() {
        guard !isRendering, let media, media.kind == .photo, let base = baseImage else { return }
        let target = appearance
        let draft = isInteractive && !target.isNeutral
        guard shownAppearance != target || shownIsDraft != draft else { return }

        if target.isNeutral {
            show(base, for: media, appearance: target, draft: false)
            return
        }

        isRendering = true
        let renderer = self.renderer
        let scale = draft ? Metrics.Media.draftScale : 1
        let mediaID = media.id
        Task.detached(priority: .userInitiated) { [weak self] in
            let output = renderer.render(base, appearance: target, scale: scale)
            await self?.finishRender(output, appearance: target, draft: draft, mediaID: mediaID)
        }
    }

    private func finishRender(_ image: CGImage?, appearance rendered: Appearance, draft: Bool, mediaID: UUID) {
        isRendering = false
        if let image, let media, media.id == mediaID {
            show(image, for: media, appearance: rendered, draft: draft)
        }
        renderIfNeeded()
    }

    private func show(_ image: CGImage, for media: ImportedMedia, appearance shown: Appearance, draft: Bool) {
        // Drafts and reduced-memory decodes have fewer pixels. Scaling each to
        // the same point width keeps the viewer's zoom and position unchanged.
        let scale = max(CGFloat(image.width) / max(stagePointWidth, 1), 0.01)
        let wrapped = UIImage(cgImage: image, scale: scale, orientation: .up)
        // Crossfade deliberate changes; slider drafts swap instantly.
        let crossfade = !draft && !shownIsDraft && shownAppearance != shown
        stagePhoto = StagePhoto(mediaID: media.id, image: UIImageBox(wrapped), crossfade: crossfade)
        shownAppearance = shown
        shownIsDraft = draft
    }

    private func rebuildLookPreviews() {
        lookPreviews = [:]
        guard let seed = previewSeed, let mediaID = media?.id else { return }
        let renderer = self.renderer
        Task.detached(priority: .utility) { [weak self] in
            var previews: [String: UIImage] = [:]
            for look in Look.all {
                let appearance = Appearance(look: look, intensity: 1, exposure: 0)
                if let image = renderer.render(seed, appearance: appearance, scale: 1) {
                    previews[look.id] = UIImage(cgImage: image)
                }
            }
            await self?.setLookPreviews(previews, mediaID: mediaID)
        }
    }

    private func setLookPreviews(_ previews: [String: UIImage], mediaID: UUID) {
        guard media?.id == mediaID else { return }
        lookPreviews = previews
    }

    // MARK: - Export

    /// Saves the framed region of the imported photo, with its look, as a new image.
    func exportFramedCopy(visibleRect: CGRect) async -> PhotoLibrarySaver.Outcome {
        guard let media, media.kind == .photo else { return .failed }
        let appearance = self.appearance
        let renderer = self.renderer
        let data = await Task.detached(priority: .userInitiated) {
            FramedExporter.render(media, visibleRect: visibleRect, appearance: appearance, renderer: renderer)
        }.value
        guard let data else { return .failed }
        return await withCheckedContinuation { continuation in
            PhotoLibrarySaver.savePhoto(data) { outcome in
                continuation.resume(returning: outcome)
            }
        }
    }

    // MARK: - Memory

    /// Called on a memory warning: drops caches and re-decodes the still smaller.
    func reduceMemoryFootprint() {
        renderer.clearCaches()
        lookPreviews = [:]
        guard let media, media.kind == .photo, displayPixelLimit > Metrics.Media.reducedDisplayPixel else { return }
        displayPixelLimit = Metrics.Media.reducedDisplayPixel
        let limit = displayPixelLimit
        let url = media.url
        Task { [weak self] in
            let smaller = await Task.detached(priority: .userInitiated) {
                ImagePipeline.downsample(url: url, maxPixel: limit)
            }.value
            guard let self, let smaller, self.media?.id == media.id else { return }
            self.baseImage = smaller
            self.shownAppearance = nil
            self.renderIfNeeded()
        }
    }
}
