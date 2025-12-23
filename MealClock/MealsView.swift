import SwiftUI

struct MealsView: View {
    @EnvironmentObject var model: AppModel
    @State private var isPresentingAdd = false
    @State private var editingMeal: Meal?

    var body: some View {
        NavigationView {
            List {
                ForEach(model.meals) { meal in
                    Button {
                        editingMeal = meal
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(meal.name)
                                    .font(.headline)
                                Text(meal.macroSummary)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(meal.calories) kcal")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: model.deleteMeals)
            }
            .navigationTitle("Meals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAdd) {
                MealEditorView(meal: Meal(name: "", calories: 0)) { newMeal in
                    model.addMeal(newMeal)
                }
            }
            .sheet(item: $editingMeal) { meal in
                MealEditorView(meal: meal) { updated in
                    model.updateMeal(updated)
                }
            }
        }
    }
}

struct MealEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var meal: Meal
    var onSave: (Meal) -> Void

    init(meal: Meal, onSave: @escaping (Meal) -> Void) {
        _meal = State(initialValue: meal)
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Meal") {
                    TextField("Name", text: $meal.name)
                    Stepper(value: $meal.calories, in: 0...5000, step: 10) {
                        HStack {
                            Text("Calories")
                            Spacer()
                            Text("\(meal.calories)")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Macros (optional)") {
                    IntFieldRow(title: "Protein (g)", value: Binding(
                        get: { meal.protein ?? 0 },
                        set: { meal.protein = ($0 == 0 ? nil : $0) }
                    ))
                    IntFieldRow(title: "Carbs (g)", value: Binding(
                        get: { meal.carbs ?? 0 },
                        set: { meal.carbs = ($0 == 0 ? nil : $0) }
                    ))
                    IntFieldRow(title: "Fat (g)", value: Binding(
                        get: { meal.fat ?? 0 },
                        set: { meal.fat = ($0 == 0 ? nil : $0) }
                    ))
                }

                Section("Notes") {
                    TextField("Optional notes", text: Binding(
                        get: { meal.notes ?? "" },
                        set: { meal.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...8)
                }
            }
            .navigationTitle(meal.name.isEmpty ? "New Meal" : "Edit Meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = meal.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        meal.name = trimmed
                        onSave(meal)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct IntFieldRow: View {
    var title: String
    @Binding var value: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }
}
