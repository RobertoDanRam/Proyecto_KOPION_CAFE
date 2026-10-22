//
//  AuthViewModel.swift
//  kopion
//
//  ViewModel reutilizable para pantallas de autenticación.
//  Consume AuthManager con async/await y expone estado de UI seguro para SwiftUI.
//

import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var usuarioActual: UserProfile?
    @Published var estaCargando = false
    @Published var mensajeError: String?

    private let gestorAuth: AuthManaging

    convenience init() {
        self.init(gestorAuth: AuthManager.shared)
    }

    init(gestorAuth: AuthManaging) {
        self.gestorAuth = gestorAuth
        self.usuarioActual = gestorAuth.usuarioActual
    }

    /// Registra usuario en Firebase Auth y guarda su perfil en Firestore /users/{uid}.
    func registrar(
        correo: String,
        contrasena: String,
        nombre: String,
        apellidos: String,
        rol: UserProfileRole,
        sucursal: UserProfileBranch,
        escuela: UserProfileEscuela? = nil
    ) async -> UserProfile? {
        guard !estaCargando else { return nil }
        estaCargando = true
        mensajeError = nil
        defer { estaCargando = false }

        do {
            let perfil = try await gestorAuth.registrar(
                correo: correo,
                contrasena: contrasena,
                nombre: nombre,
                apellidos: apellidos,
                rol: rol,
                sucursal: sucursal,
                escuela: escuela
            )
            usuarioActual = perfil
            return perfil
        } catch {
            mensajeError = Self.mensajeAmigable(para: error)
            return nil
        }
    }

    /// Inicia sesión y recupera el perfil Firestore para conocer rol y sucursal.
    func iniciarSesion(correo: String, contrasena: String) async -> UserProfile? {
        guard !estaCargando else { return nil }
        estaCargando = true
        mensajeError = nil
        defer { estaCargando = false }

        do {
            let perfil = try await gestorAuth.iniciarSesion(correo: correo, contrasena: contrasena)
            usuarioActual = perfil
            return perfil
        } catch {
            mensajeError = Self.mensajeAmigable(para: error)
            return nil
        }
    }

    /// Cierra sesión en Firebase Auth.
    func cerrarSesion() {
        do {
            try gestorAuth.cerrarSesion()
            usuarioActual = nil
        } catch {
            mensajeError = Self.mensajeAmigable(para: error)
        }
    }

    /// Solicita correo de recuperación de contraseña.
    func enviarCorreoRestablecimiento(correo: String) async -> Bool {
        guard !estaCargando else { return false }
        estaCargando = true
        mensajeError = nil
        defer { estaCargando = false }

        do {
            try await gestorAuth.enviarCorreoRestablecimiento(correo: correo)
            return true
        } catch {
            mensajeError = Self.mensajeAmigable(para: error)
            return false
        }
    }

    /// Mensaje final en español para cualquier error que llegue a la interfaz.
    static func mensajeAmigable(para error: Error) -> String {
        if let localizado = error as? LocalizedError,
           let descripcion = localizado.errorDescription {
            return descripcion
        }
        return "Ocurrió un error inesperado. Inténtalo de nuevo."
    }
}
