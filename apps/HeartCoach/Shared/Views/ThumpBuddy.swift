// ThumpBuddy.swift
// ThumpCore
//
// Premium glassmorphic animated companion. Psychology-driven design:
// — Round shape = instant trust + warmth (Bouba/Kiki effect)
// — Large eyes = 70% of emotional communication in cartoon faces
// — Expression-first = color + eyes + mouth carry mood, no clutter
// — Mood-specific personalities: aggressive energy for activity,
//   peaceful halo for calm, warm coral for stress
// — Glassmorphic sphere with subsurface scattering, specular
//   highlights, and layered depth for premium luxury feel
//
// Inspired by Duolingo Owl simplicity, Gentler Streak universality,
// Finch growth loop, ClassDojo emotional bonds.
//
// Architecture:
// - ThumpBuddySphere.swift  — premium sphere body with glassmorphism
// - ThumpBuddyFace.swift    — eyes, mouth, expressions
// - ThumpBuddyEffects.swift — auras, particles, sparkles
// - ThumpBuddyAnimations.swift — animation state and timing
//
// Platforms: iOS 17+, watchOS 10+

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Buddy Mood

/// Maps health assessment data to a character mood that drives visuals.
enum BuddyMood: String, Equatable, Sendable {
    case thriving
    case content
    case nudging
    case stressed
    case tired
    case celebrating
    /// Mid-activity: animated pushing/running face — shown while goal is in progress
    case active
    /// Goal conquered: triumphant face with flag raised — shown immediately after completion
    case conquering

    // MARK: - Derived from Assessment

    static func from(
        assessment: HeartAssessment,
        readinessScore: Int? = nil,
        nudgeCompleted: Bool = false,
        feedbackType: DailyFeedback? = nil,
        activityInProgress: Bool = false
    ) -> BuddyMood {
        if nudgeCompleted { return .conquering }
        if feedbackType == .positive { return .conquering }
        if activityInProgress { return .active }

        // Use readiness score as primary signal (coherent with Thump Check card).
        // Only show .tired when BOTH anomaly status AND readiness agree the user
        // should rest — prevents "Rest Up" contradicting "Good to go" (BUG-1).
        if let score = readinessScore {
            if score >= 80 { return .thriving }
            if score >= 60 {
                // Moderate-to-good readiness: show content unless stress is high
                return assessment.stressFlag ? .stressed : .content
            }
            if score >= 40 {
                // Below average: nudging toward recovery
                return assessment.stressFlag ? .stressed : .nudging
            }
            // Low readiness (< 40): genuinely tired — BUT only show sleeping
            // mood in evening hours. During daytime, show nudging instead.
            let hour = Calendar.current.component(.hour, from: Date())
            let isEvening = hour >= 20 || hour < 6
            return isEvening ? .tired : .nudging
        }

        // Fallback for nil readiness (first run, no data)
        if assessment.stressFlag { return .stressed }
        if assessment.status == .needsAttention { return .nudging }
        if assessment.status == .improving {
            if let cardio = assessment.cardioScore, cardio >= 70 { return .thriving }
            return .content
        }
        return .nudging
    }

    // MARK: - Visual Properties

    /// Rich gradient for OLED — top highlight -> mid -> deep shadow.
    var bodyColors: [Color] {
        switch self {
        case .thriving:    return [Color(hex: 0xFEF08A), Color(hex: 0xEAB308), Color(hex: 0x854D0E)]
        case .content:     return [Color(hex: 0x6EE7B7), Color(hex: 0x22C55E), Color(hex: 0x15803D)]
        case .nudging:     return [Color(hex: 0xFDE68A), Color(hex: 0xFBBF24), Color(hex: 0xD97706)]
        case .stressed:    return [Color(hex: 0xFDBA74), Color(hex: 0xF97316), Color(hex: 0xC2410C)]
        case .tired:       return [Color(hex: 0xC4B5FD), Color(hex: 0x8B5CF6), Color(hex: 0x6D28D9)]
        case .celebrating: return [Color(hex: 0x6EE7B7), Color(hex: 0x22C55E), Color(hex: 0x15803D)]
        case .active:      return [Color(hex: 0xFCA5A5), Color(hex: 0xEF4444), Color(hex: 0xB91C1C)]
        case .conquering:  return [Color(hex: 0xFEF08A), Color(hex: 0xEAB308), Color(hex: 0x854D0E)]
        }
    }

    var glowColor: Color { bodyColors[1] }
    var labelColor: Color { bodyColors.last ?? .blue }

    /// Specular highlight — lighter, more glass-like.
    var highlightColor: Color {
        switch self {
        case .thriving:    return Color(hex: 0xFEFCBF)
        case .content:     return Color(hex: 0xD1FAE5)
        case .nudging:     return Color(hex: 0xFEF3C7)
        case .stressed:    return Color(hex: 0xFFEDD5)
        case .tired:       return Color(hex: 0xEDE9FE)
        case .celebrating: return Color(hex: 0xD1FAE5)
        case .active:      return Color(hex: 0xFEE2E2)
        case .conquering:  return Color(hex: 0xFEFCBF)
        }
    }

    var badgeIcon: String {
        switch self {
        case .thriving:    return "arrow.up.heart.fill"
        case .content:     return "heart.fill"
        case .nudging:     return "figure.walk"
        case .stressed:    return "flame.fill"
        case .tired:       return "moon.zzz.fill"
        case .celebrating: return "star.fill"
        case .active:      return "figure.run"
        case .conquering:  return "flag.fill"
        }
    }

    var label: String {
        switch self {
        case .thriving:    return "Crushing It"
        case .content:     return "Heart Happy"
        case .nudging:     return "Train Your Heart"
        case .stressed:    return "Take a Breath"
        case .tired:       return "Rest Up"
        case .celebrating: return "Nice Work!"
        case .active:      return "In the Zone"
        case .conquering:  return "Goal Conquered!"
        }
    }
}

// MARK: - Thump Buddy View

/// Premium glassmorphic sphere character with expression-driven mood states.
/// Composes ThumpBuddySphere, ThumpBuddyFace, and ThumpBuddyEffects
/// with shared BuddyAnimationState for coordinated animation.
struct ThumpBuddy: View {

    let mood: BuddyMood
    let size: CGFloat
    /// Set false to hide the ambient aura — useful at small sizes on dark backgrounds.
    let showAura: Bool
    /// Enable tap-to-cycle: tapping the buddy cycles through all moods
    /// with a squish animation and haptic feedback.
    let tappable: Bool

    init(mood: BuddyMood, size: CGFloat = 80, showAura: Bool = true, tappable: Bool = false) {
        self.mood = mood
        self.size = size
        self.showAura = showAura
        self.tappable = tappable
    }

    // MARK: - Animation State

    @State private var anim = BuddyAnimationState()

    // MARK: - Tap Interaction State

    /// Override mood when cycling through taps. nil = use the real mood.
    @State private var tapMoodOverride: BuddyMood?
    /// Tracks which mood index we're at in the cycle (persists across reverts).
    @State private var cycleIndex: Int = 0
    /// Squish scale for tap feedback.
    @State private var tapSquish: CGFloat = 1.0
    /// Speech bubble text shown after tap.
    @State private var speechText: String?
    /// Auto-revert task — cancelled on each new tap.
    @State private var revertTask: Task<Void, Never>?
    /// Pet mode — triggered by long press.
    @State private var isPetting: Bool = false

    /// The mood to display — tap override > real mood.
    /// Pet mode keeps the current mood (doesn't override to content).
    private var displayMood: BuddyMood {
        tapMoodOverride ?? mood
    }

    /// Whether eyes should force-close (blink state) during petting.
    private var petEyesClosed: Bool { isPetting }

    /// All moods in cycle order.
    private static let allMoods: [BuddyMood] = [
        .content, .thriving, .nudging, .active, .stressed, .tired, .celebrating, .conquering
    ]

    /// Mood-aware speech lines — what ThumpBuddy would say.
    private static let speechLines: [BuddyMood: [String]] = [
        .content:     ["All good here", "Balanced day", "Steady as she goes"],
        .thriving:    ["Feeling strong!", "Great energy today", "Let's go!"],
        .nudging:     ["Time to move?", "A walk would help", "Let's get steps in"],
        .active:      ["In the zone!", "Keep it up!", "Heart's pumping"],
        .stressed:    ["Take a breath", "I see the tension", "Let's slow down"],
        .tired:       ["Rest is power", "Zzz... recharging", "Sleep helps everything"],
        .celebrating: ["You did it!", "Goal crushed!", "Party time!"],
        .conquering:  ["Champion mode!", "Unstoppable!", "Victory!"],
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            // Mood-specific aura (suppressed at small sizes)
            if showAura {
                ThumpBuddyAura(mood: displayMood, size: size, anim: anim)
            }

            // Celebration confetti (id forces recreation for repeating bursts)
            if displayMood == .celebrating || displayMood == .conquering {
                ThumpBuddyConfetti(size: size, active: anim.confettiActive)
                    .id(anim.confettiGeneration)
            }

            // Conquering: waving flag raised above buddy
            if displayMood == .conquering {
                ThumpBuddyFlag(size: size, anim: anim)
            }

            // Content: monk-style aurora halo ring orbiting the head
            if displayMood == .content {
                BuddyMonkHalo(mood: displayMood, size: size, anim: anim)
            }

            // Floating heart for thriving
            if displayMood == .thriving {
                ThumpBuddyFloatingHeart(size: size, anim: anim)
            }

            // Thriving: flexing arms BEHIND the sphere (Duolingo wing trick)
            if displayMood == .thriving {
                BuddyFlexArms(mood: displayMood, size: size, anim: anim)
                    .offset(
                        x: anim.horizontalDrift,
                        y: anim.bounceOffset + anim.fidgetOffsetY + anim.moodOffsetY
                    )
            }

            // Main sphere body with face + mood body shape
            ZStack {
                ThumpBuddySphere(mood: displayMood, size: size, anim: anim)
                ThumpBuddyFace(mood: displayMood, size: size, anim: anim)

                // Stressed: sweat drop
                if anim.sweatDrop {
                    BuddySweatDrop(size: size)
                }
            }
            .scaleEffect(
                x: anim.breatheScaleX * anim.moodScaleX,
                y: anim.breatheScaleY * anim.moodScaleY
            )
            .offset(
                x: anim.horizontalDrift,
                y: anim.bounceOffset + anim.fidgetOffsetY + anim.moodOffsetY
            )
            .rotationEffect(.degrees(
                anim.wiggleAngle + anim.fidgetRotation + anim.marchTilt + anim.moodTilt
            ))

            // Celebration sparkles
            if displayMood == .celebrating {
                ThumpBuddySparkles(size: size, anim: anim)
            }

            // Tired: cot with legs — rendered outside rotation so it stays level
            if displayMood == .tired {
                BuddySleepCot(size: size, coverage: anim.blanketCoverage)
                BuddySleepZzz(size: size)
            }
        }
        .scaleEffect(tapSquish)
        .scaleEffect(anim.entranceScale)
        .overlay(alignment: .top) {
            // Speech bubble — appears on tap, fades out
            if let text = speechText {
                Text(text)
                    .font(.system(size: size * 0.14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, size * 0.12)
                    .padding(.vertical, size * 0.06)
                    .background(
                        Capsule().fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 4)
                    )
                    .offset(y: -size * 0.15)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity).combined(with: .offset(y: 10)),
                        removal: .opacity
                    ))
            }
        }
        .frame(width: size * 2.0, height: size * 2.0)
        .contentShape(Circle().scale(0.6))
        .onTapGesture { if tappable { handleTap() } }
        .onLongPressGesture(minimumDuration: 0.5) { if tappable { handlePet() } }
        .onAppear { anim.startAnimations(mood: displayMood, size: size) }
        .onChange(of: displayMood) { _, newMood in anim.startAnimations(mood: newMood, size: size) }
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: displayMood)
        .animation(.spring(response: 0.3), value: speechText != nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Thump buddy feeling \(displayMood.label)")
    }

    // MARK: - Tap to Cycle

    private func handleTap() {
        // Cancel any pending revert
        revertTask?.cancel()
        isPetting = false

        // Haptic
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #elseif canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif

        // Squish bounce
        withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
            tapSquish = 0.85
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                tapSquish = 1.0
            }
        }

        // Advance cycle index (persists even after revert)
        cycleIndex = (cycleIndex + 1) % Self.allMoods.count
        let next = Self.allMoods[cycleIndex]
        tapMoodOverride = next

        // Show speech bubble with random line for this mood
        let lines = Self.speechLines[next] ?? ["Hey!"]
        withAnimation(.spring(response: 0.3)) {
            speechText = lines.randomElement()
        }

        // Schedule revert: mood + speech bubble fade after 4s
        revertTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                tapMoodOverride = nil
                speechText = nil
            }
        }
    }

    // MARK: - Long Press to Pet

    private func handlePet() {
        // Cancel any pending revert but keep current mood
        revertTask?.cancel()

        // Haptic — soft
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #elseif canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif

        // Enter pet mode — eyes close, big inflate, content mood
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            isPetting = true
            tapSquish = 2.08
            anim.eyeBlink = true  // eyes close — happy sigh
        }

        // Show pet speech
        let petLines = ["That feels nice", "Happy to see you", "I'm here for you", "Ahh..."]
        withAnimation(.spring(response: 0.3)) {
            speechText = petLines.randomElement()
        }

        // Release after 1 second
        revertTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isPetting = false
                tapSquish = 1.0
                speechText = nil
                anim.eyeBlink = false  // eyes re-open
            }
        }
    }
}

// MARK: - Custom Shapes

/// Near-perfect sphere with very slight organic squish (95% circle).
/// Echoes the watch face shape. Faster cognitive processing than angular shapes.
struct SphereShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.5, y: 0))

        path.addCurve(
            to: CGPoint(x: w, y: h * 0.48),
            control1: CGPoint(x: w * 0.78, y: 0),
            control2: CGPoint(x: w, y: h * 0.2)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control1: CGPoint(x: w, y: h * 0.78),
            control2: CGPoint(x: w * 0.78, y: h)
        )

        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.48),
            control1: CGPoint(x: w * 0.22, y: h),
            control2: CGPoint(x: 0, y: h * 0.78)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control1: CGPoint(x: 0, y: h * 0.2),
            control2: CGPoint(x: w * 0.22, y: 0)
        )

        path.closeSubpath()
        return path
    }
}

/// Happy squint eye shape — like ^
struct BuddySquintShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: 0)
        )
        return path
    }
}

/// ThumpBuddy happy eye — a crescent/half-moon shape.
/// Top edge curves down (like a smile), bottom is a gentle arc.
/// The result is a squished eye that says "I'm happy" without a mouth.
///
///    ╭───────╮      ← top curves DOWN into the eye
///    │  ◠◠◠  │      ← filled white crescent
///    ╰───────╯      ← bottom curves up slightly
///
struct BuddyHappyEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Start at left edge, vertically centered
        let leftPt = CGPoint(x: 0, y: rect.midY)
        let rightPt = CGPoint(x: rect.maxX, y: rect.midY)

        // Top edge — curves DOWN into the eye (the happy squish)
        // Control point is below midY to push the top lid down
        let topControl = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.15)

        // Bottom edge — gentle upward curve (the lower lid)
        // Control point below to create the crescent opening
        let bottomControl = CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.1)

        path.move(to: leftPt)
        path.addQuadCurve(to: rightPt, control: topControl)
        path.addQuadCurve(to: leftPt, control: bottomControl)
        path.closeSubpath()

        return path
    }
}

/// Blink shape — curved line.
struct BuddyBlinkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

/// Single confetti piece that floats upward.
struct ConfettiPiece: View {
    let index: Int
    let size: CGFloat
    let active: Bool

    @State private var yOffset: CGFloat = 0
    @State private var xDrift: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var rotation: Double = 0

    private var pieceColor: Color {
        let colors: [Color] = [
            Color(hex: 0xFDE047), Color(hex: 0x5EEAD4), Color(hex: 0x34D399),
            Color(hex: 0xFBBF24), Color(hex: 0xA78BFA), Color(hex: 0x38BDF8),
            Color(hex: 0x06B6D4), Color(hex: 0x22C55E),
        ]
        return colors[index % colors.count]
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(pieceColor)
            .frame(width: size * 0.04, height: size * 0.06)
            .rotationEffect(.degrees(rotation))
            .offset(x: xDrift, y: yOffset)
            .opacity(opacity)
            .onAppear {
                guard active else { return }
                let startX = CGFloat.random(in: -size * 0.35...size * 0.35)
                let delay = Double(index) * 0.08
                xDrift = startX
                withAnimation(.easeOut(duration: 2.0).delay(delay)) {
                    yOffset = -size * CGFloat.random(in: 0.5...0.85)
                    xDrift = startX + CGFloat.random(in: -size * 0.15...size * 0.15)
                    opacity = 0
                }
                withAnimation(.linear(duration: 1.8).delay(delay)) {
                    rotation = Double.random(in: -360...360)
                }
                withAnimation(.easeIn(duration: 0.15).delay(delay)) {
                    opacity = 0.9
                }
                withAnimation(.easeOut(duration: 0.6).delay(delay + 1.2)) {
                    opacity = 0
                }
            }
    }
}

// MARK: - Buddy Status Card

/// Complete buddy card with character, mood label, and optional metric.
struct ThumpBuddyCard: View {

    let assessment: HeartAssessment
    let nudgeCompleted: Bool
    let feedbackType: DailyFeedback?

    private var mood: BuddyMood {
        BuddyMood.from(
            assessment: assessment,
            nudgeCompleted: nudgeCompleted,
            feedbackType: feedbackType
        )
    }

    var body: some View {
        VStack(spacing: 4) {
            ThumpBuddy(mood: mood, size: 70)
            moodLabelPill
            cardioScoreRow
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let base = "Your buddy is \(mood.label)"
        if let score = assessment.cardioScore {
            return base + ", cardio score \(Int(score))"
        }
        return base
    }

    private var moodLabelPill: some View {
        let gradient = LinearGradient(
            colors: [mood.labelColor.opacity(0.95), mood.labelColor],
            startPoint: .leading,
            endPoint: .trailing
        )
        return HStack(spacing: 4) {
            Image(systemName: mood.badgeIcon)
                .font(.system(size: 9, weight: .semibold))
                .symbolEffect(.pulse, isActive: mood == .celebrating)
            Text(mood.label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(gradient)
                .shadow(color: mood.labelColor.opacity(0.3), radius: 4, y: 2)
        )
    }

    @ViewBuilder
    private var cardioScoreRow: some View {
        if let score = assessment.cardioScore {
            HStack(spacing: 3) {
                Text("\(Int(score))")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(score))
                Text("cardio")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 2)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 70...:   return .green
        case 40..<70: return .orange
        default:      return .red
        }
    }
}

// MARK: - Breath Prompt Buddy

struct BreathBuddyOverlay: View {

    let nudge: DailyNudge
    let onDismiss: () -> Void

    @State private var isBreathing = false
    @State private var currentMood: BuddyMood = .stressed

    var body: some View {
        VStack(spacing: 12) {
            ThumpBuddy(mood: currentMood, size: 60)
                .scaleEffect(isBreathing ? 1.15 : 0.95)
                .animation(
                    .easeInOut(duration: 4.0).repeatForever(autoreverses: true),
                    value: isBreathing
                )

            Text(nudge.title)
                .font(.system(size: 14, weight: .bold))

            Text(nudge.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if let duration = nudge.durationMinutes {
                Text("\(duration) min")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .foregroundStyle(.secondary)
            }

            Button("Done") {
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentMood = .celebrating
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onDismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
        .onAppear {
            isBreathing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    currentMood = .content
                }
            }
        }
    }
}

// MARK: - Flexing Arms (Thriving mood)

/// Bodybuilder flex — two simple Capsule arms that stay attached to the body.
/// Upper arm extends from body, forearm curls up at the elbow.
/// No fists, no dots, no detached parts. Everything connects seamlessly.
struct BuddyFlexArms: View {
    let mood: BuddyMood
    let size: CGFloat
    let anim: BuddyAnimationState

    /// Maps flexAngle (0–35) to visible forearm curl (0–87°)
    private var curlDeg: Double { anim.flexAngle * 2.5 }

    var body: some View {
        ZStack {
            flexArm(side: -1)
            flexArm(side: 1)
        }
    }

    @ViewBuilder
    private func flexArm(side: CGFloat) -> some View {
        let s = side

        // Upper arm — starts overlapping with body, extends outward
        Capsule()
            .fill(
                LinearGradient(
                    colors: [mood.bodyColors[1], mood.bodyColors[0]],
                    startPoint: s < 0 ? .trailing : .leading,
                    endPoint: s < 0 ? .leading : .trailing
                )
            )
            .frame(width: size * 0.38, height: size * 0.15)
            .offset(x: s * size * 0.38, y: size * 0.0)

        // Forearm — curls upward from end of upper arm
        Capsule()
            .fill(
                LinearGradient(
                    colors: [mood.bodyColors[0], mood.bodyColors[1]],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: size * 0.14, height: size * 0.30)
            .offset(x: s * size * 0.55, y: -size * 0.15)
            .rotationEffect(
                .degrees(s < 0 ? (-90 + curlDeg) : (90 - curlDeg)),
                anchor: UnitPoint(x: 0.5, y: 1.0)
            )
    }
}

// MARK: - Blanket Prop (Tired mood)

/// White blanket that drapes over ThumpBuddy from top, covering the body downward.
/// Also includes a bed underneath for the sleeping scene.
struct BuddyBlanket: View {
    let mood: BuddyMood
    let size: CGFloat
    let coverage: CGFloat

    var body: some View {
        // Cot is NOT inside the rotated body group — it stays level in world space.
        // It sits below the sphere as a stable surface ThumpBuddy rests on.
        EmptyView()
    }
}

/// Sleep scene — geometrically placed for 75° tilt.
/// Mattress at y=size*0.51 catches the deflated sphere's lowest point.
/// Pillow at head-end, blanket tilted -15° along body axis.
struct BuddySleepCot: View {
    let size: CGFloat
    let coverage: CGFloat

    var body: some View {
        ZStack {
            // MARK: Mattress — horizontal platform (shifted left)
            RoundedRectangle(cornerRadius: size * 0.06)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.38), Color(white: 0.20)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: size * 0.88, height: size * 0.12)
                .shadow(color: .black.opacity(0.5), radius: 5, y: 3)
                .offset(x: -size * 0.05, y: size * 0.51)

            // MARK: Bed legs
            RoundedRectangle(cornerRadius: size * 0.02)
                .fill(Color(white: 0.22))
                .frame(width: size * 0.055, height: size * 0.15)
                .offset(x: -size * 0.46, y: size * 0.62)

            RoundedRectangle(cornerRadius: size * 0.02)
                .fill(Color(white: 0.22))
                .frame(width: size * 0.055, height: size * 0.15)
                .offset(x: size * 0.38, y: size * 0.62)

            // MARK: Pillow — at right side (feet-end)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.95), Color(white: 0.82)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: size * 0.22, height: size * 0.15)
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                .offset(x: size * 0.30, y: size * 0.45)

            // Blanket removed
        }
    }
}

// MARK: - Sweat Drop (Stressed mood)

struct BuddySweatDrop: View {
    let size: CGFloat

    @State private var dropOffset: CGFloat = 0
    @State private var dropOpacity: Double = 0

    var body: some View {
        SweatDropShape()
            .fill(
                LinearGradient(
                    colors: [Color(hex: 0xBFDBFE), Color(hex: 0x60A5FA)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: size * 0.1, height: size * 0.16)
            .shadow(color: Color(hex: 0x3B82F6).opacity(0.4), radius: 3, y: 1)
            .offset(x: size * 0.28, y: -size * 0.22 + dropOffset)
            .opacity(dropOpacity)
            .onAppear { animateDrop() }
    }

    private func animateDrop() {
        withAnimation(.easeIn(duration: 0.3)) { dropOpacity = 0.9 }

        Task { @MainActor in
            while !Task.isCancelled {
                dropOffset = 0
                withAnimation(.easeIn(duration: 0.3)) { dropOpacity = 0.9 }
                withAnimation(.easeIn(duration: 1.2)) {
                    dropOffset = size * 0.2
                }
                try? await Task.sleep(for: .seconds(1.0))
                withAnimation(.easeOut(duration: 0.2)) { dropOpacity = 0 }
                try? await Task.sleep(for: .seconds(Double.random(in: 1.2...2.5)))
            }
        }
    }
}

struct SweatDropShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: 0))
            p.addQuadCurve(
                to: CGPoint(x: rect.midX, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.midY)
            )
            p.addQuadCurve(
                to: CGPoint(x: rect.midX, y: 0),
                control: CGPoint(x: 0, y: rect.midY)
            )
        }
    }
}

// MARK: - Sleep Zzz Particles

/// Floating "Z" letters on both sides that drift upward — universal sleep shorthand.
struct BuddySleepZzz: View {
    let size: CGFloat

    // Left side Z's
    @State private var leftOffsets: [CGFloat] = [0, 0, 0]
    @State private var leftOpacities: [Double] = [0, 0, 0]

    // Right side Z's
    @State private var rightOffsets: [CGFloat] = [0, 0, 0]
    @State private var rightOpacities: [Double] = [0, 0, 0]

    private let zSizes: [CGFloat] = [0.42, 0.33, 0.24]
    private let leftX: [CGFloat] = [-0.5, -0.62, -0.72]
    private let rightX: [CGFloat] = [0.5, 0.62, 0.72]
    private let leftDelays: [Double] = [0, 0.6, 1.2]
    private let rightDelays: [Double] = [0.3, 0.9, 1.5]

    var body: some View {
        ZStack {
            // Left side
            ForEach(0..<3, id: \.self) { i in
                Text("z")
                    .font(.system(size: size * zSizes[i], weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .offset(x: size * leftX[i], y: -size * 0.15 + leftOffsets[i])
                    .opacity(leftOpacities[i])
            }
            // Right side
            ForEach(0..<3, id: \.self) { i in
                Text("z")
                    .font(.system(size: size * zSizes[i], weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .offset(x: size * rightX[i], y: -size * 0.15 + rightOffsets[i])
                    .opacity(rightOpacities[i])
            }
        }
        .onAppear {
            animateSide(offsets: $leftOffsets, opacities: $leftOpacities, delays: leftDelays)
            animateSide(offsets: $rightOffsets, opacities: $rightOpacities, delays: rightDelays)
        }
    }

    private func animateSide(offsets: Binding<[CGFloat]>, opacities: Binding<[Double]>, delays: [Double]) {
        Task { @MainActor in
            while !Task.isCancelled {
                for i in 0..<3 {
                    try? await Task.sleep(for: .seconds(delays[i]))
                    offsets[i].wrappedValue = 0
                    withAnimation(.easeIn(duration: 0.3)) { opacities[i].wrappedValue = 0.85 }
                    withAnimation(.easeOut(duration: 2.0)) { offsets[i].wrappedValue = -size * 0.4 }
                    try? await Task.sleep(for: .seconds(1.4))
                    withAnimation(.easeOut(duration: 0.4)) { opacities[i].wrappedValue = 0 }
                }
                try? await Task.sleep(for: .seconds(1.0))
            }
        }
    }
}

// MARK: - Monk Halo Ring (Content mood)

/// Golden/white aurora ring that orbits the head like a monk's halo.
/// Rotates slowly, tilted at an angle for 3D feel.
struct BuddyMonkHalo: View {
    let mood: BuddyMood
    let size: CGFloat
    let anim: BuddyAnimationState

    var body: some View {
        ZStack {
            // Huge outer glow — very bright and unmissable
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.7),
                            Color.yellow.opacity(0.4),
                            Color.white.opacity(0.15),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size * 1.2, height: size * 0.4)
                .blur(radius: 8)

            // Main halo ring — HUGE, golden-white, unmissable
            Ellipse()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color.yellow.opacity(0.7),
                            Color.white
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: size * 0.055
                )
                .frame(width: size * 1.0, height: size * 0.28)
                .rotation3DEffect(.degrees(18), axis: (x: 1, y: 0, z: 0))
                .shadow(color: Color.yellow.opacity(0.8), radius: 8)
                .shadow(color: Color.white.opacity(0.5), radius: 4)

            // Inner bright fill
            Ellipse()
                .fill(Color.yellow.opacity(0.08))
                .frame(width: size * 0.9, height: size * 0.22)
                .rotation3DEffect(.degrees(18), axis: (x: 1, y: 0, z: 0))

            // Inner glow ring
            Ellipse()
                .stroke(Color.white.opacity(0.6), lineWidth: size * 0.025)
                .frame(width: size * 0.88, height: size * 0.24)
                .rotation3DEffect(.degrees(18), axis: (x: 1, y: 0, z: 0))
                .blur(radius: 3)
        }
        .offset(y: -size * 0.48)
        .scaleEffect(anim.glowPulse)
    }
}

// MARK: - Nude Buddy (animation debug view)

/// Stripped-down buddy that shows only wireframe outline + eyes.
/// No sphere fill, no effects — pure animation mechanics visible.
struct ThumpBuddyNude: View {

    let mood: BuddyMood
    let size: CGFloat

    @State private var anim = BuddyAnimationState()

    var body: some View {
        ZStack {
            // Wireframe sphere outline
            SphereShape()
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                .frame(width: size, height: size * 1.03)

            // Squash/stretch guide lines
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: size * 1.2, height: 0.5)
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 0.5, height: size * 1.2)

            // Face (eyes are the expression)
            ThumpBuddyFace(mood: mood, size: size, anim: anim)
        }
        .scaleEffect(
            x: anim.breatheScaleX * anim.moodScaleX,
            y: anim.breatheScaleY * anim.moodScaleY
        )
        .offset(
            x: anim.horizontalDrift,
            y: anim.bounceOffset + anim.fidgetOffsetY + anim.moodOffsetY
        )
        .rotationEffect(.degrees(
            anim.wiggleAngle + anim.fidgetRotation + anim.marchTilt + anim.moodTilt
        ))
        .scaleEffect(anim.entranceScale)
        .frame(width: size * 2.0, height: size * 2.0)
        .onAppear { anim.startAnimations(mood: mood, size: size) }
        .onChange(of: mood) { _, _ in anim.startAnimations(mood: mood, size: size) }
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: mood)
    }
}

// Color(hex:) extension is defined in Shared/Theme/ColorExtensions.swift

// MARK: - Preview

#Preview("All Moods") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach([BuddyMood.thriving, .content, .nudging, .stressed, .tired, .celebrating, .active, .conquering], id: \.rawValue) { mood in
                VStack(spacing: 4) {
                    ThumpBuddy(mood: mood, size: 80)
                    Text(mood.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

#Preview("Nude Animation Debug") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach([BuddyMood.thriving, .content, .nudging, .stressed, .tired, .celebrating, .active, .conquering], id: \.rawValue) { mood in
                HStack(spacing: 20) {
                    ThumpBuddyNude(mood: mood, size: 80)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mood.rawValue)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(mood.label)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }
    .background(.black)
}

#Preview("Side by Side: Nude vs Full") {
    HStack(spacing: 24) {
        VStack(spacing: 8) {
            ThumpBuddyNude(mood: .stressed, size: 80)
            Text("Nude")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        VStack(spacing: 8) {
            ThumpBuddy(mood: .stressed, size: 80)
            Text("Full")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
    .background(.black)
}

#Preview("Premium Sizes") {
    HStack(spacing: 24) {
        ThumpBuddy(mood: .thriving, size: 50)
        ThumpBuddy(mood: .content, size: 80)
        ThumpBuddy(mood: .celebrating, size: 120)
    }
    .padding()
}
