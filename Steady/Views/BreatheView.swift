import SwiftUI
import SmartSpectra

/// The adaptive breathing exercise. The guide's pace responds to the live breathing
/// rate, the face cue responds to expressions, and the pulse trend is shown gently.
struct BreatheView: View {
    let store: VitalsStore
    let startingRate: Double?
    let baselinePulse: Double?
    var onFinish: () -> Void

    @State private var pacer = BreathPacer()
    @State private var started = Date.now
    @State private var elapsed: TimeInterval = 0
    @State private var hapticsOn = true

    private let suggestedLength: TimeInterval = 120

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text(timeText).font(.headline.monospacedDigit())
                Spacer()
                Button {
                    hapticsOn.toggle()
                } label: {
                    Image(systemName: hapticsOn ? "iphone.radiowaves.left.and.right" : "iphone.slash")
                }
                .accessibilityLabel(hapticsOn ? "Turn off breath haptics" : "Turn on breath haptics")
                SignalChip()
            }

            Spacer(minLength: 0)

            BreathOrb(fill: pacer.fill, phase: pacer.phase)
                .frame(width: 260, height: 260)

            Text(pacer.phase == .inhale ? "Breathe in" : "Breathe out")
                .font(.title.weight(.semibold))
                .contentTransition(.opacity)
                .accessibilityAddTraits(.updatesFrequently)

            Text(pacer.coachingNote)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(minHeight: 40)

            if let cue = faceCue {
                Label(cue, systemImage: "face.smiling")
                    .font(.footnote)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.white.opacity(0.08), in: Capsule())
                    .transition(.opacity)
            }

            Spacer(minLength: 0)

            BreathTraceView(samples: store.chestSamples)
                .frame(height: 54)
                .overlay(alignment: .topLeading) {
                    Text("Your breath (live)")
                        .font(.caption2).foregroundStyle(.secondary)
                }

            HStack(spacing: 12) {
                VitalTile(label: "Breathing", value: store.currentBreathingRate, unit: "/min", tint: .teal)
                VitalTile(label: "Guide", value: pacer.targetRate, unit: "/min", tint: .white)
                VitalTile(label: "Pulse", value: store.currentPulse, unit: "bpm", tint: .pink)
            }

            if let trend = pulseTrend {
                Text(trend).font(.footnote).foregroundStyle(.secondary)
            }

            Button(action: onFinish) {
                Text(elapsed >= suggestedLength ? "Finish — I'm ready" : "Finish")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(elapsed >= suggestedLength ? Color.teal : Color.white.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(elapsed >= suggestedLength ? .black : .white)
            }
        }
        .padding(20)
        .foregroundStyle(.white)
        .animation(.easeInOut(duration: 0.4), value: faceCue)
        .sensoryFeedback(.impact(weight: .light), trigger: pacer.phase) { _, _ in hapticsOn }
        .onAppear {
            started = .now
            pacer.start(fromMeasuredRate: startingRate)
        }
        .task {
            // ~30 fps animation clock for the orb.
            while !Task.isCancelled {
                let now = Date.now
                pacer.tick(now)
                // Gated internally to once every `stepInterval` seconds.
                pacer.adapt(liveRate: store.currentBreathingRate, at: now)
                elapsed = now.timeIntervalSince(started)
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    private var timeText: String {
        let s = Int(elapsed)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Gentle, non-judgemental cue based on the dominant facial expression.
    private var faceCue: String? {
        guard let top = store.dominantExpression, top.confidence >= 55 else { return nil }
        switch top.type {
        case .angry, .disgust, .contempt, .fear, .sad:
            return "Let your jaw and forehead soften."
        case .happy:
            return "That ease suits you. Keep it."
        default:
            return nil
        }
    }

    /// Describes how the pulse has moved since check-in, without judging it.
    private var pulseTrend: String? {
        guard let base = baselinePulse, let now = store.currentPulse, elapsed > 30 else { return nil }
        let delta = Int((now - base).rounded())
        if delta <= -2 { return "Pulse is \(-delta) bpm lower than at check-in." }
        if delta >= 2 { return "Pulse is \(delta) bpm higher than at check-in. Totally fine — keep going." }
        return "Pulse is about the same as at check-in."
    }
}

/// The guide: a soft circle that grows on the inhale and shrinks on the exhale.
struct BreathOrb: View {
    let fill: Double
    let phase: BreathPacer.Phase

    var body: some View {
        let scale = 0.45 + 0.55 * fill
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 1)
            Circle()
                .fill(
                    RadialGradient(colors: [Color.teal.opacity(0.9), Color.teal.opacity(0.25)],
                                   center: .center, startRadius: 4, endRadius: 140)
                )
                .scaleEffect(scale)
                .shadow(color: .teal.opacity(0.5), radius: 30 * fill)
        }
        .accessibilityHidden(true)
    }
}

/// Live chest-motion trace from SmartSpectra, so people can see their own breath.
struct BreathTraceView: View {
    let samples: [Double]

    var body: some View {
        GeometryReader { geo in
            Path { path in
                guard samples.count > 1,
                      let lo = samples.min(), let hi = samples.max() else { return }
                let range = max(hi - lo, 0.0001)
                for (i, v) in samples.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(samples.count - 1)
                    let y = geo.size.height * (1 - CGFloat((v - lo) / range) * 0.8 - 0.1)
                    i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color.teal, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .padding(.top, 14)
        .accessibilityLabel("Live breathing waveform")
    }
}
