import Foundation

enum Formatters {
    static let timeShort: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    static let dateAbbrev: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static func weekdayShort(for date: Date) -> String {
        let cal = Calendar.current
        let idx = cal.component(.weekday, from: date) - 1 // 0..6
        let symbols = cal.shortWeekdaySymbols
        if idx >= 0 && idx < symbols.count { return symbols[idx] }
        return "Day"
    }
}
