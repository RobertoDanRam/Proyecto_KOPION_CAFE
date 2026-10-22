//
//  AuthManager.swift
//  kopion
//
//  Capa central de autenticación: Firebase Auth + Firestore.
//  Mantiene la UI completamente separada de Firebase y expone
//  operaciones limpias con async/await en español.
//

import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

// MARK: - Errores de autenticación

/// Errores propios de la capa de autenticación y perfil de usuario.
enum AuthManagerError: Error, LocalizedError, Equatable {
    case sinResultadoDeFirebase
    case perfilIncompleto
    case perfilNoEncontrado

    var errorDescription: String? {
        switch self {
        case .sinResultadoDeFirebase:
            return "No fue posible obtener la sesión de Firebase."
        case .perfilIncompleto:
            return "El perfil del usuario está incompleto."
        case .perfilNoEncontrado:
            return "No encontramos el perfil del usuario en la base de datos."
        }
    }
}

/// Error con mensaje personalizado para mostrar directamente en la UI.
struct MensajeDeError: Error, LocalizedError, Equatable {
    let mensaje: String

    init(_ mensaje: String) {
        self.mensaje = mensaje
    }

    var errorDescription: String? { mensaje }
}

// MARK: - Protocolo

/// Contrato que permite inyectar autenticación real o mocks en los ViewModels.
protocol AuthManaging: AnyObject {
    /// Usuario autenticado actualmente. nil = sin sesión activa.
    var usuarioActual: UserProfile? { get }

    /// Error del último intento de envío de correo de verificación.
    /// nil = sin error o no intentado aún.
    var errorVerificacionCorreo: Error? { get }

    func registrar(correo: String, contrasena: String, nombre: String, apellidos: String, rol: UserProfileRole, sucursal: UserProfileBranch, escuela: UserProfileEscuela?) async throws -> UserProfile
    func iniciarSesion(correo: String, contrasena: String) async throws -> UserProfile
    func iniciarSesionConGoogle(rol: UserProfileRole, sucursal: UserProfileBranch) async throws -> UserProfile
    func cerrarSesion() throws
    func enviarCorreoRestablecimiento(correo: String) async throws
    func enviarVerificacionCorreo() async throws
}

// MARK: - Implementación

/// Manager central de Firebase Auth + Firestore.
/// @MainActor garantiza que todas las actualizaciones de @Published ocurran en el hilo principal.
@MainActor
final class AuthManager: ObservableObject, AuthManaging {

    /// Instancia compartida para toda la app.
    static let shared = AuthManager()

    /// Usuario autenticado actualmente. SwiftUI observa este valor para navegar automáticamente.
    @Published private(set) var usuarioActual: UserProfile?

    /// Error del último intento de envío de correo de verificación.
    private(set) var errorVerificacionCorreo: Error?

    private let auth: Auth
    private let firestore: Firestore

    /// Referencia al listener de estado de sesión para poder cancelarlo en deinit.
    private var manejadorEstadoAuth: AuthStateDidChangeListenerHandle?

    init(auth: Auth = Auth.auth(), firestore: Firestore = Firestore.firestore()) {
        self.auth      = auth
        self.firestore = firestore
        observarEstadoDeSesion()
    }

    deinit {
        if let manejadorEstadoAuth {
            auth.removeStateDidChangeListener(manejadorEstadoAuth)
        }
    }

    // MARK: - Registro

    /// Crea un usuario en Firebase Auth, guarda su perfil en Firestore /users/{uid}
    /// y envía el correo de verificación.
    /// El envío del correo NO bloquea el registro: si falla, se guarda en errorVerificacionCorreo
    /// para que la UI lo muestre sin impedir que el usuario entre a la app.
    func registrar(
        correo: String,
        contrasena: String,
        nombre: String,
        apellidos: String,
        rol: UserProfileRole,
        sucursal: UserProfileBranch,
        escuela: UserProfileEscuela? = nil
    ) async throws -> UserProfile {
        do {
            let resultado = try await crearUsuarioFirebase(correo: correo, contrasena: contrasena)

            let perfil = UserProfile(
                id:        resultado.user.uid,
                correo:    correo,
                nombre:    nombre,
                apellidos: apellidos,
                rol:       rol,
                sucursal:  sucursal,
                escuela:   escuela
            )
            try await guardarPerfil(perfil)

            // Paso 3: Intentar enviar correo de verificación.
            // Si falla, la cuenta ya existe y el usuario puede reenviar después.
            do {
                try await enviarVerificacionCorreo()
            } catch {
                errorVerificacionCorreo = traducirErrorFirebase(error)
            }

            usuarioActual = perfil
            return perfil
        } catch {
            throw traducirErrorFirebase(error)
        }
    }

    // MARK: - Inicio de sesión con correo

    /// Autentica con correo y contraseña, luego recupera el perfil de Firestore
    /// para conocer el rol y la sucursal reales del usuario.
    func iniciarSesion(correo: String, contrasena: String) async throws -> UserProfile {
        do {
            let resultado = try await autenticarUsuarioFirebase(correo: correo, contrasena: contrasena)
            let perfil    = try await obtenerPerfil(uid: resultado.user.uid)
            usuarioActual = perfil
            return perfil
        } catch {
            throw traducirErrorFirebase(error)
        }
    }

    // MARK: - Inicio de sesión con Google

    /// Inicia sesión con Google OAuth delegando el flujo a GoogleSignInService.
    /// Actualiza usuarioActual con el perfil resultante de Firestore.
    func iniciarSesionConGoogle(
        rol: UserProfileRole = .cliente,
        sucursal: UserProfileBranch = .ningunaCliente
    ) async throws -> UserProfile {
        do {
            let resultado = try await GoogleSignInService.shared.iniciarSesion(rol: rol, sucursal: sucursal)
            usuarioActual = resultado.perfil
            return resultado.perfil
        } catch let error as ErrorGoogleSignIn {
            // Cancelación silenciosa: el usuario cerró el sheet sin elegir cuenta.
            if case .cancelado = error { throw error }
            throw MensajeDeError(error.localizedDescription)
        } catch {
            throw traducirErrorFirebase(error)
        }
    }

    // MARK: - Cierre de sesión

    /// Cierra la sesión en Firebase Auth y limpia el usuario local.
    func cerrarSesion() throws {
        do {
            try auth.signOut()
            usuarioActual = nil
        } catch {
            throw traducirErrorFirebase(error)
        }
    }

    // MARK: - Correo de restablecimiento

    /// Envía un correo de restablecimiento de contraseña al correo indicado.
    func enviarCorreoRestablecimiento(correo: String) async throws {
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                auth.sendPasswordReset(withEmail: correo) { error in
                    if let error { cont.resume(throwing: error) }
                    else         { cont.resume(returning: ()) }
                }
            }
        } catch {
            throw traducirErrorFirebase(error)
        }
    }

    // MARK: - Verificación de correo

    /// Envía el enlace de verificación al correo del usuario autenticado actualmente.
    func enviarVerificacionCorreo() async throws {
        guard let usuarioFirebase = auth.currentUser else {
            throw AuthManagerError.sinResultadoDeFirebase
        }

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                usuarioFirebase.sendEmailVerification { error in
                    if let error { cont.resume(throwing: error) }
                    else         { cont.resume(returning: ()) }
                }
            }
        } catch {
            throw traducirErrorFirebase(error)
        }
    }

    // MARK: - Observador de estado de sesión

    /// Escucha cambios de sesión de Firebase.
    /// Cuando la app se abre y Firebase restaura una sesión previa,
    /// este listener recupera el perfil de Firestore automáticamente.
    private func observarEstadoDeSesion() {
        manejadorEstadoAuth = auth.addStateDidChangeListener { [weak self] _, usuarioFirebase in
            guard let self else { return }

            Task { @MainActor in
                guard let uid = usuarioFirebase?.uid else {
                    self.usuarioActual = nil
                    return
                }
                self.usuarioActual = try? await self.obtenerPerfil(uid: uid)
            }
        }
    }

    // MARK: - Helpers privados de Firebase

    /// Crea un usuario nuevo en Firebase Auth con correo y contraseña.
    private func crearUsuarioFirebase(correo: String, contrasena: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { cont in
            auth.createUser(withEmail: correo, password: contrasena) { resultado, error in
                if let error     { cont.resume(throwing: error) }
                else if let resultado { cont.resume(returning: resultado) }
                else             { cont.resume(throwing: AuthManagerError.sinResultadoDeFirebase) }
            }
        }
    }

    /// Autentica un usuario existente en Firebase Auth con correo y contraseña.
    private func autenticarUsuarioFirebase(correo: String, contrasena: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { cont in
            auth.signIn(withEmail: correo, password: contrasena) { resultado, error in
                if let error     { cont.resume(throwing: error) }
                else if let resultado { cont.resume(returning: resultado) }
                else             { cont.resume(throwing: AuthManagerError.sinResultadoDeFirebase) }
            }
        }
    }

    /// Guarda el perfil del usuario en Firestore en la colección "users".
    private func guardarPerfil(_ perfil: UserProfile) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            firestore.collection("users").document(perfil.id).setData(perfil.datosFirestore) { error in
                if let error { cont.resume(throwing: error) }
                else         { cont.resume(returning: ()) }
            }
        }
    }

    /// Recupera el perfil del usuario desde Firestore usando su UID.
    private func obtenerPerfil(uid: String) async throws -> UserProfile {
        let documento: DocumentSnapshot = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<DocumentSnapshot, Error>) in
            firestore.collection("users").document(uid).getDocument { documento, error in
                if let error        { cont.resume(throwing: error) }
                else if let documento { cont.resume(returning: documento) }
                else                { cont.resume(throwing: AuthManagerError.perfilNoEncontrado) }
            }
        }

        guard documento.exists, let datos = documento.data() else {
            throw AuthManagerError.perfilNoEncontrado
        }

        return try UserProfile(id: documento.documentID, datos: datos)
    }

    // MARK: - Traducción de errores de Firebase

    /// Convierte errores de Firebase Auth a mensajes en español con código técnico para diagnóstico.
    private func traducirErrorFirebase(_ error: Error) -> Error {
        // Si ya es un error propio, lo devolvemos sin envolver.
        if let propio = error as? AuthManagerError  { return propio }
        if let propio = error as? MensajeDeError    { return propio }

        let nsError = error as NSError
        let sufijo  = " [Firebase \(nsError.code)]"

        guard let codigo = AuthErrorCode(rawValue: nsError.code) else {
            return MensajeDeError(nsError.localizedDescription + sufijo)
        }

        switch codigo {
        case .emailAlreadyInUse:
            return MensajeDeError("Ese correo ya está registrado." + sufijo)
        case .weakPassword:
            return MensajeDeError("La contraseña es muy débil. Usa al menos 6 caracteres." + sufijo)
        case .invalidEmail:
            return MensajeDeError("Escribe un correo válido." + sufijo)
        case .wrongPassword, .userNotFound, .invalidCredential:
            return MensajeDeError("Correo o contraseña incorrectos." + sufijo)
        case .networkError:
            return MensajeDeError("Sin conexión a internet. Inténtalo de nuevo." + sufijo)
        case .tooManyRequests:
            return MensajeDeError("Demasiados intentos. Espera unos minutos." + sufijo)
        case .operationNotAllowed:
            return MensajeDeError(
                "El proveedor Email/Contraseña no está habilitado. " +
                "Ve a Firebase Console → Authentication → Método de acceso y actívalo." + sufijo
            )
        default:
            return MensajeDeError(nsError.localizedDescription + sufijo)
        }
    }
}
