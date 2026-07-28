//
//  ROOM_UNAPApp.swift
//  ROOM-UNAP
//
//  Created by Erick on 23/07/26.
//

import SwiftUI

@main
struct ROOM_UNAPApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .onOpenURL { url in
                    authViewModel.handleLoginCallback(url)
                }
        }
    }
}
