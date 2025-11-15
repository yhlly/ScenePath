//
//  ScenePathApp.swift
//  ScenePath
//

import SwiftUI
import SwiftData

@main
struct ScenePathApp: App {
    let container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: CollectibleItem.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
