# Photobooth (Mac app)

Native macOS version of the [web photobooth](../index.html) — same 4-photo
strip, same three frame templates, but runs offline as a real app with a
dock icon, using AVFoundation for the camera instead of a browser.

The strip canvas is 600×2040, matching the web app exactly, so a custom
frame PNG exported for one works in the other.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15 or later

## Build & run

Open `Photobooth.xcodeproj` in Xcode and press **Cmd+R**.

The first time you build, Xcode will ask you to pick a signing team —
choose your own Apple ID under **Signing & Capabilities** (a free personal
team works fine; no paid Developer account needed to run it locally).

On first launch, macOS will ask for camera permission — click **Allow**.

## Project structure

This project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
from `project.yml`. If you add/remove/rename source files, regenerate the
project instead of hand-editing `Photobooth.xcodeproj`:

```bash
brew install xcodegen   # one-time
cd mac
xcodegen generate
```

```
mac/
  project.yml                  — XcodeGen project spec
  Photobooth.xcodeproj/        — generated Xcode project (committed so it opens without XcodeGen)
  Photobooth/
    App/                       — app entry point
    Camera/                    — AVCaptureSession wrapper + SwiftUI preview layer
    Compositing/                — draws photos + frame onto the final strip
    Models/                    — layout constants, frame drawing, view model
    Views/                     — SwiftUI UI
    Resources/                 — Info.plist, entitlements, asset catalog
```

## Saving

**Save to Downloads** opens a standard macOS save dialog defaulted to your
Downloads folder — pick the filename/location and confirm.

## Custom frames

**Choose Frame Image…** lets you pick any PNG/JPEG/TIFF image as a frame
overlay. For a frame that lines up with the four photo windows, export at
600×2040px (see `StripLayout.swift` for the exact photo positions).
