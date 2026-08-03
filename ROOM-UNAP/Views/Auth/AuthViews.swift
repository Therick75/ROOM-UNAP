import SwiftUI

struct AuthRootView: View {
    var body: some View {
        NavigationStack {
            LoginView()
        }
    }
}

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("preferredInteractionAccent") private var preferredInteractionAccent = InteractionAccent.blue.rawValue
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 12) {
                LogoView(isCompact: false)
                Text("Habitaciones para estudiantes universitarios")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                SecureField("Contrasena", text: $password)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(spacing: 12) {
                Button {
                    Task { await authViewModel.signIn(email: email, password: password) }
                } label: {
                    HStack {
                        if authViewModel.isLoading { ProgressView().tint(.white) }
                        Text("Acceder")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.white)
                    .background(interactionAccent.tintColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(RoomUnapPressableButtonStyle(accentColor: interactionAccent.tintColor, cornerRadius: 16))
                .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)

                GoogleSignInButton(isLoading: authViewModel.isLoading) {
                    Task { await authViewModel.signInWithGoogle() }
                }
            }

            NavigationLink("Crear cuenta") {
                RegisterView()
            }
            .font(.callout.weight(.semibold))

            Spacer()
        }
        .padding(24)
        .alert("No se pudo iniciar sesion", isPresented: errorBinding) {
            Button("OK", role: .cancel) { authViewModel.errorMessage = nil }
        } message: {
            Text(authViewModel.errorMessage ?? "Intenta nuevamente.")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { authViewModel.errorMessage != nil },
            set: { if !$0 { authViewModel.errorMessage = nil } }
        )
    }

    private var interactionAccent: InteractionAccent {
        InteractionAccent(rawValue: preferredInteractionAccent) ?? .blue
    }
}

struct RegisterView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("preferredInteractionAccent") private var preferredInteractionAccent = InteractionAccent.blue.rawValue
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var role: UserRole = .estudiante

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    LogoView(isCompact: false)
                    Spacer()
                }
                .listRowBackground(Color.clear)

                TextField("Nombre completo", text: $fullName)
                    .textContentType(.name)
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                SecureField("Contrasena", text: $password)
                    .textContentType(.newPassword)
                SecureField("Confirmar contrasena", text: $confirmPassword)
                    .textContentType(.newPassword)
            }

            Section("Rol") {
                Picker("Rol", selection: $role) {
                    Text(UserRole.estudiante.displayName).tag(UserRole.estudiante)
                    Text(UserRole.arrendador.displayName).tag(UserRole.arrendador)
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button {
                    Task {
                        await authViewModel.signUp(
                            fullName: fullName,
                            email: email,
                            password: password,
                            confirmPassword: confirmPassword,
                            role: role
                        )
                    }
                } label: {
                    HStack {
                        Spacer()
                        if authViewModel.isLoading { ProgressView() }
                        Text("Crear cuenta")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .frame(height: 50)
                    .foregroundStyle(.white)
                    .background(interactionAccent.tintColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(RoomUnapPressableButtonStyle(accentColor: interactionAccent.tintColor, cornerRadius: 16))
                .disabled(authViewModel.isLoading || fullName.isEmpty || email.isEmpty || password.isEmpty)
            }

            Section {
                GoogleSignInButton(isLoading: authViewModel.isLoading) {
                    Task { await authViewModel.signInWithGoogle() }
                }
            }
        }
        .navigationTitle("Registro")
        .alert("No se pudo crear la cuenta", isPresented: errorBinding) {
            Button("OK", role: .cancel) { authViewModel.errorMessage = nil }
        } message: {
            Text(authViewModel.errorMessage ?? "Intenta nuevamente.")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { authViewModel.errorMessage != nil },
            set: { if !$0 { authViewModel.errorMessage = nil } }
        )
    }

    private var interactionAccent: InteractionAccent {
        InteractionAccent(rawValue: preferredInteractionAccent) ?? .blue
    }
}

private struct GoogleSignInButton: View {
    let isLoading: Bool
    let action: () -> Void
    @AppStorage("preferredInteractionAccent") private var preferredInteractionAccent = InteractionAccent.blue.rawValue

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                GoogleLogoMark()
                    .frame(width: 20, height: 20)

                Text("Continuar con Google")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(RoomUnapPressableButtonStyle(accentColor: interactionAccent.tintColor, cornerRadius: 8))
        .disabled(isLoading)
    }

    private var interactionAccent: InteractionAccent {
        InteractionAccent(rawValue: preferredInteractionAccent) ?? .blue
    }
}

private struct GoogleLogoMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .overlay(
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [
                                    Color(red: 0.91, green: 0.30, blue: 0.24),
                                    Color(red: 0.96, green: 0.77, blue: 0.21),
                                    Color(red: 0.20, green: 0.58, blue: 0.86),
                                    Color(red: 0.21, green: 0.72, blue: 0.35),
                                    Color(red: 0.91, green: 0.30, blue: 0.24)
                                ],
                                center: .center
                            ),
                            lineWidth: 3.2
                        )
                )

            Rectangle()
                .fill(Color(red: 0.20, green: 0.58, blue: 0.86))
                .frame(width: 7, height: 3.6)
                .offset(x: 4.5, y: 0.5)
        }
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }
}
