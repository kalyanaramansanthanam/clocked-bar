import SwiftUI
import AppKit

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    let onDone: () -> Void

    private var allEntries: [(project: Project, entry: TimeEntry)] {
        appState.projects.flatMap { project in
            project.entries.map { (project: project, entry: $0) }
        }
        .sorted { $0.entry.startDate > $1.entry.startDate }
    }

    private var groupedByDate: [(date: String, items: [(project: Project, entry: TimeEntry)])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let grouped = Dictionary(grouping: allEntries) { formatter.string(from: $0.entry.startDate) }
        // Sort groups by actual date (most recent first)
        return grouped.sorted { lhs, rhs in
            lhs.value.first!.entry.startDate > rhs.value.first!.entry.startDate
        }
        .map { (date: $0.key, items: $0.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    onDone()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Text("History")
                    .font(.headline)

                Spacer()

                Button {
                    let markdown = appState.exportAllEntriesAsMarkdown()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(markdown, forType: .string)
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .help("Copy all sessions as Markdown")
                .disabled(allEntries.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if allEntries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("No sessions yet")
                        .foregroundColor(.secondary)
                        .font(.callout)
                    Text("Stop a timer to record a session")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedByDate, id: \.date) { group in
                            Text(group.date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.top, 10)
                                .padding(.bottom, 4)

                            ForEach(group.items, id: \.entry.id) { item in
                                entryRow(item.project, item.entry)
                                if item.entry.id != group.items.last?.entry.id {
                                    Divider().padding(.leading, 14)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 340)
            }
        }
        .frame(width: 320)
    }

    @ViewBuilder
    private func entryRow(_ project: Project, _ entry: TimeEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(project.name)
                    .font(.callout)
                    .fontWeight(.medium)
                Spacer()
                Text(formatDurationShort(entry.seconds))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text(Self.timeRange(entry))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private static func timeRange(_ entry: TimeEntry) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return "\(fmt.string(from: entry.startDate))–\(fmt.string(from: entry.endDate))"
    }
}
