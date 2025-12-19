import Foundation
import SwiftUI

// MARK: - Core Models

struct Meal: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var calories: Int
    var proteinGrams: Int?
    var carbsGrams: Int?
    var fatGrams: Int?
    var notes: String?

    var macroSummary: String {
        let p = proteinGrams.map { "\($0)P" }
        let c = carbsGrams.map { "\($0)C" }
        let f = fatGrams.map { "\($0)F" }
        let parts = [p, c, f].compactMap { $0 }
        return parts.isEmpty ? "—" : parts.joined(separator: " • ")
    }
}

struct ClockTime: Codable, Hashable, Comparable {
    var hour: Int
    var minute: Int

    static func < (lhs: ClockTime, rhs: ClockTime) -> Bool {
        if lhs.hour != rhs.hour { return lhs.hour < rhs.hour }
        return lhs.minute < rhs.minute
    }

    var display: String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let cal = Calendar.current
        let date = cal.date(from: comps) ?? Date()
        return Formatters.timeShort.string(from: date)
    }

    func date(on day: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start) ?? start
    }

    static func from(date: Date, calendar: Calendar = .current) -> ClockTime {
        ClockTime(hour: calendar.component(.hour, from: date),
                  minute: calendar.component(.minute, from: date))
    }
}

struct MealSlot: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var time: ClockTime
    var mealId: UUID?

    func resolvedMeal(in meals: [Meal]) -> Meal? {
        guard let mealId else { return nil }
        return meals.first(where: { $0.id == mealId })
    }
}

enum Weekday: Int, CaseIterable, Codable, Hashable, Identifiable {
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

struct DateOnly: Codable, Hashable, Comparable, Identifiable {
    var year: Int
    var month: Int
    var day: Int

    var id: String { "\(year)-\(month)-\(day)" }

    static func < (lhs: DateOnly, rhs: DateOnly) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }

    func asDate(calendar: Calendar = .current) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return calendar.date(from: comps) ?? Date()
    }

    static func from(date: Date, calendar: Calendar = .current) -> DateOnly {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return DateOnly(year: comps.year ?? 1970, month: comps.month ?? 1, day: comps.day ?? 1)
    }

    var display: String {
        return Formatters.dateAbbrev.string(from: asDate())
    }
}

struct Holiday: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var date: DateOnly
    var slots: [MealSlot]
}

// MARK: - Settings

enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct AppSettings: Codable, Hashable {
    var dailyCalorieGoal: Int = 2000
    var theme: AppTheme = .system
    var notificationsEnabled: Bool = true
    var notifyMinutesBefore: Int = 0 // 0 = at mealtime
}

// MARK: - Stored App State (Codable)

struct AppState: Codable {
    var meals: [Meal]
    /// Keyed by weekday rawValue as a String: "1"..."7"
    var weeklySlotsByWeekday: [String: [MealSlot]]
    var holidays: [Holiday]
    var settings: AppSettings

    static let `default` = AppState(
        meals: [
            Meal(name: "Breakfast", calories: 450, proteinGrams: 25, carbsGrams: 45, fatGrams: 15, notes: "Example meal"),
            Meal(name: "Lunch", calories: 650, proteinGrams: 35, carbsGrams: 65, fatGrams: 20, notes: nil),
            Meal(name: "Dinner", calories: 750, proteinGrams: 45, carbsGrams: 55, fatGrams: 30, notes: nil)
        ],
        weeklySlotsByWeekday: {
            // Default schedule: 3 meals/day
            func slots() -> [MealSlot] {
                [
                    MealSlot(time: ClockTime(hour: 8, minute: 0), mealId: nil),
                    MealSlot(time: ClockTime(hour: 12, minute: 30), mealId: nil),
                    MealSlot(time: ClockTime(hour: 18, minute: 30), mealId: nil)
                ]
            }
            var dict: [String: [MealSlot]] = [:]
            Weekday.allCases.forEach { dict[String($0.rawValue)] = slots() }
            return dict
        }(),
        holidays: [],
        settings: AppSettings()
    )
}
