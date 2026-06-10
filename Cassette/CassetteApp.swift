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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
