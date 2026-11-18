import Foundation

/// Pops up a puzzle a few times a day, spread (with some randomness) across the active hours.
@MainActor
final class PuzzleScheduler: ObservableObject {
    @Published private(set) var nextFire: Date? {
        didSet { UserDefaults.standard.set(nextFire, forKey: "scheduler.nextFire") }
    }
    var onFire: () -> Void = {}
    /// Returning false postpones a due puzzle (e.g. the popover is already open).
    var canFire: () -> Bool = { true }

    private let settings: AppSettings
    private var timer: Timer?

    init(settings: AppSettings) {
        self.settings = settings
        nextFire = UserDefaults.standard.object(forKey: "scheduler.nextFire") as? Date
    }

    func start() {
        if let n = nextFire, n.timeIntervalSinceNow < -3600 { nextFire = nil } // stale (e.g. after a night asleep)
        if nextFire == nil { reschedule() }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private var interval: TimeInterval {
        let (from, to) = window
        return Double(to - from) * 3600 / Double(max(settings.puzzlesPerDay, 1))
    }

    private var window: (Int, Int) {
        let from = max(0, min(settings.activeFromHour, 23))
        let to = max(from + 1, min(settings.activeToHour, 24))
        return (from, to)
    }

    func reschedule(from now: Date = Date()) {
        guard settings.puzzlesPerDay > 0 else { nextFire = nil; return }
        let candidate = now.addingTimeInterval(interval * Double.random(in: 0.75...1.25))
        nextFire = fitIntoWindow(candidate)
    }

    /// Called when the user opens a puzzle manually so the next automatic one isn't right after.
    func userOpenedPuzzle() {
        guard settings.puzzlesPerDay > 0 else { return }
        let earliest = Date().addingTimeInterval(interval * 0.5)
        if let n = nextFire, n >= earliest { return }
        nextFire = fitIntoWindow(earliest)
    }

    private func fitIntoWindow(_ date: Date) -> Date {
        let cal = Calendar.current
        let (from, to) = window
        let day = cal.startOfDay(for: date)
        let start = cal.date(byAdding: .hour, value: from, to: day)!
        let end = cal.date(byAdding: .hour, value: to, to: day)!
        let jitter = Double.random(in: 5 * 60...min(max(interval * 0.4, 6 * 60), 45 * 60))
        if date < start { return start.addingTimeInterval(jitter) }
        if date >= end {
            let nextStart = cal.date(byAdding: .day, value: 1, to: start)!
            return nextStart.addingTimeInterval(jitter)
        }
        return date
    }

    private func tick() {
        guard settings.puzzlesPerDay > 0 else { nextFire = nil; return }
        guard let n = nextFire else { reschedule(); return }
        guard Date() >= n else { return }
        if canFire() {
            onFire()
            reschedule()
        } else {
            nextFire = Date().addingTimeInterval(10 * 60)
        }
    }
}
