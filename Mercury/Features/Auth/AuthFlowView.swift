import SwiftUI

struct AuthFlowView: View {
    enum Mode {
        case signIn
        case signUp
    }

    let session: SessionModel

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if mode == .signUp {
                        TextField("Name", text: $name)
                            .textContentType(.name)
                    }
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    // No .newPassword content type: the system's "Use Strong
                    // Password?" sheet would interrupt sign-up (and automation).
                    SecureField("Password (8+ characters)", text: $password)
                        .textContentType(mode == .signUp ? nil : .password)
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(mode == .signIn ? "Sign In" : "Create Account")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }

                Section {
                    Button(mode == .signIn
                           ? "New to Mercury? Create an account"
                           : "Already have an account? Sign in") {
                        mode = mode == .signIn ? .signUp : .signIn
                        errorMessage = nil
                    }
                    .font(.footnote)
                }
            }
            .navigationTitle("Mercury")
        }
    }

    private var canSubmit: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 8
        let nameValid = mode == .signIn || !name.trimmingCharacters(in: .whitespaces).isEmpty
        return emailValid && passwordValid && nameValid
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            switch mode {
            case .signIn:
                try await session.signIn(email: email, password: password)
            case .signUp:
                try await session.signUp(name: name, email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
