import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingEditProjects = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var isAddingProject = false
    @State private var newProjectName = ""
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        // Inline navigation: swap the entire view rather than presenting a sheet.
        // Sheets transfer window focus, which makes the NSPopover dismiss itself.
        if showingEditProjects {
            EditProjectsView(onDone: { showingEditProjects = false })
                .environmentObject(appState)
        } else if showingSettings {
            SettingsView(onDone: { showingSettings = false })
                .environmentObject(appState)
        } else if showingHistory {
            HistoryView(onDone: { showingHistory = false })
                .environmentObject(appState)
        } else {
            mainView
        }
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Hours")
                    .font(.headline)
                Spacer()
                Button {
                    showingHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .buttonStyle(.plain)
                .help("Session history")
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("Settings")
                Button {
                    showingEditProjects = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.plain)
                .help("Manage projects")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Project list
            if appState.projects.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.plus")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("No projects yet")
                        .foregroundColor(.secondary)
                        .font(.callout)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                // Use a fixed height derived from project count so the ScrollView
                // always has a defined frame (unconstrained ScrollViews can collapse
                // to zero height in NSPopover-hosted SwiftUI views).
                let rowHeight: CGFloat = 50
                let listHeight = min(CGFloat(appState.projects.count) * rowHeight, 280)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(appState.projects) { project in
                            ProjectRowView(project: project)
                            if project.id != appState.projects.last?.id {
                                Divider().padding(.leading, 32)
                            }
                        }
                    }
                }
                .frame(height: listHeight)
            }

            Divider()

            // Footer
            if isAddingProject {
                HStack(spacing: 8) {
                    TextField("Project name", text: $newProjectName)
                        .textFieldStyle(.plain)
                        .focused($addFieldFocused)
                        .onAppear { addFieldFocused = true }
                        .onSubmit { submitNewProject() }
                    Button("Add") { submitNewProject() }
                        .keyboardShortcut(.return)
                        .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Cancel") {
                        isAddingProject = false
                        newProjectName = ""
                    }
                    .keyboardShortcut(.escape)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            } else {
                HStack {
                    Button {
                        isAddingProject = true
                    } label: {
                        Label("Add Project", systemImage: "plus.circle")
                            .font(.callout)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .font(.callout)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            }
        }
        .frame(width: 320)
    }

    private func submitNewProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        appState.addProject(name: name)
        newProjectName = ""
        isAddingProject = false
    }
}
