import SwiftUI

struct HolidaysView: View {
    @EnvironmentObject var model: AppModel
    @State private var isAdding = false
    @State private var editingHoliday: Holiday?

    var body: some View {
        List {
            ForEach(model.holidays) { holiday in
                Button {
                    editingHoliday = holiday
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(holiday.name)
                                .font(.headline)
                            Text(holiday.date.display)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(holiday.slots.count) meals")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onDelete(perform: model.deleteHolidays)

            if model.holidays.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("No holidays yet")
                        .font(.headline)
                    Text("Add a holiday to override meal times for a specific date.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("Holidays")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isAdding = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $isAdding) {
            AddHolidaySheet { name, date in
                model.addHoliday(name: name, date: date)
            }
        }
        .sheet(item: $editingHoliday) { holiday in
            HolidayEditorView(holiday: holiday)
                .environmentObject(model)
        }
    }
}

struct AddHolidaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var date: Date = Date()

    var onAdd: (String, DateOnly) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Holiday") {
                    TextField("Name", text: $name)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("New Holiday")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onAdd(trimmed, DateOnly.from(date: date))
                        dismiss()
                    }
                }
            }
        }
    }
}

struct HolidayEditorView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var holiday: Holiday

    init(holiday: Holiday) {
        _holiday = State(initialValue: holiday)
    }

    var body: some View {
        List {
            Section("Details") {
                TextField("Name", text: $holiday.name)
                DatePicker("Date", selection: Binding(
                    get: { holiday.date.asDate() },
                    set: { holiday.date = DateOnly.from(date: $0) }
                ), displayedComponents: .date)
            }

            Section("Meal times") {
                SlotEditorList(
                    slots: holiday.slots,
                    meals: model.meals,
                    onChange: { holiday.slots = $0 }
                )
            }

            Section {
                Button("Save") {
                    model.updateHoliday(holiday)
                    dismiss()
                }
            }
        }
        .navigationTitle("Edit Holiday")
    }
}
