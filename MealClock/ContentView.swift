import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            MealsView()
                .tabItem { Label("Meals", systemImage: "fork.knife") }

            SetupView()
                .tabItem { Label("Setup", systemImage: "slider.horizontal.3") }
        }
    }
}
