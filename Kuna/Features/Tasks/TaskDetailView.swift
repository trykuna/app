// Features/Tasks/TaskDetailView.swift
import SwiftUI

struct TaskDetailView: View {
    @State private var task: VikunjaTask
    let api: VikunjaAPI
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var hasChanges = false
    @State private var isUpdating = false
    @State private var updateError: String?
    
    // Editing state
    @State private var editedDescription = ""
    @State private var availableLabels: [Label] = []
    @State private var showingLabelPicker = false
    
    // Section collapse states
    @State private var isTaskInfoExpanded = true
    @State private var isSchedulingExpanded = true
    @State private var isOrganizationExpanded = true
    @State private var isStatusExpanded = true
    
    // Date picker states
    @State private var showStartDatePicker = false
    @State private var showDueDatePicker = false
    @State private var showEndDatePicker = false
    
    // Other picker states
    @State private var showPriorityPicker = false
    @State private var showProgressSlider = false
    
    private let presetColors = [
        Color.red, Color.orange, Color.yellow, Color.green,
        Color.blue, Color.purple, Color.pink, Color.gray
    ]
    
    init(task: VikunjaTask, api: VikunjaAPI) {
        self._task = State(initialValue: task)
        self.api = api
        self._editedDescription = State(initialValue: task.description ?? "")
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // 1. TASK INFO Section
                        settingsSection(
                            title: "TASK INFO",
                            isExpanded: $isTaskInfoExpanded
                        ) {
                            VStack(spacing: 0) {
                                titleRow
                                Divider()
                                    .padding(.leading, 16)
                                descriptionRow
                            }
                            .settingsCardStyle()
                        }
                        
                        // 2. SCHEDULING Section
                        settingsSection(
                            title: "SCHEDULING",
                            isExpanded: $isSchedulingExpanded
                        ) {
                            VStack(spacing: 0) {
                                startDateRow
                                Divider()
                                    .padding(.leading, 50)
                                dueDateRow
                                Divider()
                                    .padding(.leading, 50)
                                endDateRow
                                Divider()
                                    .padding(.leading, 16)
                                remindersRow
                                Divider()
                                    .padding(.leading, 16)
                                repeatRow
                            }
                            .settingsCardStyle()
                        }
                        
                        // 3. ORGANIZATION Section
                        settingsSection(
                            title: "ORGANIZATION",
                            isExpanded: $isOrganizationExpanded
                        ) {
                            VStack(spacing: 0) {
                                labelsRow
                                Divider()
                                    .padding(.leading, 16)
                                colorRow
                            }
                            .settingsCardStyle()
                        }
                        
                        // 4. STATUS Section
                        settingsSection(
                            title: "STATUS",
                            isExpanded: $isStatusExpanded
                        ) {
                            VStack(spacing: 0) {
                                priorityRow
                                Divider()
                                    .padding(.leading, 16)
                                progressRow
                            }
                            .settingsCardStyle()
                        }
                        
                        // Bottom padding for save bar
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .background(Color(UIColor.systemGroupedBackground))
                
                // Single Save/Cancel Bar at bottom
                if isEditing && hasChanges {
                    saveBar
                }
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing && hasChanges {
                            Task { await saveChanges() }
                        } else {
                            isEditing.toggle()
                            if isEditing {
                                editedDescription = task.description ?? ""
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Settings-Style Rows
    
    private var titleRow: some View {
        HStack {
            Text("Title")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            if isEditing {
                TextField("Task title", text: $task.title)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
                    .onChange(of: task.title) { _, _ in
                        hasChanges = true
                    }
            } else {
                Text(task.title)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var descriptionRow: some View {
        HStack(alignment: .top) {
            Text("Description")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            if isEditing {
                TextField("Enter description...", text: $editedDescription, axis: .vertical)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
                    .lineLimit(1...4)
                    .onChange(of: editedDescription) { _, _ in
                        hasChanges = true
                    }
            } else {
                Text(task.description ?? "No description")
                    .foregroundColor(task.description == nil ? .secondary.opacity(0.6) : .secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var startDateRow: some View {
        dateRow(
            title: "Start Date",
            date: task.startDate,
            systemImage: "calendar"
        ) { newDate in
            task.startDate = newDate
            hasChanges = true
        }
    }
    
    private var dueDateRow: some View {
        dateRow(
            title: "Due Date",
            date: task.dueDate,
            systemImage: "calendar"
        ) { newDate in
            task.dueDate = newDate
            hasChanges = true
        }
    }
    
    private var endDateRow: some View {
        dateRow(
            title: "End Date",
            date: task.endDate,
            systemImage: "calendar"
        ) { newDate in
            task.endDate = newDate
            hasChanges = true
        }
    }
    
    private func dateRow(
        title: String,
        date: Date?,
        systemImage: String,
        onDateChange: @escaping (Date?) -> Void
    ) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(.accentColor)
                .font(.body)
                .frame(width: 20)
            
            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            if isEditing {
                DatePicker("", selection: Binding(
                    get: { date ?? Date() },
                    set: { onDateChange($0) }
                ), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                
                if date != nil {
                    Button(action: { onDateChange(nil) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            } else {
                if let date = date {
                    Text(date, style: .date)
                        .foregroundColor(.secondary)
                } else {
                    Text("Not set")
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var remindersRow: some View {
        HStack {
            Text("Reminders")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            if let reminders = task.reminders, !reminders.isEmpty {
                Text("\(reminders.count)")
                    .foregroundColor(.secondary)
            } else {
                Text("None")
                    .foregroundColor(.secondary.opacity(0.6))
            }
            
            if isEditing {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary.opacity(0.6))
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var repeatRow: some View {
        HStack {
            Text("Repeat")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            if let repeatAfter = task.repeatAfter, repeatAfter > 0 {
                Text(task.repeatMode.displayName)
                    .foregroundColor(.secondary)
            } else {
                Text("Never")
                    .foregroundColor(.secondary.opacity(0.6))
            }
            
            if isEditing {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary.opacity(0.6))
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var labelsRow: some View {
        HStack(alignment: .center) {
            Text("Labels")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            if let labels = task.labels, !labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(labels.prefix(3)) { label in
                        Text(label.title)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(label.color.opacity(0.2))
                            .foregroundColor(label.color)
                            .cornerRadius(10)
                    }
                    if labels.count > 3 {
                        Text("+\(labels.count - 3)")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            } else {
                Text("None")
                    .foregroundColor(.secondary.opacity(0.6))
            }
            
            if isEditing {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary.opacity(0.6))
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing {
                showingLabelPicker = true
                Task { await loadAvailableLabels() }
            }
        }
    }
    
    private var colorRow: some View {
        HStack {
            Text("Color")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            if isEditing {
                HStack(spacing: 8) {
                    ForEach(presetColors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(task.color == color ? Color.primary : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                task.hexColor = color.toHex()
                                hasChanges = true
                            }
                    }
                }
            } else {
                Circle()
                    .fill(task.color)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var priorityRow: some View {
        HStack {
            Text("Priority")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            if isEditing {
                Picker("Priority", selection: $task.priority) {
                    ForEach(TaskPriority.allCases) { priority in
                        HStack {
                            Image(systemName: priority.systemImage)
                                .foregroundColor(priority.color)
                            Text(priority.displayName)
                        }
                        .tag(priority)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: task.priority) { _, _ in
                    hasChanges = true
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: task.priority.systemImage)
                        .foregroundColor(task.priority.color)
                        .font(.body)
                    
                    Text(task.priority.displayName)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var progressRow: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(task.percentDone * 100))%")
                    .foregroundColor(.secondary)
            }
            
            if isEditing {
                Slider(value: Binding(
                    get: { task.percentDone },
                    set: { newValue in
                        task.percentDone = newValue
                        hasChanges = true
                    }
                ), in: 0...1, step: 0.05)
                .accentColor(.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Save Bar
    
    private var saveBar: some View {
        HStack(spacing: 16) {
            Button("Cancel") {
                // Revert changes
                Task { await reloadTask() }
                isEditing = false
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("Save Changes") {
                Task { await saveChanges() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isUpdating)
        }
        .padding()
        .background(.regularMaterial)
    }
    
    // MARK: - Helper Functions
    
    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Settings-style section header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.wrappedValue.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded.wrappedValue)
                }
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            
            // Section Content
            if isExpanded.wrappedValue {
                content()
            }
        }
    }
    
    // MARK: - API Functions
    
    private func saveChanges() async {
        isUpdating = true
        defer { isUpdating = false }
        
        // Update description
        task.description = editedDescription.isEmpty ? nil : editedDescription
        
        do {
            task = try await api.updateTask(task)
            hasChanges = false
            isEditing = false
        } catch {
            updateError = error.localizedDescription
        }
    }
    
    private func reloadTask() async {
        do {
            task = try await api.getTask(taskId: task.id)
            editedDescription = task.description ?? ""
            hasChanges = false
        } catch {
            updateError = error.localizedDescription
        }
    }
    
    private func loadAvailableLabels() async {
        do {
            availableLabels = try await api.fetchLabels()
        } catch {
            print("Failed to load labels: \(error)")
        }
    }
}

// Extensions are defined in TaskListView.swift