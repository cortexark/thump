// ThumpBuddyAnimations.swift
// ThumpCore
//
// Animation state machine for ThumpBuddy. Applies Disney's 12 principles:
// — Squash & Stretch: asymmetric X/Y breathing
// — Anticipation: crouch before bounce
// — Follow-through: pupils overshoot, multi-position gaze chains
// — Slow in/slow out: spring + easeOut curves
// — Exaggeration: amplitudes tuned for 80px watch scale
// — Secondary action: idle fidgets, double-blinks, head tilts
//
// All organic animations use Task loops with timing jitter
// to break metronomic feel. No two cycles are identical.
//
// Platforms: iOS 17+, watchOS 10+

import SwiftUI

// MARK: - Animation Constants

/// Central timing and amplitude values for buddy animations.
enum BuddyAnimationConfig {

    // MARK: - Breathing

    static func breathDuration(for mood: BuddyMood) -> Double {
        switch mood {
        case .stressed:    return 1.4
        case .tired:       return 3.2
        case .celebrating: return 1.0
        case .thriving:    return 1.6
        case .active:      return 0.7
        case .conquering:  return 1.1
        default:           return 2.2
        }
    }

    /// Vertical expansion on inhale. X-axis compresses by the inverse
    /// to create squash-and-stretch (soft, fleshy feel).
    static func breathAmplitude(for mood: BuddyMood) -> CGFloat {
        switch mood {
        case .stressed:    return 1.06
        case .celebrating: return 1.08
        case .tired:       return 1.025
        case .thriving:    return 1.06
        case .active:      return 1.08
        case .conquering:  return 1.09
        default:           return 1.04
        }
    }

    // MARK: - Glow Pulse

    static func glowPulseRange(for mood: BuddyMood) -> ClosedRange<CGFloat> {
        switch mood {
        case .thriving:    return 0.85...1.15
        case .celebrating: return 0.9...1.2
        case .stressed:    return 0.92...1.08
        case .active:      return 0.8...1.2
        case .conquering:  return 0.85...1.2
        default:           return 0.95...1.05
        }
    }

    static func glowPulseDuration(for mood: BuddyMood) -> Double {
        switch mood {
        case .active:      return 0.6
        case .celebrating: return 0.9
        case .stressed:    return 1.0
        default:           return 2.0
        }
    }
}

// MARK: - Animation State

/// Observable animation state that drives all buddy visuals.
/// Owned by ThumpBuddy and passed to child views.
@Observable
final class BuddyAnimationState {

    // MARK: - Breathing (squash & stretch)

    /// Horizontal scale — compresses on inhale for soft squash effect.
    var breatheScaleX: CGFloat = 1.0
    /// Vertical scale — expands on inhale.
    var breatheScaleY: CGFloat = 1.0

    /// Single-axis scale for backward compatibility with effects (circles).
    /// Returns the vertical component since it's the dominant axis.
    var breatheScale: CGFloat { breatheScaleY }

    // MARK: - Movement

    var bounceOffset: CGFloat = 0
    var wiggleAngle: Double = 0
    /// Rotation from idle fidgets (head tilts, leans).
    var fidgetRotation: Double = 0
    /// Vertical offset from idle fidgets (tiny hops).
    var fidgetOffsetY: CGFloat = 0

    // MARK: - Mood Body Shape (ThumpBuddy inflate/deflate)

    /// Mood-driven scale — thriving=tall/muscular, tired=wide/deflated.
    var moodScaleX: CGFloat = 1.0
    var moodScaleY: CGFloat = 1.0
    /// Mood-driven forward lean (nudging leans forward, tired slumps).
    var moodTilt: Double = 0
    /// Mood-driven vertical shift (tired sinks, thriving rises).
    var moodOffsetY: CGFloat = 0

    // MARK: - Mood Action Props

    /// Blanket coverage 0–1 for tired mood (rises from bottom of sphere).
    var blanketCoverage: CGFloat = 0
    /// Marching weight-shift phase for nudging mood.
    var marchTilt: Double = 0
    /// Horizontal drift for walking/running.
    var horizontalDrift: CGFloat = 0
    /// Sweat drop visibility for stressed.
    var sweatDrop: Bool = false
    /// Flex angle for thriving arms (0 = relaxed, ~20 = flexed).
    var flexAngle: Double = 0

    // MARK: - Eyes

    var eyeBlink: Bool = false
    /// Whether eyes should show happy squint (^_^) — thriving, celebrating, conquering.
    var eyeSquint: Bool = false
    var pupilLookX: CGFloat = 0
    var pupilLookY: CGFloat = 0

    // MARK: - Effects

    var sparkleRotation: Double = 0
    var floatingHeartOffset: CGFloat = 0
    var floatingHeartOpacity: Double = 0.9
    var confettiActive: Bool = false
    /// Incremented to force confetti view recreation for repeating bursts.
    var confettiGeneration: Int = 0
    var haloPhase: Double = 0
    var energyPulse: CGFloat = 1.0
    var glowPulse: CGFloat = 1.0
    var innerLightPhase: Double = 0

    // MARK: - Entrance

    /// Starts near zero; springs to 1.0 on first appear for elastic pop-in.
    var entranceScale: CGFloat = 0.001

    // MARK: - Task Management

    /// All organic animation tasks. Cancelled and replaced on mood change.
    private var animationTasks: [Task<Void, Never>] = []

    // MARK: - Start All

    func startAnimations(mood: BuddyMood, size: CGFloat) {
        // Cancel all previous organic animation tasks to prevent accumulation
        for task in animationTasks { task.cancel() }
        animationTasks.removeAll()

        // Reset all mood-specific states before applying new mood
        resetMoodStates()

        // Core animations (always running)
        startBreathing(mood: mood)
        startBlinking(mood: mood)
        startMicroExpressions(size: size)
        startIdleFidgets(size: size)
        // innerLightPhase rotation removed — caused flickering ring artifact
        startGlowPulse(mood: mood)

        // Mood body shape — ThumpBuddy inflate/deflate
        applyMoodBodyShape(mood: mood, size: size)

        // Mood-specific ACTION sequences
        switch mood {
        case .thriving:
            startJoyBounce(size: size)
            startFloatingHeart(size: size)
            startEnergyPulse()
            startHaloRotation()

        case .content:
            startPeacefulSway(size: size)
            startHaloRotation()

        case .nudging:
            startMarching(size: size)

        case .stressed:
            startStressPacing(size: size)

        case .tired:
            startSleeping(size: size)

        case .celebrating:
            startDancing(size: size)
            startSparkleRotation()
            startConfetti()

        case .active:
            startRunning(size: size)
            startEnergyPulse()

        case .conquering:
            startVictoryPose(size: size)
            startSparkleRotation()
            startConfetti()
            startHaloRotation()
        }

        // Elastic entrance (only on first appear)
        if entranceScale < 0.5 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                entranceScale = 1.0
            }
        }
    }

    // MARK: - Reset

    private func resetMoodStates() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            bounceOffset = 0
            wiggleAngle = 0
            marchTilt = 0
            horizontalDrift = 0
            moodTilt = 0
            moodOffsetY = 0
            blanketCoverage = 0
            sweatDrop = false
            eyeSquint = false
            flexAngle = 0
        }
    }

    // MARK: - Mood Body Shape
    //
    // Like ThumpBuddy inflating/deflating. Each mood gets a distinct
    // body proportion that tells the story at a glance.

    private func applyMoodBodyShape(mood: BuddyMood, size: CGFloat) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
            switch mood {
            case .thriving:
                // Tall, proud, chest-out — "muscular ThumpBuddy"
                moodScaleX = 0.95
                moodScaleY = 1.08
                moodOffsetY = -size * 0.02

            case .content:
                // Relaxed, natural, centered
                moodScaleX = 1.0
                moodScaleY = 1.0
                moodOffsetY = 0

            case .nudging:
                // Leaning forward, determined — about to march
                moodScaleX = 0.97
                moodScaleY = 1.03
                moodTilt = -5
                moodOffsetY = -size * 0.01

            case .stressed:
                // Slightly compressed, tense
                moodScaleX = 1.04
                moodScaleY = 0.96
                moodOffsetY = size * 0.01

            case .tired:
                // Initial shape before lying down — startSleeping overrides these
                moodScaleX = 1.0
                moodScaleY = 1.0
                moodOffsetY = 0

            case .celebrating:
                // Puffed up, excited
                moodScaleX = 1.04
                moodScaleY = 1.06
                moodOffsetY = -size * 0.03

            case .active:
                // Tall, forward lean — running posture
                moodScaleX = 0.93
                moodScaleY = 1.1
                moodTilt = -8
                moodOffsetY = -size * 0.02

            case .conquering:
                // Biggest puff — victory inflation
                moodScaleX = 1.06
                moodScaleY = 1.1
                moodOffsetY = -size * 0.04
            }
        }
    }

    // MARK: - Breathing
    //
    // Asymmetric timing: inhale is faster (40% of cycle), exhale is slower (60%).
    // Squash & stretch: Y expands while X compresses (soft, fleshy body).
    // Timing jitter: ±10% variation each cycle breaks metronomic feel.

    private func startBreathing(mood: BuddyMood) {
        let task = Task { @MainActor in
            while !Task.isCancelled {
                let baseDuration = BuddyAnimationConfig.breathDuration(for: mood)
                let amplitude = BuddyAnimationConfig.breathAmplitude(for: mood)
                let jitter = Double.random(in: 0.9...1.1)

                // Inhale — faster, stretch Y, squeeze X
                let inhaleDuration = baseDuration * 0.4 * jitter
                withAnimation(.easeOut(duration: inhaleDuration)) {
                    breatheScaleY = amplitude
                    breatheScaleX = 2.0 - amplitude
                }
                try? await Task.sleep(for: .seconds(inhaleDuration))
                guard !Task.isCancelled else { return }

                // Exhale — slower, return to rest
                let exhaleDuration = baseDuration * 0.6 * jitter
                withAnimation(.easeIn(duration: exhaleDuration)) {
                    breatheScaleY = 1.0
                    breatheScaleX = 1.0
                }
                try? await Task.sleep(for: .seconds(exhaleDuration))
            }
        }
        animationTasks.append(task)
    }

    // MARK: - Blinking
    //
    // Randomized interval (2.5–5.5s). Two special behaviors:
    // — Slow blink: 30% chance when tired (trust/drowsiness signal)
    // — Double-blink: 25% chance otherwise (natural human reflex)

    private func startBlinking(mood: BuddyMood) {
        // Tired: eyes close in startSleeping and stay closed — skip blink loop
        guard mood != .tired else { return }
        let task = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.5...5.5)))
                guard !Task.isCancelled else { return }

                let isSlowBlink = mood == .tired && Double.random(in: 0...1) < 0.3
                let closeTime = isSlowBlink ? 0.2 : 0.08
                let holdTime = isSlowBlink ? 0.3 : 0.04
                let openTime = isSlowBlink ? 0.25 : 0.08

                withAnimation(.easeInOut(duration: closeTime)) { eyeBlink = true }
                try? await Task.sleep(for: .seconds(closeTime + holdTime))
                withAnimation(.easeInOut(duration: openTime)) { eyeBlink = false }

                // Double-blink
                if !isSlowBlink && Double.random(in: 0...1) < 0.25 {
                    try? await Task.sleep(for: .seconds(0.22))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.07)) { eyeBlink = true }
                    try? await Task.sleep(for: .seconds(0.1))
                    withAnimation(.easeInOut(duration: 0.07)) { eyeBlink = false }
                }
            }
        }
        animationTasks.append(task)
    }

    // MARK: - Pupil Micro-Saccades
    //
    // Multi-axis (X + Y). Chains 1–3 gaze positions before returning,
    // like real eyes scanning an environment. Fast saccade timing
    // (60–120ms) mimics actual eye movement speed.

    private func startMicroExpressions(size: CGFloat) {
        let task = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.0...4.5)))
                guard !Task.isCancelled else { return }

                let chainLength = Int.random(in: 1...3)
                for _ in 0..<chainLength {
                    guard !Task.isCancelled else { return }
                    let lookX = CGFloat.random(in: -size * 0.03...size * 0.03)
                    let lookY = CGFloat.random(in: -size * 0.015...size * 0.015)
                    withAnimation(.easeOut(duration: Double.random(in: 0.06...0.12))) {
                        pupilLookX = lookX
                        pupilLookY = lookY
                    }
                    try? await Task.sleep(for: .seconds(Double.random(in: 0.6...1.8)))
                }

                withAnimation(.easeInOut(duration: 0.25)) {
                    pupilLookX = 0
                    pupilLookY = 0
                }
            }
        }
        animationTasks.append(task)
    }

    // MARK: - Bounce (with anticipation)
    //
    // Disney anticipation: brief crouch downward before springing up.
    // Spring physics for overshoot and natural settle.

    private func startBounce(size: CGFloat) {
        let task = Task { @MainActor in
            while !Task.isCancelled {
                let jitter = Double.random(in: 0.85...1.15)

                // Anticipation: slight crouch
                withAnimation(.easeIn(duration: 0.12)) {
                    bounceOffset = size * 0.015
                }
                try? await Task.sleep(for: .seconds(0.12))
                guard !Task.isCancelled else { return }

                // Spring upward
                withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) {
                    bounceOffset = -size * 0.06
                }
                try? await Task.sleep(for: .seconds(0.45 * jitter))
                guard !Task.isCancelled else { return }

                // Settle
                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                    bounceOffset = 0
                }
                try? await Task.sleep(for: .seconds(0.35 * jitter))
            }
        }
        animationTasks.append(task)
    }

    // MARK: - Wiggle (asymmetric, jittered)
    //
    // Each oscillation varies in angle and speed. One side swings
    // wider than the other (asymmetry = organic).

    private func startWiggle() {
        let task = Task { @MainActor in
            while !Task.isCancelled {
                let angle = Double.random(in: 3.0...5.0)
                let duration = Double.random(in: 0.25...0.4)
                withAnimation(.easeInOut(duration: duration)) {
                    wiggleAngle = angle
                }
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: duration)) {
                    wiggleAngle = -angle * Double.random(in: 0.7...1.0)
                }
                try? await Task.sleep(for: .seconds(duration))
            }
        }
        animationTasks.append(task)
    }

    // MARK: - Idle Fidgets
    //
    // Surprise micro-movements every 12–25 seconds that break the
    // ambient loop. Three types: head tilt (curiosity), tiny hop
    // (playfulness), subtle lean (weight shift). Creates inner life.

    private func startIdleFidgets(size: CGFloat) {
        let task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Double.random(in: 8...15)))

            while !Task.isCancelled {
                guard !Task.isCancelled else { return }
                let fidgetType = Int.random(in: 0...2)

                switch fidgetType {
                case 0:
                    // Head tilt
                    let angle = Double.random(in: 3...6) * (Bool.random() ? 1.0 : -1.0)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        fidgetRotation = angle
                    }
                    try? await Task.sleep(for: .seconds(Double.random(in: 1.5...2.5)))
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        fidgetRotation = 0
                    }

                case 1:
                    // Tiny hop
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                        fidgetOffsetY = -size * 0.025
                    }
                    try? await Task.sleep(for: .seconds(0.3))
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.55)) {
                        fidgetOffsetY = 0
                    }

                default:
                    // Weight shift
                    withAnimation(.easeInOut(duration: 0.7)) {
                        fidgetRotation = Double.random(in: -3.5...3.5)
                    }
                    try? await Task.sleep(for: .seconds(1.2))
                    withAnimation(.easeInOut(duration: 0.9)) {
                        fidgetRotation = 0
                    }
                }

                try? await Task.sleep(for: .seconds(Double.random(in: 12...25)))
            }
        }
        animationTasks.append(task)
    }

    // MARK: - Sparkle Rotation

    private func startSparkleRotation() {
        sparkleRotation = 0
        withAnimation(.linear(duration: 6.0).repeatForever(autoreverses: false)) {
            sparkleRotation = 360
        }
    }

    // MARK: - Floating Heart (randomized cooldown)

    private func startFloatingHeart(size: CGFloat) {
        let task = Task { @MainActor in
            while !Task.isCancelled {
                floatingHeartOffset = 0
                floatingHeartOpacity = 0.9
                withAnimation(.easeOut(duration: 2.0)) {
                    floatingHeartOffset = -size * 0.22
                    floatingHeartOpacity = 0.0
                }
                try? await Task.sleep(for: .seconds(Double.random(in: 2.5...4.0)))
            }
        }
        animationTasks.append(task)
    }

    // MARK: - Energy Pulse

    private func startEnergyPulse() {
        energyPulse = 1.0
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            energyPulse = 1.06
        }
    }

    // MARK: - Halo Rotation

    private func startHaloRotation() {
        haloPhase = 0
        withAnimation(.linear(duration: 12.0).repeatForever(autoreverses: false)) {
            haloPhase = 360
        }
    }

    // MARK: - Confetti (repeating bursts for sustained celebration)

    private func startConfetti() {
        let task = Task { @MainActor in
            while !Task.isCancelled {
                confettiGeneration += 1
                confettiActive = true
                try? await Task.sleep(for: .seconds(Double.random(in: 4.0...6.0)))
                guard !Task.isCancelled else { return }
                confettiActive = false
                try? await Task.sleep(for: .seconds(0.05))
            }
        }
        animationTasks.append(task)
    }

    // MARK: - Glow Pulse (jittered)

    private func startGlowPulse(mood: BuddyMood) {
        let range = BuddyAnimationConfig.glowPulseRange(for: mood)
        let baseDuration = BuddyAnimationConfig.glowPulseDuration(for: mood)

        let task = Task { @MainActor in
            while !Task.isCancelled {
                let jitter = Double.random(in: 0.85...1.15)
                withAnimation(.easeInOut(duration: baseDuration * jitter)) {
                    glowPulse = range.upperBound
                }
                try? await Task.sleep(for: .seconds(baseDuration * jitter))
                guard !Task.isCancelled else { return }

                let jitter2 = Double.random(in: 0.85...1.15)
                withAnimation(.easeInOut(duration: baseDuration * jitter2)) {
                    glowPulse = range.lowerBound
                }
                try? await Task.sleep(for: .seconds(baseDuration * jitter2))
            }
        }
        animationTasks.append(task)
    }

    // MARK: - Inner Light Rotation

    private func startInnerLightRotation() {
        innerLightPhase = 0
        withAnimation(.linear(duration: 20.0).repeatForever(autoreverses: false)) {
            innerLightPhase = 360
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - MOOD ACTION SEQUENCES
    // Each mood tells a visual STORY through body movement + props.
    // ═══════════════════════════════════════════════════════════════

    // MARK: - Thriving: Joy Bounce
    // Happy hops with brief hang time at peak. Eyes squint (^_^).

    private func startJoyBounce(size: CGFloat) {
        let task = Task { @MainActor in
            while !Task.isCancelled {
                let jitter = Double.random(in: 0.9...1.1)

                // Bodybuilder pose 1: Wind up
                withAnimation(.easeIn(duration: 0.2)) {
                    bounceOffset = size * 0.02
                    flexAngle = 0  // arms down
                }
                try? await Task.sleep(for: .seconds(0.2))
                guard !Task.isCancelled else { return }

                // POWER FLEX — arms curl up hard
                withAnimation(.spring(response: 0.25, dampingFraction: 0.3)) {
                    bounceOffset = -size * 0.08
                    flexAngle = 30  // full bodybuilder flex
                    moodScaleX = 1.0  // puff out chest
                }
                try? await Task.sleep(for: .seconds(0.6))
                guard !Task.isCancelled else { return }

                // Hold the flex — pump twice
                withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                    flexAngle = 20
                }
                try? await Task.sleep(for: .seconds(0.25))
                guard !Task.isCancelled else { return }

                withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                    flexAngle = 35  // even bigger second pump
                }
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { return }

                // Relax — land
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    bounceOffset = 0
                    flexAngle = 10
                    moodScaleX = 0.95
                }
                try? await Task.sleep(for: .seconds(0.7 * jitter))
            }
        }
        animationTasks.append(task)
    }

    // MARK: - Content: Peaceful Sway
    // Gentle side-to-side like a metronome. Calm, centered.

    private func startPeacefulSway(size: CGFloat) {
        let task = Task { @MainActor in
            while !Task.isCancelled {
                let jitter = Double.random(in: 0.9...1.1)
                let angle = Double.random(in: 2.5...4.0)

                withAnimation(.easeInOut(duration: 2.0 * jitter)) {
                    fidgetRotation = angle
                    horizontalDrift = size * 0.01
                }
                try? await Task.sleep(for: .seconds(2.0 * jitter))
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 2.0 * jitter)) {
                    fidgetRotation = -angle * 0.8
                    horizontalDrift = -size * 0.01
                }
                try? await Task.sleep(for: .seconds(2.0 * jitter))
            }
        }
        animationTasks.append(task)
    }

    // MARK: - Nudging: Marching
    // Determined left-right weight shift like walking in place.
    // Leans forward. Eyes look ahead.

    private func startMarching(size: CGFloat) {
        let task = Task { @MainActor in
            while !Task.isCancelled {
                // Step left: lean left + lift
                withAnimation(.easeInOut(duration: 0.3)) {
                    marchTilt = -12
                    bounceOffset = -size * 0.04
                    horizontalDrift = -size * 0.015
                }
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }

                // Land left
                withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) {
                    bounceOffset = size * 0.01
                }
                try? await Task.sleep(for: .seconds(0.15))
                guard !Task.isCancelled else { return }

                // Step right: lean right + lift
                withAnimation(.easeInOut(duration: 0.3)) {
                    marchTilt = 12
                    bounceOffset = -size * 0.04
                    horizontalDrift = size * 0.015
                }
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }

                // Land right
                withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) {
                    bounceOffset = size * 0.01
                }
                try? await Task.sleep(for: .seconds(0.15))
            }
        }
        animationTasks.append(task)
    }

    // MARK: - Stressed: Stress Pacing
    // Rapid shaking + wider eyes + sweat drop appearance.
    // Anxious energy, can't sit still.

    private func startStressPacing(size: CGFloat) {
        // Sweat drop appears
        let task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.easeIn(duration: 0.3)) { sweatDrop = true }
        }
        animationTasks.append(task)

        // Rapid shaking — faster and more intense than old wiggle
        let shakeTask = Task { @MainActor in
            while !Task.isCancelled {
                let angle = Double.random(in: 4.0...7.0)
                let duration = Double.random(in: 0.15...0.25)
                withAnimation(.easeInOut(duration: duration)) {
                    wiggleAngle = angle
                    horizontalDrift = size * 0.008
                }
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: duration)) {
                    wiggleAngle = -angle * Double.random(in: 0.8...1.0)
                    horizontalDrift = -size * 0.008
                }
                try? await Task.sleep(for: .seconds(duration))
            }
        }
        animationTasks.append(shakeTask)
    }

    // MARK: - Tired: Sleeping (ThumpBuddy Lying in Bed)
    // ThumpBuddy tips over to lie flat, sinks down, blanket pulls over.
    // Blanket is same color as body — like a warm comforter.
    // The most dramatic transformation — "low battery ThumpBuddy."

    private func startSleeping(size: CGFloat) {
        let task = Task { @MainActor in
            // Phase 1: Tip over and rest ON the cot
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                moodTilt = 75  // lie down on right side
                moodOffsetY = size * 0.05  // rest on cot surface
                moodScaleY = 0.88  // flatten slightly — deflated
                moodScaleX = 1.08  // wider when lying
            }
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled else { return }

            // Close eyes and keep them closed — sleeping
            withAnimation(.easeInOut(duration: 0.4)) {
                eyeBlink = true
            }
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }

            // Phase 2: Pull blanket up
            withAnimation(.easeInOut(duration: 1.8)) {
                blanketCoverage = 0.5
            }
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }

            // Phase 3: Snuggle in — blanket covers more
            withAnimation(.easeInOut(duration: 1.5)) {
                blanketCoverage = 0.7
                moodOffsetY = size * 0.08
            }

            // Phase 4: Gentle sleeping breathing — slow rise/fall
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 3.5...5.5)))
                guard !Task.isCancelled else { return }

                // Slow sleepy sigh — tiny upward shift
                withAnimation(.easeInOut(duration: 1.2)) {
                    fidgetOffsetY = -size * 0.01
                }
                try? await Task.sleep(for: .seconds(1.5))

                // Settle back
                withAnimation(.easeInOut(duration: 1.5)) {
                    fidgetOffsetY = 0
                }
            }
        }
        animationTasks.append(task)
    }

    // MARK: - Celebrating: Dancing
    // Full-body dance — alternating spins with bounces.

    private func startDancing(size: CGFloat) {
        let task = Task { @MainActor in
            while !Task.isCancelled {
                let jitter = Double.random(in: 0.85...1.15)

                // Spin one way
                withAnimation(.easeInOut(duration: 0.4)) {
                    wiggleAngle = 15
                    bounceOffset = -size * 0.06
                }
                try? await Task.sleep(for: .seconds(0.4))
                guard !Task.isCancelled else { return }

                // Spin other way
                withAnimation(.easeInOut(duration: 0.4)) {
                    wiggleAngle = -15
                    bounceOffset = -size * 0.03
                }
                try? await Task.sleep(for: .seconds(0.4))
                guard !Task.isCancelled else { return }

                // Land and bounce
                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                    wiggleAngle = 0
                    bounceOffset = size * 0.02
                }
                try? await Task.sleep(for: .seconds(0.3))

                // Up again
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    bounceOffset = -size * 0.08
                }
                try? await Task.sleep(for: .seconds(0.5 * jitter))

                // Settle briefly
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    bounceOffset = 0
                }
                try? await Task.sleep(for: .seconds(0.3 * jitter))
            }
        }
        animationTasks.append(task)
    }

    // MARK: - Active: Running
    // Rapid alternating tilt with forward lean.
    // Like legs pumping — fast, energetic.

    private func startRunning(size: CGFloat) {
        let task = Task { @MainActor in
            while !Task.isCancelled {
                // Quick left stride
                withAnimation(.easeInOut(duration: 0.18)) {
                    marchTilt = -10
                    bounceOffset = -size * 0.03
                    horizontalDrift = -size * 0.01
                }
                try? await Task.sleep(for: .seconds(0.18))
                guard !Task.isCancelled else { return }

                // Quick right stride
                withAnimation(.easeInOut(duration: 0.18)) {
                    marchTilt = 10
                    bounceOffset = -size * 0.03
                    horizontalDrift = size * 0.01
                }
                try? await Task.sleep(for: .seconds(0.18))
            }
        }
        animationTasks.append(task)
    }

    // MARK: - Conquering: Victory Pose
    // Puffs up big, holds triumphant, then settles into proud stance.

    private func startVictoryPose(size: CGFloat) {
        let task = Task { @MainActor in
            // Initial power-up puff
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                bounceOffset = -size * 0.08
                moodScaleX = 1.12
                moodScaleY = 1.15
            }
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled else { return }

            // Settle into proud stance
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                bounceOffset = -size * 0.03
                moodScaleX = 1.06
                moodScaleY = 1.1
            }

            // Then gentle proud sway
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2...4)))
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 1.0)) {
                    fidgetRotation = Double.random(in: -5...5)
                }
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation(.easeInOut(duration: 1.0)) {
                    fidgetRotation = 0
                }
            }
        }
        animationTasks.append(task)
    }
}
