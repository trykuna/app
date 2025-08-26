// Features/Auth/TOTPView.swift
import SwiftUI

struct TOTPView: View {
    let serverURL: String
    let username: String
    let password: String
    @Binding var isPresented: Bool
    let onSuccess: () -> Void
    let onError: (String) -> Void
    
    @EnvironmentObject var app: AppState
    @State private var totpCode = ""
    @State private var isLoggingIn = false
    @FocusState private var totpFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        // Text("Two-Factor Authentication")
                        Text(String(localized: "auth.totp.title", comment: "Title for two-factor authentication view"))
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        // Text("Enter the 6-digit code from your authenticator app")
                        Text(String(localized: "auth.totp.subtitle", comment: "Subtitle for two-factor authentication view"))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 32)
                
                // TOTP Input
                VStack(spacing: 16) {
                    ZStack(alignment: .leading) {
                        if totpCode.isEmpty {
                            Text(verbatim: "000000")
                                .foregroundColor(Color(UIColor.placeholderText))
                                .textSelection(.disabled)
                                .allowsHitTesting(false)
                        }
                        TextField("", text: $totpCode)
                            .focused($totpFocused)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .font(.system(.title, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .onChange(of: totpCode) { _, newValue in
                                // Limit to 6 digits
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered.count <= 6 {
                                    totpCode = filtered
                                } else {
                                    totpCode = String(filtered.prefix(6))
                                }
                                
                                // Auto-submit when 6 digits are entered
                                if totpCode.count == 6 {
                                    submitTOTP()
                                }
                            }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(totpFocused ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    
                    // Text("The code will be submitted automatically when complete")
                    Text(String(localized: "auth.totp.auto_submit", comment: "Label explaining that the code will be submitted automatically"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Manual submit button (in case auto-submit doesn't work)
                // Button("Verify Code") {
                Button(String(localized: "auth.totp.verifyCode", comment: "Verify code button")) {
                    submitTOTP()
                }
                .buttonStyle(.borderedProminent)
                .disabled(totpCode.count != 6 || isLoggingIn)
                .padding(.horizontal)
            }
            .navigationTitle(String(localized: "auth.verification", comment: "Verification"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Button("Cancel") {
                    Button(String(localized: "common.cancel", comment: "Cancel button")) {
                        isPresented = false
                    }
                    .disabled(isLoggingIn)
                }
            }
            .onAppear {
                totpFocused = true
            }
            .overlay {
                if isLoggingIn {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        // Text("Verifying...")
                        Text(String(localized: "auth.totp.verifying", comment: "Label shown when verifying two-factor code"))
                            .font(.headline)
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 8)
                }
            }
        }
    }
    
    private func submitTOTP() {
        guard totpCode.count == 6, !isLoggingIn else { return }
        
        isLoggingIn = true
        
        Task {
            do {
                try await app.loginWithTOTP(
                    serverURL: serverURL,
                    username: username,
                    password: password,
                    totpCode: totpCode
                )
                
                isLoggingIn = false
                onSuccess()
            } catch {
                isLoggingIn = false
                onError(error.localizedDescription)
            }
        }
    }
}

#Preview {
    TOTPView(
        serverURL: "https://example.com",
        username: "user",
        password: "password",
        isPresented: .constant(true),
        onSuccess: {},
        onError: { _ in }
    )
    .environmentObject(AppState())
}
