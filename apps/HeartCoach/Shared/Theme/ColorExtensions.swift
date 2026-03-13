// ColorExtensions.swift
// ThumpCore
//
// Shared color utilities used across iOS and watchOS targets.
//
// Platforms: iOS 17+, watchOS 10+

import SwiftUI

// MARK: - Hex Color Initializer

extension Color {
    /// Creates a `Color` from a hex integer (e.g. `0x22C55E`).
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
