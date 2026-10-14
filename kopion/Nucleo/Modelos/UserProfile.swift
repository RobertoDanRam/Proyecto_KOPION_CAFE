//
//  UserProfile.swift
//  kopion
//
//  Perfil de usuario persistido en Firestore.
//  El documento vive en la colección "users" y usa como ID el UID generado por Firebase Auth.
//

import Foundation

/// Rol persistido en Firestore para controlar navegación y permisos.
enum UserProfileRole: String, CaseIterable, Codable, Sendable {
    case administrador = "Administrador"
    case editor = "Editor"
    case colaborador = "Colaborador"
    case cliente = "Cliente"

    var appRole: UserRole {
        switch self {
        case .administrador:
            return .administrator
        case .editor:
            return .editor
        case .colaborador:
            return .collaborator
        case .cliente:
            return .customer
        }
    }

    init(appRole: UserRole) {
        switch appRole {
        case .administrator:
            self = .administrador
        case .editor:
            self = .editor
        case .collaborator:
            self = .colaborador
        case .customer:
            self = .cliente
        }
    }
}

/// Sucursal persistida en Firestore. Cliente puede quedar sin sucursal operativa fija.
enum UserProfileBranch: String, CaseIterable, Codable, Sendable {
    case kopionESCA = "Kopion ESCA"
    case kopionCECyT1 = "Kopion CECyT 1"
    case eseCafe = "ESE Café"
    case ningunaCliente = "Ninguna/Cliente"

    var appBranch: Branch? {
        switch self {
        case .kopionESCA:
            return .kopionESCA
        case .kopionCECyT1:
            return .kopionCECyT1
        case .eseCafe:
            return .cafeESE
        case .ningunaCliente:
            return nil
        }
    }

    init(branch: Branch?) {
        switch branch {
        case .kopionESCA:
            self = .kopionESCA
        case .kopionCECyT1:
            self = .kopionCECyT1
        case .cafeESE:
            self = .eseCafe
        case nil:
            self = .ningunaCliente
        }
    }
}

/// Modelo Codable que representa el documento /users/{uid} en Firestore.
struct UserProfile: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var email: String
    var role: UserProfileRole
    var sucursal: UserProfileBranch

    /// Diccionario explícito para escribir en Firestore sin depender de FirebaseFirestoreSwift.
    var firestoreData: [String: Any] {
        [
            "id": id,
            "email": email,
            "role": role.rawValue,
            "sucursal": sucursal.rawValue
        ]
    }

    /// Inicializa desde los datos crudos de Firestore validando campos requeridos.
    init(id: String, data: [String: Any]) throws {
        guard let email = data["email"] as? String,
              let roleValue = data["role"] as? String,
              let role = UserProfileRole(rawValue: roleValue),
              let branchValue = data["sucursal"] as? String,
              let branch = UserProfileBranch(rawValue: branchValue) else {
            throw AuthManagerError.missingUserProfile
        }

        self.id = id
        self.email = email
        self.role = role
        self.sucursal = branch
    }

    init(id: String, email: String, role: UserProfileRole, sucursal: UserProfileBranch) {
        self.id = id
        self.email = email
        self.role = role
        self.sucursal = sucursal
    }

    /// Convierte el perfil Firestore al AuthSession usado por la UI actual.
    var authSession: AuthSession {
        AuthSession(
            id: UUID(uuidString: id) ?? UUID(),
            email: email,
            role: role.appRole,
            branch: sucursal.appBranch,
            school: nil,
            displayName: email,
            authenticatedWithGoogle: true
        )
    }
}
