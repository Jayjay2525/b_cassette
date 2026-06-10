//
//  ContentView.swift
//  Cassette
//
//  Created by Colin on 6/8/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        MainScreen()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
