import SwiftUI
import AppKit

struct SessionNoteView: View {
    @EnvironmentObject var appState: AppState
    @State private var note = ""
    @FocusState private var textFieldFocused: Bool
    let onDismiss: () -> Void

    var body: some View {
        if let entry = appState.pendingEntry {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 4) {
                    Text(entry.projectName)
                        .font(.headline)
                    Text(formatDurationShort(entry.seconds))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Note field
                TextField("What did you work on?", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .focused($textFieldFocused)
                    .onAppear { textFieldFocused = true }

                // Buttons
                HStack {
                    Button("Skip") {
                        appState.skipNoteForPendingEntry()
                        onDismiss()
                    }
                    .keyboardShortcut(.escape)

                    Spacer()

                    Button("Save") {
                        appState.saveNoteForPendingEntry(note.trimmingCharacters(in: .whitespacesAndNewlines))
                        onDismiss()
                    }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
            .frame(width: 360)
        }
    }
}

@MainActor
class SessionNoteWindowController {
    private var window: NSWindow?
    private var appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func showWindow() {
        guard appState.pendingEntry != nil else { return }

        let view = SessionNoteView(onDismiss: { [weak self] in
            self?.closeWindow()
        })
        .environmentObject(appState)

        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Session Note"
        window.styleMask = [.titled, .closable]
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.center()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    func closeWindow() {
        window?.close()
        window = nil
    }
}
