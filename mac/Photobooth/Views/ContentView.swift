import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var vm = BoothViewModel()
    @State private var flashOpacity = 0.0

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            cameraPanel
            framePanel
        }
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Something went wrong", isPresented: Binding(
            get: { vm.saveError != nil },
            set: { if !$0 { vm.saveError = nil } }
        )) {
            Button("OK") { vm.saveError = nil }
        } message: {
            Text(vm.saveError ?? "")
        }
        .onChange(of: vm.flashTick) { _ in
            flashOpacity = 0.9
            withAnimation(.easeOut(duration: 0.35)) { flashOpacity = 0 }
        }
    }

    private var cameraPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("📸 Photobooth").font(.title).bold()
            Text("Take 4 photos, pick a frame, save your strip.")
                .foregroundStyle(.secondary)

            ZStack {
                if vm.camera.isRunning {
                    CameraPreviewView(session: vm.camera.session)
                        .scaleEffect(x: -1, y: 1) // mirror to feel like a mirror
                } else {
                    Rectangle().fill(Color.black)
                    VStack(spacing: 8) {
                        if vm.camera.permissionDenied {
                            Text("Camera access denied").foregroundStyle(.white)
                            Text("Enable it in System Settings → Privacy & Security → Camera")
                                .font(.caption).foregroundStyle(.white.opacity(0.7))
                        } else {
                            Text("Camera is off").foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }

                if let countdown = vm.countdownValue {
                    Text("\(countdown)")
                        .font(.system(size: 84, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 12)
                }

                Rectangle().fill(Color.white).opacity(flashOpacity).allowsHitTesting(false)
            }
            .aspectRatio(4/3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Picker("Camera", selection: Binding(
                get: { vm.camera.selectedDeviceID ?? "" },
                set: { vm.camera.selectDevice(id: $0) }
            )) {
                ForEach(vm.camera.devices, id: \.uniqueID) { device in
                    Text(device.localizedName).tag(device.uniqueID)
                }
            }
            .labelsHidden()

            HStack(spacing: 10) {
                Button(vm.camera.isRunning ? "Restart Camera" : "Start Camera") {
                    Task { await vm.camera.start() }
                }
                .buttonStyle(.borderedProminent)

                Button("Take 4 Photos") { vm.takeAllPhotos() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.camera.isRunning || vm.isCapturing)

                Button("Retake") { vm.retake() }
                    .disabled(vm.isCapturing || vm.shots.allSatisfy { $0 == nil })
            }

            HStack(spacing: 8) {
                ForEach(0..<StripLayout.photoCount, id: \.self) { i in
                    ShotThumbnail(image: vm.shots[i], number: i + 1)
                }
            }
        }
        .frame(width: 460)
        .task { await vm.camera.start() }
    }

    private var framePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Frame Template").font(.headline)

            FramePickerGrid(vm: vm)

            Button("Choose Frame Image…") { vm.addCustomFrame() }
                .font(.caption)

            Text("Preview").font(.headline).padding(.top, 6)

            ScrollView {
                Image(nsImage: vm.previewImage)
                    .resizable()
                    .aspectRatio(StripLayout.stripW / StripLayout.stripH, contentMode: .fit)
                    .frame(maxWidth: 260)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(maxHeight: 380)

            Button("Save to Downloads") { vm.saveToDownloads() }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.allShotsFilled)
                .frame(maxWidth: .infinity)
        }
        .frame(width: 320)
    }
}

private struct ShotThumbnail: View {
    let image: NSImage?
    let number: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(image == nil ? Color.secondary.opacity(0.4) : Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: image == nil ? [4, 3] : []))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("\(number)").foregroundStyle(.secondary)
            }
        }
        .aspectRatio(4/3, contentMode: .fit)
    }
}

private struct FramePickerGrid: View {
    @ObservedObject var vm: BoothViewModel
    private let columns = [GridItem(.adaptive(minimum: 64, maximum: 80), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            frameCell(.none, label: "No frame")
            ForEach(vm.builtInFrames) { frame in
                frameCell(frame, label: nil)
            }
            ForEach(vm.customFrames) { frame in
                frameCell(frame, label: nil)
            }
        }
    }

    private func frameCell(_ frame: FrameTemplate, label: String?) -> some View {
        let isSelected = vm.selectedFrame == frame
        return Button {
            vm.selectFrame(frame)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                if let label {
                    Text(label).font(.caption2).multilineTextAlignment(.center).padding(4)
                } else {
                    Image(nsImage: frame.thumbnail(size: CGSize(width: 60, height: 60 * StripLayout.stripH / StripLayout.stripW)))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .aspectRatio(1/2.6, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
