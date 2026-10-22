//
//  UserProfile.swift
//  kopion
//
//  Perfil de usuario persistido en Firestore.
//  El documento vive en la colección "users" y usa como ID el UID generado por Firebase Auth.
//  Cada campo tiene su equivalente en español tanto en código como en Firestore.
//

import Foundation

/// Rol persistido en Firestore para controlar navegación y permisos por pantalla.
enum UserProfileRole: String, CaseIterable, Codable, Sendable {
    case administrador = "Administrador"
    case editor        = "Editor"
    case colaborador   = "Colaborador"
    case cliente       = "Cliente"

    /// Convierte el rol de Firestore al rol interno de la app usado en permisos de UI.
    var rolApp: UserRole {
        switch self {
        case .administrador: return .administrator
        case .editor:        return .editor
        case .colaborador:   return .collaborator
        case .cliente:       return .customer
        }
    }

    /// Inicializa desde el rol interno de la app hacia el rol de Firestore.
    init(rolApp: UserRole) {
        switch rolApp {
        case .administrator: self = .administrador
        case .editor:        self = .editor
        case .collaborator:  self = .colaborador
        case .customer:      self = .cliente
        }
    }
}

/// Escuela persistida en Firestore para clientes. Determina la sucursal operativa asignada.
enum UserProfileEscuela: String, CaseIterable, Codable, Sendable {
    case escaSantoTomas = "ESCA Santo Tomás"
    case cecyt1         = "CECyT 1"
    case ese            = "ESE"

    /// Convierte desde el enum de negocio School.
    init(escuela: School) {
        switch escuela {
        case .escaSantoTomas: self = .escaSantoTomas
        case .cecyt1:         self = .cecyt1
        case .ese:            self = .ese
        }
    }

    /// Sucursal operativa que corresponde a esta escuela.
    var sucursalAsociada: UserProfileBranch {
        switch self {
        case .escaSantoTomas: return .kopionESCA
        case .cecyt1:         return .kopionCECyT1
        case .ese:            return .eseCafe
        }
    }
}

/// Sucursal persistida en Firestore. El cliente puede quedar sin sucursal operativa fija.
enum UserProfileBranch: String, CaseIterable, Codable, Sendable {
    case kopionESCA    = "Kopion ESCA"
    case kopionCECyT1  = "Kopion CECyT 1"
    case eseCafe       = "ESE Café"
    case ningunaCliente = "Ninguna/Cliente"

    /// Convierte la sucursal de Firestore a la sucursal interna de la app.
    var sucursalApp: Branch? {
        switch self {
        case .kopionESCA:     return .kopionESCA
        case .kopionCECyT1:   return .kopionCECyT1
        case .eseCafe:        return .cafeESE
        case .ningunaCliente: return nil
        }
    }

    /// Inicializa desde la sucursal interna de la app hacia la sucursal de Firestore.
    init(sucursal: Branch?) {
        switch sucursal {
        case .kopionESCA:  self = .kopionESCA
        case .kopionCECyT1: self = .kopionCECyT1
        case .cafeESE:     self = .eseCafe
        case nil:          self = .ningunaCliente
        }
    }
}

/// Modelo que representa el documento /users/{uid} en Firestore.
/// Se usa en toda la app para controlar navegación, permisos y datos del usuario.
struct UserProfile: Identifiable, Codable, Hashable, Sendable {
    /// UID generado por Firebase Auth. Es la llave primaria del documento en Firestore.
    let id: String
    var correo: String
    var nombre: String
    var apellidos: String
    var rol: UserProfileRole
    var sucursal: UserProfileBranch
    /// Escuela del cliente. nil para personal de sucursal.
    var escuela: UserProfileEscuela?

    /// Nombre completo para mostrar en encabezados y saludos de la UI.
    /// Si nombre y apellidos están vacíos, muestra el correo como respaldo.
    var nombreCompleto: String {
        let completo = "\(nombre) \(apellidos)".trimmingCharacters(in: .whitespaces)
        return completo.isEmpty ? correo : completo
    }

    /// Diccionario explícito para escribir en Firestore.
    /// No depende de FirebaseFirestoreSwift para mantener compatibilidad con cualquier versión del SDK.
    var datosFirestore: [String: Any] {
        var datos: [String: Any] = [
            "id":        id,
            "correo":    correo,
            "nombre":    nombre,
            "apellidos": apellidos,
            "rol":       rol.rawValue,
            "sucursal":  sucursal.rawValue
        ]
        if let escuela { datos["escuela"] = escuela.rawValue }
        return datos
    }

    /// Inicializa el perfil desde los datos crudos de un documento de Firestore.
    /// Lanza AuthManagerError.perfilIncompleto si faltan campos obligatorios.
    init(id: String, datos: [String: Any]) throws {
        guard
            let correo   = datos["correo"] as? String,
            let rolValor = datos["rol"] as? String,
            let rol      = UserProfileRole(rawValue: rolValor),
            let sucursalValor = datos["sucursal"] as? String,
            let sucursal = UserProfileBranch(rawValue: sucursalValor)
        else {
            throw AuthManagerError.perfilIncompleto
        }

        self.id        = id
        self.correo    = correo
        self.nombre    = datos["nombre"] as? String ?? ""
        self.apellidos = datos["apellidos"] as? String ?? ""
        self.rol       = rol
        self.sucursal  = sucursal
        // Campo opcional: solo clientes lo tienen.
        if let escuelaValor = datos["escuela"] as? String {
            self.escuela = UserProfileEscuela(rawValue: escuelaValor)
        } else {
            self.escuela = nil
        }
    }

    /// Inicializador directo para crear perfiles nuevos desde código.
    init(
        id: String,
        correo: String,
        nombre: String = "",
        apellidos: String = "",
        rol: UserProfileRole,
        sucursal: UserProfileBranch,
        escuela: UserProfileEscuela? = nil
    ) {
        self.id        = id
        self.correo    = correo
        self.nombre    = nombre
        self.apellidos = apellidos
        self.rol       = rol
        self.sucursal  = sucursal
        self.escuela   = escuela
    }

    /// Convierte el perfil de Firestore a la sesión autenticada usada por la UI.
    var sesionAutenticada: AuthSession {
        AuthSession(
            id: UUID(uuidString: id) ?? UUID(),
            email: correo,
            role: rol.rolApp,
            branch: sucursal.sucursalApp,
            school: nil,
            displayName: nombreCompleto,
            authenticatedWithGoogle: true
        )
    }
}
