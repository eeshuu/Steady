import Foundation
import Observation
import SmartSpectra

/// Holds a short, in-memory window of live SmartSpectra readings.
/// Nothing here is written to disk or sent anywhere.
@Observable
final class VitalsStore {
    private enum Window {
        static let rate = 120
        static let trace = 180
    }

    private(set) var pulse: [MeasurementWithConfidence] = []
    private(set) var breathingRate: [MeasurementWithConfidence] = []
    private(set) var chestTrace: [SmartSpectra.Measurement] = []
    private(set) var latestHrv: Hrv?
    private(set) var expressionScores: [ExpressionScore] = []

    /// Minimum confidence (0–100) before a reading is shown or used for pacing.
    static let minConfidence: Double = 60

    func reset() {
        pulse.removeAll(keepingCapacity: true)
        breathingRate.removeAll(keepingCapacity: true)
        chestTrace.removeAll(keepingCapacity: true)
        latestHrv = nil
        expressionScores.removeAll(keepingCapacity: true)
    }

    func ingest(_ metrics: Metrics) {
        if !metrics.cardio.pulseRate.isEmpty {
            pulse.appendProtoArray(contentsOf: metrics.cardio.pulseRate)
            pulse = Array(pulse.suffix(Window.rate))
        }
        if !metrics.breathing.rate.isEmpty {
            breathingRate.appendProtoArray(contentsOf: metrics.breathing.rate)
            breathingRate = Array(breathingRate.suffix(Window.rate))
        }
        if !metrics.breathing.upperTrace.isEmpty {
            chestTrace.appendProtoArray(contentsOf: metrics.breathing.upperTrace)
            chestTrace = Array(chestTrace.suffix(Window.trace))
        }
        if let hrv = metrics.cardio.hrv.last, hrv.rmssd > 0 {
            latestHrv = hrv
        }
        if let scores = metrics.face.expression.last?.scores, !scores.isEmpty {
            expressionScores = scores
        }
    }

    // MARK: - Derived values

    /// Average of the most recent confident pulse readings.
    var currentPulse: Double? { Self.recentAverage(pulse, count: 8) }

    /// Average of the most recent confident breathing-rate readings (breaths/min).
    var currentBreathingRate: Double? { Self.recentAverage(breathingRate, count: 8) }

    var currentHrv: Double? { latestHrv.map { Double($0.rmssd) } }

    var chestSamples: [Double] { chestTrace.map { Double($0.value) } }

    var dominantExpression: (type: ExpressionType, confidence: Double)? {
        guard let top = expressionScores.max(by: { $0.confidence < $1.confidence }) else { return nil }
        return (top.type, Self.percent(top.confidence))
    }

    var pulseConfidence: Double? { pulse.last.map { Self.percent($0.confidence) } }

    private static func recentAverage(_ values: [MeasurementWithConfidence], count: Int) -> Double? {
        let good = values.suffix(count).filter { percent($0.confidence) >= minConfidence }
        guard !good.isEmpty else { return nil }
        return good.map { Double($0.value) }.reduce(0, +) / Double(good.count)
    }

    /// The SDK reports confidence on a 0–100 scale; normalise defensively in case a 0–1 value appears.
    static func percent(_ confidence: Float) -> Double {
        guard confidence.isFinite else { return 0 }
        let v = Double(confidence)
        return min(max(v <= 1 ? v * 100 : v, 0), 100)
    }
}

/// A snapshot used to compare "before" and "after" on the summary screen. Kept in memory only.
struct VitalsSnapshot {
    var pulse: Double?
    var breathingRate: Double?
    var hrv: Double?

    init(_ store: VitalsStore) {
        pulse = store.currentPulse
        breathingRate = store.currentBreathingRate
        hrv = store.currentHrv
    }
}
