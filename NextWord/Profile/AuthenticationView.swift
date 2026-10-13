import SwiftUI

// UI-only authentication flow. No credentials or authentication state are persisted.
struct AuthenticationView: View {
    private enum Mode: String, CaseIterable {
        case signIn = "Sign in"
        case register = "Create account"
        case reset = "Reset password"
    }
    @Environment(\.dismiss) private var dismiss
    @State private var mode = Mode.signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var showPassword = false
    @State private var showNotice = false
    @FocusState private var focusedField: Field?
    private enum Field { case name, email, password, confirmation }

    private var validEmail: Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
    private var canSubmit: Bool {
        validEmail && (mode == .reset || !password.isEmpty) &&
        (mode != .register || (password.count >= 8 && password == confirmPassword && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 40))
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "book.pages.fill").font(.system(size: 44)).foregroundStyle(.blue)
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
                        }
                        fieldLabel("Email")
                        TextField("you@example.com", text: $email).textContentType(.emailAddress)
                            .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                            .focused($focusedField, equals: .email).submitLabel(mode == .reset ? .done : .next)
                            .onSubmit { if mode != .reset { focusedField = .password } }
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
                            if mode == .register {
                                Text("Use at least 8 characters.").font(.caption).foregroundStyle(.secondary)
                                fieldLabel("Confirm password")
                                SecureField("Repeat your password", text: $confirmPassword).textContentType(.newPassword)
                                    .focused($focusedField, equals: .confirmation)
                                if !confirmPassword.isEmpty && password != confirmPassword {
                                    Text("Passwords don’t match.").font(.caption).foregroundStyle(.red)
                                }
                            } else {
                                Button("Forgot password?") { mode = .reset }.font(.subheadline)
                            }
                        }
                    }
                    .textFieldStyle(.roundedBorder).autocorrectionDisabled().textInputAutocapitalization(.never)
                    Button {
                        focusedField = nil
                        showNotice = true
                    } label: {
                        Text(mode.rawValue).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).disabled(!canSubmit)
                    Label("Preview only · Account services are not connected yet. No account will be created and your password is not saved.", systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                    if mode == .reset { Button("Back to sign in") { mode = .signIn } }
                    Button("Continue as guest") { dismiss() }.frame(maxWidth: .infinity)
                }.padding(24).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(mode.rawValue).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .onChange(of: mode) { _, _ in
                password = ""
                confirmPassword = ""
                showPassword = false
                focusedField = nil
            }
            .alert("Account connection coming soon", isPresented: $showNotice) {
                Button("OK", role: .cancel) { }
            } message: { Text("This screen is ready for a future account service. Sign-in, registration and password reset are not available yet. Continue as a guest to use NextWord.") }
        }
    }
    private func fieldLabel(_ title: String) -> some View { Text(title).font(.subheadline.weight(.semibold)) }
}
