//
//  AuthenticationService.swift
//  kopion
//
//  Adaptador de autenticación consumido por el módulo Acceso Login.
//  Delega login, registro, perfil, verificación por enlace y restablecimiento
//  de contraseña a AuthManager para usar Firebase Auth + Firestore.
//

import Foundation

/// Errores específicos del flujo de autenticación local del módulo.
enum AuthenticationError: Error, LocalizedError, Equatable {
    case invalidEmail
    case invalidPassword
    case unauthorizedRole

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Escribe un correo válido."
        case .invalidPassword:
            return "La contraseña debe tener al menos 6 caracteres."
        case .unauthorizedRole:
            return "Tu cuenta no tiene permisos para este acceso."
        }
    }
}

/// Contrato para cambiar la implementación real por mocks en pruebas.
protocol AuthenticationServicing: Sendable {
    func signInCustomer(profile: CustomerLoginProfile, password: String) async throws -> AuthSession
    func registerCustomer(profile: CustomerLoginProfile, password: String) async throws -> AuthSession
    func signInStaff(profile: StaffLoginProfile, password: String) async throws -> AuthSession
    func registerStaffRequest(profile: StaffLoginProfile, password: String) async throws -> AuthSession
    func sendPasswordReset(to email: String) async throws
}

/// Implementación real respaldada por Firebase.
struct AuthenticationService: AuthenticationServicing {
    /// Inicia sesión de cliente existente y recupera su perfil desde Firestore.
    func signInCustomer(profile: CustomerLoginProfile, password: String) async throws -> AuthSession {
        let userProfile = try await AuthManager.shared.signIn(email: profile.email, password: password)
        return userProfile.authSession
    }

    /// Crea cuenta de cliente en Firebase Auth, guarda /users/{uid} y manda enlace de verificación.
    func registerCustomer(profile: CustomerLoginProfile, password: String) async throws -> AuthSession {
        let userProfile = try await AuthManager.shared.signUp(
            email: profile.email,
            password: password,
            role: .cliente,
            sucursal: .ningunaCliente
        )
        return userProfile.authSession
    }

    /// Inicia sesión de personal y usa Firestore para conocer rol y sucursal reales.
    func signInStaff(profile: StaffLoginProfile, password: String) async throws -> AuthSession {
        let userProfile = try await AuthManager.shared.signIn(email: profile.email, password: password)
        return userProfile.authSession
    }

    /// Registra una solicitud inicial de empleado como Colaborador y manda enlace de verificación.
    func registerStaffRequest(profile: StaffLoginProfile, password: String) async throws -> AuthSession {
        let userProfile = try await AuthManager.shared.signUp(
            email: profile.email,
            password: password,
            role: .colaborador,
            sucursal: UserProfileBranch(branch: profile.branch)
        )
        return userProfile.authSession
    }

    /// Envía correo real de restablecimiento de contraseña mediante Firebase Auth.
    func sendPasswordReset(to email: String) async throws {
        try await AuthManager.shared.sendPasswordReset(email: email)
    }
}
