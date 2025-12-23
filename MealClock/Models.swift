import Foundation
import SwiftUI

// MARK: - Meal

struct Meal: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var calories: Int

    // Optional macros (nice-to-have)
    var protein: Int?
    var carbs: Int?
    var fat: Int?

    // Optional notes
    var notes: String? = nil

    var macroSummary: String {
        let p = protein ?? 0
        let c = carbs ?? 0
        let f = fat ?? 0
        if protein == nil && carbs == nil && fat == nil { return "" }
        return "P \(p) • C \(c) • F \(f)"
    }
}

// MARK: - Meal Kind (Breakfast/Lunch/Dinner/Snack)

enum MealKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "fork.knife"
        case .dinner: return "moon.stars"
        case .snack: return "takeoutbag.and.cup.and.straw"
        }
    }
}

// MARK: - Time Helpers

struct ClockTime: Codable, Hashable, Comparable {
    var hour: Int
    var minute: Int

    static func < (lhs: ClockTime, rhs: ClockTime) -> Bool {
        if lhs.hour != rhs.hour { return lhs.hour < rhs.hour }
        return lhs.minute < rhs.minute
    }

    func asDate(on day: Date, calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.year, .month, .day], from: day)
        return calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: comps.day, hour: hour, minute: minute)) ?? day
    }

    var shortString: String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Schedule Slot (time only)

struct MealSlot: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var kind: MealKind
    var time: ClockTime

    // Legacy (v1) used to store a single meal tied to the schedule. We keep it for backwards compatibility,
    // but the app now plans meals per-day (on Home) instead.
    var mealId: UUID?

    init(id: UUID = UUID(), kind: MealKind, time: ClockTime, mealId: UUID? = nil) {
        self.id = id
        self.kind = kind
        self.time = time
        self.mealId = mealId
    }
}

extension MealSlot {
    func resolvedMeal(in meals: [Meal]) -> Meal? {
        guard let mealId else { return nil }
        return meals.first(where: { $0.id == mealId })
    }
}

// MARK: - Holiday Override (custom times on a specific date)

struct Holiday: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var month: Int
    var day: Int
    var slots: [MealSlot]

    func matches(_ date: Date, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.month, .day], from: date)
        return c.month == month && c.day == day
    }
}

// MARK: - Settings

struct Settings: Codable, Hashable {
    var dailyCalorieGoal: Int = 2000
    var notificationsEnabled: Bool = false
}

// MARK: - Day Plan + Checkmarks


// MARK: - Codable migrations (for old saved data)

extension Settings {
    enum CodingKeys: String, CodingKey { case dailyCalorieGoal, notificationsEnabled }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.dailyCalorieGoal = try c.decodeIfPresent(Int.self, forKey: .dailyCalorieGoal) ?? 2000
        self.notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
    }
}

extension MealSlot {
    enum CodingKeys: String, CodingKey { case id, kind, time, mealId }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.kind = try c.decodeIfPresent(MealKind.self, forKey: .kind) ?? .snack
        self.time = try c.decode(ClockTime.self, forKey: .time)
        self.mealId = try c.decodeIfPresent(UUID.self, forKey: .mealId)
    }
}

extension AppState {
    enum CodingKeys: String, CodingKey { case meals, weeklySlotsByWeekday, holidays, settings, dayLogs }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.meals = try c.decodeIfPresent([Meal].self, forKey: .meals) ?? AppState.default.meals
        self.weeklySlotsByWeekday = try c.decodeIfPresent([String: [MealSlot]].self, forKey: .weeklySlotsByWeekday) ?? AppState.default.weeklySlotsByWeekday
        self.holidays = try c.decodeIfPresent([Holiday].self, forKey: .holidays) ?? []
        self.settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        self.dayLogs = try c.decodeIfPresent([String: DayLog].self, forKey: .dayLogs) ?? [:]
    }
}

struct DayLog: Codable, Hashable {
    // Keys are MealKind.rawValue
    var selectionsByKind: [String: [UUID]] = [:]

    // Snapshot calories when you check a meal-time off (keys are MealKind.rawValue).
    // If key exists, that meal-time is "checked".
    var checkedCaloriesByKind: [String: Int] = [:]

    func mealIds(for kind: MealKind) -> [UUID] {
        selectionsByKind[kind.rawValue] ?? []
    }

    func isChecked(_ kind: MealKind) -> Bool {
        checkedCaloriesByKind[kind.rawValue] != nil
    }

    mutating func setChecked(_ kind: MealKind, calories: Int?) {
        if let calories {
            checkedCaloriesByKind[kind.rawValue] = calories
        } else {
            checkedCaloriesByKind.removeValue(forKey: kind.rawValue)
        }
    }

    mutating func addMeal(_ mealId: UUID, to kind: MealKind) {
        var list = selectionsByKind[kind.rawValue] ?? []
        list.append(mealId)
        selectionsByKind[kind.rawValue] = list
    }

    mutating func removeMeal(_ mealId: UUID, from kind: MealKind) {
        var list = selectionsByKind[kind.rawValue] ?? []
        list.removeAll(where: { $0 == mealId })
        selectionsByKind[kind.rawValue] = list
    }
}

// MARK: - App State

struct AppState: Codable {
    var meals: [Meal]
    var weeklySlotsByWeekday: [String: [MealSlot]] // weekday key = Calendar weekday (1...7) as String
    var holidays: [Holiday]
    var settings: Settings
    var dayLogs: [String: DayLog] // key = yyyy-MM-dd

    static let `default`: AppState = {
        let sampleMeals: [Meal] = [
            Meal(name: "Banana", calories: 105, protein: 1, carbs: 27, fat: 0),
            Meal(name: "Greek Yogurt", calories: 150, protein: 15, carbs: 12, fat: 4),
            Meal(name: "Chicken & Rice", calories: 550, protein: 40, carbs: 60, fat: 12)
        ]

        func defaultSlots() -> [MealSlot] {
            [
                MealSlot(kind: .breakfast, time: ClockTime(hour: 8, minute: 0)),
                MealSlot(kind: .lunch, time: ClockTime(hour: 12, minute: 30)),
                MealSlot(kind: .dinner, time: ClockTime(hour: 18, minute: 30)),
                MealSlot(kind: .snack, time: ClockTime(hour: 15, minute: 30))
            ]
        }

        var weekly: [String: [MealSlot]] = [:]
        for weekday in 1...7 {
            weekly[String(weekday)] = defaultSlots()
        }

        return AppState(
            meals: sampleMeals,
            weeklySlotsByWeekday: weekly,
            holidays: [],
            settings: Settings(),
            dayLogs: [:]
        )
    }()
}

// MARK: - Weekday

enum Weekday: Int, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    var id: Int { rawValue }

    var short: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    var full: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}
