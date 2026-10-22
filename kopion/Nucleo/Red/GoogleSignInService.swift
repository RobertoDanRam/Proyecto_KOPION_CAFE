//
//  GoogleSignInService.swift
//  kopion / Nucleo / Red
//
//  Maneja el flujo completo de inicio de sesión con Google:
//  1. Presenta la pantalla nativa de selección de cuenta de Google.
//  2. Obtiene el idToken y accessToken de Google.
//  3. Los intercambia por una credencial de Firebase Auth.
//  4. Crea o recupera el perfil del usuario en Firestore /users/{uid}.
//
//  Requisitos previos:
//  - SDK GoogleSignIn agregado vía SPM: https://github.com/google/GoogleSignIn-iOS
//  - GoogleService-Info.plist con CLIENT_ID y REVERSED_CLIENT_ID presentes.
//  - URL Scheme en Info.plist con el valor de REVERSED_CLIENT_ID.
//  - En kopionApp.swift: GIDSignIn.sharedInstance.handle(url) dentro de onOpenURL.
//

import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import GoogleSignIn

// MARK: - Resultado del flujo

/// Resultado del flujo de Google Sign-In listo para consumir en el ViewModel.
struct ResultadoGoogleSignIn {
    /// Perfil del usuario creado o recuperado de Firestore.
    let perfil: UserProfile
    /// true = cuenta nueva creada en esta sesión, false = usuario existente.
    let esUsuarioNuevo: Bool
}

// MARK: - Servicio

/// Servicio que encapsula Google Sign-In + Firebase Auth + Firestore.
/// @MainActor garantiza que la presentación del sheet de Google ocurra en el hilo principal.
@MainActor
final class GoogleSignInService {

    /// Instancia compartida para toda la app.
    static let shared = GoogleSignInService()

    private let auth: Auth
    private let firestore: Firestore

    init(auth: Auth = Auth.auth(), firestore: Firestore = Firestore.firestore()) {
        self.auth      = auth
        self.firestore = firestore
    }

    // MARK: - Flujo principal

    /// Presenta la pantalla de selección de cuenta de Google, obtiene la credencial
    /// de Firebase y crea o recupera el perfil del usuario en Firestore.
    func iniciarSesion(
        rol: UserProfileRole = .cliente,
        sucursal: UserProfileBranch = .ningunaCliente
    ) async throws -> ResultadoGoogleSignIn {

        // Paso 1: Obtener el UIViewController activo para presentar el sheet de Google.
        guard let controladorRaiz = obtenerControladorRaiz() else {
            throw ErrorGoogleSignIn.sinControladorRaiz
        }

        // Paso 2: Leer el clientID desde GoogleService-Info.plist vía FirebaseApp.
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw ErrorGoogleSignIn.clientIDFaltante
        }

        // Paso 3: Configurar el SDK de Google con el clientID del proyecto.
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        // Paso 4: Presentar la pantalla de selección de cuenta de Google.
        let resultadoGoogle = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<GIDSignInResult, Error>) in
            GIDSignIn.sharedInstance.signIn(withPresenting: controladorRaiz) { resultado, error in
                if let error     { cont.resume(throwing: error) }
                else if let resultado { cont.resume(returning: resultado) }
                else             { cont.resume(throwing: ErrorGoogleSignIn.tokensFaltantes) }
            }
        }

        // Paso 5: Extraer el idToken de Google (requerido por Firebase).
        guard let idToken = resultadoGoogle.user.idToken?.tokenString else {
            throw ErrorGoogleSignIn.tokensFaltantes
        }
        let tokenAcceso = resultadoGoogle.user.accessToken.tokenString

        // Paso 6: Crear la credencial de Firebase con los tokens de Google.
        let credencial = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: tokenAcceso
        )

        // Paso 7: Autenticar en Firebase Auth con la credencial de Google.
        let resultadoFirebase = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<AuthDataResult, Error>) in
            self.auth.signIn(with: credencial) { resultado, error in
                if let error     { cont.resume(throwing: error) }
                else if let resultado { cont.resume(returning: resultado) }
                else             { cont.resume(throwing: ErrorGoogleSignIn.autenticacionFallida) }
            }
        }

        let uid           = resultadoFirebase.user.uid
        let correo        = resultadoFirebase.user.email ?? resultadoGoogle.user.profile?.email ?? ""
        let esNuevo       = resultadoFirebase.additionalUserInfo?.isNewUser ?? false
        let nombreGoogle  = resultadoGoogle.user.profile?.givenName ?? ""
        let apellidoGoogle = resultadoGoogle.user.profile?.familyName ?? ""

        // Paso 8: Crear o recuperar el perfil en Firestore.
        let perfil: UserProfile
        if esNuevo {
            // Usuario nuevo: crear documento con los datos de Google.
            perfil = UserProfile(
                id:        uid,
                correo:    correo,
                nombre:    nombreGoogle,
                apellidos: apellidoGoogle,
                rol:       rol,
                sucursal:  sucursal
            )
            try await guardarPerfil(perfil)
        } else {
            // Usuario existente: recuperar perfil de Firestore para obtener rol y sucursal reales.
            if let existente = try? await obtenerPerfil(uid: uid) {
                perfil = existente
            } else {
                // Perfil no encontrado en Firestore (caso raro): crearlo con datos de Google.
                perfil = UserProfile(
                    id:        uid,
                    correo:    correo,
                    nombre:    nombreGoogle,
                    apellidos: apellidoGoogle,
                    rol:       rol,
                    sucursal:  sucursal
                )
                try await guardarPerfil(perfil)
            }
        }

        return ResultadoGoogleSignIn(perfil: perfil, esUsuarioNuevo: esNuevo)
    }

    /// Cierra la sesión de Google y de Firebase Auth.
    func cerrarSesion() throws {
        GIDSignIn.sharedInstance.signOut()
        try auth.signOut()
    }

    // MARK: - Helpers privados

    /// Obtiene el UIViewController raíz activo para presentar el sheet de Google.
    private func obtenerControladorRaiz() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
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
            firestore.collection("users").document(uid).getDocument { doc, error in
                if let error { cont.resume(throwing: error) }
                else if let doc { cont.resume(returning: doc) }
                else { cont.resume(throwing: ErrorGoogleSignIn.perfilNoEncontrado) }
            }
        }

        guard documento.exists, let datos = documento.data() else {
            throw ErrorGoogleSignIn.perfilNoEncontrado
        }

        return try UserProfile(id: documento.documentID, datos: datos)
    }
}

// MARK: - Errores

/// Errores específicos del flujo de Google Sign-In con mensajes en español.
enum ErrorGoogleSignIn: Error, LocalizedError {
    case sinControladorRaiz
    case clientIDFaltante
    case tokensFaltantes
    case autenticacionFallida
    case perfilNoEncontrado
    case cancelado

    var errorDescription: String? {
        switch self {
        case .sinControladorRaiz:
            return "No se pudo presentar la pantalla de Google."
        case .clientIDFaltante:
            return "CLIENT_ID no encontrado en GoogleService-Info.plist. Descarga el plist actualizado desde Firebase Console."
        case .tokensFaltantes:
            return "Google no devolvió los tokens necesarios. Inténtalo de nuevo."
        case .autenticacionFallida:
            return "No se pudo autenticar con Firebase usando la cuenta de Google."
        case .perfilNoEncontrado:
            return "No se encontró el perfil del usuario en la base de datos."
        case .cancelado:
            return "Inicio de sesión cancelado."
        }
    }
}
