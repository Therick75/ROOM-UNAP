import Foundation
import AuthenticationServices
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
    private let webAuthenticationSession = OAuthWebAuthenticationSession()
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
            let session = try await self.client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "roomunap://login-callback"),
                queryParams: [
                    (name: "prompt", value: "select_account")
                ]
            ) { url in
                try await self.webAuthenticationSession.authenticate(
                    url: url,
                    callbackURLScheme: "roomunap",
                    prefersEphemeralWebBrowserSession: true
                )
            }
            self.session = session
            self.isAuthenticated = true
            await self.loadProfile(userId: session.user.id.uuidString)
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

}

private enum OAuthPresentationError: LocalizedError {
    case alreadyInProgress
    case couldNotStart

    var errorDescription: String? {
        switch self {
        case .alreadyInProgress:
            return "Ya hay un inicio de sesion con Google en curso."
        case .couldNotStart:
            return "No se pudo abrir Google. Prueba en un simulador o dispositivo real, no en Preview."
        }
    }
}

@MainActor
private final class OAuthWebAuthenticationSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var activeSession: ASWebAuthenticationSession?

    func authenticate(url: URL, callbackURLScheme: String, prefersEphemeralWebBrowserSession: Bool) async throws -> URL {
        guard activeSession == nil else { throw OAuthPresentationError.alreadyInProgress }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme) { [weak self] callbackURL, error in
                Task { @MainActor in
                    self?.activeSession = nil

                    if let error {
                        continuation.resume(throwing: error)
                    } else if let callbackURL {
                        continuation.resume(returning: callbackURL)
                    } else {
                        continuation.resume(throwing: OAuthPresentationError.couldNotStart)
                    }
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
            activeSession = session

            if !session.start() {
                activeSession = nil
                continuation.resume(throwing: OAuthPresentationError.couldNotStart)
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return window
        }
        if let scene = scenes.first {
            return ASPresentationAnchor(windowScene: scene)
        }
        #endif

        return ASPresentationAnchor()
    }
}


private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
