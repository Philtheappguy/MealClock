import SwiftUI

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var selectedDay: Date = Date()

    var body: some View {
        NavigationView {
            List {
                Section {
                    WeekStrip(selectedDate: $selectedDay)
                        .environmentObject(model)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 8)
                }

                Section("Today") {
                    CalorieProgressCard(day: selectedDay)
                        .environmentObject(model)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 8)

                    NextMealCard()
                        .environmentObject(model)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 8)
                }

                Section("Schedule") {
                    TodayScheduleList(day: selectedDay)
                        .environmentObject(model)
                }
            }
            .navigationTitle("MealClock")
        }
    }
}

// MARK: - Week Strip

struct WeekStrip: View {
    @EnvironmentObject var model: AppModel
    @Binding var selectedDate: Date

    var body: some View {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(days, id: \.self) { day in
                    let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                    let label = Formatters.weekdayShort(for: day)
                    let dayNum = calendar.component(.day, from: day)

                    VStack(spacing: 6) {
                        Text(label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(dayNum)")
                            .font(.headline)
                            .frame(width: 40, height: 40)
                            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedDate = day }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Cards

struct CalorieProgressCard: View {
    @EnvironmentObject var model: AppModel
    var day: Date

    var body: some View {
        let now = Date()
        let consumed = model.consumedCaloriesSoFar(for: day, now: now)
        let planned = model.plannedCalories(for: day)
        let rawGoal = model.settings.dailyCalorieGoal
        let denom = rawGoal > 0 ? max(rawGoal, 1) : max(planned, 1)
        let progress = min(Double(consumed) / Double(denom), 1.0)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Calories", systemImage: "flame.fill")
                Spacer()
                Text(rawGoal > 0 ? "\(consumed) / \(rawGoal)" : "\(consumed) / \(planned)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: progress)
                .accentColor(.accentColor)

            Text("Planned today: \(planned) kcal")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct NextMealCard: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let now = Date()
        let next = model.nextMeal(after: now)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Next meal", systemImage: "timer")
                Spacer()
                if let next {
                    Text(next.slot.time.display)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("—")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let next {
                let mealName = next.slot.resolvedMeal(in: model.meals)?.name ?? "Meal"
                let mealCals = next.slot.resolvedMeal(in: model.meals)?.calories
                Text(mealCals.map { "\(mealName) • \($0) kcal" } ?? mealName)
                    .font(.headline)

                CountdownText(targetDate: next.slot.time.date(on: next.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No more meals scheduled this week.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct CountdownText: View {
    var targetDate: Date
    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let remaining = max(Int(targetDate.timeIntervalSince(now)), 0)
        let hrs = remaining / 3600
        let mins = (remaining % 3600) / 60
        let secs = remaining % 60

        return Group {
            if remaining == 0 {
                Text("It's meal time.")
            } else if hrs > 0 {
                Text("In \(hrs)h \(mins)m")
            } else if mins > 0 {
                Text("In \(mins)m \(secs)s")
            } else {
                Text("In \(secs)s")
            }
        }
        .onReceive(timer) { t in
            now = t
        }
    }
}

// MARK: - Schedule list

struct TodayScheduleList: View {
    @EnvironmentObject var model: AppModel
    var day: Date

    var body: some View {
        let calendar = Calendar.current
        let now = Date()
        let slots = model.slots(for: day).sorted(by: { $0.time < $1.time })

        if slots.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                Text("No meal times")
                    .font(.headline)
                Text("Add a weekly schedule in Setup.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        } else {
            ForEach(slots) { slot in
                let dt = slot.time.date(on: day, calendar: calendar)
                let isPast = dt <= now && calendar.isDate(day, inSameDayAs: now)
                let meal = slot.resolvedMeal(in: model.meals)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(slot.time.display)
                            .font(.headline)

                        Text(meal?.name ?? "Meal")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let calories = meal?.calories {
                        Text("\(calories) kcal")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: isPast ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isPast ? .green : .secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
}
