import Foundation
import UserNotifications

enum Notify {
    static let identifierPrefix = "mealclock.meal."

    static func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                completion(true)
            case .denied:
                completion(false)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    completion(granted)
                }
            @unknown default:
                completion(false)
            }
        }
    }

    static func scheduleNextDays(
        days: Int,
        now: Date = Date(),
        settings: AppSettings,
        meals: [Meal],
        scheduleProvider: @escaping (Date) -> [MealSlot]
    ) {
        guard settings.notificationsEnabled else { return }

        requestAuthorizationIfNeeded { ok in
            guard ok else { return }
            let center = UNUserNotificationCenter.current()

            center.getPendingNotificationRequests { pending in
                let toRemove = pending.map { $0.identifier }.filter { $0.hasPrefix(identifierPrefix) }
                center.removePendingNotificationRequests(withIdentifiers: toRemove)

                let calendar = Calendar.current

                for offset in 0..<days {
                    guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
                    let slots = scheduleProvider(day).sorted(by: { $0.time < $1.time })

                    for slot in slots {
                        let mealName = slot.resolvedMeal(in: meals)?.name ?? "Meal"
                        let mealCalories = slot.resolvedMeal(in: meals)?.calories

                        let base = slot.time.date(on: day, calendar: calendar)
                        let fireDate = calendar.date(byAdding: .minute, value: -settings.notifyMinutesBefore, to: base) ?? base
                        if fireDate < now { continue }

                        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                        comps.second = 0

                        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

                        let content = UNMutableNotificationContent()
                        content.title = "Meal time"
                        if let cals = mealCalories {
                            content.body = "\(mealName) • \(cals) kcal"
                        } else {
                            content.body = mealName
                        }
                        content.sound = .default

                        let id = "\(identifierPrefix)\(slot.id.uuidString).\(DateOnly.from(date: day).id)"
                        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                        center.add(request, withCompletionHandler: nil)
                    }
                }
            }
        }
    }
}
