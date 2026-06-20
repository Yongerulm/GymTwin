import SwiftUI

// MARK: - WorkoutControlStepper

/// Large one-handed stepper: big minus/plus buttons flanking a monospaced
/// value. Designed for use mid-workout with sweaty or gloved hands.
struct WorkoutControlStepper: View {
    let label: String
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    let unit: String
    var format: ((Double) -> String)?

    private var displayValue: String {
        if let format { return format(value) }
        // Trim trailing ".0" for whole numbers
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%g", value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: DS.Spacing.md) {
                // Minus button
                StepButton(systemImage: "minus", tint: DS.Palette.accent) {
                    let next = (value - step)
                    if next >= range.lowerBound {
                        value = next
                    }
                }

                // Value display
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                    Text(displayValue)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .frame(minWidth: 72, alignment: .center)
                    Text(unit)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Plus button
                StepButton(systemImage: "plus", tint: DS.Palette.accent) {
                    let next = (value + step)
                    if next <= range.upperBound {
                        value = next
                    }
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(label): \(displayValue) \(unit)")
    }
}

/// Internal large circular step button.
private struct StepButton: View {
    let systemImage: String
    let tint: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 56, height: 56)
                .background(tint.opacity(0.14), in: Circle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.6), trigger: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .scaleEffect(isPressed ? 0.93 : 1)
        .animation(DS.Motion.snappy, value: isPressed)
    }
}

// MARK: - RestTimerView

/// Self-contained rest timer: countdown ring, mm:ss display, play/pause,
/// reset, and +15 s. Manages its own @State timer via a 1-second Task loop.
struct RestTimerView: View {
    /// Configured rest length (persisted by the parent). Adjustable while idle
    /// to set the preferred default; flexible down to 15 s.
    @Binding var durationSeconds: Int
    var onFinished: (() -> Void)?
    /// Called when the user skips the rest to jump straight to the next set.
    var onSkip: (() -> Void)?

    @State private var remaining: Int
    @State private var isRunning: Bool = false
    @State private var timerTask: Task<Void, Never>?
    @State private var didFinish: Bool = false

    private static let minDuration = 15
    private static let maxDuration = 600
    private static let maxRemaining = 900

    init(durationSeconds: Binding<Int>, onFinished: (() -> Void)? = nil, onSkip: (() -> Void)? = nil) {
        _durationSeconds = durationSeconds
        self.onFinished = onFinished
        self.onSkip = onSkip
        _remaining = State(initialValue: durationSeconds.wrappedValue)
    }

    private var progress: Double {
        guard durationSeconds > 0 else { return 0 }
        return Double(remaining) / Double(durationSeconds)
    }

    private var timeString: String {
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            // Ring + time
            ZStack {
                // Track
                Circle()
                    .stroke(.white.opacity(0.07), lineWidth: 8)

                // Progress arc
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        AngularGradient(
                            colors: [DS.Palette.rest, DS.Palette.rest.opacity(0.4)],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(DS.Motion.spring, value: remaining)

                VStack(spacing: 2) {
                    Text(timeString)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(remaining == 0 ? DS.Palette.success : .primary)
                    Text("REST")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .kerning(1.5)
                }
            }
            .frame(width: 140, height: 140)

            // Main controls: −15 s · play/pause · +15 s
            HStack(spacing: DS.Spacing.xl) {
                // −15 s (trims the current rest, or lowers the default when idle)
                TimerControlButton(systemImage: "minus", label: "−15 s") { adjust(-15) }

                // Play / Pause
                Button {
                    togglePlay()
                } label: {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(DS.Palette.rest, in: Circle())
                        .shadow(color: DS.Palette.rest.opacity(0.40), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRunning ? "Pause timer" : "Start timer")
                .scaleEffect(isRunning ? 1 : 0.97)
                .animation(DS.Motion.snappy, value: isRunning)

                // +15 s
                TimerControlButton(systemImage: "plus", label: "+15 s") { adjust(15) }
            }

            // Secondary row: reset · skip
            HStack(spacing: DS.Spacing.md) {
                Button {
                    stopTimer()
                    remaining = durationSeconds
                    didFinish = false
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(.white.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset rest timer")

                Button {
                    stopTimer()
                    onSkip?()
                } label: {
                    Label("Skip Rest", systemImage: "forward.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Palette.rest, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip rest and continue to the next set")
            }
        }
        .padding(DS.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
        .sensoryFeedback(.success, trigger: didFinish)
        .onDisappear { stopTimer() }
        .accessibilityElement(children: .contain)
    }

    private func togglePlay() {
        if isRunning {
            stopTimer()
        } else {
            if remaining == 0 { remaining = durationSeconds; didFinish = false }
            startTimer()
        }
    }

    /// While running: extend/trim the current rest by `delta` seconds.
    /// While idle: change the configured (persisted) rest length, flexible
    /// down to 15 s, and reset the countdown to it.
    private func adjust(_ delta: Int) {
        if isRunning {
            remaining = max(0, min(remaining + delta, Self.maxRemaining))
            if remaining == 0 {
                stopTimer()
                didFinish = true
                onFinished?()
            }
        } else {
            durationSeconds = max(Self.minDuration, min(durationSeconds + delta, Self.maxDuration))
            remaining = durationSeconds
            didFinish = false
        }
    }

    private func startTimer() {
        guard !isRunning else { return }
        isRunning = true
        timerTask = Task { @MainActor in
            while remaining > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                remaining -= 1
                if remaining == 0 {
                    isRunning = false
                    didFinish = true
                    onFinished?()
                    break
                }
            }
            isRunning = false
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        isRunning = false
    }
}

/// Small secondary control button for the timer's reset and +15s.
private struct TimerControlButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.xxs) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.07), in: Circle())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Previews

#Preview("WorkoutControlStepper") {
    struct Demo: View {
        @State private var weight = 57.5
        @State private var reps = 10.0

        var body: some View {
            VStack(spacing: DS.Spacing.md) {
                WorkoutControlStepper(
                    label: "Weight",
                    value: $weight,
                    step: 2.5,
                    range: 0...300,
                    unit: "kg"
                )
                WorkoutControlStepper(
                    label: "Reps",
                    value: $reps,
                    step: 1,
                    range: 1...50,
                    unit: "reps",
                    format: { "\(Int($0))" }
                )
            }
            .padding()
        }
    }
    return Demo().preferredColorScheme(.dark)
}

#Preview("RestTimerView") {
    struct Demo: View {
        @State private var duration = 90
        var body: some View {
            RestTimerView(durationSeconds: $duration, onFinished: {}, onSkip: {})
                .padding()
        }
    }
    return Demo().preferredColorScheme(.dark)
}
