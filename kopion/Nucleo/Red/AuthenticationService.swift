//
//  AuthenticationService.swift
//  kopion / Nucleo / Red
//
//  Adaptador entre el módulo AccesoLogin y AuthManager.
//  Traduce los perfiles de UI (CustomerLoginProfile, StaffLoginProfile)
//  a las llamadas de AuthManager con Firebase Auth + Firestore.
//

import Foundation

// MARK: - Errores de validación local

/// Errores de validación que se detectan antes de llamar a Firebase.
enum ErrorAutenticacion: Error, LocalizedError, Equatable {
    case correoInvalido
    case contrasenaCorta
    case rolNoAutorizado

    var errorDescription: String? {
        switch self {
        case .correoInvalido:
            return "Escribe un correo válido."
        case .contrasenaCorta:
            return "La contraseña debe tener al menos 6 caracteres."
        case .rolNoAutorizado:
            return "Tu cuenta no tiene permisos para este acceso."
        }
    }
}

// MARK: - Protocolo

/// Contrato del servicio de autenticación.
/// Permite sustituir la implementación real por mocks en pruebas unitarias.
protocol AuthenticationServicing: Sendable {
    /// Error del último intento de envío de correo de verificación. nil = sin error.
    var errorVerificacionCorreo: Error? { get }

    func iniciarSesionCliente(perfil: CustomerLoginProfile, contrasena: String) async throws -> AuthSession
    func registrarCliente(perfil: CustomerLoginProfile, contrasena: String, escuela: UserProfileEscuela, sucursal: UserProfileBranch) async throws -> AuthSession
    func iniciarSesionPersonal(perfil: StaffLoginProfile, contrasena: String) async throws -> AuthSession
    func registrarSolicitudPersonal(perfil: StaffLoginProfile, contrasena: String) async throws -> AuthSession
    func iniciarSesionConGoogle(rol: UserProfileRole, sucursal: UserProfileBranch) async throws -> AuthSession
    func enviarCorreoRestablecimiento(a correo: String) async throws
}

// MARK: - Implementación real

/// Implementación real que delega todas las operaciones a AuthManager con Firebase.
struct AuthenticationService: AuthenticationServicing {

    /// Refleja el error de verificación que AuthManager capturó sin interrumpir el registro.
    var errorVerificacionCorreo: Error? {
        AuthManager.shared.errorVerificacionCorreo
    }

    /// Inicia sesión de cliente existente y recupera su perfil desde Firestore.
    func iniciarSesionCliente(perfil: CustomerLoginProfile, contrasena: String) async throws -> AuthSession {
        let perfilUsuario = try await AuthManager.shared.iniciarSesion(
            correo: perfil.email,
            contrasena: contrasena
        )
        return perfilUsuario.sesionAutenticada
    }

    /// Crea cuenta de cliente en Firebase Auth, guarda /users/{uid} con escuela y sucursal derivada, y envía correo de verificación.
    func registrarCliente(perfil: CustomerLoginProfile, contrasena: String, escuela: UserProfileEscuela, sucursal: UserProfileBranch) async throws -> AuthSession {
        let perfilUsuario = try await AuthManager.shared.registrar(
            correo:     perfil.email,
            contrasena: contrasena,
            nombre:     perfil.firstName,
            apellidos:  perfil.lastName,
            rol:        .cliente,
            sucursal:   sucursal,
            escuela:    escuela
        )
        return perfilUsuario.sesionAutenticada
    }

    /// Inicia sesión de personal (colaborador, editor, administrador) y recupera su perfil de Firestore.
    func iniciarSesionPersonal(perfil: StaffLoginProfile, contrasena: String) async throws -> AuthSession {
        let perfilUsuario = try await AuthManager.shared.iniciarSesion(
            correo: perfil.email,
            contrasena: contrasena
        )
        return perfilUsuario.sesionAutenticada
    }

    /// Registra una solicitud de cuenta de sucursal como Colaborador y envía correo de verificación.
    /// La dueña puede cambiar el rol desde el panel de administración después de verificar al empleado.
    func registrarSolicitudPersonal(perfil: StaffLoginProfile, contrasena: String) async throws -> AuthSession {
        let perfilUsuario = try await AuthManager.shared.registrar(
            correo:    perfil.email,
            contrasena: contrasena,
            nombre:    perfil.firstName,
            apellidos: perfil.lastName,
            rol:       .colaborador,
            sucursal:  UserProfileBranch(sucursal: perfil.branch)
        )
        return perfilUsuario.sesionAutenticada
    }

    /// Inicia sesión con Google OAuth y devuelve la sesión con rol y sucursal del perfil de Firestore.
    func iniciarSesionConGoogle(rol: UserProfileRole, sucursal: UserProfileBranch) async throws -> AuthSession {
        let perfilUsuario = try await AuthManager.shared.iniciarSesionConGoogle(
            rol: rol,
            sucursal: sucursal
        )
        return perfilUsuario.sesionAutenticada
    }

    /// Envía un correo de restablecimiento de contraseña al correo indicado.
    func enviarCorreoRestablecimiento(a correo: String) async throws {
        try await AuthManager.shared.enviarCorreoRestablecimiento(correo: correo)
    }
}
