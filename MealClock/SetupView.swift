import SwiftUI

struct SetupView: View {
    @EnvironmentObject var model: AppModel

    @State private var goal: Int = 2000
    @State private var notificationsEnabled: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    Stepper(value: $goal, in: 0...8000, step: 50) {
                        HStack {
                            Text("Daily calorie goal")
                            Spacer()
                            Text("\(goal)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Meal times") {
                    NavigationLink("Weekly schedule") {
                        WeeklyPlannerView()
                    }
                    NavigationLink("Holidays") {
                        HolidaysView()
                    }
                }

                Section {
                    Toggle("Meal reminders", isOn: $notificationsEnabled)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Reminders are scheduled using your meal times. You can change them above.")
                }
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                goal = model.settings.dailyCalorieGoal
                notificationsEnabled = model.settings.notificationsEnabled
            }
            .onChange(of: goal) { _, newValue in
                model.setDailyCalorieGoal(newValue)
            }
            .onChange(of: notificationsEnabled) { _, newValue in
                model.setNotificationsEnabled(newValue)
            }
        }
    }
}
