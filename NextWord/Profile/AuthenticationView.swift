import SwiftUI

// Sign in, create an account or reset the password with Firebase Authentication.
// Shown by RootView whenever nobody is signed in.
struct AuthenticationView: View {
    private enum Mode: String, CaseIterable {
        case signIn = "Sign in"
        case register = "Create account"
        case reset = "Reset password"
    }
    @EnvironmentObject private var authService: AuthService
    @State private var mode = Mode.signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var showPassword = false
    // True while waiting for Firebase, so the button can't be pressed twice.
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showResetSent = false
    @FocusState private var focusedField: Field?
    private enum Field { case name, email, password, confirmation }

    private var validEmail: Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
    private var canSubmit: Bool {
        validEmail && (mode == .reset || !password.isEmpty) &&
        (mode != .register || (password.count >= 8 && password == confirmPassword && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= AuthService.nameCharacterLimit))
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        // The blue bird from the app icon, so the first screen matches the Home Screen icon.
                        Image("NextWordBird").resizable().scaledToFit()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .accessibilityHidden(true)
                        Text(mode == .signIn ? "Your next word awaits." : mode == .register ? "Start your next chapter." : "Let’s get you back in.")
                            .font(.largeTitle.bold())
                        Text(mode == .reset ? "Enter your email to request a password reset." : "A home for every word you discover.")
                            .foregroundStyle(.secondary)
                    }
                    if mode != .reset {
                        Picker("Account action", selection: $mode) {
                            Text("Sign in").tag(Mode.signIn)
                            Text("Create account").tag(Mode.register)
                        }.pickerStyle(.segmented)
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        if mode == .register {
                            fieldLabel("Display name")
                            TextField("Your name", text: $name).textContentType(.nickname)
                                .textInputAutocapitalization(.words).focused($focusedField, equals: .name)
                                .submitLabel(.next).onSubmit { focusedField = .email }
                                .authField()
                        }
                        fieldLabel("Email")
                        // verbatim stops SwiftUI from turning the sample address into a blue link.
                        TextField("Email", text: $email, prompt: Text(verbatim: "you@example.com")).textContentType(.emailAddress)
                            .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .focused($focusedField, equals: .email).submitLabel(mode == .reset ? .done : .next)
                            .onSubmit { if mode != .reset { focusedField = .password } }
                            .authField()
                        if !email.isEmpty && !validEmail {
                            Text("Enter a valid email address.").font(.caption).foregroundStyle(.red)
                        }
                        if mode != .reset {
                            fieldLabel("Password")
                            HStack {
                                Group {
                                    if showPassword { TextField("Password", text: $password) }
                                    else { SecureField("Password", text: $password) }
                                }
                                .textContentType(mode == .register ? .newPassword : .password)
                                .focused($focusedField, equals: .password)
                                Button { showPassword.toggle() } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye").frame(minWidth: 44, minHeight: 44)
                                }.accessibilityLabel(showPassword ? "Hide password" : "Show password")
                            }
                            .authField()
                            if mode == .register {
                                Text("Use at least 8 characters.").font(.caption).foregroundStyle(.secondary)
                                fieldLabel("Confirm password")
                                SecureField("Repeat your password", text: $confirmPassword).textContentType(.newPassword)
                                    .focused($focusedField, equals: .confirmation)
                                    .authField()
                                if !confirmPassword.isEmpty && password != confirmPassword {
                                    Text("Passwords don’t match.").font(.caption).foregroundStyle(.red)
                                }
                            } else {
                                Button("Forgot password?") { mode = .reset }.font(.subheadline)
                            }
                        }
                    }
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    Button {
                        focusedField = nil
                        Task { await submit() }
                    } label: {
                        Group {
                            if isWorking { ProgressView() } else { Text(mode.rawValue) }
                        }
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).disabled(!canSubmit || isWorking)
                    if mode == .reset { Button("Back to sign in") { mode = .signIn } }
                }.padding(24).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(mode.rawValue).navigationBarTitleDisplayMode(.inline)
            .onChange(of: mode) { _, _ in
                password = ""
                confirmPassword = ""
                showPassword = false
                focusedField = nil
            }
            .alert("Something went wrong", isPresented: errorBinding) {
                Button("OK", role: .cancel) { }
            } message: { Text(errorMessage ?? "") }
            .alert("Check your email", isPresented: $showResetSent) {
                Button("OK") { mode = .signIn }
            } message: { Text("If an account exists for this email, we've sent a link to reset your password.") }
        }
    }
    private func fieldLabel(_ title: String) -> some View { Text(title).font(.subheadline.weight(.semibold)) }

    // Show the alert while there is an error message; clear it when the alert closes.
    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // One button handles all three modes. After a successful sign-in or registration,
    // RootView sees the new user and switches to the main app by itself.
    private func submit() async {
        isWorking = true
        defer { isWorking = false }
        do {
            switch mode {
            case .signIn:
                try await authService.signIn(email: email, password: password)
            case .register:
                try await authService.createAccount(name: name, email: email, password: password)
            case .reset:
                try await authService.sendPasswordReset(email: email)
                showResetSent = true
            }
        } catch {
            errorMessage = AuthService.message(for: error)
        }
    }
}

private extension View {
    // Rounded card fields, matching the cards used across the rest of the app.
    func authField() -> some View {
        self.padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
