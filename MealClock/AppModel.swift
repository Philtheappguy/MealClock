import Foundation
import SwiftUI

final class AppModel: ObservableObject {
    @Published private(set) var meals: [Meal] = []
    @Published private(set) var weeklySlotsByWeekday: [String: [MealSlot]] = [:]
    @Published private(set) var holidays: [Holiday] = []
    @Published var settings: AppSettings = AppSettings()

    private let persistence = Persistence.shared

    func bootstrap() {
        if let loaded = persistence.load() {
            apply(state: loaded, saveAfter: false)
        } else {
            apply(state: .default, saveAfter: true)
        }
        rescheduleNotifications()
    }

    // MARK: - State

    private func apply(state: AppState, saveAfter: Bool) {
        self.meals = state.meals
        self.weeklySlotsByWeekday = state.weeklySlotsByWeekday
        self.holidays = state.holidays
        self.settings = state.settings

        if saveAfter { save() }
        ensureMealAssignments()
    }

    private func ensureMealAssignments() {
        // Optional convenience: if default schedule has nil meal IDs, assign first 3 meals.
        if meals.isEmpty { return }
        let mealIds = meals.map(\.id)
        for key in weeklySlotsByWeekday.keys {
            var slots = weeklySlotsByWeekday[key] ?? []
            for i in slots.indices {
                if slots[i].mealId == nil {
                    slots[i].mealId = mealIds[min(i, mealIds.count - 1)]
                }
            }
            weeklySlotsByWeekday[key] = slots
        }
    }

    private func save() {
        let state = AppState(meals: meals,
                             weeklySlotsByWeekday: weeklySlotsByWeekday,
                             holidays: holidays,
                             settings: settings)
        persistence.save(state)
    }

    // MARK: - Derived Schedule

    func weekday(for date: Date, calendar: Calendar = .current) -> Weekday {
        Weekday(rawValue: calendar.component(.weekday, from: date)) ?? .monday
    }

    func slots(for date: Date) -> [MealSlot] {
        let dayOnly = DateOnly.from(date: date)
        if let holiday = holidays.first(where: { $0.date == dayOnly }) {
            return holiday.slots
        }
        let wd = weekday(for: date)
        return weeklySlotsByWeekday[String(wd.rawValue)] ?? []
    }

    func plannedCalories(for date: Date) -> Int {
        slots(for: date)
            .compactMap { $0.resolvedMeal(in: meals)?.calories }
            .reduce(0, +)
    }

    func consumedCaloriesSoFar(for date: Date, now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let daySlots = slots(for: date).sorted(by: { $0.time < $1.time })
        return daySlots
            .filter { $0.time.date(on: date, calendar: calendar) <= now }
            .compactMap { $0.resolvedMeal(in: meals)?.calories }
            .reduce(0, +)
    }

    func nextMeal(after now: Date = Date()) -> (date: Date, slot: MealSlot)? {
        let calendar = Calendar.current

        for offset in 0..<8 { // search up to a week ahead
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let daySlots = slots(for: day).sorted(by: { $0.time < $1.time })
            for slot in daySlots {
                let dt = slot.time.date(on: day, calendar: calendar)
                if dt > now {
                    return (day, slot)
                }
            }
        }
        return nil
    }

    // MARK: - Meals CRUD

    func addMeal(_ meal: Meal) {
        meals.append(meal)
        save()
        rescheduleNotifications()
    }

    func updateMeal(_ meal: Meal) {
        guard let idx = meals.firstIndex(where: { $0.id == meal.id }) else { return }
        meals[idx] = meal
        save()
        rescheduleNotifications()
    }

    func deleteMeals(at offsets: IndexSet) {
        let ids = offsets.map { meals[$0].id }
        meals.remove(atOffsets: offsets)

        // Clear any slot references
        for key in weeklySlotsByWeekday.keys {
            weeklySlotsByWeekday[key] = (weeklySlotsByWeekday[key] ?? []).map { slot in
                var s = slot
                if let mId = s.mealId, ids.contains(mId) { s.mealId = nil }
                return s
            }
        }
        for i in holidays.indices {
            holidays[i].slots = holidays[i].slots.map { slot in
                var s = slot
                if let mId = s.mealId, ids.contains(mId) { s.mealId = nil }
                return s
            }
        }

        save()
        rescheduleNotifications()
    }

    // MARK: - Weekly Slots CRUD

    func setSlots(_ slots: [MealSlot], for weekday: Weekday) {
        weeklySlotsByWeekday[String(weekday.rawValue)] = slots.sorted(by: { $0.time < $1.time })
        save()
        rescheduleNotifications()
    }

    // MARK: - Holidays CRUD

    func addHoliday(name: String, date: DateOnly) {
        let holiday = Holiday(name: name, date: date, slots: slots(for: date.asDate()))
        holidays.append(holiday)
        holidays.sort(by: { $0.date < $1.date })
        save()
        rescheduleNotifications()
    }

    func updateHoliday(_ holiday: Holiday) {
        guard let idx = holidays.firstIndex(where: { $0.id == holiday.id }) else { return }
        holidays[idx] = holiday
        holidays.sort(by: { $0.date < $1.date })
        save()
        rescheduleNotifications()
    }

    func deleteHolidays(at offsets: IndexSet) {
        holidays.remove(atOffsets: offsets)
        save()
        rescheduleNotifications()
    }

    // MARK: - Settings

    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        save()
        rescheduleNotifications()
    }

    // MARK: - Notifications

    func rescheduleNotifications() {
    Notify.scheduleNextDays(days: 30, settings: settings, meals: meals) { [weak self] date in
        return self?.slots(for: date) ?? []
    }
}


}
