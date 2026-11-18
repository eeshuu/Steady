import SwiftUI

/// Before/after comparison. Held in memory only; "Done" discards it.
struct SummaryView: View {
    let before: VitalsSnapshot?
    let after: VitalsSnapshot?
    let duration: TimeInterval
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("You took \(minutesText) for yourself.")
                    .font(.title2.weight(.semibold))
                Text("Here's how your signals moved. Any direction is okay.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            VStack(spacing: 12) {
                CompareRow(label: "Breathing", unit: "/min",
                           before: before?.breathingRate, after: after?.breathingRate)
                CompareRow(label: "Pulse", unit: "bpm",
                           before: before?.pulse, after: after?.pulse)
                CompareRow(label: "HRV (RMSSD)", unit: "ms",
                           before: before?.hrv, after: after?.hrv)
            }

            Label("Wellness estimates from the camera, not medical measurements.",
                  systemImage: "info.circle")
                .font(.footnote).foregroundStyle(.secondary)

            Spacer()

            Label("Nothing from this session is saved. Tapping Done clears it.",
                  systemImage: "lock")
                .font(.footnote).foregroundStyle(.secondary)

            Button(action: onDone) {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.teal, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.black)
            }
        }
        .padding(20)
        .foregroundStyle(.white)
    }

    private var minutesText: String {
        let m = Int((duration / 60).rounded())
        return m <= 1 ? "a minute" : "\(m) minutes"
    }
}

private struct CompareRow: View {
    let label: String
    let unit: String
    let before: Double?
    let after: Double?

    var body: some View {
        HStack {
            Text(label).font(.subheadline.weight(.semibold))
            Spacer()
            Text(format(before)).foregroundStyle(.secondary)
            Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
            Text(format(after)).font(.title3.weight(.bold)).monospacedDigit()
            Text(unit).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(format(before)) before, \(format(after)) after, \(unit)")
    }

    private func format(_ v: Double?) -> String {
        v.map { "\(Int($0.rounded()))" } ?? "--"
    }
}
