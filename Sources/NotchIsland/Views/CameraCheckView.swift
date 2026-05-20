import SwiftUI
import AVFoundation
import AppKit

// Camera Check — shows a live camera preview so the user can check their appearance
// before joining a video call. Uses AVFoundation directly; no permission dialog
// is shown for apps outside the sandbox as long as Privacy.plist is set.
struct CameraCheckView: View {
    @StateObject private var session = CameraSession()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.07))
            cameraContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear  { session.start() }
        .onDisappear { session.stop() }
    }

    // MARK: – Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "camera.fill")
                .font(.system(size: 10))
                .foregroundStyle(session.isRunning ? .green.opacity(0.8) : .white.opacity(0.5))
            Text("Camera Check")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Circle()
                .fill(session.isRunning ? Color.red : Color.clear)
                .frame(width: 6, height: 6)
            Spacer()
            if session.permissionDenied {
                Text("Camera access denied")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange.opacity(0.8))
            } else {
                Text(session.isRunning ? "Live" : "Starting…")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: – Camera preview

    @ViewBuilder
    private var cameraContent: some View {
        if session.permissionDenied {
            VStack(spacing: 8) {
                Image(systemName: "camera.fill.badge.ellipsis")
                    .font(.system(size: 24)).foregroundStyle(.white.opacity(0.2))
                Text("Allow camera access in System Settings")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                Button("Open Privacy Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.blue).buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            CameraPreview(session: session.captureSession)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(8)
                .overlay(alignment: .bottomTrailing) {
                    // Mirrored indicator
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                            .font(.system(size: 7))
                        Text("Mirrored")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(.white.opacity(0.25))
                    .padding(.trailing, 12).padding(.bottom, 12)
                }
        }
    }
}

// MARK: – NSViewRepresentable camera preview

private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.connection?.automaticallyAdjustsVideoMirroring = false
        preview.connection?.isVideoMirrored = true   // selfie-mirror
        view.wantsLayer = true
        view.layer = preview
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: – Session manager

@MainActor
final class CameraSession: ObservableObject {
    @Published var isRunning = false
    @Published var permissionDenied = false

    let captureSession = AVCaptureSession()

    func start() {
        guard !isRunning else { return }
        Task.detached { [weak self] in
            guard let self else { return }
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                await self.configureAndStart()
            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted { await self.configureAndStart() }
                else { await MainActor.run { self.permissionDenied = true } }
            default:
                await MainActor.run { self.permissionDenied = true }
            }
        }
    }

    func stop() {
        captureSession.stopRunning()
        isRunning = false
    }

    private func configureAndStart() async {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                        ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)
        captureSession.commitConfiguration()
        captureSession.startRunning()
        await MainActor.run { self.isRunning = true }
    }
}
