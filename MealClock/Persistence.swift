import Foundation

final class Persistence {
    static let shared = Persistence()
    private init() {}

    private let filename = "MealClockState.json"

    private var url: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(filename)
    }

    func load() -> AppState? {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(AppState.self, from: data)
        } catch {
            return nil
        }
    }

    func save(_ state: AppState) {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: url, options: [.atomic])
        } catch {
            // In a real app you'd log this somewhere.
        }
    }
}
