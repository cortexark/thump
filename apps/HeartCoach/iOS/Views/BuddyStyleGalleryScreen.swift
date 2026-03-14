// BuddyStyleGalleryScreen.swift
// Shows ThumpBuddy in all 8 moods on one page for evaluation.

import SwiftUI

struct BuddyStyleGalleryScreen: View {

    private let allMoods: [BuddyMood] = [
        .thriving, .content, .nudging, .stressed, .tired, .celebrating, .active, .conquering
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(allMoods, id: \.rawValue) { mood in
                    VStack(spacing: 2) {
                        ThumpBuddy(mood: mood, size: 48)
                            .frame(height: 88)
                        Text(mood.label)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(mood.bodyColors[1])
                        Text(mood.rawValue)
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 2)
        }
        .background(.black)
    }
}

#Preview {
    BuddyStyleGalleryScreen()
}
