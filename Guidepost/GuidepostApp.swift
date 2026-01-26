//
//  GuidepostApp.swift
//  Guidepost
//
//  Created by John Gambrell on 11/21/25.
//

import SwiftUI

@main
struct GuidepostApp: App {
    @State private var authViewModel = AuthViewModel()
    @State private var imageGridViewModel = ImageGridViewModel()
    @State private var appearanceManager = AppearanceManager()
    @State private var showLaunchScreen = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(authViewModel)
                    .environment(imageGridViewModel)
                    .environment(appearanceManager)
                
                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showLaunchScreen = false
                    }
                }
            }
        }
    }
}
