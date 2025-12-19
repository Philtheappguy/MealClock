import SwiftUI

struct SetupView: View {
    @EnvironmentObject var model: AppModel
    @State private var workingSettings: AppSettings = AppSettings()
    @State private var showingNotificationHelp = false

    var body: some View {
        NavigationView {
            Form {
                Section("Goal") {
                    Stepper(value: $workingSettings.dailyCalorieGoal, in: 0...8000, step: 50) {
                        HStack {
                            Text("Daily calorie goal")
                            Spacer()
                            Text(workingSettings.dailyCalorieGoal == 0 ? "Off" : "\(workingSettings.dailyCalorieGoal)")
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("Progress fills as each scheduled meal time passes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Notifications") {
                    Toggle("Meal time alerts", isOn: $workingSettings.notificationsEnabled)

                    Picker("Notify", selection: $workingSettings.notifyMinutesBefore) {
                        Text("At meal time").tag(0)
                        Text("5 minutes before").tag(5)
                        Text("10 minutes before").tag(10)
                        Text("15 minutes before").tag(15)
                    }

                    Button("Reschedule notifications") {
                        model.updateSettings(workingSettings)
                        model.rescheduleNotifications()
                    }
                    .disabled(!workingSettings.notificationsEnabled)

                    Button("Help: Notifications") { showingNotificationHelp = true }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $workingSettings.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.label).tag(theme)
                        }
                    }
                }

                Section("Meal times") {
                    NavigationLink {
                        WeeklyPlannerView()
                            .environmentObject(model)
                    } label: {
                        Label("Weekly schedule", systemImage: "calendar")
                    }

                    NavigationLink {
                        HolidaysView()
                            .environmentObject(model)
                    } label: {
                        Label("Holidays", systemImage: "calendar.badge.plus")
                    }
                }

                Section {
                    Text("Weekly times repeat forever. Holidays override the weekly schedule for that specific date.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Setup")
            .onAppear {
                workingSettings = model.settings
            }
            .onChange(of: workingSettings) { _, newValue in
                model.updateSettings(newValue)
            }
            .alert(isPresented: $showingNotificationHelp) {
                Alert(title: Text("Notifications"),
                      message: Text("On first run, iOS will ask for permission. If you previously denied notifications, enable them in Settings → Notifications → MealClock."),
                      dismissButton: .default(Text("OK")))
            }
}
    }
}
