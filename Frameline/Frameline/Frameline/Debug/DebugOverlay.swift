#if DEBUG
import PhotosUI
import SwiftUI
import UIKit

/// Developer overlay: live readings, layout guides and a reference image.
/// Touch and hold the status badge to open its panel.
struct DebugOverlay: View {
    let layout: ViewfinderLayout
    @ObservedObject var settings: DebugSettings

    @EnvironmentObject private var model: ViewfinderModel
    @EnvironmentObject private var camera: CameraService
    @EnvironmentObject private var media: MediaStore
    @StateObject private var fps = FPSMonitor()

    var body: some View {
        let frame = model.frameRect(in: layout)
        ZStack {
            if settings.showsReference, let image = settings.referenceImage {
                ReferenceOverlay(image: image, layout: layout, settings: settings)
            }
            if settings.showsGuides {
                guides(frame)
            }
            if settings.showsHUD {
                hud(frame)
                    .position(x: layout.size.width / 2, y: layout.topBarRect.maxY + 150)
            }
            // Invisible hot zone over the status badge.
            Color.clear
                .frame(width: 130, height: Metrics.TopBar.chipHeight)
                .contentShape(Rectangle())
                .position(x: layout.size.width / 2, y: layout.topBarRect.midY)
                .onLongPressGesture(minimumDuration: 0.8) {
                    settings.isPanelPresented = true
                }
                .accessibilityHidden(true)
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .onChange(of: settings.showsHUD) { _, shows in
            if shows {
                fps.start()
            } else {
                fps.stop()
            }
        }
        .sheet(isPresented: $settings.isPanelPresented) {
            DebugPanel(settings: settings)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Guides

    private func guides(_ frame: CGRect) -> some View {
        ZStack {
            outline(layout.topBarRect, colour: .orange, name: "top bar")
            outline(layout.deckRect, colour: .purple, name: "deck")
            outline(frame, colour: .green, name: "frame")
            outline(
                CGRect(
                    x: layout.insets.leading,
                    y: layout.insets.top,
                    width: layout.size.width - layout.insets.leading - layout.insets.trailing,
                    height: layout.size.height - layout.insets.top - layout.insets.bottom
                ),
                colour: .red,
                name: "safe area"
            )
            Path { path in
                path.move(to: CGPoint(x: layout.size.width / 2, y: 0))
                path.addLine(to: CGPoint(x: layout.size.width / 2, y: layout.size.height))
                path.move(to: CGPoint(x: 0, y: frame.midY))
                path.addLine(to: CGPoint(x: layout.size.width, y: frame.midY))
            }
            .stroke(Color.cyan.opacity(0.8), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func outline(_ rect: CGRect, colour: Color, name: String) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .strokeBorder(colour, lineWidth: 1)
            Text("\(name)  x\(Self.number(rect.minX)) y\(Self.number(rect.minY))  \(Self.size(rect.size))")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 3)
                .background(colour)
        }
        .frame(width: max(rect.width, 0), height: max(rect.height, 0))
        .position(x: rect.midX, y: rect.midY)
    }

    // MARK: - HUD

    private func hud(_ frame: CGRect) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(readings(frame), id: \.self) { line in
                Text(line)
            }
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(.white)
        .padding(8)
        .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func readings(_ frame: CGRect) -> [String] {
        let screen = UIScreen.main
        let memory: String = MemoryProbe.footprintMegabytes().map { String(format: "%.0f MB", $0) } ?? "n/a"
        let points: String = Self.size(layout.size)
        let native: String = Self.size(screen.nativeBounds.size)
        let scale: String = Self.number(screen.scale)
        let insets = layout.insets
        let count: String = model.countdown.map { String($0) } ?? "-"
        let control: String = model.activeControl?.rawValue ?? "-"
        let mediaKind: String = media.media?.kind.rawValue ?? "-"
        let mediaSize: String = Self.size(media.media?.pixelSize ?? .zero)
        let intensity: Int = Int((model.lookIntensity * 100).rounded())

        var lines: [String] = []
        lines.append("fps \(fps.framesPerSecond)   mem \(memory)")
        lines.append("screen \(points) @\(scale)x   native \(native)")
        lines.append("safe t\(Self.number(insets.top)) b\(Self.number(insets.bottom)) l\(Self.number(insets.leading)) r\(Self.number(insets.trailing))")
        lines.append("frame x\(Self.number(frame.minX)) y\(Self.number(frame.minY)) \(Self.size(frame.size))")
        lines.append("mode \(model.mode.rawValue)   aspect \(model.effectiveAspect.label)")
        lines.append("flash \(model.flash.rawValue) usable \(model.isFlashUsable)   timer \(model.timer.label) count \(count)")
        lines.append("zoom camera \(ZoomControl.format(camera.displayZoom)) viewer \(ZoomControl.format(model.viewerZoom))")
        lines.append("exposure \(ExposureControl.format(model.exposure))")
        lines.append("camera \(String(describing: camera.status)) \(camera.facing.rawValue) recording \(camera.isRecording)")
        lines.append("media \(String(describing: media.phase)) \(mediaKind) \(mediaSize)")
        lines.append("look \(model.look.id) \(intensity)%")
        lines.append("panel \(model.isPanelOpen) control \(control) immersive \(model.isImmersive)")
        return lines
    }

    private static func size(_ value: CGSize) -> String {
        "\(number(value.width))×\(number(value.height))"
    }

    private static func number(_ value: CGFloat) -> String {
        let rounded = (Double(value) * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }
}

/// Switches and reference-image adjustments.
struct DebugPanel: View {
    @ObservedObject var settings: DebugSettings
    @State private var referenceItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("Overlay") {
                    Toggle("Readings (FPS, memory, state)", isOn: $settings.showsHUD)
                    Toggle("Bounds, safe area and centre lines", isOn: $settings.showsGuides)
                }
                Section("Reference image") {
                    PhotosPicker(selection: $referenceItem, matching: .images) {
                        Text(settings.referenceImage == nil ? "Choose image" : "Replace image")
                    }
                    Toggle("Show", isOn: $settings.showsReference)
                        .disabled(settings.referenceImage == nil)
                    slider("Opacity", value: $settings.referenceOpacity, range: 0...1)
                    slider("X offset", value: $settings.referenceOffsetX, range: -200...200)
                    slider("Y offset", value: $settings.referenceOffsetY, range: -200...200)
                    slider("Scale", value: $settings.referenceScale, range: 0.5...2)
                    Button("Reset placement") {
                        settings.referenceOffsetX = 0
                        settings.referenceOffsetY = 0
                        settings.referenceScale = 1
                        settings.referenceOpacity = 0.5
                    }
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: referenceItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    settings.referenceImage = image
                    settings.showsReference = true
                }
            }
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(title): \(String(format: "%.2f", value.wrappedValue))")
                .font(.caption.monospacedDigit())
            Slider(value: value, in: range)
        }
    }
}
#endif
