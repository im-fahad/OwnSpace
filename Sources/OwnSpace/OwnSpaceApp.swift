import AppKit
import SwiftUI

@main
struct OwnSpaceApp: App {
    @State private var model = AppModel()

    init() {
        // Run straight from `swift run` there is no bundle, so ask for a Dock icon and focus explicitly.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }

    var body: some Scene {
        WindowGroup("OwnSpace") {
            ContentView()
                .environment(model)
                .frame(minWidth: 820, minHeight: 560)
                .task { await model.scan() }
        }
        .defaultSize(width: 1040, height: 720)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Scan Again") { Task { await model.scan() } }
                    .keyboardShortcut("r")
                    .disabled(model.isBusy)
            }
        }
    }
}
