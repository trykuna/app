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
                Section("Quick Filters") {
                    Picker("Quick Filter", selection: $filter.quickFilter) {
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
                Section("Status") {
                    Toggle("Show Completed Tasks", isOn: $filter.showCompleted)
                    Toggle("Show Incomplete Tasks", isOn: $filter.showIncomplete)
                }
                
                // Priority Section
                Section {
                    Toggle("Filter by Priority", isOn: $filter.filterByPriority)
                    
                    if filter.filterByPriority {
                        HStack {
                            // Text("Min Priority")
                            Text(String(localized: "min_priority_title", comment: "Title for min priority"))
                            Spacer()
                            Picker("Min", selection: $filter.minPriority) {
                                ForEach(TaskPriority.allCases) { priority in
                                    Text(priority.displayName).tag(priority)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        HStack {
                            // Text("Max Priority")
                            Text(String(localized: "max_priority_title", comment: "Title for max priority"))
                            Spacer()
                            Picker("Max", selection: $filter.maxPriority) {
                                ForEach(TaskPriority.allCases) { priority in
                                    Text(priority.displayName).tag(priority)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                } header: {
                    // Text("Priority")
                    Text(String(localized: "priority_title", comment: "Title for priority"))
                }
                
                // Progress Section
                Section {
                    Toggle("Filter by Progress", isOn: $filter.filterByProgress)
                    
                    if filter.filterByProgress {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                // TODO: Localize
                                Text("Min: \(Int(filter.minProgress * 100))%")
                                Spacer()
                                Text("Max: \(Int(filter.maxProgress * 100))%")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            Slider(value: $filter.minProgress, in: 0...filter.maxProgress)
                            Slider(value: $filter.maxProgress, in: filter.minProgress...1)
                        }
                    }
                } header: {
                    // Text("Progress")
                    Text(String(localized: "progress_title", comment: "Title for progress"))
                }
                
                // Due Date Section
                Section {
                    Toggle("Filter by Due Date", isOn: $filter.filterByDueDate)
                    
                    if filter.filterByDueDate {
                        DatePicker("From", selection: Binding(
                            get: { filter.dueDateFrom ?? Date() },
                            set: { filter.dueDateFrom = $0 }
                        ), displayedComponents: [.date])
                        
                        DatePicker("To", selection: Binding(
                            get: { filter.dueDateTo ?? Date() },
                            set: { filter.dueDateTo = $0 }
                        ), displayedComponents: [.date])
                        
                        Button("Clear Dates") {
                            filter.dueDateFrom = nil
                            filter.dueDateTo = nil
                        }
                        .foregroundColor(.red)
                    }
                } header: {
                    // Text("Due Date")
                    Text(String(localized: "due_date_title", comment: "Title for due date"))
                }
                
                // Labels Section
                Section {
                    Toggle("Filter by Labels", isOn: $filter.filterByLabels)
                    
                    if filter.filterByLabels {
                        NavigationLink("Required Labels (\(filter.requiredLabelIds.count))") {
                            LabelSelectionView(
                                title: "Required Labels",
                                availableLabels: availableLabels,
                                selectedLabelIds: $filter.requiredLabelIds,
                                subtitle: "Tasks must have all selected labels"
                            )
                        }
                        
                        NavigationLink("Excluded Labels (\(filter.excludedLabelIds.count))") {
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
                    Text(String(localized: "labels_title", comment: "Title for labels"))
                }
                
                // Reset Section
                if filter.hasActiveFilters {
                    Section {
                        Button("Reset All Filters") {
                            filter.reset()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Filter Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
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