import Foundation
import UserNotifications

enum Notify {
    static func requestPermissionIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
    }

    static func scheduleNextDays(
        daysAhead: Int,
        now: Date = Date(),
        meals: [Meal],
        slotsForDate: @escaping (Date) -> [MealSlot]
    ) {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }

            // Simple approach: clear and reschedule all MealClock notifications
            cancelAll()

            let calendar = Calendar.current
            let start = calendar.startOfDay(for: now)

            for offset in 0..<max(0, daysAhead) {
                guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
                let slots = slotsForDate(day).sorted(by: { $0.time < $1.time })

                for slot in slots {
                    let fireDate = slot.time.asDate(on: day, calendar: calendar)
                    if fireDate <= now { continue }

                    let content = UNMutableNotificationContent()
                    content.title = "MealClock"

                    if let meal = slot.resolvedMeal(in: meals) {
                        content.body = "Time for \(slot.kind.title): \(meal.name)"
                    } else {
                        content.body = "Time for \(slot.kind.title)"
                    }
                    content.sound = .default

                    let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

                    let identifier = "MealClock-\(day.formatted(.dateTime.year().month().day()))-\(slot.kind.rawValue)-\(slot.time.hour)-\(slot.time.minute)"
                    let req = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                    center.add(req)
                }
            }
        }
    }
}
