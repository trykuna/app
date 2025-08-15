// Features/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Default Color Balls")
                                .font(.body)
                            
                            Text("Display color indicators for tasks using the default blue color")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $settings.showDefaultColorBalls)
                            .labelsHidden()
                    }
                } header: {
                    Text("Display")
                } footer: {
                    Text("When disabled, only tasks with custom colors will show color balls in the task list.")
                }
                
                Section {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.orange)
                            .font(.body)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Sort Order")
                                .font(.body)
                            
                            Text("How tasks are sorted when you open a project")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Picker("Default Sort", selection: $settings.defaultSortOption) {
                            ForEach(TaskSortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Task List")
                }
                
                Section {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.green)
                            .font(.body)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Server")
                                .font(.body)
                            
                            if let serverURL = Keychain.readServerURL() {
                                Text(serverURL)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("No server configured")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                        
                        Spacer()
                    }
                } header: {
                    Text("Connection")
                }
                
                Section {
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.body)
                            
                            Text("About")
                                .font(.body)
                        }
                    }
                } header: {
                    Text("Information")
                }
                
                Section {
                    Button("Sign Out", role: .destructive) {
                        appState.logout()
                        dismiss()
                    }
                } header: {
                    Text("Account")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}