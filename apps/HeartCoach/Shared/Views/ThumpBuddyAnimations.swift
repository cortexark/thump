// ThumpBuddyAnimations.swift
// ThumpCore
//
// Animation state machine and timing for ThumpBuddy.
// Manages breathing, blinking, micro-expressions, and
// mood-specific animation sequences with organic timing.
// Platforms: iOS 17+, watchOS 10+

import SwiftUI

// MARK: - Animation Constants

/// Central timing and amplitude values for buddy animations.
enum BuddyAnimationConfig {

    // MARK: - Breathing

    static func breathDuration(for mood: BuddyMood) -> Double {
        switch mood {
        case .stressed:    return 1.2
        case .tired:       return 3.0
        case .celebrating: return 0.8
        case .thriving:    return 1.4
        case .active:      return 0.5
        case .conquering:  return 0.9
        default:           return 2.0
        }
    }

    static func breathAmplitude(for mood: BuddyMood) -> CGFloat {
        switch mood {
        case .stressed:    return 1.04
        case .celebrating: return 1.06
        case .tired:       return 1.015
        case .thriving:    return 1.05
        case .active:      return 1.07
        case .conquering:  return 1.08
        default:           return 1.025
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

    // MARK: - Published State

    var breatheScale: CGFloat = 1.0
    var bounceOffset: CGFloat = 0
    var eyeBlink: Bool = false
    var sparkleRotation: Double = 0
    var wiggleAngle: Double = 0
    var floatingHeartOffset: CGFloat = 0
    var floatingHeartOpacity: Double = 0.9
    var confettiActive: Bool = false
    var haloPhase: Double = 0
    var pupilLookX: CGFloat = 0
    var energyPulse: CGFloat = 1.0
    var glowPulse: CGFloat = 1.0
    var innerLightPhase: Double = 0

    // MARK: - Start All

    func startAnimations(mood: BuddyMood, size: CGFloat) {
        startBreathing(mood: mood)
        startBlinking()
        startMicroExpressions(size: size)
        startInnerLightRotation()

        if mood == .celebrating || mood == .conquering {
            startSparkleRotation()
            startConfetti()
        }
        if mood == .nudging || mood == .active { startBounce(size: size) }
        if mood == .stressed {
            startWiggle()
        } else {
            withAnimation(.easeOut(duration: 0.3)) { wiggleAngle = 0 }
        }
        if mood == .thriving {
            startFloatingHeart(size: size)
            startEnergyPulse()
        }
        if mood == .active {
            startEnergyPulse()
        }
        if mood == .content || mood == .thriving || mood == .conquering {
            startHaloRotation()
        }
        startGlowPulse(mood: mood)
    }

    // MARK: - Individual Animations

    private func startBreathing(mood: BuddyMood) {
        let duration = BuddyAnimationConfig.breathDuration(for: mood)
        let amplitude = BuddyAnimationConfig.breathAmplitude(for: mood)
        withAnimation(
            .easeInOut(duration: duration)
            .repeatForever(autoreverses: true)
        ) {
            breatheScale = amplitude
        }
    }

    private func startBlinking() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.5...5.0)))
                withAnimation(.easeInOut(duration: 0.1)) { eyeBlink = true }
                try? await Task.sleep(for: .seconds(0.15))
                withAnimation(.easeInOut(duration: 0.1)) { eyeBlink = false }
            }
        }
    }

    private func startMicroExpressions(size: CGFloat) {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 3.0...6.0)))
                let look = CGFloat.random(in: -size * 0.015...size * 0.015)
                withAnimation(.easeInOut(duration: 0.4)) { pupilLookX = look }
                try? await Task.sleep(for: .seconds(Double.random(in: 1.0...2.5)))
                withAnimation(.easeInOut(duration: 0.3)) { pupilLookX = 0 }
            }
        }
    }

    private func startSparkleRotation() {
        withAnimation(.linear(duration: 6.0).repeatForever(autoreverses: false)) {
            sparkleRotation = 360
        }
    }

    private func startBounce(size: CGFloat) {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            bounceOffset = -size * 0.05
        }
    }

    private func startWiggle() {
        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
            wiggleAngle = 2.5
        }
    }

    private func startFloatingHeart(size: CGFloat) {
        Task { @MainActor in
            while !Task.isCancelled {
                floatingHeartOffset = 0
                floatingHeartOpacity = 0.9
                withAnimation(.easeOut(duration: 2.0)) {
                    floatingHeartOffset = -size * 0.22
                    floatingHeartOpacity = 0.0
                }
                try? await Task.sleep(for: .seconds(3.0))
            }
        }
    }

    private func startEnergyPulse() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            energyPulse = 1.06
        }
    }

    private func startHaloRotation() {
        withAnimation(.linear(duration: 12.0).repeatForever(autoreverses: false)) {
            haloPhase = 360
        }
    }

    private func startConfetti() {
        confettiActive = false
        withAnimation(.easeOut(duration: 0.1)) { confettiActive = true }
    }

    private func startGlowPulse(mood: BuddyMood) {
        let range = BuddyAnimationConfig.glowPulseRange(for: mood)
        let duration = BuddyAnimationConfig.glowPulseDuration(for: mood)
        glowPulse = range.lowerBound
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            glowPulse = range.upperBound
        }
    }

    private func startInnerLightRotation() {
        withAnimation(.linear(duration: 20.0).repeatForever(autoreverses: false)) {
            innerLightPhase = 360
        }
    }
}
