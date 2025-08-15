// Features/Tasks/TaskListView.swift
import SwiftUI

/* Temporarily commented out - moved to TaskDetailView.swift
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
    @State private var newReminderDate = Date()
    @State private var repeatIntervalDays = 1
    @State private var repeatIntervalHours = 0
    @State private var repeatIntervalMinutes = 0

    // Individual editing states for different sections
    @State private var isEditingPriority = false
    @State private var isEditingProgress = false
    @State private var isEditingColor = false
    @State private var isEditingReminders = false
    @State private var isEditingRepeat = false
    @State private var isEditingLabels = false
    @State private var isEditingDates = false
    @State private var isCreatingNewLabel = false
    @State private var newLabelTitle = ""
    @State private var newLabelColor = Color.blue

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
                        // Task Header (always visible)
                        taskHeaderSection

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
                if isEditing {
                    saveBar
                }
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Cancel" : "Edit") {
                        if isEditing {
                            cancelEditing()
                        } else {
                            startEditing()
                        }
                    }
                    .disabled(isUpdating)
                }
            }
            .overlay {
                if isUpdating {
                    ProgressView("Updating...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
            .alert("Error", isPresented: .constant(updateError != nil)) {
                Button("OK") { updateError = nil }
            } message: {
                Text(updateError ?? "")
            }
            .sheet(isPresented: $showingLabelPicker) {
                labelPickerSheet
            }
        }
    }

    // MARK: - New Card-Based Sections

    private var taskHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: {
                    Task { await toggleTaskCompletion() }
                }) {
                    Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.done ? .green : .gray)
                        .font(.title2)
                }
                .disabled(isUpdating)

                Text(task.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .strikethrough(task.done)
                    .foregroundColor(.primary)

                Spacer()
            }
        }
        .cardStyle()
    }

    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Description", systemImage: "text.alignleft")

            if isEditing {
                TextField("Enter task description...", text: $editedDescription, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...8)
                    .onChange(of: editedDescription) { _, _ in
                        hasChanges = true
                    }
            } else {
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                } else {
                    Text("No description")
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.6))
                        .italic()
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private var priorityDisplayView: some View {
        HStack(spacing: 8) {
            Image(systemName: task.priority.systemImage)
                .foregroundColor(task.priority.color)
                .font(.title3)

            Text(task.priority.displayName)
                .font(.body)
                .foregroundColor(task.priority == .unset ? .secondary : .primary)
        }
    }

    @ViewBuilder
    private var priorityEditingView: some View {
        VStack(spacing: 16) {
            // Current priority display
            HStack(spacing: 8) {
                Image(systemName: task.priority.systemImage)
                    .foregroundColor(task.priority.color)
                    .font(.title2)

                Text(task.priority.displayName)
                    .font(.headline)
                    .foregroundColor(task.priority.color)
            }
            .padding()
            .background(task.priority.color.opacity(0.1))
            .cornerRadius(8)

            VStack(spacing: 8) {
                // Slider
                Slider(
                    value: Binding(
                        get: { Double(task.priority.rawValue) },
                        set: { newValue in
                            let newPriority = TaskPriority(rawValue: Int(newValue)) ?? .unset
                            Task { await updatePriority(newPriority) }
                        }
                    ),
                    in: 0...5,
                    step: 1
                )
                .accentColor(task.priority.color)
                .disabled(isUpdating)

                // Priority level indicators
                HStack {
                    ForEach(TaskPriority.allCases, id: \.rawValue) { priority in
                        VStack(spacing: 2) {
                            Image(systemName: priority.systemImage)
                                .font(.caption2)
                                .foregroundColor(task.priority == priority ? priority.color : .secondary)

                            Text(priority.displayName)
                                .font(.caption2)
                                .foregroundColor(task.priority == priority ? priority.color : .secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    isEditingPriority = false
                }
                .buttonStyle(.bordered)
                .disabled(isUpdating)

                Button("Done") {
                    isEditingPriority = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdating)
            }
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if !isEditingProgress {
                    Button("Edit") {
                        isEditingProgress = true
                    }
                    .disabled(isUpdating)
                }
            }

            if isEditingProgress {
                progressEditingView
            } else {
                progressDisplayView
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var progressDisplayView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(Int(task.percentDone * 100))%")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                Text(progressStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: task.percentDone)
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                .scaleEffect(y: 1.5)
        }
    }

    @ViewBuilder
    private var progressEditingView: some View {
        VStack(spacing: 16) {
            // Current progress display
            HStack {
                Text("\(Int(task.percentDone * 100))%")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(progressColor)

                Spacer()

                Text(progressStatus)
                    .font(.headline)
                    .foregroundColor(progressColor)
            }
            .padding()
            .background(progressColor.opacity(0.1))
            .cornerRadius(8)

            VStack(spacing: 8) {
                // Slider
                Slider(
                    value: Binding(
                        get: { task.percentDone },
                        set: { newValue in
                            Task { await updateProgress(newValue) }
                        }
                    ),
                    in: 0.0...1.0,
                    step: 0.05
                )
                .accentColor(progressColor)
                .disabled(isUpdating)

                // Progress milestones
                HStack {
                    ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { milestone in
                        VStack(spacing: 2) {
                            Text("\(Int(milestone * 100))%")
                                .font(.caption2)
                                .foregroundColor(abs(task.percentDone - milestone) < 0.05 ? progressColor : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    isEditingProgress = false
                }
                .buttonStyle(.bordered)
                .disabled(isUpdating)

                Button("Done") {
                    isEditingProgress = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdating)
            }
        }
    }

    private var progressColor: Color {
        if task.percentDone == 0.0 {
            return .gray
        } else if task.percentDone < 0.25 {
            return .red
        } else if task.percentDone < 0.5 {
            return .orange
        } else if task.percentDone < 0.75 {
            return .yellow
        } else if task.percentDone < 1.0 {
            return .blue
        } else {
            return .green
        }
    }

    private var progressStatus: String {
        if task.percentDone == 0.0 {
            return "Not Started"
        } else if task.percentDone < 0.25 {
            return "Just Started"
        } else if task.percentDone < 0.5 {
            return "In Progress"
        } else if task.percentDone < 0.75 {
            return "Making Progress"
        } else if task.percentDone < 1.0 {
            return "Almost Done"
        } else {
            return "Completed"
        }
    }

    @ViewBuilder
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Color")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if !isEditingColor {
                    Button("Edit") {
                        isEditingColor = true
                    }
                    .disabled(isUpdating)
                }
            }

            if isEditingColor {
                colorEditingView
            } else {
                colorDisplayView
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var colorDisplayView: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(task.color)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )

            Text(task.hexColor?.uppercased() ?? "Default Color")
                .font(.body)
                .foregroundColor(.primary)
        }
    }

    @ViewBuilder
    private var colorEditingView: some View {
        VStack(spacing: 16) {
            // Current color display
            HStack {
                Circle()
                    .fill(task.color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Color")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(task.hexColor?.uppercased() ?? "Default")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(task.color.opacity(0.1))
            .cornerRadius(8)

            // Color picker
            VStack(spacing: 8) {
                HStack {
                    Text("Choose Color:")
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Spacer()

                    ColorPicker("", selection: Binding(
                        get: { task.color },
                        set: { newColor in
                            Task { await updateColor(newColor) }
                        }
                    ), supportsOpacity: false)
                    .labelsHidden()
                    .disabled(isUpdating)
                }

                // Preset colors
                Text("Quick Colors:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                    ForEach(presetColors, id: \.self) { color in
                        Button(action: {
                            Task { await updateColor(color) }
                        }) {
                            Circle()
                                .fill(color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(task.color == color ? Color.primary : Color.primary.opacity(0.2),
                                               lineWidth: task.color == color ? 2 : 1)
                                )
                        }
                        .disabled(isUpdating)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    isEditingColor = false
                }
                .buttonStyle(.bordered)
                .disabled(isUpdating)

                Button("Done") {
                    isEditingColor = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdating)
            }
        }
    }

    private var presetColors: [Color] {
        [
            .red, .orange, .yellow, .green,
            .blue, .purple, .pink, .gray
        ]
    }

    @ViewBuilder
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Reminders")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if !isEditingReminders {
                    Button("Edit") {
                        isEditingReminders = true
                        newReminderDate = Date()
                    }
                    .disabled(isUpdating)
                }
            }

            if isEditingReminders {
                remindersEditingView
            } else {
                remindersDisplayView
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var remindersDisplayView: some View {
        if let reminders = task.reminders, !reminders.isEmpty {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160))
            ], alignment: .leading, spacing: 8) {
                ForEach(reminders.sorted(by: { $0.reminder < $1.reminder })) { reminder in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.purple)
                                .font(.caption)

                            Text(reminder.reminder, style: .date)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }

                        Text(reminder.reminder, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        } else {
            Text("No reminders")
                .font(.body)
                .foregroundColor(.secondary.opacity(0.6))
                .italic()
        }
    }

    @ViewBuilder
    private var remindersEditingView: some View {
        VStack(spacing: 12) {
            // Current reminders with remove buttons
            if let reminders = task.reminders, !reminders.isEmpty {
                Text("Current Reminders:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 180))
                ], alignment: .leading, spacing: 8) {
                    ForEach(reminders.sorted(by: { $0.reminder < $1.reminder })) { reminder in
                        reminderWithRemoveButton(reminder)
                    }
                }
            }

            // Add new reminder
            VStack(spacing: 12) {
                Text("Add New Reminder:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                DatePicker("Reminder Date & Time", selection: $newReminderDate, displayedComponents: [.date, .hourAndMinute])
                    .disabled(isUpdating)

                Button("Add Reminder") {
                    Task { await addReminder(newReminderDate) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdating)
            }
            .padding()
            .background(Color.purple.opacity(0.05))
            .cornerRadius(8)

            // Done/Cancel buttons
            HStack {
                Button("Cancel") {
                    isEditingReminders = false
                }
                .buttonStyle(.bordered)
                .disabled(isUpdating)

                Button("Done") {
                    isEditingReminders = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdating)
            }
        }
    }

    private func reminderWithRemoveButton(_ reminder: Reminder) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.purple)
                        .font(.caption2)

                    Text(reminder.reminder, style: .date)
                        .font(.caption)
                        .foregroundColor(.primary)
                }

                Text(reminder.reminder, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 12)
            }

            Spacer()

            if let reminderId = reminder.id {
                Button(action: {
                    Task { await removeReminder(reminderId) }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .disabled(isUpdating)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(6)
    }

    @ViewBuilder
    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Repeat")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if !isEditingRepeat {
                    Button("Edit") {
                        isEditingRepeat = true
                        setupRepeatEditingValues()
                    }
                    .disabled(isUpdating)
                }
            }

            if isEditingRepeat {
                repeatEditingView
            } else {
                repeatDisplayView
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var repeatDisplayView: some View {
        HStack(spacing: 12) {
            Image(systemName: task.repeatAfter != nil ? task.repeatMode.systemImage : "repeat.circle")
                .foregroundColor(task.repeatAfter != nil ? .cyan : .gray)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                if let repeatAfter = task.repeatAfter, repeatAfter > 0 {
                    Text("Task repeats")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(task.repeatMode.displayName)
                        .font(.body)
                        .foregroundColor(.primary)

                    if task.repeatMode == .afterAmount {
                        Text("Every \(formatRepeatInterval(repeatAfter))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No repeat")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Task will not repeat")
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.6))
                        .italic()
                }
            }
        }
    }

    @ViewBuilder
    private var repeatEditingView: some View {
        VStack(spacing: 16) {
            // Enable/Disable repeat toggle
            HStack {
                Text("Enable Repeat")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { task.repeatAfter != nil && task.repeatAfter! > 0 },
                    set: { enabled in
                        if enabled && task.repeatAfter == nil {
                            Task { await updateRepeatSettings(calculateRepeatSeconds(), task.repeatMode) }
                        } else if !enabled {
                            Task { await updateRepeatSettings(nil, task.repeatMode) }
                        }
                    }
                ))
                .disabled(isUpdating)
            }
            .padding()
            .background(Color.cyan.opacity(0.05))
            .cornerRadius(8)

            // Repeat mode selection (only if repeat is enabled)
            if task.repeatAfter != nil && task.repeatAfter! > 0 {
                VStack(spacing: 12) {
                    Text("Repeat Mode")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                        ForEach(RepeatMode.allCases) { mode in
                            Button(action: {
                                Task { await updateRepeatSettings(task.repeatAfter, mode) }
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: mode.systemImage)
                                        .font(.title3)
                                        .foregroundColor(task.repeatMode == mode ? .cyan : .secondary)

                                    Text(mode.displayName)
                                        .font(.caption)
                                        .fontWeight(task.repeatMode == mode ? .semibold : .regular)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)

                                    Text(mode.description)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .frame(minHeight: 80)
                                .background(
                                    task.repeatMode == mode
                                        ? Color.cyan.opacity(0.15)
                                        : Color.gray.opacity(0.05)
                                )
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            task.repeatMode == mode ? Color.cyan : Color.gray.opacity(0.3),
                                            lineWidth: task.repeatMode == mode ? 2 : 1
                                        )
                                )
                            }
                            .disabled(isUpdating)
                        }
                    }
                }

                // Interval settings (only for afterAmount mode)
                if task.repeatMode == .afterAmount {
                    VStack(spacing: 12) {
                        Text("Repeat Interval")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 8) {
                            HStack {
                                Text("Days:")
                                    .frame(width: 60, alignment: .leading)

                                Stepper("\(repeatIntervalDays)", value: $repeatIntervalDays, in: 0...365)
                                    .onChange(of: repeatIntervalDays) { _, _ in
                                        task.repeatAfter = calculateRepeatSeconds()
                                        hasChanges = true
                                    }
                            }

                            HStack {
                                Text("Hours:")
                                    .frame(width: 60, alignment: .leading)

                                Stepper("\(repeatIntervalHours)", value: $repeatIntervalHours, in: 0...23)
                                    .onChange(of: repeatIntervalHours) { _, _ in
                                        task.repeatAfter = calculateRepeatSeconds()
                                        hasChanges = true
                                    }
                            }

                            HStack {
                                Text("Minutes:")
                                    .frame(width: 60, alignment: .leading)

                                Stepper("\(repeatIntervalMinutes)", value: $repeatIntervalMinutes, in: 0...59)
                                    .onChange(of: repeatIntervalMinutes) { _, _ in
                                        task.repeatAfter = calculateRepeatSeconds()
                                        hasChanges = true
                                    }
                            }
                        }

                        Text("Total: \(formatRepeatInterval(calculateRepeatSeconds()))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
            }

            // Done/Cancel buttons
            HStack {
                Button("Cancel") {
                    isEditingRepeat = false
                }
                .buttonStyle(.bordered)
                .disabled(isUpdating)

                Button("Done") {
                    isEditingRepeat = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdating)
            }
        }
    }

    private func setupRepeatEditingValues() {
        if let repeatAfter = task.repeatAfter, repeatAfter > 0 {
            let totalSeconds = repeatAfter
            repeatIntervalDays = totalSeconds / (24 * 3600)
            repeatIntervalHours = (totalSeconds % (24 * 3600)) / 3600
            repeatIntervalMinutes = (totalSeconds % 3600) / 60
        } else {
            repeatIntervalDays = 1
            repeatIntervalHours = 0
            repeatIntervalMinutes = 0
        }
    }

    private func calculateRepeatSeconds() -> Int {
        return repeatIntervalDays * 24 * 3600 + repeatIntervalHours * 3600 + repeatIntervalMinutes * 60
    }

    private func formatRepeatInterval(_ seconds: Int) -> String {
        guard seconds > 0 else { return "No interval" }

        let days = seconds / (24 * 3600)
        let hours = (seconds % (24 * 3600)) / 3600
        let minutes = (seconds % 3600) / 60

        var parts: [String] = []

        if days > 0 {
            parts.append("\(days) day\(days == 1 ? "" : "s")")
        }
        if hours > 0 {
            parts.append("\(hours) hour\(hours == 1 ? "" : "s")")
        }
        if minutes > 0 {
            parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")")
        }

        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Labels")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if !isEditingLabels {
                    Button("Edit") {
                        isEditingLabels = true
                        Task { await loadAvailableLabels() }
                    }
                    .disabled(isUpdating)
                }
            }

            if isEditingLabels {
                labelEditingView
            } else {
                labelDisplayView
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var labelDisplayView: some View {
        if let labels = task.labels, !labels.isEmpty {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80))
            ], alignment: .leading, spacing: 8) {
                ForEach(labels) { label in
                    Text(label.title)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(label.color.opacity(0.2))
                        .foregroundColor(label.color)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(label.color, lineWidth: 1)
                        )
                }
            }
        } else {
            Text("No labels")
                .font(.body)
                .foregroundColor(.secondary.opacity(0.6))
                .italic()
        }
    }

    @ViewBuilder
    private var labelEditingView: some View {
        VStack(spacing: 12) {
            currentLabelsWithRemove
            availableLabelsToAddView
            labelEditingButtons
        }
    }

    @ViewBuilder
    private var currentLabelsWithRemove: some View {
        if let labels = task.labels, !labels.isEmpty {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100))
            ], alignment: .leading, spacing: 8) {
                ForEach(labels) { label in
                    labelWithRemoveButton(label)
                }
            }
        }
    }

    private func labelWithRemoveButton(_ label: Label) -> some View {
        HStack(spacing: 4) {
            Text(label.title)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(label.color.opacity(0.2))
                .foregroundColor(label.color)
                .cornerRadius(6)

            Button(action: {
                Task { await removeLabel(label) }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .disabled(isUpdating)
        }
    }

    @ViewBuilder
    private var availableLabelsToAddView: some View {
        if isCreatingNewLabel {
            newLabelCreationView
        } else {
            existingLabelsView
            createNewLabelButton
        }
    }

    @ViewBuilder
    private var existingLabelsView: some View {
        if !availableLabels.isEmpty {
            Text("Available Labels")
                .font(.subheadline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80))
            ], alignment: .leading, spacing: 8) {
                ForEach(availableLabelsToAdd) { label in
                    availableLabelButton(label)
                }
            }
        }
    }

    @ViewBuilder
    private var createNewLabelButton: some View {
        Button(action: {
            isCreatingNewLabel = true
            newLabelTitle = ""
            newLabelColor = .blue
        }) {
            HStack {
                Image(systemName: "plus")
                Text("Create New Label")
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))
            .foregroundColor(.primary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isUpdating)
    }

    @ViewBuilder
    private var newLabelCreationView: some View {
        VStack(spacing: 12) {
            Text("Create New Label")
                .font(.subheadline)
                .fontWeight(.semibold)

            TextField("Label name", text: $newLabelTitle)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Color:")
                    .font(.caption)
                ColorPicker("", selection: $newLabelColor, supportsOpacity: false)
                    .labelsHidden()
                Spacer()
            }

            // Preview
            Text(newLabelTitle.isEmpty ? "Preview" : newLabelTitle)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(newLabelColor.opacity(0.2))
                .foregroundColor(newLabelColor)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(newLabelColor, lineWidth: 1)
                )

            HStack {
                Button("Cancel") {
                    isCreatingNewLabel = false
                    newLabelTitle = ""
                }
                .buttonStyle(.bordered)
                .disabled(isUpdating)

                Button("Create & Add") {
                    Task { await createAndAddNewLabel() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newLabelTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUpdating)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    private func availableLabelButton(_ label: Label) -> some View {
        Button(action: {
            Task { await addLabel(label) }
        }) {
            Text(label.title)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(label.color.opacity(0.1))
                .foregroundColor(label.color)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(label.color.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [2]))
                )
        }
        .disabled(isUpdating)
    }

    @ViewBuilder
    private var labelEditingButtons: some View {
        HStack {
            Button("Cancel") {
                isEditingLabels = false
            }
            .buttonStyle(.bordered)
            .disabled(isUpdating)

            Button("Done") {
                isEditingLabels = false
            }
            .buttonStyle(.borderedProminent)
            .disabled(isUpdating)
        }
    }

    private var availableLabelsToAdd: [Label] {
        let currentLabelIds = Set(task.labels?.map(\.id) ?? [])
        return availableLabels.filter { !currentLabelIds.contains($0.id) }
    }

    // MARK: - Collapsible Section Helper

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
                Text(task.description ?? "Add description...")
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
        VStack(spacing: 0) {
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

                if let date = date {
                    Text(date, style: .date)
                        .foregroundColor(.secondary)
                } else {
                    Text("Not set")
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
                    // Toggle date picker visibility
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if title == "Start Date" {
                            showStartDatePicker.toggle()
                        } else if title == "Due Date" {
                            showDueDatePicker.toggle()
                        } else if title == "End Date" {
                            showEndDatePicker.toggle()
                        }
                    }
                }
            }

            // Inline date picker
            if isEditing {
                if (title == "Start Date" && showStartDatePicker) ||
                   (title == "Due Date" && showDueDatePicker) ||
                   (title == "End Date" && showEndDatePicker) {

                    VStack(spacing: 0) {
                        Divider()
                            .padding(.leading, 50)

                        DatePicker("", selection: Binding(
                            get: { date ?? Date() },
                            set: { newDate in
                                onDateChange(newDate)
                            }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.wheels)
                        .labelsHidden()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                        HStack {
                            Button("Clear") {
                                onDateChange(nil)
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if title == "Start Date" {
                                        showStartDatePicker = false
                                    } else if title == "Due Date" {
                                        showDueDatePicker = false
                                    } else if title == "End Date" {
                                        showEndDatePicker = false
                                    }
                                }
                            }
                            .foregroundColor(.red)

                            Spacer()

                            Button("Done") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if title == "Start Date" {
                                        showStartDatePicker = false
                                    } else if title == "Due Date" {
                                        showDueDatePicker = false
                                    } else if title == "End Date" {
                                        showEndDatePicker = false
                                    }
                                }
                            }
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
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

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary.opacity(0.6))
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            // Handle reminders navigation
        }
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

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary.opacity(0.6))
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            // Handle repeat navigation
        }
    }

    private var labelsRow: some View {
        HStack(alignment: .top) {
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

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary.opacity(0.6))
                .font(.caption)
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
                            if isEditing {
                                task.hexColor = color.toHex()
                                hasChanges = true
                            }
                        }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var priorityRow: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Priority")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: task.priority.systemImage)
                        .foregroundColor(task.priority.color)
                        .font(.body)

                    Text(task.priority.displayName)
                        .foregroundColor(.secondary)
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showPriorityPicker.toggle()
                    }
                }
            }

            // Inline priority picker
            if isEditing && showPriorityPicker {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.leading, 16)

                    ForEach(TaskPriority.allCases) { priority in
                        HStack {
                            Image(systemName: priority.systemImage)
                                .foregroundColor(priority.color)
                                .font(.body)
                                .frame(width: 20)

                            Text(priority.displayName)
                                .font(.body)
                                .foregroundColor(.primary)

                            Spacer()

                            if task.priority == priority {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                                    .font(.body)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            task.priority = priority
                            hasChanges = true
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showPriorityPicker = false
                            }
                        }

                        if priority != TaskPriority.allCases.last {
                            Divider()
                                .padding(.leading, 50)
                        }
                    }
                }
            }
        }
    }

    private var progressRow: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Progress")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Spacer()

            Text("\(Int(task.percentDone * 100))%")
                .foregroundColor(.secondary)

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
                withAnimation(.easeInOut(duration: 0.2)) {
                    showProgressSlider.toggle()
                }
            }
        }

        // Inline progress slider
        if isEditing && showProgressSlider {
            VStack(spacing: 0) {
                Divider()
                    .padding(.leading, 16)

                VStack(spacing: 8) {
                    HStack {
                        Text("0%")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("100%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Slider(value: Binding(
                        get: { task.percentDone },
                        set: { newValue in
                            task.percentDone = newValue
                            hasChanges = true
                        }
                    ), in: 0...1, step: 0.05)
                    .accentColor(.accentColor)

                    Button("Done") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showProgressSlider = false
                        }
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            descriptionHeader
            descriptionContent
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var descriptionHeader: some View {
        HStack {
            Text("Description")
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            if !isEditing {
                Button("Edit") {
                    isEditing = true
                    editedDescription = task.description ?? ""
                }
                .disabled(isUpdating)
            }
        }
    }

    @ViewBuilder
    private var descriptionContent: some View {
        if isEditing {
            editingView
        } else {
            displayView
        }
    }

    private var editingView: some View {
        VStack(spacing: 12) {
            TextField("Enter task description...", text: $editedDescription, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...10)

            HStack {
                Button("Cancel") {
                    isEditing = false
                    editedDescription = task.description ?? ""
                }
                .buttonStyle(.bordered)
                .disabled(isUpdating)

                Button("Save") {
                    Task { await saveDescription() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdating)
            }
        }
    }

    @ViewBuilder
    private var displayView: some View {
        if let description = task.description, !description.isEmpty {
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        } else {
            Text("No description")
                .font(.body)
                .foregroundColor(.secondary.opacity(0.6))
                .italic()
        }
    }

    @ViewBuilder
    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Dates")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if !isEditingDates {
                    Button("Edit") {
                        isEditingDates = true
                    }
                    .disabled(isUpdating)
                }
            }

            if isEditingDates {
                datesEditingView
            } else {
                datesDisplayView
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var datesDisplayView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Start Date
            HStack {
                Image(systemName: "play.circle")
                    .foregroundColor(.green)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Start Date")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let startDate = task.startDate {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(startDate, style: .date)
                                .font(.body)
                                .foregroundColor(.primary)
                            Text(startDate, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Not set")
                            .font(.body)
                            .foregroundColor(.secondary.opacity(0.6))
                            .italic()
                    }
                }
            }

            // Due Date
            HStack {
                Image(systemName: "clock.circle")
                    .foregroundColor(.orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Due Date")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let dueDate = task.dueDate {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(dueDate, style: .date)
                                .font(.body)
                                .foregroundColor(.primary)
                            Text(dueDate, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Not set")
                            .font(.body)
                            .foregroundColor(.secondary.opacity(0.6))
                            .italic()
                    }
                }
            }

            // End Date
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.blue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("End Date")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let endDate = task.endDate {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(endDate, style: .date)
                                .font(.body)
                                .foregroundColor(.primary)
                            Text(endDate, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Not set")
                            .font(.body)
                            .foregroundColor(.secondary.opacity(0.6))
                            .italic()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var datesEditingView: some View {
        VStack(spacing: 16) {
            // Start Date
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "play.circle")
                        .foregroundColor(.green)
                    Text("Start Date")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    if task.startDate != nil {
                        Button("Clear") {
                            Task { await updateStartDate(nil) }
                        }
                        .font(.caption)
                        .disabled(isUpdating)
                    }
                }

                DatePicker("", selection: Binding(
                    get: { task.startDate ?? Date() },
                    set: { newDate in
                        Task { await updateStartDate(newDate) }
                    }
                ), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .disabled(isUpdating)
            }
            .padding()
            .background(Color.green.opacity(0.05))
            .cornerRadius(8)

            // Due Date
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock.circle")
                        .foregroundColor(.orange)
                    Text("Due Date")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    if task.dueDate != nil {
                        Button("Clear") {
                            Task { await updateDueDate(nil) }
                        }
                        .font(.caption)
                        .disabled(isUpdating)
                    }
                }

                DatePicker("", selection: Binding(
                    get: { task.dueDate ?? Date() },
                    set: { newDate in
                        Task { await updateDueDate(newDate) }
                    }
                ), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .disabled(isUpdating)
            }
            .padding()
            .background(Color.orange.opacity(0.05))
            .cornerRadius(8)

            // End Date
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.blue)
                    Text("End Date")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    if task.endDate != nil {
                        Button("Clear") {
                            Task { await updateEndDate(nil) }
                        }
                        .font(.caption)
                        .disabled(isUpdating)
                    }
                }

                DatePicker("", selection: Binding(
                    get: { task.endDate ?? Date() },
                    set: { newDate in
                        Task { await updateEndDate(newDate) }
                    }
                ), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .disabled(isUpdating)
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)

            HStack {
                Button("Cancel") {
                    isEditingDates = false
                }
                .buttonStyle(.bordered)
                .disabled(isUpdating)

                Button("Done") {
                    isEditingDates = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdating)
            }
        }
    }

    private func toggleTaskCompletion() async {
        isUpdating = true
        do {
            let updatedTask = try await api.setTaskDone(task: task, done: !task.done)
            task = updatedTask
        } catch {
            updateError = error.localizedDescription
        }
        isUpdating = false
    }

    private func saveDescription() async {
        isUpdating = true
        do {
            var updatedTask = task
            updatedTask.description = editedDescription.isEmpty ? nil : editedDescription

            let savedTask = try await api.updateTask(updatedTask)
            task = savedTask
            isEditing = false
        } catch {
            updateError = error.localizedDescription
        }
        isUpdating = false
    }

    private func loadAvailableLabels() async {
        do {
            availableLabels = try await api.fetchLabels()
        } catch {
            updateError = error.localizedDescription
        }
    }

    private func addLabel(_ label: Label) async {
        isUpdating = true
        do {
            let updatedTask = try await api.addLabelToTask(taskId: task.id, labelId: label.id)
            task = updatedTask
        } catch {
            updateError = error.localizedDescription
        }
        isUpdating = false
    }

    private func removeLabel(_ label: Label) async {
        isUpdating = true
        do {
            let updatedTask = try await api.removeLabelFromTask(taskId: task.id, labelId: label.id)
            task = updatedTask
        } catch {
            updateError = error.localizedDescription
        }
        isUpdating = false
    }

    private func createAndAddNewLabel() async {
        isUpdating = true
        do {
            // Create the new label
            let hexColor = newLabelColor.toHex()
            let newLabel = try await api.createLabel(title: newLabelTitle, hexColor: hexColor)

            // Add it to available labels
            availableLabels.append(newLabel)

            // Add it to the current task
            let updatedTask = try await api.addLabelToTask(taskId: task.id, labelId: newLabel.id)
            task = updatedTask

            // Reset the creation form
            isCreatingNewLabel = false
            newLabelTitle = ""
            newLabelColor = .blue
        } catch {
            updateError = error.localizedDescription
        }
        isUpdating = false
    }

    private func updatePriority(_ newPriority: TaskPriority) async {
        isUpdating = true
        do {
            var updatedTask = task
            updatedTask.priority = newPriority

            let savedTask = try await api.updateTask(updatedTask)
            task = savedTask
            isEditingPriority = false
        } catch {
            updateError = error.localizedDescription
        }
        isUpdating = false
    }

    private func updateProgress(_ newProgress: Double) async {
        isUpdating = true
        do {
            var updatedTask = task
            updatedTask.percentDone = max(0.0, min(1.0, newProgress))

            let savedTask = try await api.updateTask(updatedTask)
            task = savedTask
        } catch {
            updateError = error.localizedDescription
        }
        isUpdating = false
    }

    private func updateColor(_ newColor: Color) async {
        isUpdating = true
        do {
            var updatedTask = task
            updatedTask.hexColor = newColor.toHex()

            let savedTask = try await api.updateTask(updatedTask)
            task = savedTask
        } catch {
            updateError = error.localizedDescription
        }
        isUpdating = false
    }

    private func updateStartDate(_ newDate: Date?) async {
        isUpdating = true
        do {
            var updatedTask = task
            updatedTask.startDate = newDate

            let savedTask = try await api.updateTask(updatedTask)
            task = savedTask
        } catch {
            updateError = error.localizedDescription
        }
        isUpdating = false
    }

    private func updateDueDate(_ newDate: Date?) async {
        isUpdating = true
        do {
            var updatedTask = task
            updatedTask.dueDate = newDate

            let savedTask = try await api.updateTask(updatedTask)
            task = savedTask
        } catch {
            updateError = error.localizedDescription
        }
        isUpdating = false
    }

    private func updateEndDate(_ newDate: Date?) async {
        isUpdating = true
        do {
            var updatedTask = task
            updatedTask.endDate = newDate

            let savedTask = try await api.updateTask(updatedTask)
            task = savedTask
        } catch {
            updateError = error.localizedDescription
        }
        isUpdating = false
    }

    private func addReminder(_ reminderDate: Date) async {
        isUpdating = true
        do {
            let updatedTask = try await api.addReminderToTask(taskId: task.id, reminderDate: reminderDate)
            task = updatedTask
            newReminderDate = Date() // Reset to current time
        } catch {
            updateError = error.localizedDescription
        }
        isUpdating = false
    }

    private func removeReminder(_ reminderId: Int) async {
        isUpdating = true
        do {
            let updatedTask = try await api.removeReminderFromTask(taskId: task.id, reminderId: reminderId)
            task = updatedTask
        } catch {
            updateError = error.localizedDescription
        }
        isUpdating = false
    }

    private func updateRepeatSettings(_ repeatAfter: Int?, _ repeatMode: RepeatMode) async {
        isUpdating = true
        do {
            var updatedTask = task
            updatedTask.repeatAfter = repeatAfter
            updatedTask.repeatMode = repeatMode

            let savedTask = try await api.updateTask(updatedTask)
            task = savedTask
        } catch {
            updateError = error.localizedDescription
        }
        isUpdating = false
    }

    // MARK: - New Card Components

    private var datesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Dates", systemImage: "calendar")

            VStack(spacing: 12) {
                // Start Date
                dateRow("Start Date", date: task.startDate, color: .green, icon: "play.circle") {
                    if isEditing {
                        DatePicker("", selection: Binding(
                            get: { task.startDate ?? Date() },
                            set: { newDate in
                                task.startDate = newDate
                                hasChanges = true
                            }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                }

                // Due Date
                dateRow("Due Date", date: task.dueDate, color: .orange, icon: "clock") {
                    if isEditing {
                        DatePicker("", selection: Binding(
                            get: { task.dueDate ?? Date() },
                            set: { newDate in
                                task.dueDate = newDate
                                hasChanges = true
                            }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                }

                // End Date
                dateRow("End Date", date: task.endDate, color: .blue, icon: "checkmark.circle") {
                    if isEditing {
                        DatePicker("", selection: Binding(
                            get: { task.endDate ?? Date() },
                            set: { newDate in
                                task.endDate = newDate
                                hasChanges = true
                            }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var priorityProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Priority & Progress", systemImage: "flag.checkered")

            VStack(spacing: 16) {
                // Priority
                VStack(alignment: .leading, spacing: 8) {
                    Text("Priority")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if isEditing {
                        Slider(
                            value: Binding(
                                get: { Double(task.priority.rawValue) },
                                set: { newValue in
                                    task.priority = TaskPriority(rawValue: Int(newValue)) ?? .unset
                                    hasChanges = true
                                }
                            ),
                            in: 0...5,
                            step: 1
                        ) {
                            Text("Priority")
                        } minimumValueLabel: {
                            Text("Low")
                                .font(.caption)
                        } maximumValueLabel: {
                            Text("High")
                                .font(.caption)
                        }
                        .accentColor(task.priority.color)
                    }

                    // Priority display
                    HStack(spacing: 8) {
                        Image(systemName: task.priority.systemImage)
                            .foregroundColor(task.priority.color)
                            .font(.body)

                        Text(task.priority.displayName)
                            .font(.body)
                            .foregroundColor(task.priority == .unset ? .secondary : .primary)
                    }
                }

                Divider()

                // Progress
                VStack(alignment: .leading, spacing: 8) {
                    Text("Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if isEditing {
                        Slider(
                            value: Binding(
                                get: { task.percentDone },
                                set: { newValue in
                                    task.percentDone = newValue
                                    hasChanges = true
                                }
                            ),
                            in: 0.0...1.0,
                            step: 0.05
                        ) {
                            Text("Progress")
                        } minimumValueLabel: {
                            Text("0%")
                                .font(.caption)
                        } maximumValueLabel: {
                            Text("100%")
                                .font(.caption)
                        }
                        .accentColor(progressColor)
                    }

                    // Progress display
                    HStack {
                        ProgressView(value: task.percentDone)
                            .progressViewStyle(LinearProgressViewStyle(tint: progressColor))

                        Text("\(Int(task.percentDone * 100))%")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(progressColor)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var labelsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Labels", systemImage: "tag")

                Spacer()

                if isEditing {
                    Button("Manage Labels") {
                        Task { await loadAvailableLabels() }
                        showingLabelPicker = true
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }

            // Selected labels
            if let labels = task.labels, !labels.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(labels) { label in
                        labelPill(label, showRemove: isEditing)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No labels")
                    .font(.body)
                    .foregroundColor(.secondary.opacity(0.6))
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .cardStyle()
    }

    private var colorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Color", systemImage: "paintpalette")

            if isEditing {
                VStack(spacing: 12) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(presetColors, id: \.self) { color in
                            Button(action: {
                                task.hexColor = color.toHex()
                                hasChanges = true
                            }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(task.color == color ? Color.primary : Color.clear, lineWidth: 3)
                                    )
                            }
                        }
                    }

                    ColorPicker("Custom Color", selection: Binding(
                        get: { task.color },
                        set: { newColor in
                            task.hexColor = newColor.toHex()
                            hasChanges = true
                        }
                    ), supportsOpacity: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 12) {
                    Circle()
                        .fill(task.color)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )

                    Text(task.hexColor?.uppercased() ?? "Default Color")
                        .font(.body)
                        .foregroundColor(.primary)

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .cardStyle()
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Reminders", systemImage: "bell")

                Spacer()

                if isEditing {
                    Button("Add") {
                        Task { await addReminder(newReminderDate) }
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                }
            }

            if isEditing {
                DatePicker("New Reminder", selection: $newReminderDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
            }

            if let reminders = task.reminders?.sorted(by: { $0.reminder < $1.reminder }), !reminders.isEmpty {
                ForEach(reminders) { reminder in
                    reminderRow(reminder)
                }
            } else {
                Text("No reminders")
                    .font(.body)
                    .foregroundColor(.secondary.opacity(0.6))
                    .italic()
            }
        }
        .cardStyle()
    }

    private var repeatCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Repeat", systemImage: "repeat")

            if isEditing {
                Toggle("Enable Repeat", isOn: Binding(
                    get: { task.repeatAfter != nil && task.repeatAfter! > 0 },
                    set: { enabled in
                        if enabled {
                            task.repeatAfter = calculateRepeatSeconds()
                        } else {
                            task.repeatAfter = nil
                        }
                        hasChanges = true
                    }
                ))

                if task.repeatAfter != nil && task.repeatAfter! > 0 {
                    // Repeat mode picker
                    Picker("Mode", selection: Binding(
                        get: { task.repeatMode },
                        set: { newMode in
                            task.repeatMode = newMode
                            hasChanges = true
                        }
                    )) {
                        ForEach(RepeatMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if task.repeatMode == .afterAmount {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Days:")
                                Spacer()
                                Stepper("\(repeatIntervalDays)", value: Binding(
                                    get: { repeatIntervalDays },
                                    set: { newValue in
                                        repeatIntervalDays = newValue
                                        task.repeatAfter = calculateRepeatSeconds()
                                        hasChanges = true
                                    }
                                ), in: 0...365)
                            }

                            HStack {
                                Text("Hours:")
                                Spacer()
                                Stepper("\(repeatIntervalHours)", value: Binding(
                                    get: { repeatIntervalHours },
                                    set: { newValue in
                                        repeatIntervalHours = newValue
                                        task.repeatAfter = calculateRepeatSeconds()
                                        hasChanges = true
                                    }
                                ), in: 0...23)
                            }
                        }
                    }
                }
            } else {
                if let repeatAfter = task.repeatAfter, repeatAfter > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: task.repeatMode.systemImage)
                                .foregroundColor(.cyan)
                            Text(task.repeatMode.displayName)
                                .fontWeight(.medium)
                        }

                        if task.repeatMode == .afterAmount {
                            Text("Every \(formatRepeatInterval(repeatAfter))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("No repeat")
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.6))
                        .italic()
                }
            }
        }
        .cardStyle()
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                Button("Cancel") {
                    cancelEditing()
                }
                .buttonStyle(.bordered)
                .disabled(isUpdating)

                Spacer()

                Button("Save Changes") {
                    Task { await saveAllChanges() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges || isUpdating)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
    }

    private var labelPickerSheet: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(availableLabelsToAdd) { label in
                        Button(action: {
                            addLabelToTask(label)
                        }) {
                            HStack {
                                Text(label.title)
                                    .foregroundColor(.primary)
                                Spacer()
                                Circle()
                                    .fill(label.color)
                                    .frame(width: 20, height: 20)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Labels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingLabelPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Helper Components

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(.secondary)
                .font(.headline)

            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }

    private func dateRow(_ title: String, date: Date?, color: Color, icon: String, @ViewBuilder editingView: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.body)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if isEditing && date != nil {
                    Button("Clear") {
                        switch title {
                        case "Start Date": task.startDate = nil
                        case "Due Date": task.dueDate = nil
                        case "End Date": task.endDate = nil
                        default: break
                        }
                        hasChanges = true
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }

            if let date = date {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date, style: .date)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(date, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if isEditing {
                Text("Not set - tap to add")
                    .font(.body)
                    .foregroundColor(.secondary.opacity(0.6))
                    .italic()
            } else {
                Text("Not set")
                    .font(.body)
                    .foregroundColor(.secondary.opacity(0.6))
                    .italic()
            }

            editingView()
        }
    }

    private func labelPill(_ label: Label, showRemove: Bool) -> some View {
        HStack(spacing: 6) {
            Text(label.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(label.color)

            if showRemove {
                Button(action: {
                    removeLabelFromTask(label.id)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(label.color.opacity(0.15))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(label.color.opacity(0.5), lineWidth: 1)
        )
    }

    private func reminderRow(_ reminder: Reminder) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.reminder, style: .date)
                    .font(.body)
                    .foregroundColor(.primary)
                Text(reminder.reminder, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isEditing, let reminderId = reminder.id {
                Button(action: {
                    Task { await removeReminder(reminderId) }
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func startEditing() {
        isEditing = true
        editedDescription = task.description ?? ""
        setupRepeatEditingValues()
    }

    private func cancelEditing() {
        isEditing = false
        hasChanges = false
        // Reset any unsaved changes
        editedDescription = task.description ?? ""
    }

    private func saveAllChanges() async {
        guard hasChanges else { return }

        isUpdating = true
        do {
            var updatedTask = task
            updatedTask.description = editedDescription.isEmpty ? nil : editedDescription

            let savedTask = try await api.updateTask(updatedTask)
            task = savedTask
            hasChanges = false
            isEditing = false
        } catch {
            updateError = error.localizedDescription
        }
        isUpdating = false
    }

    private func addLabelToTask(_ label: Label) {
        if task.labels?.contains(where: { $0.id == label.id }) != true {
            if task.labels == nil {
                task.labels = []
            }
            task.labels?.append(label)
            hasChanges = true
        }
    }

    private func removeLabelFromTask(_ labelId: Int) {
        task.labels?.removeAll { $0.id == labelId }
        hasChanges = true
    }

}
*/ // End of commented out TaskDetailView

// MARK: - View Extensions

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.bounds
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
}

struct FlowResult {
    var bounds = CGSize.zero
    var frames: [CGRect] = []

    init(in maxWidth: CGFloat, subviews: LayoutSubviews, spacing: CGFloat) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
        }

        bounds = CGSize(width: maxWidth, height: y + lineHeight)
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    func settingsCardStyle() -> some View {
        self
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Color Extension for Hex Conversion
extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)

        return String(format: "%02X%02X%02X", r, g, b)
    }
}

@MainActor
final class TaskListVM: ObservableObject {
    @Published var tasks: [VikunjaTask] = []
    @Published var loading = false
    @Published var error: String?
    @Published var isAddingTask = false
    private let api: VikunjaAPI
    private let projectId: Int

    init(api: VikunjaAPI, projectId: Int) {
        self.api = api; self.projectId = projectId
    }

    func load(queryItems: [URLQueryItem] = []) async {
        loading = true; defer { loading = false }
        do {
            if queryItems.isEmpty {
                tasks = try await api.fetchTasks(projectId: projectId)
            } else {
                tasks = try await api.fetchTasks(projectId: projectId, queryItems: queryItems)
            }
            // Write widget cache after successful load
            WidgetCacheWriter.writeWidgetSnapshot(from: tasks, projectId: projectId)
            // Also write to shared file for watch
            SharedFileManager.shared.writeTasks(tasks, for: projectId)
        }
        catch { self.error = error.localizedDescription }
    }

    func toggle(_ task: VikunjaTask) async {
        do {
            let updated = try await api.setTaskDone(task: task, done: !task.done)
            if let i = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[i] = updated
                // Update widget cache after task change
                WidgetCacheWriter.writeWidgetSnapshot(from: tasks, projectId: projectId)
            }
        } catch { self.error = error.localizedDescription }
    }

    func createTask(title: String, description: String?) async {
        do {
            let newTask = try await api.createTask(projectId: projectId, title: title, description: description)
            tasks.insert(newTask, at: 0)
            isAddingTask = false
            // Update widget cache after creating new task
            WidgetCacheWriter.writeWidgetSnapshot(from: tasks, projectId: projectId)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct TaskListView: View {
    let project: Project
    let api: VikunjaAPI
    @StateObject private var vm: TaskListVM
    @StateObject private var settings = AppSettings.shared
    @State private var newTaskTitle = ""
    @State private var newTaskDescription = ""

    // Filter and Sort state
    @State private var currentFilter = TaskFilter()
    @State private var showingFilter = false
    @State private var currentSort: TaskSortOption
    @State private var showingSort = false

    init(project: Project, api: VikunjaAPI) {
        self.project = project
        self.api = api
        _vm = StateObject(wrappedValue: TaskListVM(api: api, projectId: project.id))
        _currentSort = State(initialValue: AppSettings.getDefaultSortOption())
    }

    var filteredTasks: [VikunjaTask] {
        currentFilter.apply(to: vm.tasks)
    }

    var sortedAndGroupedTasks: [(String?, [VikunjaTask])] {
        let filtered = filteredTasks
        let sorted = sortTasks(filtered, by: currentSort)

        if currentSort.needsSectionHeaders {
            return groupTasksForSorting(sorted, by: currentSort)
        } else {
            return [(nil, sorted)]
        }
    }

    private func sortTasks(_ tasks: [VikunjaTask], by sortOption: TaskSortOption) -> [VikunjaTask] {
        switch sortOption {
        case .serverOrder:
            return tasks // Return tasks in their original server order
        case .alphabetical:
            return tasks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .startDate:
            return tasks.sorted { task1, task2 in
                switch (task1.startDate, task2.startDate) {
                case (nil, nil): return false
                case (nil, _): return false
                case (_, nil): return true
                case (let date1?, let date2?): return date1 < date2
                }
            }
        case .endDate:
            return tasks.sorted { task1, task2 in
                switch (task1.endDate, task2.endDate) {
                case (nil, nil): return false
                case (nil, _): return false
                case (_, nil): return true
                case (let date1?, let date2?): return date1 < date2
                }
            }
        case .dueDate:
            return tasks.sorted { task1, task2 in
                switch (task1.dueDate, task2.dueDate) {
                case (nil, nil): return false
                case (nil, _): return false
                case (_, nil): return true
                case (let date1?, let date2?): return date1 < date2
                }
            }
        case .priority:
            return tasks.sorted { $0.priority.rawValue > $1.priority.rawValue }
        }
    }

    private func groupTasksForSorting(_ tasks: [VikunjaTask], by sortOption: TaskSortOption) -> [(String?, [VikunjaTask])] {
        let calendar = Calendar.current
        let now = Date()

        switch sortOption {
        case .serverOrder:
            return [(nil, tasks)]
        case .alphabetical:
            return [(nil, tasks)]

        case .startDate:
            let grouped = Dictionary(grouping: tasks) { task -> String in
                guard let startDate = task.startDate else { return "No Start Date" }
                if calendar.isDateInToday(startDate) { return "Today" }
                if calendar.isDateInTomorrow(startDate) { return "Tomorrow" }
                if calendar.isDateInYesterday(startDate) { return "Yesterday" }

                let daysFromNow = calendar.dateComponents([.day], from: now, to: startDate).day ?? 0
                if daysFromNow > 0 && daysFromNow <= 7 { return "This Week" }
                if daysFromNow > 7 && daysFromNow <= 30 { return "This Month" }
                if daysFromNow < 0 { return "Past" }
                return DateFormatter.mediumDateFormatter.string(from: startDate)
            }
            return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }

        case .endDate:
            let grouped = Dictionary(grouping: tasks) { task -> String in
                guard let endDate = task.endDate else { return "No End Date" }
                if calendar.isDateInToday(endDate) { return "Today" }
                if calendar.isDateInTomorrow(endDate) { return "Tomorrow" }
                if calendar.isDateInYesterday(endDate) { return "Yesterday" }

                let daysFromNow = calendar.dateComponents([.day], from: now, to: endDate).day ?? 0
                if daysFromNow > 0 && daysFromNow <= 7 { return "This Week" }
                if daysFromNow > 7 && daysFromNow <= 30 { return "This Month" }
                if daysFromNow < 0 { return "Past" }
                return DateFormatter.mediumDateFormatter.string(from: endDate)
            }
            return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }

        case .dueDate:
            let grouped = Dictionary(grouping: tasks) { task -> String in
                guard let dueDate = task.dueDate else { return "No Due Date" }
                if calendar.isDateInToday(dueDate) { return "Today" }
                if calendar.isDateInTomorrow(dueDate) { return "Tomorrow" }
                if calendar.isDateInYesterday(dueDate) { return "Yesterday" }

                let daysFromNow = calendar.dateComponents([.day], from: now, to: dueDate).day ?? 0
                if daysFromNow > 0 && daysFromNow <= 7 { return "This Week" }
                if daysFromNow > 7 && daysFromNow <= 30 { return "This Month" }
                if daysFromNow < 0 { return "Overdue" }
                return DateFormatter.mediumDateFormatter.string(from: dueDate)
            }
            return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }

        case .priority:
            let grouped = Dictionary(grouping: tasks) { task -> String in
                return task.priority == .unset ? "No Priority" : task.priority.displayName
            }
            let priorityOrder = [TaskPriority.doNow, .high, .medium, .low, .unset]
            return priorityOrder.compactMap { priority in
                let key = priority == .unset ? "No Priority" : priority.displayName
                if let tasks = grouped[key], !tasks.isEmpty {
                    return (key, tasks)
                }
                return nil
            }
        }
    }

    var body: some View {
        List {
            // Add new task section
            if vm.isAddingTask {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Task title", text: $newTaskTitle)
                            .textFieldStyle(.roundedBorder)

                        TextField("Description (optional)", text: $newTaskDescription, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)

                        HStack {
                            Button("Cancel") {
                                vm.isAddingTask = false
                                newTaskTitle = ""
                                newTaskDescription = ""
                            }
                            .buttonStyle(.bordered)

                            Button("Add Task") {
                                Task {
                                    await vm.createTask(
                                        title: newTaskTitle,
                                        description: newTaskDescription.isEmpty ? nil : newTaskDescription
                                    )
                                    newTaskTitle = ""
                                    newTaskDescription = ""
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Existing tasks
            ForEach(sortedAndGroupedTasks, id: \.0) { sectionTitle, tasks in
                if let sectionTitle = sectionTitle {
                    Section(header: Text(sectionTitle).font(.caption).fontWeight(.medium).foregroundColor(.secondary).textCase(.uppercase)) {
                        ForEach(tasks) { t in
                            taskRow(for: t)
                        }
                    }
                } else {
                    ForEach(tasks) { t in
                        taskRow(for: t)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 8) {
                    Button {
                        showingFilter = true
                    } label: {
                        Image(systemName: currentFilter.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .foregroundColor(currentFilter.hasActiveFilters ? .accentColor : .primary)

                    Button {
                        showingSort = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    vm.isAddingTask = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(vm.isAddingTask)
            }
        }
        .sheet(isPresented: $showingFilter) {
            FilterView(
                filter: $currentFilter,
                isPresented: $showingFilter,
                availableLabels: []
            )
        }
        .actionSheet(isPresented: $showingSort) {
            ActionSheet(
                title: Text("Sort Tasks"),
                buttons: TaskSortOption.allCases.map { sortOption in
                    ActionSheet.Button.default(
                        Text(sortOption.rawValue),
                        action: { currentSort = sortOption }
                    )
                } + [ActionSheet.Button.cancel()]
            )
        }
        .onAppear {
            Task {
                let query = currentFilter.hasActiveFilters ? currentFilter.toQueryItems() : []
                await vm.load(queryItems: query)
            }
        }
        .onChange(of: currentFilter) { _, _ in
            Task {
                let query = currentFilter.hasActiveFilters ? currentFilter.toQueryItems() : []
                await vm.load(queryItems: query)
            }
        }
        .onChange(of: settings.defaultSortOption) { _, newSortOption in
            currentSort = newSortOption
        }
    }

    @ViewBuilder
    private func taskRow(for t: VikunjaTask) -> some View {
        NavigationLink(destination: TaskDetailView(task: t, api: api)) {
            HStack {
                Button(action: {
                    Task { await vm.toggle(t) }
                }) {
                    Image(systemName: t.done ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(t.done ? .green : .gray)
                }
                .buttonStyle(PlainButtonStyle())

                // Color ball - only show if task has custom color OR setting allows default colors
                if t.hasCustomColor || settings.showDefaultColorBalls {
                    Circle()
                        .fill(t.color)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                        )
                }

                // Priority icon - only show if not unset
                if t.priority != .unset {
                    Image(systemName: t.priority.systemImage)
                        .foregroundColor(t.priority.color)
                        .font(.body)
                        .frame(width: 16, height: 16)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(t.title)
                            .strikethrough(t.done)
                            .foregroundColor(.primary)

                        Spacer()
                    }

                    if let labels = t.labels, !labels.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(labels) { label in
                                    Text(label.title)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(label.color.opacity(0.2))
                                        .foregroundColor(label.color)
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }

                    // Date indicators
                    if t.startDate != nil || t.dueDate != nil || t.endDate != nil {
                        HStack(spacing: 4) {
                            if let startDate = t.startDate {
                                HStack(spacing: 2) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    VStack(spacing: 0) {
                                        Text(startDate, style: .date)
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                        Text(startDate, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.green.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(3)
                            }

                            if let dueDate = t.dueDate {
                                HStack(spacing: 2) {
                                    Image(systemName: "clock.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    VStack(spacing: 0) {
                                        Text(dueDate, style: .date)
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                        Text(dueDate, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.orange.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(3)
                            }

                            if let endDate = t.endDate {
                                HStack(spacing: 2) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    VStack(spacing: 0) {
                                        Text(endDate, style: .date)
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                        Text(endDate, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.blue.opacity(0.8))
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(3)
                            }
                        }
                    }

                    // Repeat indicator
                    if let repeatAfter = t.repeatAfter, repeatAfter > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "repeat")
                                .font(.caption2)
                                .foregroundColor(.purple)
                            Text(t.repeatMode.displayName)
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(3)
                    }

                    // Reminders indicator
                    if let reminders = t.reminders, !reminders.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: reminders.contains(where: { isReminderSoon($0.reminder) }) ? "bell.fill" : "bell")
                                .font(.caption2)
                                .foregroundColor(reminders.contains(where: { isReminderSoon($0.reminder) }) ? .red : .gray)
                            Text("\(reminders.count) reminder\(reminders.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(3)
                    }
                }

                Spacer()
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await vm.toggle(t) }
            } label: {
                Image(systemName: t.done ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(t.done ? .orange : .green)
        }
        .swipeActions(edge: .trailing) {
            Button {
                Task {
                    do {
                        try await api.deleteTask(taskId: t.id)
                        await vm.load(queryItems: currentFilter.hasActiveFilters ? currentFilter.toQueryItems() : []) // Refresh the task list
                    } catch {
                        vm.error = error.localizedDescription
                    }
                }
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)
        }
    }

    private func isReminderSoon(_ reminderDate: Date) -> Bool {
        let now = Date()
        let timeDifference = reminderDate.timeIntervalSince(now)
        return timeDifference <= 3600 && timeDifference > 0 // Within 1 hour from now
    }
}
