//
//  AuthViewModel.swift
//  kopion
//
//  ViewModel reusable para pantallas de autenticación.
//  Consume AuthManager con async/await y expone estado de UI seguro para SwiftUI.
//

import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var currentUser: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authManager: AuthManaging

    init(authManager: AuthManaging = AuthManager.shared) {
        self.authManager = authManager
        self.currentUser = authManager.currentUser
    }

    /// Registra usuario en Firebase Auth y guarda su perfil en Firestore /users/{uid}.
    func signUp(
        email: String,
        password: String,
        role: UserProfileRole,
        sucursal: UserProfileBranch
    ) async -> UserProfile? {
        guard !isLoading else { return nil }
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let profile = try await authManager.signUp(
                email: email,
                password: password,
                role: role,
                sucursal: sucursal
            )
            currentUser = profile
            return profile
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
            return nil
        }
    }

    /// Inicia sesión y recupera el perfil Firestore para conocer rol y sucursal.
    func signIn(email: String, password: String) async -> UserProfile? {
        guard !isLoading else { return nil }
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let profile = try await authManager.signIn(email: email, password: password)
            currentUser = profile
            return profile
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
            return nil
        }
    }

    /// Cierra sesión en Firebase Auth.
    func signOut() {
        do {
            try authManager.signOut()
            currentUser = nil
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
        }
    }

    /// Solicita correo de recuperación de contraseña.
    func sendPasswordReset(email: String) async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await authManager.sendPasswordReset(email: email)
            return true
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
            return false
        }
    }

    /// Mensaje final en español para cualquier error que llegue a la interfaz.
    static func friendlyMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }

        return "Ocurrió un error inesperado. Inténtalo de nuevo."
    }
}
