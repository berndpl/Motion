//
//  MotionApp.swift
//  Motion
//
//  Created by Bernd Plontsch on 30.07.2025.
//

import SwiftUI

@main
struct MotionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
#if os(macOS)
.windowStyle(.hiddenTitleBar)
.windowResizability(.contentMinSize)
.defaultSize(width: 300, height: 200)
#endif
    }
}
