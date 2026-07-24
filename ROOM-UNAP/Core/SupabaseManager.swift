import Foundation
#if canImport(UIKit)
import UIKit
#endif
import Supabase

struct SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://mucdgyesawxmnnitwfaq.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im11Y2RneWVzYXd4bW5uaXR3ZmFxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyNTc3MDEsImV4cCI6MjA5MjgzMzcwMX0.SO-X-4DNFCdp1GdnKztQEc6aQIgRA_tnHno4fSCbSDQ"
        )
    }
}

enum AppError: LocalizedError {
    case invalidCredentials
    case passwordMismatch
    case missingSession
    case missingImageData
    case profileUnavailable
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Revisa tu correo y contrasena."
        case .passwordMismatch:
            return "Las contrasenas no coinciden."
        case .missingSession:
            return "No hay una sesion activa."
        case .missingImageData:
            return "No se pudo leer la imagen seleccionada."
        case .profileUnavailable:
            return "No se pudo cargar tu perfil."
        case .custom(let message):
            return message
        }
    }
}

struct Haptics {
    static func success() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    static func error() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}
