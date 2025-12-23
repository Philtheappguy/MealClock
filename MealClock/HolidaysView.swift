import SwiftUI

struct HolidaysView: View {
    @EnvironmentObject var model: AppModel
    @State private var showingAdd: Bool = false

    var body: some View {
        List {
            if model.holidays.isEmpty {
                ContentUnavailableView("No holidays", systemImage: "calendar", description: Text("Add a holiday to override your normal meal times for that date."))
            } else {
                ForEach(model.holidays) { holiday in
                    NavigationLink(holiday.name) {
                        HolidayEditorView(holidayId: holiday.id)
                    }
                }
                .onDelete { indexSet in
                    for idx in indexSet {
                        model.deleteHoliday(model.holidays[idx].id)
                    }
                }
            }
        }
        .navigationTitle("Holidays")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddHolidaySheet(isPresented: $showingAdd)
        }
    }
}

private struct HolidayEditorView: View {
    @EnvironmentObject var model: AppModel
    let holidayId: UUID

    var holiday: Holiday? {
        model.holidays.first(where: { $0.id == holidayId })
    }

    var body: some View {
        if let holiday {
            List {
                Section {
                    Text("\(holiday.month)/\(holiday.day)")
                        .foregroundStyle(.secondary)
                } header: {
                    Text(holiday.name)
                }

                Section("Meal times") {
                    ForEach(MealKind.allCases) { kind in
                        HolidayTimeRow(
                            title: kind.title,
                            time: timeFor(kind: kind, holiday: holiday),
                            onChange: { newTime in
                                model.updateHolidayTime(holidayId: holidayId, kind: kind, time: newTime)
                            }
                        )
                    }
                }
            }
            .navigationTitle(holiday.name)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Holiday not found", systemImage: "calendar.badge.exclamationmark")
        }
    }

    private func timeFor(kind: MealKind, holiday: Holiday) -> ClockTime {
        holiday.slots.first(where: { $0.kind == kind })?.time ?? ClockTime(hour: 12, minute: 0)
    }
}


private struct HolidayTimeRow: View {
    let title: String
    let time: ClockTime
    let onChange: (ClockTime) -> Void

    private let calendar: Calendar = .current

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            DatePicker(
                "",
                selection: Binding(
                    get: { dateFrom(time) },
                    set: { newDate in
                        let comps = calendar.dateComponents([.hour, .minute], from: newDate)
                        onChange(ClockTime(hour: comps.hour ?? time.hour, minute: comps.minute ?? time.minute))
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
    }

    private func dateFrom(_ t: ClockTime) -> Date {
        calendar.date(from: DateComponents(hour: t.hour, minute: t.minute)) ?? Date()
    }
}

private struct AddHolidaySheet: View {
    @EnvironmentObject var model: AppModel
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var date: Date = Date()

    private let calendar: Calendar = .current

    var body: some View {
        NavigationStack {
            Form {
                Section("Holiday") {
                    TextField("Name", text: $name)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Holiday")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let comps = calendar.dateComponents([.month, .day], from: date)
                        model.addHoliday(name: name.isEmpty ? "Holiday" : name, month: comps.month ?? 1, day: comps.day ?? 1)
                        isPresented = false
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
