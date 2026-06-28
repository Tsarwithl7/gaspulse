import SwiftUI

@main
struct OilMonitorApp: App {
    @StateObject private var viewModel = OilPriceViewModel()

    var body: some Scene {
        Window("Oil Monitor", id: "main") {
            MenuBarContentView()
                .environmentObject(viewModel)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Settings {
            SettingsView()
                .environmentObject(viewModel)
        }
    }
}
