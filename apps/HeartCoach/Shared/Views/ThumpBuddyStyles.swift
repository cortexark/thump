// ThumpBuddyStyles.swift
// ThumpCore
//
// 10 character style variants for evaluation. Each shares the same
// BuddyAnimationState engine — only the visual rendering differs.
// Open "Character Style Gallery" preview to compare all 10 side by side.
//
// Platforms: iOS 17+, watchOS 10+

import SwiftUI

// MARK: - Style 1: Pulse Orb
// Luminous abstract orb. Data-driven glow. No face details — expression
// is entirely through color, pulse intensity, and particle density.

struct BuddyStylePulseOrb: View {
    let mood: BuddyMood
    let size: CGFloat
    let anim: BuddyAnimationState

    var body: some View {
        ZStack {
            // Ambient glow ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [mood.glowColor.opacity(0.35), mood.glowColor.opacity(0.08), .clear],
                        center: .center, startRadius: size * 0.12, endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(anim.glowPulse)

            // Core orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [mood.highlightColor, mood.bodyColors[1], mood.bodyColors[2]],
                        center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: size * 0.35
                    )
                )
                .frame(width: size * 0.5, height: size * 0.5)
                .shadow(color: mood.glowColor.opacity(0.5), radius: size * 0.1)

            // Inner light dot
            Circle()
                .fill(.white.opacity(0.7))
                .frame(width: size * 0.08)
                .offset(x: -size * 0.06, y: -size * 0.06)
                .blur(radius: 1)

            // Two subtle eye dots
            HStack(spacing: size * 0.07) {
                Circle().fill(.white.opacity(0.85)).frame(width: size * 0.045)
                Circle().fill(.white.opacity(0.85)).frame(width: size * 0.045)
            }
            .scaleEffect(y: anim.eyeBlink ? 0.1 : 1.0)
        }
        .scaleEffect(x: anim.breatheScaleX, y: anim.breatheScaleY)
        .offset(y: anim.bounceOffset + anim.fidgetOffsetY)
        .rotationEffect(.degrees(anim.fidgetRotation))
    }
}

// MARK: - Style 2: Geo Creature (Fox)
// Geometric animal built from circles + triangles. Big expressive eyes.

struct BuddyStyleGeoCreature: View {
    let mood: BuddyMood
    let size: CGFloat
    let anim: BuddyAnimationState

    private var earDroop: CGFloat {
        switch mood {
        case .tired: return 20
        case .stressed: return 10
        case .celebrating, .conquering: return -5
        default: return 0
        }
    }

    var body: some View {
        ZStack {
            // Left ear
            BuddyTriangle()
                .fill(mood.bodyColors[0].opacity(0.8))
                .frame(width: size * 0.18, height: size * 0.22)
                .rotationEffect(.degrees(-10 + earDroop))
                .offset(x: -size * 0.16, y: -size * 0.22)

            // Right ear
            BuddyTriangle()
                .fill(mood.bodyColors[0].opacity(0.8))
                .frame(width: size * 0.18, height: size * 0.22)
                .rotationEffect(.degrees(10 - earDroop))
                .offset(x: size * 0.16, y: -size * 0.22)

            // Head
            Circle()
                .fill(
                    LinearGradient(
                        colors: [mood.bodyColors[0], mood.bodyColors[1], mood.bodyColors[2]],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.5, height: size * 0.5)

            // Eyes
            HStack(spacing: size * 0.08) {
                geoEye(isLeft: true)
                geoEye(isLeft: false)
            }
            .scaleEffect(y: anim.eyeBlink ? 0.1 : 1.0)
            .offset(y: -size * 0.01)

            // Nose dot
            Ellipse()
                .fill(mood.bodyColors[2])
                .frame(width: size * 0.04, height: size * 0.03)
                .offset(y: size * 0.06)
        }
        .scaleEffect(x: anim.breatheScaleX, y: anim.breatheScaleY)
        .offset(y: anim.bounceOffset + anim.fidgetOffsetY)
        .rotationEffect(.degrees(anim.fidgetRotation))
    }

    private func geoEye(isLeft: Bool) -> some View {
        ZStack {
            Ellipse().fill(.white)
                .frame(width: size * 0.11, height: size * 0.13)
            Circle().fill(Color(white: 0.08))
                .frame(width: size * 0.055)
                .offset(x: anim.pupilLookX * 0.4, y: anim.pupilLookY * 0.4)
            Circle().fill(.white.opacity(0.8))
                .frame(width: size * 0.02)
                .offset(x: -size * 0.01, y: -size * 0.015)
        }
    }
}

struct BuddyTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: 0))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: 0, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

// MARK: - Style 3: Ink Spirit
// Single calligraphic brushstroke with two dot eyes.

struct BuddyStyleInkSpirit: View {
    let mood: BuddyMood
    let size: CGFloat
    let anim: BuddyAnimationState

    private var strokeCurvature: CGFloat {
        switch mood {
        case .stressed: return size * 0.08
        case .tired: return size * 0.15
        case .celebrating, .conquering: return -size * 0.06
        default: return 0
        }
    }

    var body: some View {
        ZStack {
            // Ink wash background glow
            Ellipse()
                .fill(mood.glowColor.opacity(0.08))
                .frame(width: size * 0.7, height: size * 0.5)
                .blur(radius: size * 0.06)

            // Main brushstroke body
            InkStrokePath(curvature: strokeCurvature)
                .fill(
                    LinearGradient(
                        colors: [mood.bodyColors[1].opacity(0.9), mood.bodyColors[2]],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: size * 0.5, height: size * 0.35)

            // Two brush-dot eyes
            HStack(spacing: size * 0.1) {
                Circle().fill(.white.opacity(0.9)).frame(width: size * 0.05)
                Circle().fill(.white.opacity(0.9)).frame(width: size * 0.05)
            }
            .scaleEffect(y: anim.eyeBlink ? 0.15 : 1.0)
            .offset(y: -size * 0.02)
        }
        .scaleEffect(x: anim.breatheScaleX, y: anim.breatheScaleY)
        .offset(y: anim.bounceOffset + anim.fidgetOffsetY)
        .rotationEffect(.degrees(anim.fidgetRotation))
    }
}

struct InkStrokePath: Shape {
    var curvature: CGFloat

    var animatableData: CGFloat {
        get { curvature }
        set { curvature = newValue }
    }

    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: rect.midY))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY),
                control: CGPoint(x: rect.midX, y: rect.midY + curvature)
            )
            p.addQuadCurve(
                to: CGPoint(x: 0, y: rect.midY),
                control: CGPoint(x: rect.midX, y: rect.midY - rect.height * 0.8 + curvature * 0.3)
            )
        }
    }
}

// MARK: - Style 4: Dot Constellation
// Character made of floating dots that form a face shape.

struct BuddyStyleDotConstellation: View {
    let mood: BuddyMood
    let size: CGFloat
    let anim: BuddyAnimationState

    var body: some View {
        ZStack {
            // Constellation dots forming a circular outline
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) * (360.0 / 12.0)
                let radius = size * 0.22
                let dotSize = size * CGFloat.random(in: 0.02...0.04)
                Circle()
                    .fill(mood.bodyColors[i % 3].opacity(0.7))
                    .frame(width: dotSize)
                    .offset(
                        x: cos(angle * .pi / 180) * radius,
                        y: sin(angle * .pi / 180) * radius
                    )
            }

            // Inner fill dots
            ForEach(0..<6, id: \.self) { i in
                let angle = Double(i) * 60 + 30
                let radius = size * 0.1
                Circle()
                    .fill(mood.highlightColor.opacity(0.4))
                    .frame(width: size * 0.025)
                    .offset(
                        x: cos(angle * .pi / 180) * radius,
                        y: sin(angle * .pi / 180) * radius
                    )
            }

            // Two bright eye dots
            HStack(spacing: size * 0.09) {
                Circle().fill(.white).frame(width: size * 0.055)
                    .shadow(color: .white.opacity(0.6), radius: 2)
                Circle().fill(.white).frame(width: size * 0.055)
                    .shadow(color: .white.opacity(0.6), radius: 2)
            }
            .scaleEffect(y: anim.eyeBlink ? 0.1 : 1.0)
            .offset(y: -size * 0.01)
        }
        .scaleEffect(x: anim.breatheScaleX, y: anim.breatheScaleY)
        .offset(y: anim.bounceOffset + anim.fidgetOffsetY)
        .rotationEffect(.degrees(anim.fidgetRotation + anim.wiggleAngle * 0.3))
    }
}

// MARK: - Style 5: Chibi Coach
// Kawaii minimal human with oversized head, dot eyes, coach whistle.

struct BuddyStyleChibiCoach: View {
    let mood: BuddyMood
    let size: CGFloat
    let anim: BuddyAnimationState

    private var mouthCurve: CGFloat {
        switch mood {
        case .thriving, .celebrating, .conquering: return -size * 0.015
        case .stressed: return size * 0.005
        case .tired: return 0
        default: return -size * 0.008
        }
    }

    var body: some View {
        ZStack {
            // Body (small)
            RoundedRectangle(cornerRadius: size * 0.06)
                .fill(mood.bodyColors[1])
                .frame(width: size * 0.22, height: size * 0.18)
                .offset(y: size * 0.2)

            // Head (large — 3:1 ratio)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xFDE8D0), Color(hex: 0xF5D5B8)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: size * 0.4, height: size * 0.4)

            // Hair / headband
            Capsule()
                .fill(mood.bodyColors[1])
                .frame(width: size * 0.42, height: size * 0.06)
                .offset(y: -size * 0.14)

            // Eyes
            HStack(spacing: size * 0.08) {
                chibiEye
                chibiEye
            }
            .scaleEffect(y: anim.eyeBlink ? 0.1 : 1.0)
            .offset(y: -size * 0.01)

            // Mouth
            ChibiMouth(curve: mouthCurve)
                .stroke(Color(hex: 0x8B6F5C), lineWidth: size * 0.012)
                .frame(width: size * 0.06, height: size * 0.03)
                .offset(y: size * 0.06)

            // Whistle
            Circle()
                .fill(Color(hex: 0xC0C0C0))
                .frame(width: size * 0.03)
                .offset(x: size * 0.12, y: size * 0.08)
        }
        .scaleEffect(x: anim.breatheScaleX, y: anim.breatheScaleY)
        .offset(y: anim.bounceOffset + anim.fidgetOffsetY)
        .rotationEffect(.degrees(anim.fidgetRotation))
    }

    private var chibiEye: some View {
        ZStack {
            Ellipse()
                .fill(Color(white: 0.1))
                .frame(width: size * 0.05, height: size * 0.06)
            Circle()
                .fill(.white.opacity(0.8))
                .frame(width: size * 0.018)
                .offset(x: -size * 0.008, y: -size * 0.01)
        }
    }
}

struct ChibiMouth: Shape {
    var curve: CGFloat

    var animatableData: CGFloat {
        get { curve }
        set { curve = newValue }
    }

    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: rect.midY))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY),
                control: CGPoint(x: rect.midX, y: rect.midY + curve)
            )
        }
    }
}

// MARK: - Style 6: Ring Spirit
// Three concentric activity-ring arcs that form a face.

struct BuddyStyleRingSpirit: View {
    let mood: BuddyMood
    let size: CGFloat
    let anim: BuddyAnimationState

    private var ringFill: CGFloat {
        switch mood {
        case .thriving, .celebrating, .conquering: return 0.9
        case .content: return 0.7
        case .nudging, .active: return 0.5
        case .stressed: return 0.6
        case .tired: return 0.3
        }
    }

    var body: some View {
        ZStack {
            // Outer ring (Move)
            Circle()
                .trim(from: 0, to: ringFill)
                .stroke(mood.bodyColors[0], style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round))
                .frame(width: size * 0.48, height: size * 0.48)
                .rotationEffect(.degrees(-90))

            // Middle ring (Exercise)
            Circle()
                .trim(from: 0, to: ringFill * 0.85)
                .stroke(mood.bodyColors[1], style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round))
                .frame(width: size * 0.36, height: size * 0.36)
                .rotationEffect(.degrees(-90))

            // Inner ring (Stand)
            Circle()
                .trim(from: 0, to: ringFill * 0.7)
                .stroke(mood.bodyColors[2], style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round))
                .frame(width: size * 0.24, height: size * 0.24)
                .rotationEffect(.degrees(-90))

            // Eyes in center
            HStack(spacing: size * 0.06) {
                Circle().fill(.white.opacity(0.9)).frame(width: size * 0.04)
                Circle().fill(.white.opacity(0.9)).frame(width: size * 0.04)
            }
            .scaleEffect(y: anim.eyeBlink ? 0.1 : 1.0)
            .offset(y: -size * 0.01)
        }
        .scaleEffect(x: anim.breatheScaleX, y: anim.breatheScaleY)
        .offset(y: anim.bounceOffset + anim.fidgetOffsetY)
        .rotationEffect(.degrees(anim.fidgetRotation))
    }
}

// MARK: - Style 7: Blob Guardian
// Organic morphing shape with smooth edges.

struct BuddyStyleBlobGuardian: View {
    let mood: BuddyMood
    let size: CGFloat
    let anim: BuddyAnimationState

    var body: some View {
        ZStack {
            // Blob body — overlapping circles create organic shape
            ZStack {
                Circle()
                    .fill(mood.bodyColors[1])
                    .frame(width: size * 0.4, height: size * 0.4)
                Circle()
                    .fill(mood.bodyColors[0].opacity(0.7))
                    .frame(width: size * 0.3, height: size * 0.35)
                    .offset(x: -size * 0.06, y: -size * 0.04)
                Circle()
                    .fill(mood.bodyColors[1].opacity(0.8))
                    .frame(width: size * 0.28, height: size * 0.3)
                    .offset(x: size * 0.05, y: size * 0.02)
                Circle()
                    .fill(mood.bodyColors[0].opacity(0.5))
                    .frame(width: size * 0.2, height: size * 0.22)
                    .offset(x: 0, y: -size * 0.1)
            }
            .blur(radius: size * 0.02)

            // Eyes
            HStack(spacing: size * 0.08) {
                blobEye
                blobEye
            }
            .scaleEffect(y: anim.eyeBlink ? 0.1 : 1.0)
            .offset(y: -size * 0.02)
        }
        .scaleEffect(x: anim.breatheScaleX, y: anim.breatheScaleY)
        .offset(y: anim.bounceOffset + anim.fidgetOffsetY)
        .rotationEffect(.degrees(anim.wiggleAngle + anim.fidgetRotation))
    }

    private var blobEye: some View {
        ZStack {
            Circle().fill(.white).frame(width: size * 0.08)
            Circle().fill(Color(white: 0.1))
                .frame(width: size * 0.04)
                .offset(x: anim.pupilLookX * 0.3, y: anim.pupilLookY * 0.3)
        }
    }
}

// MARK: - Style 8: Pixel Heart
// 8x8 retro pixel art creature. Frame-based expression.

struct BuddyStylePixelHeart: View {
    let mood: BuddyMood
    let size: CGFloat
    let anim: BuddyAnimationState

    // 8x8 grid — 1 = body, 2 = eye, 0 = empty
    private var grid: [[Int]] {
        if anim.eyeBlink {
            return [
                [0,0,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,0],
                [1,1,1,1,1,1,1,1],
                [1,1,0,1,1,0,1,1],  // blink: empty eyes
                [1,1,1,1,1,1,1,1],
                [0,1,1,1,1,1,1,0],
                [0,0,1,1,1,1,0,0],
                [0,0,0,1,1,0,0,0],
            ]
        }
        return [
            [0,0,1,1,1,1,0,0],
            [0,1,1,1,1,1,1,0],
            [1,1,1,1,1,1,1,1],
            [1,1,2,1,1,2,1,1],  // eyes
            [1,1,1,1,1,1,1,1],
            [0,1,1,1,1,1,1,0],
            [0,0,1,1,1,1,0,0],
            [0,0,0,1,1,0,0,0],
        ]
    }

    var body: some View {
        let pixelSize = size * 0.055
        VStack(spacing: 1) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<8, id: \.self) { col in
                        let cell = grid[row][col]
                        Rectangle()
                            .fill(pixelColor(cell))
                            .frame(width: pixelSize, height: pixelSize)
                    }
                }
            }
        }
        .scaleEffect(x: anim.breatheScaleX, y: anim.breatheScaleY)
        .offset(y: anim.bounceOffset + anim.fidgetOffsetY)
        .rotationEffect(.degrees(anim.fidgetRotation))
    }

    private func pixelColor(_ cell: Int) -> Color {
        switch cell {
        case 1: return mood.bodyColors[1]
        case 2: return .white
        default: return .clear
        }
    }
}

// MARK: - Style 9: Aura Silhouette
// Mature, meditative. Dark silhouette with mood-colored gradient aura.

struct BuddyStyleAuraSilhouette: View {
    let mood: BuddyMood
    let size: CGFloat
    let anim: BuddyAnimationState

    var body: some View {
        ZStack {
            // Aura glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [mood.glowColor.opacity(0.3), mood.glowColor.opacity(0.08), .clear],
                        center: .center, startRadius: size * 0.1, endRadius: size * 0.45
                    )
                )
                .frame(width: size * 0.9, height: size * 0.9)
                .scaleEffect(anim.glowPulse)

            // Head silhouette
            Circle()
                .fill(Color(white: 0.08))
                .frame(width: size * 0.28, height: size * 0.28)
                .offset(y: -size * 0.06)

            // Shoulders silhouette
            Capsule()
                .fill(Color(white: 0.08))
                .frame(width: size * 0.42, height: size * 0.15)
                .offset(y: size * 0.12)

            // Neck
            Rectangle()
                .fill(Color(white: 0.08))
                .frame(width: size * 0.1, height: size * 0.08)
                .offset(y: size * 0.04)

            // Subtle eye glints
            HStack(spacing: size * 0.06) {
                Circle().fill(mood.glowColor.opacity(0.6)).frame(width: size * 0.025)
                Circle().fill(mood.glowColor.opacity(0.6)).frame(width: size * 0.025)
            }
            .scaleEffect(y: anim.eyeBlink ? 0.1 : 1.0)
            .offset(y: -size * 0.07)
        }
        .scaleEffect(x: anim.breatheScaleX, y: anim.breatheScaleY)
        .offset(y: anim.bounceOffset + anim.fidgetOffsetY)
        .rotationEffect(.degrees(anim.fidgetRotation))
    }
}

// MARK: - Style 10: Current ThumpBuddy (reference)
// The existing glassmorphic sphere with ThumpBuddy eyes. Included for comparison.
// Uses ThumpBuddy directly in the gallery preview.

// MARK: - Style Gallery Preview

#Preview("Character Style Gallery") {
    ScrollView {
        VStack(spacing: 24) {
            Text("Pick Your Buddy")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            // Show all 10 at the same mood for fair comparison
            let mood: BuddyMood = .content
            let previewSize: CGFloat = 80

            styleRow("1. Pulse Orb", "Abstract • Data-driven") {
                BuddyStyleGalleryItem(mood: mood, size: previewSize) { m, s, a in
                    BuddyStylePulseOrb(mood: m, size: s, anim: a)
                }
            }
            styleRow("2. Geo Creature", "Geometric fox • Expressive") {
                BuddyStyleGalleryItem(mood: mood, size: previewSize) { m, s, a in
                    BuddyStyleGeoCreature(mood: m, size: s, anim: a)
                }
            }
            styleRow("3. Ink Spirit", "Brushstroke • Artisanal") {
                BuddyStyleGalleryItem(mood: mood, size: previewSize) { m, s, a in
                    BuddyStyleInkSpirit(mood: m, size: s, anim: a)
                }
            }
            styleRow("4. Dot Constellation", "Particles • Living form") {
                BuddyStyleGalleryItem(mood: mood, size: previewSize) { m, s, a in
                    BuddyStyleDotConstellation(mood: m, size: s, anim: a)
                }
            }
            styleRow("5. Chibi Coach", "Kawaii human • Friendly") {
                BuddyStyleGalleryItem(mood: mood, size: previewSize) { m, s, a in
                    BuddyStyleChibiCoach(mood: m, size: s, anim: a)
                }
            }
            styleRow("6. Ring Spirit", "Activity rings • Apple-native") {
                BuddyStyleGalleryItem(mood: mood, size: previewSize) { m, s, a in
                    BuddyStyleRingSpirit(mood: m, size: s, anim: a)
                }
            }
            styleRow("7. Blob Guardian", "Organic blob • Playful") {
                BuddyStyleGalleryItem(mood: mood, size: previewSize) { m, s, a in
                    BuddyStyleBlobGuardian(mood: m, size: s, anim: a)
                }
            }
            styleRow("8. Pixel Heart", "Retro 8-bit • Nostalgic") {
                BuddyStyleGalleryItem(mood: mood, size: previewSize) { m, s, a in
                    BuddyStylePixelHeart(mood: m, size: s, anim: a)
                }
            }
            styleRow("9. Aura Silhouette", "Mature • Meditative") {
                BuddyStyleGalleryItem(mood: mood, size: previewSize) { m, s, a in
                    BuddyStyleAuraSilhouette(mood: m, size: s, anim: a)
                }
            }
            styleRow("10. ThumpBuddy Glass", "Current • Premium sphere") {
                ThumpBuddy(mood: mood, size: previewSize)
            }
        }
        .padding()
    }
    .background(.black)
}

#Preview("Styles × Moods Matrix") {
    ScrollView(.horizontal) {
        VStack(alignment: .leading, spacing: 12) {
            let moods: [BuddyMood] = [.content, .stressed, .tired, .thriving, .active]
            ForEach(moods, id: \.rawValue) { mood in
                VStack(alignment: .leading, spacing: 4) {
                    Text(mood.rawValue)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        BuddyStyleGalleryItem(mood: mood, size: 56) { m, s, a in
                            BuddyStylePulseOrb(mood: m, size: s, anim: a)
                        }
                        BuddyStyleGalleryItem(mood: mood, size: 56) { m, s, a in
                            BuddyStyleGeoCreature(mood: m, size: s, anim: a)
                        }
                        BuddyStyleGalleryItem(mood: mood, size: 56) { m, s, a in
                            BuddyStyleInkSpirit(mood: m, size: s, anim: a)
                        }
                        BuddyStyleGalleryItem(mood: mood, size: 56) { m, s, a in
                            BuddyStyleBlobGuardian(mood: m, size: s, anim: a)
                        }
                        ThumpBuddy(mood: mood, size: 56)
                    }
                }
            }
        }
        .padding()
    }
    .background(.black)
}

// MARK: - Gallery Helpers

/// Wraps a style variant with its own animation state for independent preview.
struct BuddyStyleGalleryItem<Content: View>: View {
    let mood: BuddyMood
    let size: CGFloat
    let content: (BuddyMood, CGFloat, BuddyAnimationState) -> Content

    @State private var anim = BuddyAnimationState()

    var body: some View {
        content(mood, size, anim)
            .frame(width: size * 1.4, height: size * 1.4)
            .onAppear { anim.startAnimations(mood: mood, size: size) }
            .onChange(of: mood) { _, _ in anim.startAnimations(mood: mood, size: size) }
    }
}

@ViewBuilder
private func styleRow<Content: View>(_ name: String, _ subtitle: String, @ViewBuilder content: () -> Content) -> some View {
    HStack(spacing: 16) {
        content()
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        Spacer()
    }
}
