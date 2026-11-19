import Foundation
import SwiftUI
import ServiceManagement

struct PuzzleLevel: Identifiable, Hashable {
    let id: Int
    let name: String
    let range: ClosedRange<Int>
    var label: String { "\(name) (\(range.lowerBound)–\(range.upperBound == 3200 ? "2800+" : String(range.upperBound)))" }

    static let all: [PuzzleLevel] = [
        .init(id: 0, name: "Beginner", range: 600...1099),
        .init(id: 1, name: "Casual", range: 1100...1399),
        .init(id: 2, name: "Medium", range: 1400...1699),
        .init(id: 3, name: "Hard", range: 1700...1999),
        .init(id: 4, name: "Expert", range: 2000...2299),
        .init(id: 5, name: "Master", range: 2300...3200),
    ]
}

struct EngineStrength: Identifiable, Hashable {
    let id: Int
    let name: String
    let movetimeMs: Int

    static let all: [EngineStrength] = [
        .init(id: 0, name: "Quick (0.25s)", movetimeMs: 250),
        .init(id: 1, name: "Normal (0.6s)", movetimeMs: 600),
        .init(id: 2, name: "Strong (1.2s)", movetimeMs: 1200),
        .init(id: 3, name: "Deep (2.5s)", movetimeMs: 2500),
    ]
}

enum BoardTheme: Int, CaseIterable, Identifiable {
    case brown, green, blue, gray
    var id: Int { rawValue }
    var name: String { ["Wood", "Green", "Blue", "Slate"][rawValue] }
    var light: Color {
        switch self {
        case .brown: return Color(red: 0.94, green: 0.85, blue: 0.71)
        case .green: return Color(red: 0.93, green: 0.93, blue: 0.82)
        case .blue: return Color(red: 0.87, green: 0.89, blue: 0.90)
        case .gray: return Color(red: 0.86, green: 0.86, blue: 0.86)
        }
    }
    var dark: Color {
        switch self {
        case .brown: return Color(red: 0.71, green: 0.53, blue: 0.39)
        case .green: return Color(red: 0.46, green: 0.59, blue: 0.34)
        case .blue: return Color(red: 0.55, green: 0.64, blue: 0.68)
        case .gray: return Color(red: 0.55, green: 0.57, blue: 0.60)
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    @Published var level: Int { didSet { d.set(level, forKey: "level") } }
    @Published var engineStrength: Int { didSet { d.set(engineStrength, forKey: "engineStrength") } }
    /// 0 = never show automatically.
    @Published var puzzlesPerDay: Int { didSet { d.set(puzzlesPerDay, forKey: "puzzlesPerDay") } }
    @Published var activeFromHour: Int { didSet { d.set(activeFromHour, forKey: "activeFromHour") } }
    @Published var activeToHour: Int { didSet { d.set(activeToHour, forKey: "activeToHour") } }
    @Published var boardTheme: Int { didSet { d.set(boardTheme, forKey: "boardTheme") } }
    @Published var sounds: Bool { didSet { d.set(sounds, forKey: "sounds") } }
    @Published var showCoordinates: Bool { didSet { d.set(showCoordinates, forKey: "showCoordinates") } }
    @Published var acceptEngineAlternatives: Bool { didSet { d.set(acceptEngineAlternatives, forKey: "acceptEngineAlternatives") } }
    @Published var customEnginePath: String { didSet { d.set(customEnginePath, forKey: "customEnginePath") } }

    private init() {
        d.register(defaults: [
            "level": 2, "engineStrength": 1, "puzzlesPerDay": 4,
            "activeFromHour": 9, "activeToHour": 21, "boardTheme": 0,
            "sounds": true, "showCoordinates": true, "acceptEngineAlternatives": true,
            "customEnginePath": "",
        ])
        level = d.integer(forKey: "level")
        engineStrength = d.integer(forKey: "engineStrength")
        puzzlesPerDay = d.integer(forKey: "puzzlesPerDay")
        activeFromHour = d.integer(forKey: "activeFromHour")
        activeToHour = d.integer(forKey: "activeToHour")
        boardTheme = d.integer(forKey: "boardTheme")
        sounds = d.bool(forKey: "sounds")
        showCoordinates = d.bool(forKey: "showCoordinates")
        acceptEngineAlternatives = d.bool(forKey: "acceptEngineAlternatives")
        customEnginePath = d.string(forKey: "customEnginePath") ?? ""
    }

    var puzzleLevel: PuzzleLevel { PuzzleLevel.all[max(0, min(level, PuzzleLevel.all.count - 1))] }
    var strength: EngineStrength { EngineStrength.all[max(0, min(engineStrength, EngineStrength.all.count - 1))] }
    var theme: BoardTheme { BoardTheme(rawValue: boardTheme) ?? .brown }

    // MARK: Launch at login

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Launch at login change failed: \(error)")
            }
        }
    }
}

@MainActor
final class Stats: ObservableObject {
    static let shared = Stats()
    private let d = UserDefaults.standard

    @Published private(set) var solved: Int
    @Published private(set) var failed: Int
    @Published private(set) var skipped: Int
    @Published private(set) var streak: Int
    @Published private(set) var bestStreak: Int
    private(set) var seen: Set<String>

    private init() {
        solved = d.integer(forKey: "stats.solved")
        failed = d.integer(forKey: "stats.failed")
        skipped = d.integer(forKey: "stats.skipped")
        streak = d.integer(forKey: "stats.streak")
        bestStreak = d.integer(forKey: "stats.bestStreak")
        seen = Set(d.stringArray(forKey: "stats.seen") ?? [])
    }

    func recordSolved() { solved += 1; streak += 1; bestStreak = max(bestStreak, streak); save() }
    func recordFailed() { failed += 1; streak = 0; save() }
    func recordSkipped() { skipped += 1; save() }
    func markSeen(_ id: String) { seen.insert(id); save() }
    func forgetSeen() { seen.removeAll(); save() }
    func reset() { solved = 0; failed = 0; skipped = 0; streak = 0; bestStreak = 0; seen = []; save() }

    private func save() {
        d.set(solved, forKey: "stats.solved")
        d.set(failed, forKey: "stats.failed")
        d.set(skipped, forKey: "stats.skipped")
        d.set(streak, forKey: "stats.streak")
        d.set(bestStreak, forKey: "stats.bestStreak")
        d.set(Array(seen), forKey: "stats.seen")
    }
}
