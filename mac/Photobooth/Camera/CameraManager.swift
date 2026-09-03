import AVFoundation
import AppKit
import Combine

@MainActor
final class CameraManager: NSObject, ObservableObject {
    @Published var devices: [AVCaptureDevice] = []
    @Published var selectedDeviceID: String?
    @Published var isRunning = false
    @Published var permissionDenied = false
    @Published var errorMessage: String?

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var captureContinuation: CheckedContinuation<NSImage, Error>?

    override init() {
        super.init()
        session.sessionPreset = .high
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        refreshDevices()
    }

    func refreshDevices() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown, .deskViewCamera],
            mediaType: .video,
            position: .unspecified
        )
        devices = discovery.devices
        if selectedDeviceID == nil {
            selectedDeviceID = devices.first?.uniqueID
        }
    }

    func start() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            beginSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                beginSession()
            } else {
                permissionDenied = true
            }
        default:
            permissionDenied = true
        }
    }

    private func beginSession() {
        permissionDenied = false
        refreshDevices()
        configureInput(deviceID: selectedDeviceID)
        if !session.isRunning {
            Task.detached(priority: .userInitiated) { [session] in
                session.startRunning()
            }
        }
        isRunning = true
    }

    func selectDevice(id: String) {
        selectedDeviceID = id
        guard isRunning else { return }
        configureInput(deviceID: id)
    }

    private func configureInput(deviceID: String?) {
        guard let device = devices.first(where: { $0.uniqueID == deviceID }) ?? devices.first else {
            errorMessage = "No camera found."
            return
        }
        session.beginConfiguration()
        if let currentInput { session.removeInput(currentInput) }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                currentInput = input
            }
        } catch {
            errorMessage = "Could not open camera: \(error.localizedDescription)"
        }
        if let connection = photoOutput.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        session.commitConfiguration()
    }

    /// Captures a still and crops it to the strip's 4:3 photo aspect ratio,
    /// mirrored to match the on-screen preview.
    func capturePhoto() async throws -> NSImage {
        try await withCheckedThrowingContinuation { continuation in
            self.captureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        Task { @MainActor in
            guard let continuation = self.captureContinuation else { return }
            self.captureContinuation = nil
            if let error {
                continuation.resume(throwing: error)
                return
            }
            guard let cgImage = photo.cgImageRepresentation() else {
                continuation.resume(throwing: CameraError.captureFailed)
                return
            }
            let cropped = CameraManager.cropToPhotoAspect(cgImage)
            continuation.resume(returning: NSImage(cgImage: cropped, size: .zero))
        }
    }

    nonisolated static func cropToPhotoAspect(_ cgImage: CGImage) -> CGImage {
        let targetRatio = StripLayout.photoW / StripLayout.photoH
        let w = CGFloat(cgImage.width), h = CGFloat(cgImage.height)
        let currentRatio = w / h
        var cropRect: CGRect
        if currentRatio > targetRatio {
            let newW = h * targetRatio
            cropRect = CGRect(x: (w - newW) / 2, y: 0, width: newW, height: h)
        } else {
            let newH = w / targetRatio
            cropRect = CGRect(x: 0, y: (h - newH) / 2, width: w, height: newH)
        }
        return cgImage.cropping(to: cropRect) ?? cgImage
    }
}

enum CameraError: LocalizedError {
    case captureFailed
    var errorDescription: String? { "Could not process the captured photo." }
}
