//
//  Theme.swift
//  Guidepost
//
//  Created by John Gambrell on 1/22/26.
//

import SwiftUI

// MARK: - Color Theme Extension

extension Color {
    static let theme = ColorTheme()
}

struct ColorTheme {
    let backgroundPrimary = Color("BackgroundPrimary")
    let backgroundSecondary = Color("BackgroundSecondary")
    let textPrimary = Color("TextPrimary")
    let textSecondary = Color("TextSecondary")
    let inputBackground = Color("InputBackground")
    let inputBorder = Color("InputBorder")
    let accent = Color.cyan
    
    func accentGradient() -> LinearGradient {
        LinearGradient(
            colors: [.cyan, .blue],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Adaptive Background View

struct AdaptiveBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if colorScheme == .dark {
                // Dark mode: Current dark navy gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.1, blue: 0.25),
                        Color(red: 0.05, green: 0.1, blue: 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                // Light mode: Clean light gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.97, blue: 0.99),
                        Color(red: 0.95, green: 0.96, blue: 0.98),
                        Color(red: 0.96, green: 0.97, blue: 0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}

