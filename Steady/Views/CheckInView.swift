import SwiftUI
import SmartSpectra

/// ~20 s of sitting still so SmartSpectra can lock on. The breathing guide then
/// starts from the person's own measured breathing rate.
struct CheckInView: View {
    let store: VitalsStore
    /// Set when SmartSpectra could not start; the check-in then explains why
    /// instead of quietly timing out into an exercise with no readings.
    var startError: String? = nil
    var onRetry: () -> Void = {}
    var onReady: () -> Void
    var onCancel: () -> Void

    private let sdk = SmartSpectraSDK.shared
    private let minimumSeconds = 20.0
    private let maximumSeconds = 45.0

    @State private var started = Date.now
    @State private var elapsed: TimeInterval = 0

    private var hasBaseline: Bool {
        store.currentPulse != nil && store.currentBreathingRate != nil
    }

    private var progress: Double { min(elapsed / minimumSeconds, 1) }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button("Stop", action: onCancel)
                    .buttonStyle(.bordered)
                Spacer()
                SignalChip()
            }

            Text("Getting to know your breath")
                .font(.title2.weight(.semibold))
            Text("Sit comfortably, face the screen, and breathe normally.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            CameraBubble()
                .frame(width: 220, height: 220)
                .overlay(
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(.teal, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(-8)
                )

            HStack(spacing: 14) {
                VitalTile(label: "Pulse", value: store.currentPulse, unit: "bpm", tint: .pink)
                VitalTile(label: "Breathing", value: store.currentBreathingRate, unit: "/min", tint: .teal)
            }

            Spacer()

            if let startError {
                VStack(spacing: 10) {
                    Label("Couldn't start the reading. \(startError)",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.yellow)
                        .multilineTextAlignment(.center)
                    Button("Try again", action: onRetry)
                    .buttonStyle(.bordered)
                }
            } else {
                Text(statusLine)
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .foregroundStyle(.white)
        // Keyed on the error: a running task keeps the `startError` it began with,
        // so it has to restart for a new error (or a cleared one on retry) to count.
        .task(id: startError) {
            started = .now
            elapsed = 0
            // With a start error there is no camera running, so the 45 s fallback
            // would only lead into an exercise with no readings. Wait for a retry.
            guard startError == nil else { return }
            while !Task.isCancelled {
                elapsed = Date.now.timeIntervalSince(started)
                if (elapsed >= minimumSeconds && hasBaseline) || elapsed >= maximumSeconds {
                    onReady()
                    return
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private var statusLine: String {
        if let status = sdk.validationStatus, status.code != .ok { return status.hint }
        if elapsed < minimumSeconds { return "About \(Int(minimumSeconds - elapsed)) seconds…" }
        return "Waiting for a steady reading…"
    }
}

// MARK: - Shared pieces

/// Small circular self-view from the SDK's image output, so people can frame their face.
struct CameraBubble: View {
    private let sdk = SmartSpectraSDK.shared
    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.06))
            if let image = sdk.imageOutput {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "face.dashed")
                    .font(.system(size: 54))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
        .accessibilityLabel("Camera preview")
    }
}

/// Shows whether SmartSpectra is happy with lighting / framing / motion.
struct SignalChip: View {
    private let sdk = SmartSpectraSDK.shared
    var body: some View {
        let ok = sdk.validationStatus?.code == .ok
        HStack(spacing: 6) {
            Circle().fill(ok ? Color.green : Color.yellow).frame(width: 8, height: 8)
            Text(ok ? "Signal good" : "Adjusting")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.white.opacity(0.1), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct VitalTile: View {
    let label: String
    let value: Double?
    let unit: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 7, height: 7)
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value.map { "\(Int($0.rounded()))" } ?? "--")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value.map { "\(Int($0.rounded())) \(unit)" } ?? "not available yet")")
    }
}
