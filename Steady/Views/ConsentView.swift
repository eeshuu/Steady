import SwiftUI
import AVFoundation
import SmartSpectra

/// Plain-language consent shown before every session. The camera never starts until
/// the person taps "Start check-in", and the SDK's diagnostic telemetry is opt-in.
struct ConsentView: View {
    var onContinue: () -> Void

    @AppStorage(ConsentKeys.camera) private var hasCameraConsent = false
    @AppStorage(ConsentKeys.telemetry) private var shareDiagnostics = false
    @State private var cameraDenied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Steady")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("Two calm minutes before the call.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                Text("Steady reads your pulse and breathing from the front camera, then guides a breathing exercise that adapts to you as you go.")
                    .font(.body)

                VStack(alignment: .leading, spacing: 14) {
                    InfoRow(icon: "camera", title: "Camera only while you breathe",
                            text: "The camera turns on when you start and off when you finish, leave the app, or tap Stop.")
                    InfoRow(icon: "internaldrive", title: "Nothing is saved",
                            text: "No video, photos or vital signs are stored. Your before/after numbers live in memory and vanish when you close the summary.")
                    InfoRow(icon: "network", title: "What leaves your phone",
                            text: "The Presage SmartSpectra SDK authenticates with Presage using this app's API key. Steady itself sends nothing to any server and uses no AI service.")
                    InfoRow(icon: "heart.text.square", title: "Not a medical device",
                            text: "Readings are wellness estimates. They don't diagnose anything and shouldn't guide medical decisions.")
                }

                Toggle(isOn: $shareDiagnostics) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Share SDK diagnostics with Presage").font(.subheadline.weight(.semibold))
                        Text("Optional. Sends device/performance summaries (no video, no vital-sign values) to help Presage improve the SDK. Off by default.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .tint(.teal)
                .onChange(of: shareDiagnostics) { _, on in
                    SmartSpectraSDK.shared.config.enableTelemetry = on
                }

                Toggle(isOn: $hasCameraConsent) {
                    Text("I understand and agree to use the camera for this session.")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(.teal)

                if cameraDenied {
                    Label("Camera access is off. Turn it on in Settings › Steady to continue.",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.yellow)
                }

                Button(action: requestCameraAndContinue) {
                    Text("Start check-in")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(hasCameraConsent ? Color.teal : Color.gray.opacity(0.3),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.black)
                }
                .disabled(!hasCameraConsent)
                .accessibilityHint("Turns on the front camera and starts a 20 second check-in")
            }
            .padding(20)
        }
        .foregroundStyle(.white)
    }

    private func requestCameraAndContinue() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            onContinue()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { onContinue() } else { cameraDenied = true }
                }
            }
        default:
            cameraDenied = true
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.teal)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
