import SwiftUI

struct WeeklyPlannerView: View {
    @EnvironmentObject var model: AppModel
    private let calendar: Calendar = .current

    var body: some View {
        List {
            ForEach(Weekday.allCases) { weekday in
                Section(weekday.full) {
                    ForEach(MealKind.allCases) { kind in
                        TimeRow(
                            title: kind.title,
                            time: weeklyTime(for: weekday, kind: kind),
                            onChange: { newTime in
                                model.updateWeeklyTime(weekday: weekday, kind: kind, time: newTime)
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func weeklyTime(for weekday: Weekday, kind: MealKind) -> ClockTime {
        let key = String(weekday.rawValue)
        let slots = model.weeklySlotsByWeekday[key] ?? []
        return slots.first(where: { $0.kind == kind })?.time ?? defaultTime(for: kind)
    }

    private func defaultTime(for kind: MealKind) -> ClockTime {
        switch kind {
        case .breakfast: return ClockTime(hour: 8, minute: 0)
        case .lunch: return ClockTime(hour: 12, minute: 30)
        case .snack: return ClockTime(hour: 15, minute: 30)
        case .dinner: return ClockTime(hour: 18, minute: 30)
        }
    }
}

private struct TimeRow: View {
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
