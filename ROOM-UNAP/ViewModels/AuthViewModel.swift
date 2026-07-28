import Foundation
import Combine
import Supabase
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client: SupabaseClient
    private let service: RoomUnapService
    private var authTask: Task<Void, Never>?

    init(
        client: SupabaseClient? = nil,
        service: RoomUnapService? = nil
    ) {
        self.client = client ?? SupabaseManager.shared.client
        self.service = service ?? RoomUnapService()
        listenForAuthChanges()
    }

    deinit {
        authTask?.cancel()
    }

    func listenForAuthChanges() {
        authTask = Task { [weak self] in
            guard let self else { return }
            for await (_, session) in client.auth.authStateChanges {
                self.session = session
                self.isAuthenticated = session != nil

                if let userId = session?.user.id.uuidString {
                    await self.loadProfile(userId: userId)
                } else {
                    self.currentUser = nil
                }
            }
        }
    }

    func signIn(email: String, password: String) async {
        await runAuthAction {
            try await self.client.auth.signIn(email: email.trimmed, password: password)
        }
    }

    func signInWithGoogle() async {
        await runAuthAction {
            let redirectURL = URL(string: "roomunap://login-callback")!
            let url = try self.client.auth.getOAuthSignInURL(
                provider: .google,
                redirectTo: redirectURL
            )
            try await self.openOAuthURL(url)
        }
    }

    func handleLoginCallback(_ url: URL) {
        client.auth.handle(url)
    }

    func signUp(fullName: String, email: String, password: String, confirmPassword: String, role: UserRole) async {
        guard password == confirmPassword else {
            errorMessage = AppError.passwordMismatch.localizedDescription
            Haptics.error()
            return
        }

        await runAuthAction {
            let response = try await self.client.auth.signUp(
                email: email.trimmed,
                password: password,
                data: [
                    "full_name": .string(fullName.trimmed),
                    "role": .string(role.rawValue)
                ]
            )

            if response.session != nil {
                await self.loadProfile(userId: response.user.id.uuidString)
            }
        }
    }

    func signOut() async {
        await runAuthAction {
            try await self.client.auth.signOut()
            self.currentUser = nil
            self.session = nil
            self.isAuthenticated = false
        }
    }

    func loadProfile(userId: String? = nil) async {
        let resolvedUserId = userId ?? session?.user.id.uuidString
        guard let resolvedUserId else { return }

        do {
            currentUser = try await service.fetchProfile(userId: resolvedUserId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runAuthAction(_ action: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil

        do {
            try await action()
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }

        isLoading = false
    }

    private func openOAuthURL(_ url: URL) async throws {
        #if canImport(UIKit)
        let opened = await UIApplication.shared.open(url)
        guard opened else {
            throw AppError.custom("No se pudo abrir Google. Prueba en un simulador o dispositivo real, no en Preview.")
        }
        #else
        throw AppError.custom("Google Sign-In solo esta disponible en iOS.")
        #endif
    }
}


private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
