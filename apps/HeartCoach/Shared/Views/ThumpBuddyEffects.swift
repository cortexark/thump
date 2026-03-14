// ThumpBuddyEffects.swift
// ThumpCore
//
// Premium ambient effects for ThumpBuddy — multi-layer blur auras,
// sparkles, confetti, floating heart, conquering flag.
// Each mood gets a unique layered glow composition.
// Platforms: iOS 17+, watchOS 10+

import SwiftUI

// MARK: - Mood Aura

/// Multi-layer ambient aura surrounding the buddy sphere.
/// Each mood gets a unique composition of blurred gradients
/// and animated rings for a premium feel.
struct ThumpBuddyAura: View {

    let mood: BuddyMood
    let size: CGFloat
    let anim: BuddyAnimationState

    var body: some View {
        switch mood {
        case .content:
            contentAura
        case .thriving:
            thrivingAura
        case .celebrating:
            celebratingAura
        case .stressed:
            stressedAura
        case .active:
            activeAura
        case .conquering:
            conqueringAura
        case .tired:
            tiredAura
        default:
            defaultAura
        }
    }

    // MARK: - Content: Peaceful Multi-Ring Halo

    private var contentAura: some View {
        ZStack {
            // Soft outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            mood.glowColor.opacity(0.12),
                            mood.glowColor.opacity(0.04),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.35,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size * 1.4, height: size * 1.4)
                .scaleEffect(anim.glowPulse)

            // Concentric rings
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(
                        mood.glowColor.opacity(0.1 - Double(i) * 0.025),
                        lineWidth: 1.2
                    )
                    .frame(
                        width: size * (1.15 + CGFloat(i) * 0.18),
                        height: size * (1.15 + CGFloat(i) * 0.18)
                    )
                    .scaleEffect(anim.breatheScale * (1.0 + CGFloat(i) * 0.02))
            }
        }
    }

    // MARK: - Thriving: Animated Gradient Power Ring

    private var thrivingAura: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            mood.glowColor.opacity(0.15),
                            mood.glowColor.opacity(0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.75
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)
                .scaleEffect(anim.glowPulse)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            mood.glowColor.opacity(0.5),
                            mood.bodyColors[0].opacity(0.15),
                            mood.glowColor.opacity(0.5),
                            mood.bodyColors[0].opacity(0.15),
                            mood.glowColor.opacity(0.5),
                        ],
                        center: .center
                    ),
                    lineWidth: 2.5
                )
                .frame(width: size * 1.18, height: size * 1.18)
                .scaleEffect(anim.energyPulse)
        }
    }

    // MARK: - Celebrating: Golden Radiant Burst

    private var celebratingAura: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            mood.glowColor.opacity(0.28),
                            mood.glowColor.opacity(0.1),
                            mood.glowColor.opacity(0.03),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.15,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size * 1.4, height: size * 1.4)
                .scaleEffect(anim.glowPulse)

            // Shimmer ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            mood.bodyColors[0].opacity(0.35),
                            .clear,
                            mood.glowColor.opacity(0.25),
                            .clear,
                            mood.bodyColors[0].opacity(0.35),
                        ],
                        center: .center
                    ),
                    lineWidth: 1.5
                )
                .frame(width: size * 1.25, height: size * 1.25)
        }
    }

    // MARK: - Stressed: Warm Urgent Pulse

    private var stressedAura: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0xF97316).opacity(0.15),
                            Color(hex: 0xEA580C).opacity(0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.35,
                        endRadius: size * 0.65
                    )
                )
                .frame(width: size * 1.3, height: size * 1.3)
                .scaleEffect(anim.glowPulse)

            Circle()
                .stroke(
                    Color(hex: 0xF97316).opacity(0.18),
                    lineWidth: 1.8
                )
                .frame(width: size * 1.12, height: size * 1.12)
                .scaleEffect(anim.breatheScale * 1.03)
        }
    }

    // MARK: - Active: High-Energy Speed Rings

    private var activeAura: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0xEF4444).opacity(0.12),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.35,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size * 1.4, height: size * 1.4)
                .scaleEffect(anim.glowPulse)

            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .stroke(
                        Color(hex: 0xEF4444).opacity(0.13 - Double(i) * 0.025),
                        lineWidth: 1.5
                    )
                    .frame(
                        width: size * (1.1 + CGFloat(i) * 0.12),
                        height: size * (1.1 + CGFloat(i) * 0.12)
                    )
                    .scaleEffect(anim.energyPulse * (1.0 + CGFloat(i) * 0.015))
            }
        }
    }

    // MARK: - Conquering: Champion Golden Burst

    private var conqueringAura: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0xEAB308).opacity(0.35),
                            Color(hex: 0xFDE047).opacity(0.15),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.15,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size * 1.4, height: size * 1.4)
                .scaleEffect(anim.breatheScale * 1.06)

            // Trophy shimmer ring — static
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(hex: 0xFEF08A).opacity(0.4),
                            .clear,
                            Color(hex: 0xEAB308).opacity(0.3),
                            .clear,
                        ],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: size * 1.3, height: size * 1.3)
        }
    }

    // MARK: - Tired: Soft Moonlight Glow

    private var tiredAura: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hex: 0x8B5CF6).opacity(0.1),
                        Color(hex: 0xC4B5FD).opacity(0.03),
                        .clear
                    ],
                    center: .center,
                    startRadius: size * 0.3,
                    endRadius: size * 0.65
                )
            )
            .frame(width: size * 1.3, height: size * 1.3)
            .scaleEffect(anim.breatheScale)
    }

    // MARK: - Default: Subtle Glow

    private var defaultAura: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        mood.glowColor.opacity(0.15),
                        mood.glowColor.opacity(0.04),
                        .clear
                    ],
                    center: .center,
                    startRadius: size * 0.1,
                    endRadius: size * 0.6
                )
            )
            .frame(width: size * 1.3, height: size * 1.3)
            .scaleEffect(anim.breatheScale)
    }
}

// MARK: - Celebration Sparkles

struct ThumpBuddySparkles: View {

    let size: CGFloat
    let anim: BuddyAnimationState

    var body: some View {
        ForEach(0..<6, id: \.self) { i in
            Image(systemName: i % 2 == 0 ? "sparkle" : "heart.fill")
                .font(.system(size: size * (i % 2 == 0 ? 0.08 : 0.065)))
                .foregroundStyle(sparkleColor(index: i))
                .offset(sparkleOffset(index: i))
                .opacity(0.85)
                .rotationEffect(.degrees(anim.sparkleRotation * (i % 2 == 0 ? 1 : -0.5) + Double(i * 60)))
        }
    }

    private func sparkleColor(index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: 0xFDE047),
            Color(hex: 0x5EEAD4),
            Color(hex: 0x34D399),
            Color(hex: 0xFBBF24),
            Color(hex: 0x8B5CF6),
            Color(hex: 0x06B6D4),
        ]
        return colors[index % colors.count]
    }

    private func sparkleOffset(index: Int) -> CGSize {
        let angle = Double(index) * (360.0 / 6.0) + anim.sparkleRotation * 0.3
        let radius = size * 0.58 + (Double(index % 3) * size * 0.05)
        return CGSize(
            width: cos(angle * .pi / 180) * radius,
            height: sin(angle * .pi / 180) * radius
        )
    }
}

// MARK: - Confetti

struct ThumpBuddyConfetti: View {

    let size: CGFloat
    let active: Bool

    var body: some View {
        ForEach(0..<8, id: \.self) { i in
            ConfettiPiece(index: i, size: size, active: active)
        }
    }
}

// MARK: - Floating Heart

struct ThumpBuddyFloatingHeart: View {

    let size: CGFloat
    let anim: BuddyAnimationState

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size * 0.12))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: 0xEF4444), Color(hex: 0xDC2626)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .offset(x: size * 0.38, y: -size * 0.32 + anim.floatingHeartOffset)
            .opacity(anim.floatingHeartOpacity)
            .scaleEffect(0.8 + anim.floatingHeartOpacity * 0.2)
    }
}

// MARK: - Conquering Flag

struct ThumpBuddyFlag: View {

    let size: CGFloat
    let anim: BuddyAnimationState

    var body: some View {
        ZStack {
            // Flag pole
            Rectangle()
                .fill(Color.white.opacity(0.85))
                .frame(width: size * 0.025, height: size * 0.38)
                .offset(x: size * 0.34, y: -size * 0.5)
            // Flag banner
            Image(systemName: "flag.fill")
                .font(.system(size: size * 0.18, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: 0xEF4444), Color(hex: 0xB91C1C)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(anim.sparkleRotation * 0.08))
                .offset(x: size * 0.42, y: -size * 0.62)
        }
    }
}
