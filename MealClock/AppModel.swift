import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var meals: [Meal] = []
    @Published private(set) var weeklySlotsByWeekday: [String: [MealSlot]] = [:]
    @Published private(set) var holidays: [Holiday] = []
    @Published private(set) var settings: Settings = Settings()
    @Published private(set) var dayLogs: [String: DayLog] = [:]

    private let persistence: Persistence
    private let calendar: Calendar = .current

    init(persistence: Persistence = .shared) {
        self.persistence = persistence

        let state = persistence.load() ?? .default
        self.meals = state.meals
        self.weeklySlotsByWeekday = state.weeklySlotsByWeekday
        self.holidays = state.holidays
        self.settings = state.settings
        self.dayLogs = state.dayLogs

        normalizeSchedules()

        if settings.notificationsEnabled {
            Notify.scheduleNextDays(
                daysAhead: 14,
                meals: meals,
                slotsForDate: { [weak self] date in
                    self?.slots(for: date) ?? []
                }
            )
        }
    }

    // MARK: - Persistence

    private func save() {
        let state = AppState(
            meals: meals,
            weeklySlotsByWeekday: weeklySlotsByWeekday,
            holidays: holidays,
            settings: settings,
            dayLogs: dayLogs
        )
        persistence.save(state)
    }

    // MARK: - Meals CRUD

    func addMeal(_ meal: Meal) {
        meals.append(meal)
        meals.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        save()
    }

    func updateMeal(_ meal: Meal) {
        if let i = meals.firstIndex(where: { $0.id == meal.id }) {
            meals[i] = meal
            meals.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            save()
        }
    }

    func deleteMeal(_ mealId: UUID) {
        meals.removeAll(where: { $0.id == mealId })

        // Remove from any day plans
        for (key, var log) in dayLogs {
            for kind in MealKind.allCases {
                if log.mealIds(for: kind).contains(mealId) {
                    log.removeMeal(mealId, from: kind)

                    // keep checked calories consistent with current selection
                    if log.isChecked(kind) {
                        let cals = plannedCalories(in: log, kind: kind)
                        log.setChecked(kind, calories: cals)
                    }
                }
            }
            dayLogs[key] = log
        }

        save()
    }


    func deleteMeals(_ offsets: IndexSet) {
        // Delete from highest to lowest index to be safe
        for i in offsets.sorted(by: >) {
            guard i < meals.count else { continue }
            deleteMeal(meals[i].id)
        }
    }

    // MARK: - Day planning (Home)

    func selectedMeals(for date: Date, kind: MealKind) -> [Meal] {
        let log = dayLog(for: date)
        let ids = log.mealIds(for: kind)
        return ids.compactMap { id in meals.first(where: { $0.id == id }) }
    }

    func addMeal(to date: Date, kind: MealKind, mealId: UUID) {
        let key = dayKey(date)
        var log = dayLogs[key] ?? DayLog()
        log.addMeal(mealId, to: kind)

        // If already checked, refresh snapshot calories
        if log.isChecked(kind) {
            let cals = plannedCalories(in: log, kind: kind)
            log.setChecked(kind, calories: cals)
        }

        dayLogs[key] = log
        save()
    }

    func removeMeal(from date: Date, kind: MealKind, mealId: UUID) {
        let key = dayKey(date)
        var log = dayLogs[key] ?? DayLog()
        log.removeMeal(mealId, from: kind)

        // If checked, refresh snapshot calories
        if log.isChecked(kind) {
            let cals = plannedCalories(in: log, kind: kind)
            log.setChecked(kind, calories: cals)
        }

        dayLogs[key] = log
        save()
    }

    func isChecked(for date: Date, kind: MealKind) -> Bool {
        dayLog(for: date).isChecked(kind)
    }

    func toggleChecked(for date: Date, kind: MealKind) {
        let key = dayKey(date)
        var log = dayLogs[key] ?? DayLog()
        if log.isChecked(kind) {
            log.setChecked(kind, calories: nil)
        } else {
            let cals = plannedCalories(in: log, kind: kind)
            log.setChecked(kind, calories: cals)
        }
        dayLogs[key] = log
        save()
    }

    func plannedCalories(for date: Date) -> Int {
        let log = dayLog(for: date)
        return MealKind.allCases.reduce(0) { total, kind in
            total + plannedCalories(in: log, kind: kind)
        }
    }

    func consumedCaloriesSoFar(for date: Date, now: Date = Date()) -> Int {
        let log = dayLog(for: date)
        return MealKind.allCases.reduce(0) { total, kind in
            total + (log.checkedCaloriesByKind[kind.rawValue] ?? 0)
        }
    }

    private func plannedCalories(in log: DayLog, kind: MealKind) -> Int {
        let plannedMeals = log.mealIds(for: kind).compactMap { id in meals.first(where: { $0.id == id }) }
        return plannedMeals.reduce(0) { $0 + $1.calories }
    }

    private func dayLog(for date: Date) -> DayLog {
        dayLogs[dayKey(date)] ?? DayLog()
    }

    private func dayKey(_ date: Date) -> String {
        // yyyy-MM-dd in current calendar/timezone
        let d = calendar.startOfDay(for: date)
        let comps = calendar.dateComponents([.year, .month, .day], from: d)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let da = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, da)
    }

    // MARK: - Schedule (times only)

    func slots(for date: Date) -> [MealSlot] {
        if let holiday = holidays.first(where: { $0.matches(date, calendar: calendar) }) {
            return normalizeSlots(holiday.slots)
        }
        let weekday = calendar.component(.weekday, from: date) // 1...7
        return normalizeSlots(weeklySlotsByWeekday[String(weekday)] ?? [])
    }

    func updateWeeklyTime(weekday: Weekday, kind: MealKind, time: ClockTime) {
        let key = String(weekday.rawValue)
        var slots = normalizeSlots(weeklySlotsByWeekday[key] ?? [])
        if let idx = slots.firstIndex(where: { $0.kind == kind }) {
            slots[idx].time = time
        }
        weeklySlotsByWeekday[key] = slots
        save()
    }

    func addHoliday(name: String, month: Int, day: Int) {
        let slots = defaultSlots()
        holidays.append(Holiday(name: name, month: month, day: day, slots: slots))
        save()
    }

    func deleteHoliday(_ id: UUID) {
        holidays.removeAll(where: { $0.id == id })
        save()
    }

    func updateHolidayTime(holidayId: UUID, kind: MealKind, time: ClockTime) {
        guard let i = holidays.firstIndex(where: { $0.id == holidayId }) else { return }
        var slots = normalizeSlots(holidays[i].slots)
        if let idx = slots.firstIndex(where: { $0.kind == kind }) {
            slots[idx].time = time
        }
        holidays[i].slots = slots
        save()
    }

    // MARK: - Settings

    func setDailyCalorieGoal(_ goal: Int) {
        settings.dailyCalorieGoal = max(0, goal)
        save()
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        settings.notificationsEnabled = enabled
        save()
        if enabled {
            Notify.requestPermissionIfNeeded()
            Notify.scheduleNextDays(daysAhead: 14, meals: meals, slotsForDate: { [weak self] date in
                self?.slots(for: date) ?? []
            })
        } else {
            Notify.cancelAll()
        }
    }

    // MARK: - Next meal

    struct NextMeal: Hashable {
        var date: Date
        var kind: MealKind
        var time: Date
    }

    func nextMeal(after now: Date = Date()) -> NextMeal? {
        for offset in 0..<14 {
            let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) ?? now
            let daySlots = slots(for: day).sorted(by: { $0.time < $1.time })
            for slot in daySlots {
                let t = slot.time.asDate(on: day, calendar: calendar)
                if t > now {
                    return NextMeal(date: day, kind: slot.kind, time: t)
                }
            }
        }
        return nil
    }

    // MARK: - Helpers

    private func normalizeSchedules() {
        // Weekly schedule
        for weekday in 1...7 {
            let key = String(weekday)
            weeklySlotsByWeekday[key] = normalizeSlots(weeklySlotsByWeekday[key] ?? [])
        }

        // Holidays
        for i in holidays.indices {
            holidays[i].slots = normalizeSlots(holidays[i].slots)
        }

        save()
    }

    private func normalizeSlots(_ slots: [MealSlot]) -> [MealSlot] {
        // Prefer explicit kind-matches, but support legacy saved arrays by index order.
        var result: [MealSlot] = []
        for (idx, kind) in MealKind.allCases.enumerated() {
            if let existing = slots.first(where: { $0.kind == kind }) {
                result.append(MealSlot(id: existing.id, kind: kind, time: existing.time, mealId: nil))
            } else if idx < slots.count {
                let legacy = slots[idx]
                result.append(MealSlot(id: legacy.id, kind: kind, time: legacy.time, mealId: nil))
            } else {
                // fallback default times
                result.append(defaultSlots()[idx])
            }
        }
        // Keep stable order by MealKind
        return result
    }

    private func defaultSlots() -> [MealSlot] {
        [
            MealSlot(kind: .breakfast, time: ClockTime(hour: 8, minute: 0)),
            MealSlot(kind: .lunch, time: ClockTime(hour: 12, minute: 30)),
            MealSlot(kind: .dinner, time: ClockTime(hour: 18, minute: 30)),
            MealSlot(kind: .snack, time: ClockTime(hour: 15, minute: 30))
        ]
    }
}
