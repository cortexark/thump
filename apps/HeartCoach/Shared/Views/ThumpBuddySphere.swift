// ThumpBuddySphere.swift
// ThumpCore
//
// Premium glassmorphic sphere body for ThumpBuddy.
// Multi-layer depth: radial gradient base, glass highlight overlay,
// inner rim refraction, triple shadow stack.
// Platforms: iOS 17+, watchOS 10+

import SwiftUI

// MARK: - Premium Sphere Body

/// Glassmorphic sphere with subsurface-scattering-inspired gradients,
/// specular highlight, rim light, and layered shadows.
struct ThumpBuddySphere: View {

    let mood: BuddyMood
    let size: CGFloat
    let anim: BuddyAnimationState

    var body: some View {
        ZStack {
            // Layer 0: Ground contact shadow
            groundShadow

            // Layer 1: Colored glow shadow (below sphere)
            coloredGlowShadow

            // Layer 2: Main sphere body — multi-stop radial gradient
            mainSphereBody

            // Layer 3: Glass specular highlight — off-center for 3D depth
            glassHighlight

            // Layer 4: Inner rim refraction ring
            rimRefractionRing

            // Layer 5: Subtle secondary rim light
            secondaryRimLight
        }
    }

    // MARK: - Ground Shadow

    private var groundShadow: some View {
        Ellipse()
            .fill(Color.black.opacity(0.15))
            .frame(width: size * 0.5, height: size * 0.08)
            .blur(radius: size * 0.04)
            .offset(y: size * 0.5)
    }

    // MARK: - Colored Glow Shadow

    private var coloredGlowShadow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        mood.glowColor.opacity(0.3),
                        mood.glowColor.opacity(0.08),
                        .clear
                    ],
                    center: .center,
                    startRadius: size * 0.2,
                    endRadius: size * 0.6
                )
            )
            .frame(width: size * 1.2, height: size * 1.2)
            .offset(y: size * 0.06)
            .blur(radius: size * 0.04)
    }

    // MARK: - Main Sphere Body

    /// 5-stop radial gradient with off-center light source
    /// to simulate subsurface scattering.
    private var mainSphereBody: some View {
        let palette = mood.premiumPalette
        return SphereShape()
            .fill(
                RadialGradient(
                    colors: [
                        palette.highlight,
                        palette.light,
                        palette.core,
                        palette.mid,
                        palette.deep
                    ],
                    center: UnitPoint(x: 0.35, y: 0.25),
                    startRadius: 0,
                    endRadius: size * 0.6
                )
            )
            .frame(width: size, height: size * 1.03)
            .shadow(color: palette.deep.opacity(0.45), radius: size * 0.08, y: size * 0.06)
            .shadow(color: mood.glowColor.opacity(0.2), radius: size * 0.14, y: size * 0.02)
    }

    // MARK: - Glass Highlight

    /// Elliptical glass overlay — bright top-left fading out.
    /// Simulates a smooth specular surface reflection.
    private var glassHighlight: some View {
        SphereShape()
            .fill(
                EllipticalGradient(
                    colors: [
                        .white.opacity(0.55),
                        .white.opacity(0.22),
                        .white.opacity(0.06),
                        .clear
                    ],
                    center: UnitPoint(x: 0.3, y: 0.18),
                    startRadiusFraction: 0.0,
                    endRadiusFraction: 0.55
                )
            )
            .frame(width: size, height: size * 1.03)
            .blendMode(.overlay)
    }

    // MARK: - Rim Refraction

    /// Subtle static rim highlight — no rotating angular gradient.
    private var rimRefractionRing: some View {
        SphereShape()
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(0.15),
                        .clear,
                        .clear,
                        mood.premiumPalette.highlight.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: size * 0.012
            )
            .frame(width: size * 0.98, height: size * 1.01)
    }

    // MARK: - Secondary Rim Light

    private var secondaryRimLight: some View {
        SphereShape()
            .stroke(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.1),
                        .white.opacity(0.04),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )
            .frame(width: size, height: size * 1.03)
    }
}

// MARK: - Premium Palette

/// 5-stop gradient palette per mood for the premium sphere.
struct BuddyPalette {
    let highlight: Color
    let light: Color
    let core: Color
    let mid: Color
    let deep: Color
}

extension BuddyMood {

    /// Rich 5-stop gradient palette for glassmorphic sphere.
    var premiumPalette: BuddyPalette {
        switch self {
        case .thriving:
            return BuddyPalette(
                highlight: Color(hex: 0xFEFCBF),
                light:     Color(hex: 0xFEF08A),
                core:      Color(hex: 0xEAB308),
                mid:       Color(hex: 0xCA8A04),
                deep:      Color(hex: 0x713F12)
            )
        case .content:
            return BuddyPalette(
                highlight: Color(hex: 0xD1FAE5),
                light:     Color(hex: 0x6EE7B7),
                core:      Color(hex: 0x22C55E),
                mid:       Color(hex: 0x16A34A),
                deep:      Color(hex: 0x0F5132)
            )
        case .nudging:
            return BuddyPalette(
                highlight: Color(hex: 0xFEF3C7),
                light:     Color(hex: 0xFDE68A),
                core:      Color(hex: 0xFBBF24),
                mid:       Color(hex: 0xF59E0B),
                deep:      Color(hex: 0x92400E)
            )
        case .stressed:
            return BuddyPalette(
                highlight: Color(hex: 0xFFEDD5),
                light:     Color(hex: 0xFDBA74),
                core:      Color(hex: 0xF97316),
                mid:       Color(hex: 0xEA580C),
                deep:      Color(hex: 0x7C2D12)
            )
        case .tired:
            return BuddyPalette(
                highlight: Color(hex: 0xEDE9FE),
                light:     Color(hex: 0xC4B5FD),
                core:      Color(hex: 0x8B5CF6),
                mid:       Color(hex: 0x7C3AED),
                deep:      Color(hex: 0x3B0764)
            )
        case .celebrating:
            return BuddyPalette(
                highlight: Color(hex: 0xD1FAE5),
                light:     Color(hex: 0x6EE7B7),
                core:      Color(hex: 0x22C55E),
                mid:       Color(hex: 0x16A34A),
                deep:      Color(hex: 0x0F5132)
            )
        case .active:
            return BuddyPalette(
                highlight: Color(hex: 0xFEE2E2),
                light:     Color(hex: 0xFCA5A5),
                core:      Color(hex: 0xEF4444),
                mid:       Color(hex: 0xDC2626),
                deep:      Color(hex: 0x7F1D1D)
            )
        case .conquering:
            return BuddyPalette(
                highlight: Color(hex: 0xFEFCBF),
                light:     Color(hex: 0xFEF08A),
                core:      Color(hex: 0xEAB308),
                mid:       Color(hex: 0xCA8A04),
                deep:      Color(hex: 0x713F12)
            )
        }
    }
}
