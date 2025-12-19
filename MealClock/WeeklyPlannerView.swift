import SwiftUI

struct WeeklyPlannerView: View {
    @EnvironmentObject var model: AppModel
    @State private var selectedWeekday: Weekday = {
        let wd = Calendar.current.component(.weekday, from: Date())
        return Weekday(rawValue: wd) ?? .monday
    }()

    var body: some View {
        let slots = model.weeklySlotsByWeekday[String(selectedWeekday.rawValue)] ?? []

        List {
            Section {
                Picker("Day", selection: $selectedWeekday) {
                    ForEach(Weekday.allCases) { wd in
                        Text(wd.full).tag(wd)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Meals for \(selectedWeekday.full)") {
                SlotEditorList(
                    slots: slots,
                    meals: model.meals,
                    onChange: { newSlots in
                        model.setSlots(newSlots, for: selectedWeekday)
                    }
                )
            }

            Section {
                Text("These meal times repeat every \(selectedWeekday.full).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Weekly schedule")
    }
}

struct SlotEditorList: View {
    var slots: [MealSlot]
    var meals: [Meal]
    var onChange: ([MealSlot]) -> Void

    @State private var localSlots: [MealSlot] = []

    var body: some View {
        ForEach(localSlots) { slot in
            SlotRowEditor(slot: binding(for: slot), meals: meals)
        }
        .onDelete { offsets in
            localSlots.remove(atOffsets: offsets)
            commit()
        }

        Button {
            localSlots.append(MealSlot(time: ClockTime(hour: 12, minute: 0), mealId: meals.first?.id))
            localSlots.sort(by: { $0.time < $1.time })
            commit()
        } label: {
            Label("Add meal time", systemImage: "plus")
        }
        .onAppear {
            localSlots = slots.sorted(by: { $0.time < $1.time })
        }
        .onChange(of: slots) { _, newValue in
            // Keep in sync if parent changes
            localSlots = newValue.sorted(by: { $0.time < $1.time })
        }
    }

    private func binding(for slot: MealSlot) -> Binding<MealSlot> {
        guard let idx = localSlots.firstIndex(where: { $0.id == slot.id }) else {
            return .constant(slot)
        }
        return Binding(
            get: { localSlots[idx] },
            set: { newValue in
                localSlots[idx] = newValue
                localSlots.sort(by: { $0.time < $1.time })
                commit()
            }
        )
    }

    private func commit() {
        onChange(localSlots.sorted(by: { $0.time < $1.time }))
    }
}

struct SlotRowEditor: View {
    @Binding var slot: MealSlot
    var meals: [Meal]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TimePickerInline(time: $slot.time)
                Spacer()
                Image(systemName: "bell")
                    .foregroundColor(.secondary)
            }

            Picker("Meal", selection: Binding(
                get: { slot.mealId ?? meals.first?.id },
                set: { slot.mealId = $0 }
            )) {
                ForEach(meals) { meal in
                    Text(meal.name).tag(Optional(meal.id))
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.vertical, 4)
    }
}

struct TimePickerInline: View {
    @Binding var time: ClockTime
    @State private var tmpDate: Date = Date()

    var body: some View {
        DatePicker("", selection: Binding(
            get: {
                var comps = DateComponents()
                comps.hour = time.hour
                comps.minute = time.minute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newDate in
                time = ClockTime.from(date: newDate)
            }
        ), displayedComponents: .hourAndMinute)
        .labelsHidden()
    }
}
