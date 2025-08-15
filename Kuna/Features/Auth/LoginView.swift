import SwiftUI

struct LoginView: View {
    @EnvironmentObject var app: AppState

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

    @FocusState private var focused: Field?
    enum Field { case server, username, password, token }

    var body: some View {
        NavigationStack {
            Form {
                // ---- App header with logo ----
                Section {
                    VStack(spacing: 8) {
                        Image("KunaLogoBlue")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(radius: 4)
                            .padding(.bottom, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                    )
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

                        Button("Log In", action: login)
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(!isServerValid)
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
            // Hide the nav title to avoid duplicate "Kuna" text
            .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
        }
    }

    private var isServerValid: Bool {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return false }
        return ["http", "https"].contains(url.scheme?.lowercased() ?? "") && !(url.host ?? "").isEmpty
    }

    private func login() {
        Task {
            do {
                try await app.login(serverURL: serverURL, username: username, password: password)
            } catch {
                self.error = error.localizedDescription
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
