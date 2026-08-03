//
//  ContentView.swift
//  ROOM-UNAP
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("preferredColorScheme") private var preferredColorScheme = "system"
    @AppStorage("preferredInteractionAccent") private var preferredInteractionAccent = InteractionAccent.blue.rawValue

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                AuthRootView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authViewModel.isAuthenticated)
        .preferredColorScheme(colorScheme)
        .tint(interactionAccent.tintColor)
        .accentColor(interactionAccent.tintColor)
        .buttonStyle(RoomUnapPressableButtonStyle(accentColor: interactionAccent.tintColor, cornerRadius: 18))
    }

    private var colorScheme: ColorScheme? {
        switch preferredColorScheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    private var interactionAccent: InteractionAccent {
        InteractionAccent(rawValue: preferredInteractionAccent) ?? .blue
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
