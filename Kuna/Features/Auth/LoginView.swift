import SwiftUI

struct LoginView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.colorScheme) private var colorScheme

    enum LoginMode: String, CaseIterable, Identifiable {
        case password = "Password", token = "API Token"
        var id: String { rawValue }
    }

    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var personalToken = ""
    @State private var mode: LoginMode = .password
    @State private var error: String?
    @State private var showingURLInfo = false
    @State private var showingTOTP = false
    @State private var totpCode = ""
    @State private var isLoggingIn = false

    @FocusState private var focused: Field?
    enum Field { case server, username, password, token, totp }

    var body: some View {
        NavigationStack {
            ZStack {
                // Own the full-screen background in both appearances
                Color(.systemBackground).ignoresSafeArea()

                Form {
                    // ---- App header with logo ----
                    Section {
                        VStack(spacing: 8) {
                            AdaptiveLogo(.main)
                                .logoSize(150)
                                .logoCornerRadius(20)
                                .shadow(radius: colorScheme == .dark ? 0 : 4)
                                .padding(.bottom, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            // No card in dark mode; soft card in light mode
                            if colorScheme == .dark {
                                Color.clear
                            } else {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            }
                        }
                        .listRowInsets(EdgeInsets()) // full-width background
                    }
                    .listRowBackground(Color.clear)

                    Section("Server") {
                        HStack {
                            ZStack(alignment: .leading) {
                                if serverURL.isEmpty {
                                    Text("https:\u{200B}//tasks.example.com")
                                        .foregroundColor(Color(UIColor.placeholderText))
                                        .textSelection(.disabled)
                                        .allowsHitTesting(false)
                                }
                                TextField("", text: $serverURL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.URL)
                                    .textContentType(.URL)
                                    .focused($focused, equals: .server)
                                    .submitLabel(.next)
                                    .onSubmit { focused = mode == .password ? .username : .token }
                            }

                            Button {
                                showingURLInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .sheet(isPresented: $showingURLInfo) {
                                URLHelpSheet()
                                    .presentationDetents([.fraction(0.25), .medium])
                                    .presentationDragIndicator(.visible)
                            }
                        }
                    }

                    Section {
                        Picker("Login Method", selection: $mode) {
                            ForEach(LoginMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                                    .font(.footnote)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("**Username & Password**: Full access to all features including user management and task assignment.")
                                    Text("**API Token**: Limited to personal tasks only. User management features are not available due to Vikunja API restrictions.")
                                }
                            }
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    if mode == .password {
                        Section("Username & Password") {
                            TextField("Username", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.username)
                                .focused($focused, equals: .username)
                                .submitLabel(.next)
                                .onSubmit { focused = .password }

                            SecureField("Password", text: $password)
                                .textContentType(.password)
                                .focused($focused, equals: .password)
                                .submitLabel(.go)
                                .onSubmit { login() }

                            Button(action: login) {
                                HStack {
                                    if isLoggingIn {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .padding(.trailing, 4)
                                    }
                                    Text(isLoggingIn ? "Logging In..." : "Log In")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(!isServerValid || isLoggingIn)

                            // TOTP info
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                                Text("If you have two-factor authentication enabled, you'll be prompted for your verification code after entering your credentials.")
                            }
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Section("Personal API Token") {
                            SecureField("API Token", text: $personalToken)
                                .textContentType(.password)
                                .focused($focused, equals: .token)
                                .submitLabel(.go)
                                .onSubmit { useToken() }

                            Button("Use Token", action: useToken)
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(!isServerValid || personalToken.isEmpty)

                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.secondary)
                                Text("In Vikunja, go to **Settings → API Tokens → Create A Token** and create a new token.")
                            }
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let e = error, !e.isEmpty {
                        Section { Text(e).foregroundColor(.red).font(.callout) }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden) // let the ZStack background show
            }
            // Hide the nav title to avoid duplicate "Kuna" text
            .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
            .sheet(isPresented: $showingTOTP) {
                TOTPView(
                    serverURL: serverURL,
                    username: username,
                    password: password,
                    isPresented: $showingTOTP,
                    onSuccess: {
                        showingTOTP = false
                        error = nil
                    },
                    onError: { errorMessage in
                        error = errorMessage
                        showingTOTP = false
                    }
                )
                .environmentObject(app)
            }
        }
    }

    private var isServerValid: Bool {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return false }
        return ["http", "https"].contains(url.scheme?.lowercased() ?? "") && !(url.host ?? "").isEmpty
    }

    private func login() {
        isLoggingIn = true
        error = nil
        Task {
            do {
                try await app.login(serverURL: serverURL, username: username, password: password)
                isLoggingIn = false
            } catch {
                isLoggingIn = false
                if let apiError = error as? APIError, case .totpRequired = apiError {
                    showingTOTP = true
                } else {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    private func useToken() {
        do {
            try app.usePersonalToken(serverURL: serverURL, token: personalToken)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct URLHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.title2)
                Text("Server URL Help")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding(.bottom, 4)

            Text("Enter your server address — you don’t need to add `/api/v1`; the app will do that for you.")
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding()
    }
}

#Preview {
    LoginView().environmentObject(AppState())
}
