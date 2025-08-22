// Features/Navigation/MainContainerView.swift
import SwiftUI

struct MainContainerView: View {
    let api: VikunjaAPI
    @EnvironmentObject var appState: AppState

    @State private var selectedMenuItem: SideMenuView.MenuItem = .projects
    @State private var isMenuOpen = false
    @State private var showingNewProject = false
    @State private var showingSettings = false

    private let menuWidth: CGFloat = 280

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main content
                contentView
                    .offset(x: isMenuOpen ? menuWidth : 0)
                    .disabled(isMenuOpen)

                // Side menu
                HStack {
                    SideMenuView(
                        api: api,
                        selectedMenuItem: $selectedMenuItem,
                        isMenuOpen: $isMenuOpen
                    )
                    .frame(width: menuWidth)
                    .offset(x: isMenuOpen ? 0 : -menuWidth)
                    .accessibilityIdentifier("Sidebar")

                    Spacer()
                }

                // Overlay to close menu when tapping outside
                if isMenuOpen {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isMenuOpen = false
                            }
                        }
                        .offset(x: menuWidth)
                }
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.startLocation.x < 20 && value.translation.width > threshold {
                        // Swipe right from left edge to open menu
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMenuOpen = true
                        }
                    } else if value.startLocation.x > menuWidth && value.translation.width < -threshold && isMenuOpen {
                        // Swipe left to close menu
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMenuOpen = false
                        }
                    }
                }
        )
        .onChange(of: selectedMenuItem) { _, newValue in
            handleMenuSelection(newValue)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingNewProject) {
            NewProjectView(isPresented: $showingNewProject, api: api)
        }
        .onChange(of: appState.deepLinkTaskId) { _, newValue in
            guard let id = newValue else { return }
            Task {
                do {
                    let task = try await api.getTask(taskId: id)
                    await MainActor.run {
                        selectedMenuItem = .projects
                    }
                    // Present task detail by pushing into a temp navigation
                    // We can route via a sheet for simplicity
                    await MainActor.run {
                        let taskView = TaskDetailView(task: task, api: api)
                        let hosting = UIHostingController(rootView: taskView)
                        
                        // Use modern window scene API instead of deprecated UIApplication.shared.windows
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first {
                            window.rootViewController?.present(hosting, animated: true)
                        }
                    }
                } catch {
                    Log.app.error("DeepLink: Failed to open task id=\(id, privacy: .public): \(String(describing: error), privacy: .public)")
                }
                await MainActor.run { appState.deepLinkTaskId = nil }
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedMenuItem {
        case .favorites:
            FavoritesViewWithMenu(
                api: api,
                isMenuOpen: $isMenuOpen
            )
        case .projects:
            ProjectListViewWithMenu(
                api: api,
                isMenuOpen: $isMenuOpen,
                showingNewProject: $showingNewProject
            )
        case .labels:
            LabelsViewWithMenu(
                api: api,
                isMenuOpen: $isMenuOpen
            )
        case .settings:
            // Settings still opens as sheet, so show projects
            ProjectListViewWithMenu(
                api: api,
                isMenuOpen: $isMenuOpen,
                showingNewProject: $showingNewProject
            )
        }
    }

    private func handleMenuSelection(_ menuItem: SideMenuView.MenuItem) {
        switch menuItem {
        case .favorites:
            // Already handled by contentView
            break
        case .projects:
            // Already handled by contentView
            break
        case .labels:
            // Already handled by contentView
            break
        case .settings:
            showingSettings = true
            // Reset to projects after showing settings
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                selectedMenuItem = .projects
            }
        }
    }
}

// Modified ProjectListView for use with hamburger menu
struct ProjectListViewWithMenu: View {
    let api: VikunjaAPI
    @EnvironmentObject var app: AppState
    @StateObject private var vm: ProjectListVM
    @Binding var isMenuOpen: Bool
    @Binding var showingNewProject: Bool

    init(api: VikunjaAPI, isMenuOpen: Binding<Bool>, showingNewProject: Binding<Bool>) {
        self.api = api
        self._isMenuOpen = isMenuOpen
        self._showingNewProject = showingNewProject
        _vm = StateObject(wrappedValue: ProjectListVM(api: api))
    }

    var body: some View {
        NavigationStack {
            List(vm.projects) { p in
                NavigationLink(p.title) { TaskListView(project: p, api: api) }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMenuOpen.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .accessibilityIdentifier("MenuButton")
                    .accessibilityLabel("Menu")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewProject = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay {
                if vm.loading {
                    ProgressView("Loading…")
                } else if let error = vm.error {
                    VStack {
                        Text("Error loading projects")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            Task { await vm.load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .task { await vm.load() }
        }
    }
}

// Modified LabelsView for use with hamburger menu
struct LabelsViewWithMenu: View {
    let api: VikunjaAPI
    @StateObject private var viewModel: LabelsViewModel
    @Binding var isMenuOpen: Bool

    @State private var showingCreateLabel = false
    @State private var showingEditLabel = false
    @State private var selectedLabel: Label?
    @State private var showingDeleteAlert = false
    @State private var labelToDelete: Label?

    init(api: VikunjaAPI, isMenuOpen: Binding<Bool>) {
        self.api = api
        self._isMenuOpen = isMenuOpen
        _viewModel = StateObject(wrappedValue: LabelsViewModel(api: api))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.loading {
                    ProgressView("Loading labels...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.labels.isEmpty {
                    emptyStateView
                } else {
                    labelsList
                }
            }
            .navigationTitle("Labels")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMenuOpen.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .accessibilityIdentifier("MenuButton")
                    .accessibilityLabel("Menu")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateLabel = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateLabel) {
                CreateLabelView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingEditLabel) {
                if let label = selectedLabel {
                    EditLabelView(viewModel: viewModel, label: label)
                }
            }
            .alert("Delete Label", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let label = labelToDelete {
                        Task {
                            await viewModel.deleteLabel(label)
                        }
                    }
                }
            } message: {
                if let label = labelToDelete {
                    Text("Are you sure you want to delete '\(label.title)'? This action cannot be undone.")
                }
            }
            .task {
                await viewModel.load()
            }
            .overlay {
                if let error = viewModel.error {
                    VStack {
                        Text("Error")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .padding()
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.6))

            Text("No Labels")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create your first label to organize your tasks")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Create Label") {
                showingCreateLabel = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var labelsList: some View {
        List {
            ForEach(viewModel.labels) { label in
                labelRow(label)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func labelRow(_ label: Label) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(label.color)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(label.title)
                    .font(.body)
                    .fontWeight(.medium)

                if let description = label.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Menu {
                Button(action: {
                    selectedLabel = label
                    showingEditLabel = true
                }) {
                    SwiftUI.Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive, action: {
                    labelToDelete = label
                    showingDeleteAlert = true
                }) {
                    SwiftUI.Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MainContainerView(api: VikunjaAPI(config: .init(baseURL: URL(string: "https://example.com")!), tokenProvider: { nil }))
        .environmentObject(AppState())
}
