import SwiftUI

struct HomeView: View {
    @EnvironmentObject var model: AppModel

    @State private var selectedDate: Date = Date()
    @State private var showingPickerForKind: MealKind?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Home")
                        .font(.largeTitle.bold())
                    Text(selectedDate.formatted(date: .complete, time: .omitted))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                WeekStrip(selectedDate: $selectedDate)
                    .padding(.horizontal)

                CalorieProgressCard(day: selectedDate)
                    .padding(.horizontal)

                NextMealCard(now: Date())
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Today’s picks")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(MealKind.allCases) { kind in
                        MealTimeCard(
                            kind: kind,
                            time: timeFor(kind: kind),
                            meals: model.selectedMeals(for: selectedDate, kind: kind),
                            isChecked: model.isChecked(for: selectedDate, kind: kind),
                            onToggleChecked: { model.toggleChecked(for: selectedDate, kind: kind) },
                            onAdd: { showingPickerForKind = kind },
                            onRemove: { mealId in
                                model.removeMeal(from: selectedDate, kind: kind, mealId: mealId)
                            }
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(item: $showingPickerForKind) { kind in
            MealPickerSheet(
                title: "Add to \(kind.title)",
                meals: model.meals,
                onPick: { meal in
                    model.addMeal(to: selectedDate, kind: kind, mealId: meal.id)
                }
            )
        }
    }

    private func timeFor(kind: MealKind) -> ClockTime? {
        model.slots(for: selectedDate).first(where: { $0.kind == kind })?.time
    }
}

// MARK: - Meal Time Card

private struct MealTimeCard: View {
    let kind: MealKind
    let time: ClockTime?
    let meals: [Meal]
    let isChecked: Bool

    let onToggleChecked: () -> Void
    let onAdd: () -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(kind.title, systemImage: kind.systemImage)
                    .font(.headline)

                Spacer()

                if let time {
                    Text(time.shortString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button(action: onToggleChecked) {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isChecked ? "Uncheck \(kind.title)" : "Check \(kind.title)")
            }

            if meals.isEmpty {
                Text("No meals picked yet.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(meals) { meal in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.name)
                                if !meal.macroSummary.isEmpty {
                                    Text(meal.macroSummary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text("\(meal.calories) cal")
                                .foregroundStyle(.secondary)

                            Button {
                                onRemove(meal.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 6)
                            .accessibilityLabel("Remove \(meal.name)")
                        }
                    }
                }
            }

            Button(action: onAdd) {
                Label("Add meal", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemBackground)))
    }
}

// MARK: - Calorie Progress

private struct CalorieProgressCard: View {
    @EnvironmentObject var model: AppModel
    let day: Date

    var body: some View {
        let goal = max(1, model.settings.dailyCalorieGoal)
        let consumed = model.consumedCaloriesSoFar(for: day)
        let fraction = min(Double(consumed) / Double(goal), 1.0)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Calories")
                    .font(.headline)
                Spacer()
                Text("\(consumed) / \(goal)")
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: fraction)

            Text("Checked meals add to your total.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemBackground)))
    }
}

// MARK: - Next Meal

private struct NextMealCard: View {
    @EnvironmentObject var model: AppModel
    let now: Date

    var body: some View {
        let next = model.nextMeal(after: now)

        VStack(alignment: .leading, spacing: 10) {
            Text("Next up")
                .font(.headline)

            if let next {
                let meals = model.selectedMeals(for: next.date, kind: next.kind)
                let subtitle: String = {
                    if meals.isEmpty { return "No meal picked yet" }
                    if meals.count == 1 { return meals[0].name }
                    return "\(meals.count) meals"
                }()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(next.kind.title)
                            .font(.title3.bold())
                        Text(subtitle)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(next.time.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No upcoming meal times.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemBackground)))
    }
}

// MARK: - Week Strip

private struct WeekStrip: View {
    @Binding var selectedDate: Date

    private let calendar: Calendar = .current

    var body: some View {
        let today = calendar.startOfDay(for: Date())
        let selected = calendar.startOfDay(for: selectedDate)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(-3...10, id: \.self) { offset in
                    let day = calendar.date(byAdding: .day, value: offset, to: today) ?? today
                    let isSelected = calendar.isDate(day, inSameDayAs: selected)
                    let label = labelFor(day: day)

                    Button {
                        selectedDate = day
                    } label: {
                        Text(label)
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule().fill(isSelected ? Color.accentColor.opacity(0.25) : Color(uiColor: .secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func labelFor(day: Date) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        return day.formatted(.dateTime.weekday(.abbreviated).day())
    }
}

// MARK: - Meal Picker Sheet

private struct MealPickerSheet: View {
    let title: String
    let meals: [Meal]
    let onPick: (Meal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    var filteredMeals: [Meal] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return meals }
        return meals.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if meals.isEmpty {
                    ContentUnavailableView("No meals yet", systemImage: "fork.knife", description: Text("Add meals in the Meals tab first."))
                } else {
                    ForEach(filteredMeals) { meal in
                        Button {
                            onPick(meal)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(meal.name)
                                    if !meal.macroSummary.isEmpty {
                                        Text(meal.macroSummary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(meal.calories) cal")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
