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
        nudgeCompleted: Bool = false,
        feedbackType: DailyFeedback? = nil,
        activityInProgress: Bool = false
    ) -> BuddyMood {
        if nudgeCompleted { return .conquering }
        if feedbackType == .positive { return .conquering }
        if activityInProgress { return .active }
        if assessment.stressFlag { return .stressed }
        if assessment.status == .needsAttention { return .tired }
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

    init(mood: BuddyMood, size: CGFloat = 80, showAura: Bool = true) {
        self.mood = mood
        self.size = size
        self.showAura = showAura
    }

    // MARK: - Animation State

    @State private var anim = BuddyAnimationState()

    // MARK: - Body

    var body: some View {
        ZStack {
            // Mood-specific aura (suppressed at small sizes)
            if showAura {
                ThumpBuddyAura(mood: mood, size: size, anim: anim)
            }

            // Celebration confetti (id forces recreation for repeating bursts)
            if mood == .celebrating || mood == .conquering {
                ThumpBuddyConfetti(size: size, active: anim.confettiActive)
                    .id(anim.confettiGeneration)
            }

            // Conquering: waving flag raised above buddy
            if mood == .conquering {
                ThumpBuddyFlag(size: size, anim: anim)
            }

            // Content: monk-style aurora halo ring orbiting the head
            if mood == .content {
                BuddyMonkHalo(mood: mood, size: size, anim: anim)
            }

            // Floating heart for thriving
            if mood == .thriving {
                ThumpBuddyFloatingHeart(size: size, anim: anim)
            }

            // Thriving: flexing arms BEHIND the sphere (Duolingo wing trick)
            if mood == .thriving {
                BuddyFlexArms(mood: mood, size: size, anim: anim)
                    .offset(
                        x: anim.horizontalDrift,
                        y: anim.bounceOffset + anim.fidgetOffsetY + anim.moodOffsetY
                    )
            }

            // Main sphere body with face + mood body shape
            ZStack {
                ThumpBuddySphere(mood: mood, size: size, anim: anim)
                ThumpBuddyFace(mood: mood, size: size, anim: anim)

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
            if mood == .celebrating {
                ThumpBuddySparkles(size: size, anim: anim)
            }

            // Tired: cot with legs — rendered outside rotation so it stays level
            if mood == .tired {
                BuddySleepCot(size: size, coverage: anim.blanketCoverage)
                BuddySleepZzz(size: size)
            }
        }
        .scaleEffect(anim.entranceScale)
        .frame(width: size * 2.0, height: size * 2.0)
        .onAppear { anim.startAnimations(mood: mood, size: size) }
        .onChange(of: mood) { _, _ in anim.startAnimations(mood: mood, size: size) }
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: mood)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Thump buddy feeling \(mood.label)")
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

/// White blanket that drapes over Baymax from top, covering the body downward.
/// Also includes a bed underneath for the sleeping scene.
struct BuddyBlanket: View {
    let mood: BuddyMood
    let size: CGFloat
    let coverage: CGFloat

    var body: some View {
        // Cot is NOT inside the rotated body group — it stays level in world space.
        // It sits below the sphere as a stable surface Baymax rests on.
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

/// Floating "Z" letters that drift upward — universal sleep shorthand.
struct BuddySleepZzz: View {
    let size: CGFloat

    @State private var offsets: [CGFloat] = [0, 0, 0]
    @State private var opacities: [Double] = [0, 0, 0]

    private let zSizes: [CGFloat] = [0.14, 0.11, 0.08]
    private let xPositions: [CGFloat] = [-0.35, -0.45, -0.52]
    private let delays: [Double] = [0, 0.6, 1.2]

    var body: some View {
        ForEach(0..<3, id: \.self) { i in
            Text("z")
                .font(.system(size: size * zSizes[i], weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.7))
                .offset(
                    x: size * xPositions[i],
                    y: -size * 0.15 + offsets[i]
                )
                .opacity(opacities[i])
        }
        .onAppear { animateZzz() }
    }

    private func animateZzz() {
        Task { @MainActor in
            while !Task.isCancelled {
                for i in 0..<3 {
                    try? await Task.sleep(for: .seconds(delays[i]))
                    offsets[i] = 0
                    withAnimation(.easeIn(duration: 0.3)) { opacities[i] = 0.85 }
                    withAnimation(.easeOut(duration: 2.0)) { offsets[i] = -size * 0.4 }
                    try? await Task.sleep(for: .seconds(1.4))
                    withAnimation(.easeOut(duration: 0.4)) { opacities[i] = 0 }
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
