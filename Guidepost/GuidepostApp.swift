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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authViewModel)
                .environment(imageGridViewModel)
        }
    }
}
