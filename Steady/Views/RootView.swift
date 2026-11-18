import SwiftUI
import SmartSpectra

/// Owns the flow (consent → check-in → breathe → summary) and forwards live
/// SmartSpectra metrics into the in-memory `VitalsStore`.
struct RootView: View {
    enum Step: Equatable { case consent, checkIn, breathe, summary }

    @State private var step: Step = .consent
    @State private var store = VitalsStore()
    @State private var before: VitalsSnapshot?
    @State private var after: VitalsSnapshot?
    @State private var breatheStarted: Date?
    @State private var breatheEnded: Date?
    /// Why the SDK could not start (bad API key, no network, credits used up…).
    @State private var startError: String?
    /// Bumped by "Try again" on the check-in screen to re-run `startSensing()`.
    @State private var startAttempt = 0

    private let sdk = SmartSpectraSDK.shared

    /// Changes whenever the SDK publishes a new reading, so `.task(id:)` re-runs.
    private var metricsToken: Int64 {
        let m = sdk.metrics
        return [
            m?.cardio.pulseRate.last?.timestamp,
            m?.breathing.rate.last?.timestamp,
            m?.breathing.upperTrace.last?.timestamp,
            m?.cardio.hrv.last?.timestamp,
            m?.face.expression.last?.timestamp,
        ].compactMap { $0 }.max() ?? 0
    }

    var body: some View {
        ZStack {
            SteadyBackground()
            switch step {
            case .consent:
                ConsentView { step = .checkIn }
            case .checkIn:
                CheckInView(store: store,
                            startError: startError ?? (sdk.processingStatus == .error ? sdk.error?.message : nil),
                            onRetry: { startAttempt += 1 }) {
                    before = VitalsSnapshot(store)
                    breatheStarted = .now
                    step = .breathe
                } onCancel: { Task { await stopSensing(); step = .consent } }
            case .breathe:
                BreatheView(store: store, startingRate: before?.breathingRate,
                            baselinePulse: before?.pulse) {
                    after = VitalsSnapshot(store)
                    breatheEnded = .now
                    Task { await stopSensing() }
                    step = .summary
                }
            case .summary:
                SummaryView(before: before, after: after,
                            duration: duration) {
                    // Discard everything from this session.
                    before = nil; after = nil
                    breatheStarted = nil; breatheEnded = nil
                    store.reset()
                    step = .consent
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
        .task(id: step) {
            if step == .checkIn { await startSensing() }
        }
        .task(id: startAttempt) {
            if step == .checkIn, startAttempt > 0 { await startSensing() }
        }
        .task(id: metricsToken) {
            if let m = sdk.metrics { store.ingest(m) }
        }
        .onChange(of: scenePhase) { _, phase in
            // Never keep the camera running in the background.
            if phase != .active, step == .checkIn || step == .breathe {
                Task { await stopSensing(); step = .consent }
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    private var duration: TimeInterval {
        guard let s = breatheStarted, let e = breatheEnded else { return 0 }
        return e.timeIntervalSince(s)
    }

    private func startSensing() async {
        store.reset()
        startError = nil
        // "Done → Start check-in" can arrive while the previous session is still
        // stopping. Starting then would be a no-op and the check-in would sit there
        // with no camera, so wait (briefly) for the SDK to settle first.
        for _ in 0..<40 where sdk.processingStatus == .stopping {
            try? await Task.sleep(for: .milliseconds(50))
        }
        // `.error` is restartable too: without this, one failed start (no network,
        // bad key) left every later check-in silently waiting on a camera that
        // never started.
        guard sdk.processingStatus == .idle || sdk.processingStatus == .error else { return }
        do {
            // Explicit front camera: the SDK's default falls back to any camera,
            // and Steady promises the person it reads them through the front one.
            try sdk.useCamera(.front)
            try await sdk.start()
        } catch {
            startError = error.localizedDescription
        }
    }

    private func stopSensing() async {
        if sdk.processingStatus == .running || sdk.processingStatus == .starting {
            try? await sdk.stop()
        }
    }
}

struct SteadyBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.07, blue: 0.13),
                     Color(red: 0.06, green: 0.12, blue: 0.18),
                     .black],
            startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
    }
}
