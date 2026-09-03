import AppKit
import SwiftUI
import Combine

@MainActor
final class BoothViewModel: ObservableObject {
    let camera = CameraManager()
    private var cancellables = Set<AnyCancellable>()

    @Published var shots: [NSImage?] = Array(repeating: nil, count: StripLayout.photoCount)
    @Published var isCapturing = false
    @Published var countdownValue: Int?
    @Published var flashTick = 0
    @Published var selectedFrame: FrameTemplate = .none
    @Published var customFrames: [FrameTemplate] = []
    @Published var previewImage: NSImage = StripCompositor.render(photos: Array(repeating: nil, count: StripLayout.photoCount), frame: .none)
    @Published var saveError: String?

    let builtInFrames: [FrameTemplate] = [.classic, .polaroid, .confetti]

    var allShotsFilled: Bool { shots.allSatisfy { $0 != nil } }

    init() {
        // CameraManager is a nested ObservableObject; forward its changes so
        // views observing this BoothViewModel re-render when the camera state changes.
        camera.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func selectFrame(_ frame: FrameTemplate) {
        selectedFrame = frame
        renderPreview()
    }

    func addCustomFrame() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp, .webP]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Choose a Frame Image"
        panel.message = "Transparent PNG, \(Int(StripLayout.stripW))×\(Int(StripLayout.stripH)) recommended."
        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }
        let frame = FrameTemplate.custom(image)
        customFrames.append(frame)
        selectFrame(frame)
    }

    func takeAllPhotos() {
        guard !isCapturing else { return }
        isCapturing = true
        shots = Array(repeating: nil, count: StripLayout.photoCount)
        renderPreview()

        Task {
            for i in 0..<StripLayout.photoCount {
                await runCountdown()
                flashTick += 1
                do {
                    let image = try await camera.capturePhoto()
                    shots[i] = image
                    renderPreview()
                } catch {
                    saveError = "Couldn't capture photo \(i + 1): \(error.localizedDescription)"
                }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
            isCapturing = false
        }
    }

    func retake() {
        shots = Array(repeating: nil, count: StripLayout.photoCount)
        renderPreview()
    }

    private func runCountdown() async {
        for s in stride(from: 3, through: 1, by: -1) {
            countdownValue = s
            try? await Task.sleep(nanoseconds: 700_000_000)
        }
        countdownValue = nil
    }

    private func renderPreview() {
        previewImage = StripCompositor.render(photos: shots, frame: selectedFrame)
    }

    func saveToDownloads() {
        let panel = NSSavePanel()
        panel.title = "Save Photo Strip"
        panel.nameFieldStringValue = "photobooth-\(Self.timestamp()).png"
        panel.allowedContentTypes = [.png]
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let final = StripCompositor.render(photos: shots, frame: selectedFrame)
        guard let tiff = final.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            saveError = "Couldn't encode the photo strip."
            return
        }
        do {
            try png.write(to: url)
        } catch {
            saveError = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        return formatter.string(from: Date())
    }
}
