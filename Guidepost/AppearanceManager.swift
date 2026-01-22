//
//  AppearanceManager.swift
//  Guidepost
//
//  Created by John Gambrell on 1/22/26.
//

import SwiftUI

@Observable
class AppearanceManager {
    var selectedAppearance: AppearanceMode {
        didSet {
            UserDefaults.standard.set(selectedAppearance.rawValue, forKey: "selectedAppearance")
        }
    }
    
    init() {
        let savedValue = UserDefaults.standard.string(forKey: "selectedAppearance") ?? AppearanceMode.system.rawValue
        self.selectedAppearance = AppearanceMode(rawValue: savedValue) ?? .system
    }
    
    var colorScheme: ColorScheme? {
        switch selectedAppearance {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
    
    var displayName: String {
        rawValue
    }
}

