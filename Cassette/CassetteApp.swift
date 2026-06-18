//
//  CassetteApp.swift
//  Cassette
//
//  Created by Colin on 6/8/26.
//

import SwiftUI

@main
struct CassetteApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await SupabaseManager.shared.checkPendingCassettes(appState: appState)
                }
            }
        }
    }
}
