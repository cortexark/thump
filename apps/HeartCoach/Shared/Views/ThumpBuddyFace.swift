// ThumpBuddyFace.swift
// ThumpCore
//
// Premium face rendering for ThumpBuddy — eyes, mouth, eyebrows,
// cheeks, and expression accessories. Eyes are the hero element
// with iris rings, gradient pupils, dual specular highlights,
// and eyelid shadows for realistic depth.
// Platforms: iOS 17+, watchOS 10+

import SwiftUI

// MARK: - Face Layout

/// Complete face composition for the buddy sphere.
struct ThumpBuddyFace: View {

    let mood: BuddyMood
    let size: CGFloat
    let anim: BuddyAnimationState

    var body: some View {
        ZStack {
            faceContent

            // Cheek blush for happy moods
            if mood == .thriving || mood == .celebrating || mood == .content || mood == .conquering {
                cheekBlush
            }

            // Zzz bubble for tired
            if mood == .tired {
                zzzBubble
                    .offset(x: size * 0.35, y: -size * 0.3)
            }
        }
    }

    private var faceContent: some View {
        VStack(spacing: size * 0.04) {
            // Stressed / active eyebrows
            if mood == .stressed || mood == .active {
                stressedEyebrows
            }

            // Eyes — the hero of the character
            HStack(spacing: size * 0.24) {
                buddyEye(isLeft: true)
                buddyEye(isLeft: false)
            }

            // Mouth
            buddyMouth
        }
        .offset(y: size * 0.02)
    }

    // MARK: - Premium Eyes

    @ViewBuilder
    private func buddyEye(isLeft: Bool) -> some View {
        if anim.eyeBlink {
            blinkEye
        } else {
            switch mood {
            case .thriving:
                squintEye
            case .celebrating:
                sparkleEye
            case .tired:
                droopyEye(isLeft: isLeft)
            case .active:
                focusedEye(isLeft: isLeft)
            case .conquering:
                starEye
            default:
                premiumOpenEye(isLeft: isLeft)
            }
        }
    }

    // MARK: - Blink

    private var blinkEye: some View {
        BuddyBlinkShape()
            .stroke(.white, lineWidth: size * 0.03)
            .frame(width: size * 0.16, height: size * 0.07)
    }

    // MARK: - Premium Open Eye

    /// Full premium eye: white sclera with subtle gradient, iris ring,
    /// gradient pupil, dual specular highlights, eyelid shadow.
    private func premiumOpenEye(isLeft: Bool) -> some View {
        let w = eyeWidth
        let h = eyeHeight
        return ZStack {
            // Sclera — subtle gradient instead of flat white
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            .white,
                            Color(white: 0.96),
                            Color(white: 0.92)
                        ],
                        center: UnitPoint(x: 0.45, y: 0.35),
                        startRadius: 0,
                        endRadius: w * 0.6
                    )
                )
                .frame(width: w, height: h)

            // Iris ring — mood colored
            Circle()
                .stroke(mood.glowColor.opacity(0.35), lineWidth: size * 0.012)
                .frame(width: size * 0.105)
                .offset(
                    x: pupilOffset(isLeft: isLeft) + anim.pupilLookX,
                    y: pupilYOffset
                )

            // Pupil — gradient instead of flat black
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.02),
                            Color(white: 0.12),
                            Color(white: 0.08)
                        ],
                        center: UnitPoint(x: 0.4, y: 0.35),
                        startRadius: 0,
                        endRadius: size * 0.05
                    )
                )
                .frame(width: size * 0.085)
                .offset(
                    x: pupilOffset(isLeft: isLeft) + anim.pupilLookX,
                    y: pupilYOffset
                )

            // Primary specular highlight — crisp
            Circle()
                .fill(.white.opacity(0.95))
                .frame(width: size * 0.038)
                .offset(
                    x: isLeft ? -size * 0.018 : size * 0.006,
                    y: -size * 0.022
                )

            // Secondary specular — smaller, softer
            Circle()
                .fill(.white.opacity(0.5))
                .frame(width: size * 0.018)
                .offset(
                    x: isLeft ? size * 0.02 : -size * 0.014,
                    y: size * 0.018
                )

            // Eyelid shadow — adds depth to the eye socket
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            mood.premiumPalette.mid.opacity(0.18),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: w * 1.05, height: h * 0.35)
                .offset(y: -h * 0.35)
        }
    }

    // MARK: - Squint Eye (Thriving)

    private var squintEye: some View {
        BuddySquintShape()
            .stroke(.white, style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
            .frame(width: size * 0.17, height: size * 0.11)
    }

    // MARK: - Sparkle Eye (Celebrating)

    private var sparkleEye: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size * 0.17, weight: .bold))
            .foregroundStyle(.white)
            .symbolEffect(.pulse, isActive: true)
    }

    // MARK: - Droopy Eye (Tired)

    private func droopyEye(isLeft: Bool) -> some View {
        ZStack {
            Ellipse()
                .fill(.white)
                .frame(width: size * 0.17, height: size * 0.12)

            // Heavy eyelid
            Ellipse()
                .fill(mood.premiumPalette.mid)
                .frame(width: size * 0.18, height: size * 0.12)
                .offset(y: -size * 0.035)

            // Sleepy pupil
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.05), Color(white: 0.15)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.04
                    )
                )
                .frame(width: size * 0.07)
                .offset(y: size * 0.01)

            // Tiny glint
            Circle()
                .fill(.white.opacity(0.7))
                .frame(width: size * 0.02)
                .offset(x: -size * 0.008, y: -size * 0.005)
        }
    }

    // MARK: - Focused Eye (Active)

    private func focusedEye(isLeft: Bool) -> some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white, Color(white: 0.94)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.1
                    )
                )
                .frame(width: size * 0.19, height: size * 0.13)

            Circle()
                .fill(Color(white: 0.08))
                .frame(width: size * 0.08)

            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: size * 0.028)
                .offset(x: isLeft ? -size * 0.01 : size * 0.01, y: -size * 0.015)
        }
    }

    // MARK: - Star Eye (Conquering)

    @ViewBuilder
    private var starEye: some View {
        if #available(macOS 15, iOS 17, watchOS 10, *) {
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.16, weight: .bold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, isActive: true)
        } else {
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.16, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Eye Sizing

    private var eyeWidth: CGFloat {
        switch mood {
        case .thriving, .celebrating: return size * 0.18
        case .stressed:               return size * 0.2
        case .tired:                  return size * 0.15
        case .active:                 return size * 0.19
        case .conquering:             return size * 0.18
        default:                      return size * 0.17
        }
    }

    private var eyeHeight: CGFloat {
        switch mood {
        case .thriving, .celebrating: return size * 0.19
        case .stressed:               return size * 0.24
        case .tired:                  return size * 0.09
        case .active:                 return size * 0.13
        case .conquering:             return size * 0.22
        default:                      return size * 0.18
        }
    }

    private func pupilOffset(isLeft: Bool) -> CGFloat {
        switch mood {
        case .nudging: return size * 0.012
        case .tired:   return isLeft ? -size * 0.01 : size * 0.01
        default:       return 0
        }
    }

    private var pupilYOffset: CGFloat {
        switch mood {
        case .tired:    return size * 0.012
        case .thriving: return -size * 0.01
        default:        return 0
        }
    }

    // MARK: - Mouth

    private var buddyMouth: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            switch mood {
            case .thriving:
                // Wide aggressive grin
                var path = Path()
                path.move(to: CGPoint(x: w * 0.05, y: h * 0.1))
                path.addQuadCurve(
                    to: CGPoint(x: w * 0.95, y: h * 0.1),
                    control: CGPoint(x: w * 0.5, y: h * 1.15)
                )
                path.closeSubpath()
                context.fill(path, with: .color(Color(white: 0.1)))

                var tongue = Path()
                tongue.addEllipse(in: CGRect(x: w * 0.3, y: h * 0.4, width: w * 0.4, height: h * 0.55))
                context.fill(tongue, with: .color(Color(hex: 0xF97316).opacity(0.55)))

            case .celebrating:
                // Excited "O"
                var path = Path()
                path.addEllipse(in: CGRect(x: w * 0.22, y: 0, width: w * 0.56, height: h * 0.9))
                context.fill(path, with: .color(Color(white: 0.1)))
                var tongue = Path()
                tongue.addEllipse(in: CGRect(x: w * 0.3, y: h * 0.35, width: w * 0.4, height: h * 0.5))
                context.fill(tongue, with: .color(Color(hex: 0xF97316).opacity(0.45)))

            case .content:
                // Serene smile
                var path = Path()
                path.move(to: CGPoint(x: w * 0.18, y: h * 0.28))
                path.addQuadCurve(
                    to: CGPoint(x: w * 0.82, y: h * 0.28),
                    control: CGPoint(x: w * 0.5, y: h * 0.8)
                )
                context.stroke(path, with: .color(.white), lineWidth: w * 0.075)

            case .nudging:
                // Determined smirk
                var path = Path()
                path.move(to: CGPoint(x: w * 0.15, y: h * 0.32))
                path.addQuadCurve(
                    to: CGPoint(x: w * 0.85, y: h * 0.2),
                    control: CGPoint(x: w * 0.55, y: h * 0.85)
                )
                context.stroke(path, with: .color(.white), lineWidth: w * 0.075)

            case .stressed:
                // Worried wobbly mouth
                var path = Path()
                path.move(to: CGPoint(x: w * 0.1, y: h * 0.48))
                path.addCurve(
                    to: CGPoint(x: w * 0.9, y: h * 0.42),
                    control1: CGPoint(x: w * 0.33, y: h * 0.12),
                    control2: CGPoint(x: w * 0.67, y: h * 0.88)
                )
                context.stroke(path, with: .color(.white), lineWidth: w * 0.07)

            case .tired:
                // Little yawn "o"
                var path = Path()
                path.addEllipse(in: CGRect(x: w * 0.32, y: h * 0.12, width: w * 0.36, height: h * 0.58))
                context.fill(path, with: .color(Color(white: 0.1).opacity(0.8)))

            case .active:
                // Gritted determined teeth
                var jaw = Path()
                jaw.move(to: CGPoint(x: w * 0.1, y: h * 0.25))
                jaw.addQuadCurve(
                    to: CGPoint(x: w * 0.9, y: h * 0.25),
                    control: CGPoint(x: w * 0.5, y: h * 0.9)
                )
                jaw.closeSubpath()
                context.fill(jaw, with: .color(Color(white: 0.08)))
                var teeth = Path()
                teeth.move(to: CGPoint(x: w * 0.12, y: h * 0.27))
                teeth.addLine(to: CGPoint(x: w * 0.88, y: h * 0.27))
                context.stroke(teeth, with: .color(.white.opacity(0.7)), lineWidth: w * 0.055)

            case .conquering:
                // Massive triumph grin
                var path = Path()
                path.move(to: CGPoint(x: w * 0.02, y: h * 0.15))
                path.addQuadCurve(
                    to: CGPoint(x: w * 0.98, y: h * 0.15),
                    control: CGPoint(x: w * 0.5, y: h * 1.2)
                )
                path.closeSubpath()
                context.fill(path, with: .color(Color(white: 0.08)))
                var tongue = Path()
                tongue.addEllipse(in: CGRect(x: w * 0.28, y: h * 0.38, width: w * 0.44, height: h * 0.56))
                context.fill(tongue, with: .color(Color(hex: 0xEF4444).opacity(0.5)))
            }
        }
        .frame(width: size * 0.4, height: size * 0.24)
    }

    // MARK: - Cheek Blush

    private var cheekBlush: some View {
        HStack(spacing: size * 0.4) {
            cheekDot
            cheekDot
        }
        .offset(y: size * 0.12)
    }

    private var cheekDot: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        mood.premiumPalette.light.opacity(0.35),
                        mood.premiumPalette.light.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.09
                )
            )
            .frame(width: size * 0.18, height: size * 0.12)
    }

    // MARK: - Eyebrows

    private var stressedEyebrows: some View {
        HStack(spacing: size * 0.2) {
            Capsule()
                .fill(.white.opacity(0.85))
                .frame(width: size * 0.14, height: size * 0.028)
                .rotationEffect(.degrees(15))
            Capsule()
                .fill(.white.opacity(0.85))
                .frame(width: size * 0.14, height: size * 0.028)
                .rotationEffect(.degrees(-15))
        }
        .offset(y: -size * 0.015)
    }

    // MARK: - Zzz Bubble

    private var zzzBubble: some View {
        HStack(spacing: size * 0.01) {
            Text("z")
                .font(.system(size: size * 0.09, weight: .heavy, design: .rounded))
                .offset(y: anim.breatheScale > 1.01 ? -2 : 0)
            Text("z")
                .font(.system(size: size * 0.11, weight: .heavy, design: .rounded))
                .offset(y: anim.breatheScale > 1.01 ? -1 : 0)
            Text("z")
                .font(.system(size: size * 0.13, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.7))
    }
}
