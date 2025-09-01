// Features/Tasks/FilterView.swift
import SwiftUI

struct FilterView: View {
    @Binding var filter: TaskFilter
    @Binding var isPresented: Bool
    let availableLabels: [Label]
    
    @State private var showPriorityPicker = false
    @State private var showProgressSlider = false
    @State private var showDatePickers = false
    @State private var showLabelPicker = false
    
    var body: some View {
        NavigationView {
            Form {
                // Quick Filters Section
                // Section("Quick Filters") {
                Section(String(localized: "tasks.filter.quickFilters", comment: "Quick filters section")) {
                    // Picker("Quick Filter", selection: $filter.quickFilter) {
                    Picker(String(localized: "tasks.filter.quickFilter",
                                    comment: "Quick filter picker"), selection: $filter.quickFilter) {
                        ForEach(TaskFilter.QuickFilterType.allCases, id: \.self) { quickFilter in
                            HStack {
                                Image(systemName: quickFilter.systemImage)
                                Text(quickFilter.rawValue)
                            }
                            .tag(quickFilter)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Status Section
                // Section("Status") {
                Section(String(localized: "tasks.filter.status", comment: "Status section")) {
                    // Toggle("Show Completed Tasks", isOn: $filter.showCompleted)
                    Toggle(String(localized: "tasks.filter.showCompleted",
                                    comment: "Show completed tasks toggle"), isOn: $filter.showCompleted)
                    // Toggle("Show Incomplete Tasks", isOn: $filter.showIncomplete)
                    Toggle(String(localized: "tasks.filter.showIncomplete",
                                    comment: "Show incomplete tasks toggle"), isOn: $filter.showIncomplete)
                }
                
                // Priority Section
                Section {
                    // Toggle("Filter by Priority", isOn: $filter.filterByPriority)
                    Toggle(String(localized: "tasks.filter.byPriority",
                                    comment: "Filter by priority toggle"), isOn: $filter.filterByPriority)
                    
                    if filter.filterByPriority {
                        HStack {
                            // Text("Min Priority")
                            Text(String(localized: "tasks.priority.min", comment: "Title for min priority"))
                            Spacer()
                            // Picker("Min", selection: $filter.minPriority) {
                            Picker(String(localized: "common.min", comment: "Min label"), selection: $filter.minPriority) {
                                ForEach(TaskPriority.allCases) { priority in
                                    Text(priority.displayName).tag(priority)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        HStack {
                            // Text("Max Priority")
                            Text(String(localized: "tasks.priority.max", comment: "Title for max priority"))
                            Spacer()
                            // Picker("Max", selection: $filter.maxPriority) {
                            Picker(String(localized: "common.max", comment: "Max label"), selection: $filter.maxPriority) {
                                ForEach(TaskPriority.allCases) { priority in
                                    Text(priority.displayName).tag(priority)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                } header: {
                    // Text("Priority")
                    Text(String(localized: "tasks.details.priority.title", comment: "Title for priority"))
                }
                
                // Progress Section
                Section {
                    // Toggle("Filter by Progress", isOn: $filter.filterByProgress)
                    Toggle(String(localized: "tasks.filter.byProgress",
                                    comment: "Filter by progress toggle"), isOn: $filter.filterByProgress)
                    
                    if filter.filterByProgress {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("tasks.filter.minProgress \(filter.minProgress, format: .percent)",
                                     comment: "Minimum progress percentage in task filter")

                                Spacer()

                                Text("tasks.filter.maxProgress \(filter.maxProgress, format: .percent)",
                                     comment: "Maximum progress percentage in task filter")
                            }

                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            Slider(value: $filter.minProgress, in: 0...filter.maxProgress)
                            Slider(value: $filter.maxProgress, in: filter.minProgress...1)
                        }
                    }
                } header: {
                    // Text("Progress")
                    Text(String(localized: "tasks.details.progress.title", comment: "Title for progress"))
                }
                
                // Due Date Section
                Section {
                    // Toggle("Filter by Due Date", isOn: $filter.filterByDueDate)
                    Toggle(String(localized: "tasks.filter.byDueDate",
                                    comment: "Filter by due date toggle"), isOn: $filter.filterByDueDate)
                    
                    if filter.filterByDueDate {
                        // DatePicker("From", selection: Binding(
                        DatePicker(String(localized: "common.from", comment: "From date label"), selection: Binding(
                            get: { filter.dueDateFrom ?? Date() },
                            set: { filter.dueDateFrom = $0 }
                        ), displayedComponents: [.date])
                        
                        DatePicker(String(localized: "common.to", comment: "To"), selection: Binding(
                            get: { filter.dueDateTo ?? Date() },
                            set: { filter.dueDateTo = $0 }
                        ), displayedComponents: [.date])
                        
                        // Button("Clear Dates") {
                        Button(String(localized: "filter.clearDates", comment: "Clear date filters button")) {
                            filter.dueDateFrom = nil
                            filter.dueDateTo = nil
                        }
                        .foregroundColor(.red)
                    }
                } header: {
                    // Text("Due Date")
                    Text(String(localized: "tasks.details.dates.dueDate.title", comment: "Title for due date"))
                }
                
                // Labels Section
                Section {
                    // Toggle("Filter by Labels", isOn: $filter.filterByLabels)
                    Toggle(String(localized: "tasks.filter.byLabels",
                                    comment: "Filter by labels toggle"), isOn: $filter.filterByLabels)
                    
                    if filter.filterByLabels {
                        NavigationLink(
                            String.localizedStringWithFormat(
                                String(localized: "Required Labels (%lld)", comment: "Required labels with count"),
                                filter.requiredLabelIds.count
                            )
                        ) {
                            LabelSelectionView(
                                title: "Required Labels",
                                availableLabels: availableLabels,
                                selectedLabelIds: $filter.requiredLabelIds,
                                subtitle: "Tasks must have all selected labels"
                            )
                        }
                        
                        NavigationLink(
                            String.localizedStringWithFormat(
                                String(localized: "Excluded Labels (%lld)", comment: "Excluded labels with count"),
                                filter.excludedLabelIds.count
                            )
                        ) {
                            LabelSelectionView(
                                title: "Excluded Labels",
                                availableLabels: availableLabels,
                                selectedLabelIds: $filter.excludedLabelIds,
                                subtitle: "Tasks must not have any selected labels"
                            )
                        }
                    }
                } header: {
                    // Text("Labels")
                    Text(String(localized: "labels.title", comment: "Title for labels"))
                }
                
                // Reset Section
                if filter.hasActiveFilters {
                    Section {
                        // Button("Reset All Filters") {
                        Button(String(localized: "tasks.filter.resetAll", comment: "Reset all filters button")) {
                            filter.reset()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            // .navigationTitle("Filter Tasks")
            .navigationTitle(String(localized: "tasks.filter.title", comment: "Filter tasks navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Button("Cancel") {
                    Button(String(localized: "common.cancel", comment: "Cancel button")) {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Button("Apply") {
                    Button(String(localized: "common.apply", comment: "Apply button")) {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct LabelSelectionView: View {
    let title: String
    let availableLabels: [Label]
    @Binding var selectedLabelIds: Set<Int>
    let subtitle: String
    
    var body: some View {
        List {
            Section {
                ForEach(availableLabels) { label in
                    HStack {
                        Circle()
                            .fill(label.color)
                            .frame(width: 12, height: 12)
                        
                        Text(label.title)
                            .font(.body)
                        
                        Spacer()
                        
                        if selectedLabelIds.contains(label.id) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedLabelIds.contains(label.id) {
                            selectedLabelIds.remove(label.id)
                        } else {
                            selectedLabelIds.insert(label.id)
                        }
                    }
                }
            } footer: {
                Text(subtitle)
                    .font(.caption)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
