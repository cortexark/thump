// ThumpBuddyFace.swift
// ThumpCore
//
// ThumpBuddy-inspired minimal face. Two soft eyes. Nothing else.
// No mouth, no eyebrows, no cheeks, no accessories.
//
// Mood is communicated through:
//   1. Eye shape — round (alert), relaxed (content), heavy-lidded (tired),
//      slightly tense (stressed), narrowed (focused)
//   2. Pupil position — subtle micro-saccades for life
//   3. Blink — natural rhythm
//   4. Sphere color — already mood-driven via BuddyMood.premiumPalette
//
// At 82px on a watch face, less is more. Complexity below 50px
// becomes noise, not expression.
//
// Platforms: iOS 17+, watchOS 10+

import SwiftUI

// MARK: - Face Layout

struct ThumpBuddyFace: View {

    let mood: BuddyMood
    let size: CGFloat
    let anim: BuddyAnimationState

    var body: some View {
        ZStack {
            // ThumpBuddy signature: thin line connecting the two eyes
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: size * (eyeSpacing + 0.22), height: size * 0.018)
                .offset(y: size * eyeVerticalOffset)

            HStack(spacing: size * eyeSpacing) {
                buddyEye(isLeft: true)
                buddyEye(isLeft: false)
            }
            .offset(y: size * eyeVerticalOffset)
        }
    }

    // MARK: - Eye

    @ViewBuilder
    private func buddyEye(isLeft: Bool) -> some View {
        if anim.eyeBlink {
            // Blink — curved line
            blinkEye
        } else if anim.eyeSquint {
            // Happy squint — ^_^ ThumpBuddy smile-eyes
            squintEye
        } else {
            // Open eye — shape varies by mood
            openEye(isLeft: isLeft)
        }
    }

    // MARK: - Happy Squint Eye
    //
    // ThumpBuddy's signature happy expression: eyes squeeze into upward
    // crescent arcs — the universal ^_^ that says "I'm happy for you."
    //
    // Unlike the previous stroke-only arc, this version:
    //   1. Fills a crescent shape (white sclera still visible)
    //   2. Shows a pupil peeking below the crescent lid
    //   3. Keeps the specular highlight for life
    // This matches how ThumpBuddy's eyes narrow into warm crescents
    // while the dark pupil remains visible underneath.

    private var squintEye: some View {
        let w = size * 0.21
        let h = size * 0.15
        return ZStack {
            // Sclera — same soft white as open eye, but squished into crescent
            BuddyHappyEyeShape()
                .fill(
                    RadialGradient(
                        colors: [.white, Color(white: 0.93)],
                        center: UnitPoint(x: 0.5, y: 0.6),
                        startRadius: 0,
                        endRadius: w * 0.5
                    )
                )
                .frame(width: w, height: h)

            // Pupil — peeking below the crescent, slightly visible
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.04), Color(white: 0.18)],
                        center: UnitPoint(x: 0.4, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.04
                    )
                )
                .frame(width: size * 0.075, height: size * 0.055)
                .offset(y: h * 0.22)

            // Specular highlight — keeps the eye alive
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: size * 0.035)
                .offset(x: -size * 0.015, y: -h * 0.05)
        }
    }

    // MARK: - Open Eye
    //
    // Soft oval with a dark pupil and one specular highlight.
    // Shape and proportions shift per mood — that's the entire
    // expression system.

    private func openEye(isLeft: Bool) -> some View {
        let w = eyeWidth
        let h = eyeHeight

        return ZStack {
            // Sclera — soft white with subtle depth gradient
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            .white,
                            Color(white: 0.95),
                            Color(white: 0.90)
                        ],
                        center: UnitPoint(x: 0.45, y: 0.35),
                        startRadius: 0,
                        endRadius: w * 0.6
                    )
                )
                .frame(width: w, height: h)

            // Eyelid — for tired/stressed, a semi-circle clips the top
            if mood == .tired || mood == .stressed {
                eyelidOverlay(width: w, height: h)
            }

            // Pupil — dark circle, slightly off-center for life
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.04),
                            Color(white: 0.14),
                        ],
                        center: UnitPoint(x: 0.4, y: 0.35),
                        startRadius: 0,
                        endRadius: size * 0.045
                    )
                )
                .frame(width: pupilSize)
                .offset(
                    x: anim.pupilLookX + pupilXShift(isLeft: isLeft),
                    y: anim.pupilLookY + pupilYShift
                )

            // Primary specular highlight — bright dot, upper area
            Circle()
                .fill(.white.opacity(0.92))
                .frame(width: size * 0.048)
                .offset(
                    x: isLeft ? -size * 0.021 : size * 0.012,
                    y: -size * 0.027
                )

            // Secondary tiny sparkle — lower-left for depth
            Circle()
                .fill(.white.opacity(0.65))
                .frame(width: size * 0.02)
                .offset(
                    x: isLeft ? size * 0.015 : -size * 0.01,
                    y: size * 0.025
                )
        }
    }

    // MARK: - Eyelid Overlay
    //
    // A half-lid that droops from the top. More droop = more tired.
    // Stressed gets a slight lid tension (less droop than tired).

    private func eyelidOverlay(width: CGFloat, height: CGFloat) -> some View {
        let lidCoverage: CGFloat = mood == .tired ? 0.4 : 0.22
        return VStack(spacing: 0) {
            // The lid — matches sphere body color so it blends
            Ellipse()
                .fill(mood.premiumPalette.mid)
                .frame(width: width * 1.08, height: height * lidCoverage * 2)
                .offset(y: -height * (1 - lidCoverage) * 0.5)
            Spacer(minLength: 0)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    // MARK: - Blink

    private var blinkEye: some View {
        BuddyBlinkShape()
            .stroke(.white, lineWidth: size * 0.038)
            .frame(width: size * 0.21, height: size * 0.09)
    }

    // MARK: - Eye Dimensions Per Mood
    //
    // The eye shape IS the expression:
    //   thriving:    relaxed, slightly narrowed (content squint)
    //   content:     round, open, calm
    //   nudging:     standard, alert
    //   stressed:    slightly wider + eyelid tension
    //   tired:       narrow height + heavy eyelid
    //   active:      wider, focused
    //   celebrating: round, wide
    //   conquering:  round, satisfied

    private var eyeWidth: CGFloat {
        switch mood {
        case .thriving:                return size * 0.24
        case .content:                 return size * 0.225
        case .nudging:                 return size * 0.225
        case .stressed:                return size * 0.255
        case .tired:                   return size * 0.225
        case .active:                  return size * 0.255
        case .celebrating, .conquering: return size * 0.24
        }
    }

    private var eyeHeight: CGFloat {
        switch mood {
        case .thriving:                return size * 0.21
        case .content:                 return size * 0.24
        case .nudging:                 return size * 0.225
        case .stressed:                return size * 0.27
        case .tired:                   return size * 0.18
        case .active:                  return size * 0.225
        case .celebrating, .conquering: return size * 0.255
        }
    }

    private var pupilSize: CGFloat {
        switch mood {
        case .tired:    return size * 0.098
        case .stressed: return size * 0.105
        case .active:   return size * 0.112
        default:        return size * 0.105
        }
    }

    private var eyeSpacing: CGFloat {
        switch mood {
        case .stressed: return 0.20  // slightly closer = concerned
        case .active:   return 0.22  // slightly closer = focused
        default:        return 0.24  // normal spacing
        }
    }

    private var eyeVerticalOffset: CGFloat {
        switch mood {
        case .tired: return 0.04   // eyes sit lower = heavy
        default:     return 0.0
        }
    }

    private func pupilXShift(isLeft: Bool) -> CGFloat {
        switch mood {
        case .nudging: return size * 0.01
        case .tired:   return isLeft ? -size * 0.005 : size * 0.005
        default:       return 0
        }
    }

    private var pupilYShift: CGFloat {
        switch mood {
        case .tired:  return size * 0.01   // looking down slightly
        case .active: return -size * 0.005 // looking slightly up
        default:      return 0
        }
    }
}
