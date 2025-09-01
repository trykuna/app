import SwiftUI

struct RepeatEditorSheet: View {
    enum IntervalUnit: String, CaseIterable {
        case hours = "Hours"
        case days = "Days"
        case weeks = "Weeks"
        case months = "Months"
        
        var seconds: Int {
            switch self {
            case .hours: return 3600
            case .days: return 86400
            case .weeks: return 604800
            case .months: return 2592000 // 30 days approximation
            }
        }
        
        var localizedName: String {
            switch self {
            case .hours: return String(localized: "tasks.repeat.unit.hours", comment: "Hours")
            case .days: return String(localized: "tasks.repeat.unit.days", comment: "Days")
            case .weeks: return String(localized: "tasks.repeat.unit.weeks", comment: "Weeks")
            case .months: return String(localized: "tasks.repeat.unit.months", comment: "Months")
            }
        }
    }
    
    @State private var selectedPreset: String = ""
    @State private var customValue: String = "1"
    @State private var customUnit: IntervalUnit = .days
    @State private var useCustom: Bool = false
    @State var mode: RepeatMode
    
    let onCommit: (Int?, RepeatMode) -> Void
    let onCancel: () -> Void
    
    init(repeatAfter: Int?,
         repeatMode: RepeatMode,
         onCommit: @escaping (Int?, RepeatMode) -> Void,
         onCancel: @escaping () -> Void) {
        self._mode = State(initialValue: repeatMode)
        self.onCommit = onCommit
        self.onCancel = onCancel
        
        // Initialize state based on existing value
        if let seconds = repeatAfter, seconds > 0 {
            // Check if it matches a preset
            switch seconds {
            case 86400:
                self._selectedPreset = State(initialValue: "daily")
                self._useCustom = State(initialValue: false)
            case 604800:
                self._selectedPreset = State(initialValue: "weekly")
                self._useCustom = State(initialValue: false)
            case 2592000:
                self._selectedPreset = State(initialValue: "monthly")
                self._useCustom = State(initialValue: false)
            default:
                // Convert to most appropriate unit
                self._useCustom = State(initialValue: true)
                if seconds % 604800 == 0 {
                    self._customValue = State(initialValue: String(seconds / 604800))
                    self._customUnit = State(initialValue: .weeks)
                } else if seconds % 86400 == 0 {
                    self._customValue = State(initialValue: String(seconds / 86400))
                    self._customUnit = State(initialValue: .days)
                } else if seconds % 3600 == 0 {
                    self._customValue = State(initialValue: String(seconds / 3600))
                    self._customUnit = State(initialValue: .hours)
                } else {
                    // Default to days
                    self._customValue = State(initialValue: String(seconds / 86400))
                    self._customUnit = State(initialValue: .days)
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Preset options
                Section(String(localized: "tasks.repeat.presets", comment: "Quick Options")) {
                    HStack(spacing: 12) {
                        PresetButton(
                            title: String(localized: "tasks.repeat.daily", comment: "Daily"),
                            isSelected: selectedPreset == "daily" && !useCustom,
                            action: {
                                selectedPreset = "daily"
                                useCustom = false
                            }
                        )
                        
                        PresetButton(
                            title: String(localized: "tasks.repeat.weekly", comment: "Weekly"),
                            isSelected: selectedPreset == "weekly" && !useCustom,
                            action: {
                                selectedPreset = "weekly"
                                useCustom = false
                            }
                        )
                        
                        PresetButton(
                            title: String(localized: "tasks.repeat.monthly", comment: "Every 30 days"),
                            isSelected: selectedPreset == "monthly" && !useCustom,
                            action: {
                                selectedPreset = "monthly"
                                useCustom = false
                            }
                        )
                    }
                    .padding(.vertical, 8)
                }
                
                // Custom interval
                Section(String(localized: "tasks.repeat.custom", comment: "Custom Interval")) {
                    Toggle(String(localized: "tasks.repeat.useCustom", comment: "Use custom interval"), isOn: $useCustom)
                        .onChange(of: useCustom) { _, newValue in
                            if newValue {
                                selectedPreset = ""
                            }
                        }
                    
                    if useCustom {
                        HStack {
                            Text(String(localized: "tasks.repeat.every", comment: "Every"))
                            TextField("1", text: $customValue)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Picker(String(localized: "tasks.repeat.unit", comment: "Unit"), selection: $customUnit) {
                                ForEach(IntervalUnit.allCases, id: \.self) { unit in
                                    Text(unit.localizedName).tag(unit)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                }
                
                // Repeat mode
                Section(header: Text(String(localized: "tasks.repeat.mode", comment: "Repeat Mode")),
                        footer: Text(mode.description).font(.caption).foregroundColor(.secondary)) {
                    Picker(String(localized: "tasks.repeat.mode.picker", comment: "When to repeat"), selection: $mode) {
                        ForEach(RepeatMode.allCases) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .pickerStyle(DefaultPickerStyle())
                }
            }
            .navigationTitle(String(localized: "tasks.repeat.title", comment: "Repeat Task"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", comment: "Cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", comment: "Done")) {
                        let seconds: Int?
                        
                        if useCustom {
                            // Calculate seconds from custom value
                            if let value = Int(customValue), value > 0 {
                                seconds = value * customUnit.seconds
                            } else {
                                seconds = nil
                            }
                        } else {
                            // Use preset value
                            switch selectedPreset {
                            case "daily": seconds = 86400
                            case "weekly": seconds = 604800
                            case "monthly": seconds = 2592000
                            default: seconds = nil
                            }
                        }
                        
                        onCommit(seconds, mode)
                    }
                }
            }
        }
    }
}
