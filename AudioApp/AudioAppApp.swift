//
//  AudioAppApp.swift
//  AudioApp
//
//  Created by Rushal Butala on 7/2/25.
//


import SwiftUI
import SwiftData

@main
struct AudioAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: RecordingSession.self)
    }
}
