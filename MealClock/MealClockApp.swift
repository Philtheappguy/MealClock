import SwiftUI

@main
struct MealClockApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .preferredColorScheme(model.settings.theme.colorScheme)
                .onAppear {
                    model.bootstrap()
                }
        }
    }
}
