import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var engine: EngineService
    @ObservedObject var scheduler: PuzzleScheduler
    @ObservedObject var stats: Stats
    let store: PuzzleStore
    var onLevelChanged: () -> Void

    @State private var launchAtLogin = AppSettings.shared.launchAtLogin
    private let frequencies = [0, 1, 2, 3, 4, 6, 8, 12]

    var body: some View {
        Form {
            Section("Puzzles") {
                Picker("Level", selection: $settings.level) {
                    ForEach(PuzzleLevel.all) { lvl in
                        Text("\(lvl.label) — \(store.count(in: lvl.range)) puzzles").tag(lvl.id)
                    }
                }
                .onChange(of: settings.level) { onLevelChanged() }
                Toggle("Accept other winning moves (checked by the engine)", isOn: $settings.acceptEngineAlternatives)
            }

            Section("Chess engine") {
                Picker("Analysis strength", selection: $settings.engineStrength) {
                    ForEach(EngineStrength.all) { Text($0.name).tag($0.id) }
                }
                LabeledContent("Status") {
                    HStack {
                        Circle().fill(engine.isAvailable ? Color.green : Color.orange).frame(width: 8, height: 8)
                        Text(engine.status).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    TextField("Custom engine path (optional)", text: $settings.customEnginePath, prompt: Text("Bundled Stockfish"))
                    Button("Choose…") { chooseEngine() }
                    Button("Restart") { engine.start() }
                }
            }

            Section("Pop-up schedule") {
                Picker("Show a puzzle automatically", selection: $settings.puzzlesPerDay) {
                    ForEach(frequencies, id: \.self) { n in
                        Text(n == 0 ? "Never (only when I click the icon)" : n == 1 ? "Once a day" : "\(n) times a day").tag(n)
                    }
                }
                HStack {
                    Picker("Between", selection: $settings.activeFromHour) {
                        ForEach(0..<24, id: \.self) { Text(hourLabel($0)).tag($0) }
                    }
                    Picker("and", selection: $settings.activeToHour) {
                        ForEach(1...24, id: \.self) { Text(hourLabel($0)).tag($0) }
                    }
                }
                .disabled(settings.puzzlesPerDay == 0)
                if let next = scheduler.nextFire, settings.puzzlesPerDay > 0 {
                    LabeledContent("Next puzzle") {
                        Text(next, format: .dateTime.weekday().hour().minute()).foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: settings.puzzlesPerDay) { scheduler.reschedule() }
            .onChange(of: settings.activeFromHour) { scheduler.reschedule() }
            .onChange(of: settings.activeToHour) { scheduler.reschedule() }

            Section("Appearance") {
                Picker("Board", selection: $settings.boardTheme) {
                    ForEach(BoardTheme.allCases) { Text($0.name).tag($0.rawValue) }
                }
                LabeledContent("Board size") {
                    HStack {
                        Slider(value: $settings.boardSize, in: AppSettings.boardSizeRange, step: 20)
                            .frame(width: 180)
                        Text(verbatim: "\(Int(settings.boardSize)) pt").foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                Toggle("Show coordinates", isOn: $settings.showCoordinates)
                Toggle("Sounds", isOn: $settings.sounds)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { settings.launchAtLogin = launchAtLogin }
                LabeledContent("Statistics") {
                    HStack {
                        Text("\(stats.solved) solved · \(stats.failed) missed · \(stats.skipped) skipped · best streak \(stats.bestStreak)")
                            .foregroundStyle(.secondary)
                        Button("Reset") { stats.reset() }
                    }
                }
            }

            Section {
                Text("Puzzles from the Lichess open database (CC0). Analysis by Stockfish (GPLv3).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tint(Ink.accent)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func hourLabel(_ h: Int) -> String {
        h == 24 ? "midnight" : String(format: "%02d:00", h)
    }

    private func chooseEngine() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.message = "Choose a UCI chess engine executable"
        if panel.runModal() == .OK, let url = panel.url {
            settings.customEnginePath = url.path
            engine.start()
        }
    }
}
