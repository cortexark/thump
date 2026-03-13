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
        case .thriving:    return [Color(hex: 0x6EE7B7), Color(hex: 0x22C55E), Color(hex: 0x15803D)]
        case .content:     return [Color(hex: 0x93C5FD), Color(hex: 0x3B82F6), Color(hex: 0x1D4ED8)]
        case .nudging:     return [Color(hex: 0xFDE68A), Color(hex: 0xFBBF24), Color(hex: 0xD97706)]
        case .stressed:    return [Color(hex: 0xFDBA74), Color(hex: 0xF97316), Color(hex: 0xC2410C)]
        case .tired:       return [Color(hex: 0xC4B5FD), Color(hex: 0x8B5CF6), Color(hex: 0x6D28D9)]
        case .celebrating: return [Color(hex: 0xFDE68A), Color(hex: 0xF59E0B), Color(hex: 0xB45309)]
        case .active:      return [Color(hex: 0xFCA5A5), Color(hex: 0xEF4444), Color(hex: 0xB91C1C)]
        case .conquering:  return [Color(hex: 0xFEF08A), Color(hex: 0xEAB308), Color(hex: 0x854D0E)]
        }
    }

    var glowColor: Color { bodyColors[1] }
    var labelColor: Color { bodyColors.last ?? .blue }

    /// Specular highlight — lighter, more glass-like.
    var highlightColor: Color {
        switch self {
        case .thriving:    return Color(hex: 0xD1FAE5)
        case .content:     return Color(hex: 0xDBEAFE)
        case .nudging:     return Color(hex: 0xFEF3C7)
        case .stressed:    return Color(hex: 0xFFEDD5)
        case .tired:       return Color(hex: 0xEDE9FE)
        case .celebrating: return Color(hex: 0xFEF3C7)
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

            // Celebration confetti
            if mood == .celebrating || mood == .conquering {
                ThumpBuddyConfetti(size: size, active: anim.confettiActive)
            }

            // Conquering: waving flag raised above buddy
            if mood == .conquering {
                ThumpBuddyFlag(size: size, anim: anim)
            }

            // Floating heart for thriving
            if mood == .thriving {
                ThumpBuddyFloatingHeart(size: size, anim: anim)
            }

            // Main sphere body with face
            ZStack {
                ThumpBuddySphere(mood: mood, size: size, anim: anim)
                ThumpBuddyFace(mood: mood, size: size, anim: anim)
            }
            .scaleEffect(anim.breatheScale)
            .offset(y: anim.bounceOffset)
            .rotationEffect(.degrees(anim.wiggleAngle))

            // Celebration sparkles
            if mood == .celebrating {
                ThumpBuddySparkles(size: size, anim: anim)
            }
        }
        .frame(width: size * 1.4, height: size * 1.4)
        .onAppear { anim.startAnimations(mood: mood, size: size) }
        .onChange(of: mood) { _, _ in anim.startAnimations(mood: mood, size: size) }
        .animation(.easeInOut(duration: 0.6), value: mood)
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

#Preview("Premium Sizes") {
    HStack(spacing: 24) {
        ThumpBuddy(mood: .thriving, size: 50)
        ThumpBuddy(mood: .content, size: 80)
        ThumpBuddy(mood: .celebrating, size: 120)
    }
    .padding()
}
