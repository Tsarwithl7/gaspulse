import SwiftUI

@main
struct GasPulseApp: App {
    @StateObject private var viewModel = OilPriceViewModel()

    var body: some Scene {
        Window("GasPulse", id: "main") {
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
