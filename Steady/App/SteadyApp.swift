import SwiftUI
import SmartSpectra

@main
struct SteadyApp: App {
    init() {
        let sdk = SmartSpectraSDK.shared
        sdk.config.apiKey = Secrets.presageAPIKey
        sdk.config.imageOutputEnabled = true          // small self-view so people can frame their face
        sdk.config.requestedMetrics =
            SmartSpectraConfig.breathingMetrics +
            SmartSpectraConfig.cardioMetrics + [.expressions]
        // Telemetry is OFF until the person opts in on the consent screen.
        sdk.config.enableTelemetry = UserDefaults.standard.bool(forKey: ConsentKeys.telemetry)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}

enum ConsentKeys {
    static let camera = "steady.consent.camera.v1"
    static let telemetry = "steady.consent.telemetry.v1"
}
