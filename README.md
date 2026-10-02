# Frameline

A native iPhone app (Swift, SwiftUI, UIKit, AVFoundation) with a camera-style
viewfinder that shows one of three things:

- **Library** – a photo or video imported from Photos, always labelled as imported.
- **Photo** – the live camera, for taking stills.
- **Video** – the live camera, for recording.

Requires iOS 17 or later. Portrait only; glyphs turn with the device.

## Build an .ipa with Codemagic (no Mac needed)

1. Put this folder in a Git repository (GitHub, GitLab or Bitbucket).
2. In Codemagic, add the repository as an application. It finds `codemagic.yaml`.
3. Start the **Frameline unsigned IPA** workflow.
4. Download `Frameline-unsigned.ipa` from the build's Artifacts.

The workflow already places `Frameline.app` in a `Payload` folder and zips it,
so there is nothing to rename or repack by hand. If the build fails, the errors
are in `xcodebuild.log`, also under Artifacts.

The `.ipa` is unsigned and will not install until it is signed with your Apple
Developer account, either by a signing tool on your computer or by adding code
signing to the workflow.

## Build in Xcode

Open `Frameline.xcodeproj`, choose your team under Signing & Capabilities,
change the bundle identifier from `com.example.frameline`, then run, or use
Product > Archive to export an `.ipa`.

After adding or moving source files, run `python3 Tools/generate_xcodeproj.py`
to rebuild the project file.

## What each control does

| Control | Photo / Video (live camera) | Library (imported media) |
| --- | --- | --- |
| Flash | Auto, On, Off, sent to the camera; torch while recording | Not shown |
| Aspect | 1:1, 4:3, 16:9 frame; photos are saved in that shape (video is 16:9) | 1:1, 4:3, 16:9 frame |
| Timer | Off, 3 s, 5 s, 10 s countdown; press the shutter again to cancel | Not shown |
| Exposure | Real exposure compensation | Brightness of the picture on screen |
| Look | Not shown | Eight looks with intensity |
| Zoom | The lenses the device has, pinch, or drag along the stops | 1×, 2×, 3×, pinch, double-tap |
| Grid, Level | Shown over the frame | Grid only |
| Main button | Take photo / start and stop recording | Save framed copy / play and pause |

Controls that would do nothing in a mode are hidden there rather than faked.

## Permissions

- Camera and microphone: asked the first time Photo or Video mode is opened.
- Add to Photos: asked the first time something is saved.
- Importing uses the system picker, which needs no permission; the app never
  reads the library and nothing leaves the device.

## Debug overlay (Debug builds only)

Touch and hold the status badge at the top to open the panel. It can show live
readings (FPS, memory, screen, safe area, state), layout bounds and centre
lines, and a reference image over the app with adjustable opacity, offset and
scale. None of it is compiled into Release builds.

## Checks to run on a device

Nothing here has been run on hardware yet. After the first build, go through:

- Launch: black launch screen straight into the viewfinder, no flash of white.
- Library: import a photo, import a video, replace, remove (touch and hold the thumbnail).
- Photo viewer: pinch, pan, double-tap in and out, zoom stops, full screen.
- Video: play, pause, scrub, mute, full screen, look applied while playing and while paused.
- Aspect: 1:1, 4:3 and 16:9 in Library and Photo; the picture's centre stays put.
- Looks and brightness: each look, intensity ruler, reset.
- Photo: permission prompt, capture in each aspect, flash Auto/On/Off, timer and cancel, tap to focus, pinch zoom, lens stops, front/back.
- Video: record, stop, timer, torch, save, recording without microphone access.
- Controls panel: open, each control, tap the picture to close, swipe down to close.
- Mode dial: tap, slow drag that snaps back, fast flick, swipe on the live preview.
- Grid and level; level turns the accent colour when straight.
- Lifecycle: background and return, lock and unlock, Control Centre, relaunch restores settings and the last import.
- Denied camera, denied Photos saving, a damaged or still-downloading item.
- VoiceOver labels and adjustable controls; Reduce Motion.
- Small and large phones; Dynamic Island and home-button models.
