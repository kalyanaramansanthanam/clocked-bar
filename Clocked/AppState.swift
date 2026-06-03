import SwiftUI
import Combine

enum MenubarDisplay: String, CaseIterable {
    case iconOnly, time, name, nameAndTime

    var label: String {
        switch self {
        case .iconOnly:   return "Icon only"
        case .time:       return "Elapsed time"
        case .name:       return "Project name"
        case .nameAndTime: return "Name + time"
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var projects: [Project] = []
    @Published var activeProjectId: UUID? = nil
    @Published var timerStartDate: Date? = nil
    // Incremented each second so views that display elapsed time redraw automatically.
    @Published var tick: Date = Date()

    // Pending session note — set when a timer stops, cleared when the note window is dismissed.
    @Published var pendingEntry: TimeEntry? = nil

    // Settings
    @Published var menubarDisplay: MenubarDisplay = .time {
        didSet { saveSettings() }
    }
    @Published var menubarShowSeconds: Bool = true {
        didSet { saveSettings() }
    }

    private var timerCancellable: AnyCancellable?

    init() {
        load()
        // .common run loop mode keeps the timer firing while menus are open.
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.tick = date
            }
    }

    var isRunning: Bool { activeProjectId != nil }

    var activeProject: Project? {
        guard let id = activeProjectId else { return nil }
        return projects.first { $0.id == id }
    }

    // Returns the current displayed seconds for a project, including any
    // in-progress running time that has not yet been committed.
    func currentSeconds(for project: Project) -> Int {
        var seconds = project.totalSeconds
        if project.id == activeProjectId, let start = timerStartDate {
            seconds += Int(tick.timeIntervalSince(start))
        }
        return max(0, seconds)
    }

    func startTimer(for project: Project) {
        if activeProjectId != nil {
            commitActiveTimer()
        }
        activeProjectId = project.id
        timerStartDate = Date()
        saveTimerState()
    }

    func stopTimer() {
        commitActiveTimer()
    }

    func addProject(name: String) {
        projects.append(Project(name: name))
        saveProjects()
    }

    func deleteProjects(at offsets: IndexSet) {
        let removingActive = offsets.contains(where: { projects[$0].id == activeProjectId })
        if removingActive {
            activeProjectId = nil
            timerStartDate = nil
        }
        projects.remove(atOffsets: offsets)
        saveProjects()
        saveTimerState()
    }

    func moveProjects(from source: IndexSet, to destination: Int) {
        projects.move(fromOffsets: source, toOffset: destination)
        saveProjects()
    }

    func renameProject(_ project: Project, to name: String) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[idx].name = name
        saveProjects()
    }

    // Sets the total displayed time for a project. If the project's timer is
    // currently running, the running portion is reset so the display continues
    // counting up from the new value.
    func setTime(for project: Project, seconds: Int) {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[idx].totalSeconds = max(0, seconds)
        if project.id == activeProjectId {
            timerStartDate = Date()
            saveTimerState()
        }
        saveProjects()
    }

    func saveNoteForPendingEntry(_ note: String) {
        guard var entry = pendingEntry else { return }
        entry.note = note
        if let idx = projects.firstIndex(where: { $0.name == entry.projectName }) {
            projects[idx].entries.append(entry)
            saveProjects()
        }
        pendingEntry = nil
    }

    func skipNoteForPendingEntry() {
        guard let entry = pendingEntry else { return }
        if let idx = projects.firstIndex(where: { $0.name == entry.projectName }) {
            projects[idx].entries.append(entry)
            saveProjects()
        }
        pendingEntry = nil
    }

    func deleteEntry(_ entry: TimeEntry, from project: Project) {
        guard let pIdx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[pIdx].entries.removeAll { $0.id == entry.id }
        saveProjects()
    }

    func exportAllEntriesAsMarkdown() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        var lines = ["# Clocked — Session Log", ""]
        for project in projects where !project.entries.isEmpty {
            lines.append("## \(project.name)")
            let sorted = project.entries.sorted { $0.startDate > $1.startDate }
            for entry in sorted {
                let date = dateFormatter.string(from: entry.startDate)
                let start = timeFormatter.string(from: entry.startDate)
                let end = timeFormatter.string(from: entry.endDate)
                let dur = formatDurationShort(entry.seconds)
                let note = entry.note.isEmpty ? "(no note)" : entry.note
                lines.append("- \(date) \(start)–\(end) (\(dur)): \(note)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func commitActiveTimer() {
        guard let id = activeProjectId, let start = timerStartDate else { return }
        let end = Date()
        let elapsed = Int(end.timeIntervalSince(start))
        var projectName = ""
        if let idx = projects.firstIndex(where: { $0.id == id }) {
            projects[idx].totalSeconds += elapsed
            projectName = projects[idx].name
        }
        activeProjectId = nil
        timerStartDate = nil
        saveProjects()
        saveTimerState()

        // Create a pending entry so the note window can appear
        if elapsed > 0 {
            pendingEntry = TimeEntry(
                projectName: projectName,
                startDate: start,
                endDate: end,
                seconds: elapsed
            )
        }
    }

    // MARK: - Persistence

    private func saveSettings() {
        UserDefaults.standard.set(menubarDisplay.rawValue, forKey: "hours.menubar.display")
        UserDefaults.standard.set(menubarShowSeconds, forKey: "hours.menubar.showSeconds")
    }

    private func saveProjects() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        UserDefaults.standard.set(data, forKey: "hours.projects")
    }

    private func saveTimerState() {
        if let id = activeProjectId {
            UserDefaults.standard.set(id.uuidString, forKey: "hours.activeProjectId")
            UserDefaults.standard.set(timerStartDate, forKey: "hours.timerStartDate")
        } else {
            UserDefaults.standard.removeObject(forKey: "hours.activeProjectId")
            UserDefaults.standard.removeObject(forKey: "hours.timerStartDate")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "hours.projects"),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            projects = decoded
        }
        if let idStr = UserDefaults.standard.string(forKey: "hours.activeProjectId"),
           let id = UUID(uuidString: idStr),
           projects.contains(where: { $0.id == id }) {
            activeProjectId = id
            timerStartDate = UserDefaults.standard.object(forKey: "hours.timerStartDate") as? Date ?? Date()
        }
        if let raw = UserDefaults.standard.string(forKey: "hours.menubar.display"),
           let display = MenubarDisplay(rawValue: raw) {
            menubarDisplay = display
        }
        if UserDefaults.standard.object(forKey: "hours.menubar.showSeconds") != nil {
            menubarShowSeconds = UserDefaults.standard.bool(forKey: "hours.menubar.showSeconds")
        }
    }
}
