//
//  GuidepostApp.swift
//  Guidepost
//
//  Created by John Gambrell on 11/21/25.
//

import SwiftUI

@main
struct GuidepostApp: App {
    @State private var viewModel = ImageGridViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(viewModel)
        }
    }
}
