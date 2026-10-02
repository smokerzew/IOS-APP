import SwiftUI

/// Zoom stops for whatever is on the stage. For a live camera the stops are
/// the lenses that device actually has; for an imported photo they are
/// magnifications of the picture.
struct ZoomControl: View {
    @EnvironmentObject private var model: ViewfinderModel
    @EnvironmentObject private var camera: CameraService
    @EnvironmentObject private var media: MediaStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragStartZoom: CGFloat?

    var body: some View {
        let stops = currentStops
        let zoom = currentZoom
        let selected = Self.selectedStop(in: stops, for: zoom)

        HStack(spacing: Metrics.Zoom.spacing) {
            ForEach(stops, id: \.self) { stop in
                chip(stop, isSelected: stop == selected, zoom: zoom)
            }
        }
        .padding(Metrics.Space.tight)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .opacity(stops.isEmpty ? 0 : 1)
        .contentShape(Rectangle())
        .gesture(drag(zoom: zoom))
        .animation(Motion.selection(reduceMotion), value: selected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Zoom")
        .accessibilityValue("\(Self.format(zoom)) times")
        .accessibilityAdjustableAction { direction in
            step(direction == .increment ? 1 : -1, stops: stops, selected: selected)
        }
        .accessibilityHidden(stops.isEmpty)
        .accessibilityIdentifier(AccessibilityID.zoom)
    }

    private var isCamera: Bool { model.mode.usesCamera }

    private var currentStops: [CGFloat] {
        if isCamera {
            return camera.status == .running ? camera.zoomStops.map(\.displayFactor) : []
        }
        return media.media?.kind == .photo ? Metrics.Zoom.viewerStops : []
    }

    private var currentZoom: CGFloat {
        isCamera ? camera.displayZoom : model.viewerZoom
    }

    private func chip(_ stop: CGFloat, isSelected: Bool, zoom: CGFloat) -> some View {
        Button {
            apply(stop, animated: true)
        } label: {
            Text(isSelected ? "\(Self.format(zoom))×" : Self.format(stop))
                .font(Theme.Typeface.numeric(Metrics.Zoom.labelSize, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.Palette.onAccent : Theme.Palette.text)
                .frame(
                    width: isSelected ? Metrics.Zoom.selectedChipWidth : Metrics.Zoom.chipSize,
                    height: Metrics.Zoom.chipSize
                )
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Theme.Palette.accent : Theme.Palette.chip)
                )
                .frame(minHeight: Metrics.Touch.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    /// Dragging along the stops zooms continuously; each doubling takes the
    /// same distance, which is how zoom feels even to the eye.
    private func drag(zoom: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let start = dragStartZoom ?? zoom
                if dragStartZoom == nil { dragStartZoom = start }
                let target = start * pow(2, value.translation.width / Metrics.Zoom.dragPointsPerDoubling)
                apply(target, animated: false)
            }
            .onEnded { _ in
                dragStartZoom = nil
            }
    }

    private func apply(_ value: CGFloat, animated: Bool) {
        if isCamera {
            model.setCameraZoom(value, ramp: animated)
        } else {
            let clamped = min(max(value, 1), Metrics.Viewer.maxRelativeZoom)
            model.setViewerZoom(clamped, animated: animated)
        }
    }

    private func step(_ direction: Int, stops: [CGFloat], selected: CGFloat?) {
        guard let selected, let index = stops.firstIndex(of: selected) else { return }
        let target = min(max(index + direction, 0), stops.count - 1)
        apply(stops[target], animated: true)
    }

    /// The stop the current zoom has reached: the largest one at or below it.
    static func selectedStop(in stops: [CGFloat], for zoom: CGFloat) -> CGFloat? {
        let reached = stops.filter { $0 <= zoom * (1 + Metrics.Zoom.stopTolerance) }
        return reached.max() ?? stops.first
    }

    static func format(_ value: CGFloat) -> String {
        let rounded = (Double(value) * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }
}
