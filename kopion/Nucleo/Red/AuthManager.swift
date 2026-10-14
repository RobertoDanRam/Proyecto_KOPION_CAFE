//
//  AuthManager.swift
//  kopion
//
//  Capa de servicio responsable de Firebase Auth y Firestore.
//  Mantiene la UI lejos de Firebase y expone operaciones async/await limpias.
//

import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Errores propios de la capa de autenticación y perfil.
enum AuthManagerError: Error, LocalizedError, Equatable {
    case missingAuthResult
    case missingUserProfile
    case userProfileNotFound

    var errorDescription: String? {
        switch self {
        case .missingAuthResult:
            return "No fue posible obtener la sesión de Firebase."
        case .missingUserProfile:
            return "El perfil del usuario está incompleto."
        case .userProfileNotFound:
            return "No encontramos el perfil del usuario en la base de datos."
        }
    }
}

/// Contrato para inyectar autenticación real o mocks en ViewModels.
protocol AuthManaging: AnyObject {
    var currentUser: UserProfile? { get }

    func signUp(email: String, password: String, role: UserProfileRole, sucursal: UserProfileBranch) async throws -> UserProfile
    func signIn(email: String, password: String) async throws -> UserProfile
    func signOut() throws
    func sendPasswordReset(email: String) async throws
}

/// Manager central de Firebase Auth + Firestore.
@MainActor
final class AuthManager: ObservableObject, AuthManaging {
    static let shared = AuthManager()

    @Published private(set) var currentUser: UserProfile?

    private let auth: Auth
    private let firestore: Firestore
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init(auth: Auth = Auth.auth(), firestore: Firestore = Firestore.firestore()) {
        self.auth = auth
        self.firestore = firestore
        observeAuthState()
    }

    deinit {
        if let authStateHandle {
            auth.removeStateDidChangeListener(authStateHandle)
        }
    }

    /// Crea usuario en Firebase Auth y después crea /users/{uid} en Firestore.
    func signUp(
        email: String,
        password: String,
        role: UserProfileRole,
        sucursal: UserProfileBranch
    ) async throws -> UserProfile {
        do {
            let result = try await createFirebaseUser(email: email, password: password)
            let profile = UserProfile(
                id: result.user.uid,
                email: email,
                role: role,
                sucursal: sucursal
            )
            try await saveUserProfile(profile)
            currentUser = profile
            return profile
        } catch {
            throw mapFirebaseError(error)
        }
    }

    /// Autentica en Firebase Auth y recupera el documento /users/{uid} para conocer rol y sucursal.
    func signIn(email: String, password: String) async throws -> UserProfile {
        do {
            let result = try await signInFirebaseUser(email: email, password: password)
            let profile = try await fetchUserProfile(uid: result.user.uid)
            currentUser = profile
            return profile
        } catch {
            throw mapFirebaseError(error)
        }
    }

    /// Cierra sesión local y Firebase Auth.
    func signOut() throws {
        do {
            try auth.signOut()
            currentUser = nil
        } catch {
            throw mapFirebaseError(error)
        }
    }

    /// Envía correo real de recuperación de contraseña desde Firebase Auth.
    func sendPasswordReset(email: String) async throws {
        do {
            try await withCheckedThrowingContinuation { continuation in
                auth.sendPasswordReset(withEmail: email) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        } catch {
            throw mapFirebaseError(error)
        }
    }

    /// Escucha cambios de sesión y refresca el perfil si Firebase restaura usuario al abrir la app.
    private func observeAuthState() {
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self else { return }

            Task { @MainActor in
                guard let uid = firebaseUser?.uid else {
                    self.currentUser = nil
                    return
                }

                self.currentUser = try? await self.fetchUserProfile(uid: uid)
            }
        }
    }

    private func createFirebaseUser(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            auth.createUser(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthManagerError.missingAuthResult)
                }
            }
        }
    }

    private func signInFirebaseUser(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            auth.signIn(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthManagerError.missingAuthResult)
                }
            }
        }
    }

    private func saveUserProfile(_ profile: UserProfile) async throws {
        try await withCheckedThrowingContinuation { continuation in
            firestore.collection("users").document(profile.id).setData(profile.firestoreData) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func fetchUserProfile(uid: String) async throws -> UserProfile {
        let snapshot = try await withCheckedThrowingContinuation { continuation in
            firestore.collection("users").document(uid).getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: AuthManagerError.userProfileNotFound)
                }
            }
        }

        guard snapshot.exists, let data = snapshot.data() else {
            throw AuthManagerError.userProfileNotFound
        }

        return try UserProfile(id: snapshot.documentID, data: data)
    }

    /// Traduce errores frecuentes de Firebase Auth a mensajes claros para la UI.
    private func mapFirebaseError(_ error: Error) -> Error {
        if let authManagerError = error as? AuthManagerError {
            return authManagerError
        }

        let nsError = error as NSError
        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            return error
        }

        switch code {
        case .emailAlreadyInUse:
            return AuthenticationErrorMessage("Ese correo ya está registrado.")
        case .weakPassword:
            return AuthenticationErrorMessage("La contraseña es muy débil. Usa al menos 6 caracteres.")
        case .invalidEmail:
            return AuthenticationErrorMessage("Escribe un correo válido.")
        case .wrongPassword, .userNotFound, .invalidCredential:
            return AuthenticationErrorMessage("Correo o contraseña incorrectos.")
        case .networkError:
            return AuthenticationErrorMessage("No hay conexión. Inténtalo de nuevo.")
        case .tooManyRequests:
            return AuthenticationErrorMessage("Demasiados intentos. Espera unos minutos.")
        default:
            return AuthenticationErrorMessage(nsError.localizedDescription)
        }
    }
}

/// Error simple con mensaje localizado para presentar directamente en la UI.
struct AuthenticationErrorMessage: Error, LocalizedError, Equatable {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
