import Foundation
import Observation

/// An adaptive breathing guide.
///
/// It starts close to the person's *measured* breathing rate and steps the pace down
/// toward ~6 breaths/min. Every step it checks the live breathing rate from SmartSpectra:
/// if the person can't keep up (they're breathing well above the guide), it holds or
/// eases the pace instead of pushing harder.
@Observable
final class BreathPacer {
    enum Phase { case inhale, exhale }

    static let floorRate = 6.0
    static let ceilingRate = 14.0
    static let stepInterval: TimeInterval = 30

    private(set) var targetRate: Double = 10          // breaths per minute
    private(set) var phase: Phase = .inhale
    /// 0…1 — how "full" the orb should be right now.
    private(set) var fill: Double = 0
    private(set) var coachingNote: String = "Breathe with the circle."

    private var cyclePosition: Double = 0             // 0..<1 through the current breath
    private var lastTick: Date?
    private var lastStep: Date?

    func start(fromMeasuredRate measured: Double?, at date: Date = .now) {
        let start = (measured ?? 10).rounded()
        targetRate = min(max(start, Self.floorRate + 2), Self.ceilingRate)
        cyclePosition = 0
        lastTick = date
        lastStep = date
        coachingNote = "Starting at your own pace — \(Int(targetRate)) breaths a minute."
    }

    /// Advance the animation. Call on every frame.
    func tick(_ date: Date) {
        guard let last = lastTick else { lastTick = date; return }
        let dt = date.timeIntervalSince(last)
        lastTick = date
        let cycleLength = 60 / targetRate
        cyclePosition = (cyclePosition + dt / cycleLength).truncatingRemainder(dividingBy: 1)

        // Inhale ~40% of the breath, exhale ~60% — longer exhales feel calmer.
        let inhaleShare = 0.4
        if cyclePosition < inhaleShare {
            phase = .inhale
            fill = Self.ease(cyclePosition / inhaleShare)
        } else {
            phase = .exhale
            fill = 1 - Self.ease((cyclePosition - inhaleShare) / (1 - inhaleShare))
        }
    }

    /// Re-evaluate the pace against the live breathing rate. Call whenever new readings arrive.
    func adapt(liveRate: Double?, at date: Date = .now) {
        guard let lastStep, date.timeIntervalSince(lastStep) >= Self.stepInterval else { return }
        self.lastStep = date

        guard let live = liveRate else {
            coachingNote = "Holding this pace while the signal settles."
            return
        }

        let gap = live - targetRate
        if gap > 5 {
            targetRate = min(targetRate + 1, Self.ceilingRate)
            coachingNote = "Easing up — follow at whatever pace feels comfortable."
        } else if gap > 2.5 {
            coachingNote = "Staying here a little longer. No rush."
        } else if targetRate > Self.floorRate {
            targetRate = max(targetRate - 1, Self.floorRate)
            coachingNote = "You're in step. Slowing to \(Int(targetRate)) breaths a minute."
        } else {
            coachingNote = "Nice and slow. Stay here as long as you like."
        }
    }

    private static func ease(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        return 0.5 - 0.5 * cos(.pi * x)
    }
}
