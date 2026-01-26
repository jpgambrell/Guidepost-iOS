//
//  LaunchScreenView.swift
//  Guidepost
//
//  Created by John Gambrell
//

import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // Background gradient matching the icon
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.063, green: 0.725, blue: 0.506), // #10B981
                    Color(red: 0.020, green: 0.588, blue: 0.412)  // #059669
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // App Icon
                Image("LaunchIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                
                // App Name
                Text("Guidepost")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
