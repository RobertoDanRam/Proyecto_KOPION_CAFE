//
//  BusinessModels.swift
//  kopion
//
//  Modelos centrales del negocio Kopion.
//  Estas estructuras separan el dominio de la interfaz para que POS, inventario,
//  CRM, pagos y analitica compartan la misma fuente de verdad.
//

import Foundation

/// Sucursales operativas. El stock y los precios se calculan por sucursal.
enum Branch: String, CaseIterable, Identifiable, Codable, Sendable {
    case kopionESCA
    case kopionCECyT1
    case cafeESE

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kopionESCA:
            return "Kopion ESCA"
        case .kopionCECyT1:
            return "Kopion CECyT 1"
        case .cafeESE:
            return "La Capital del Cafe ESE"
        }
    }

    var shortName: String {
        switch self {
        case .kopionESCA:
            return "ESCA"
        case .kopionCECyT1:
            return "CECyT 1"
        case .cafeESE:
            return "ESE Cafe"
        }
    }
}

/// Roles solicitados en el prompt para controlar permisos por pantalla y accion.
enum UserRole: String, CaseIterable, Identifiable, Codable, Sendable {
    case administrator
    case editor
    case collaborator
    case customer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .administrator:
            return "Administrador"
        case .editor:
            return "Editor"
        case .collaborator:
            return "Colaborador"
        case .customer:
            return "Usuario final"
        }
    }
}

/// Metodos de pago de fase 1. Los pagos digitales se concilian manualmente.
enum PaymentMethod: String, CaseIterable, Identifiable, Codable, Sendable {
    case cash
    case card
    case transfer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cash:
            return "Efectivo"
        case .card:
            return "Tarjeta"
        case .transfer:
            return "Transferencia"
        }
    }
}

/// Estado simple para pedidos y trabajos especiales.
enum WorkOrderStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case received
    case designing
    case printing
    case ready
    case delivered

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .received:
            return "Recibido"
        case .designing:
            return "En diseno"
        case .printing:
            return "En impresion"
        case .ready:
            return "Listo"
        case .delivered:
            return "Entregado"
        }
    }
}

/// Nivel de urgencia para peticiones internas de insumos.
enum UrgencyLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low:
            return "Baja"
        case .medium:
            return "Media"
        case .high:
            return "Alta"
        }
    }
}

/// Turnos usados en checador, limpieza e insumos.
enum WorkShift: String, CaseIterable, Identifiable, Codable, Sendable {
    case morning
    case evening

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning:
            return "Matutino"
        case .evening:
            return "Vespertino"
        }
    }
}

/// Producto o servicio vendible, con precios y stock separados por sucursal.
struct Product: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var normalizedName: String
    var category: String
    var barcode: String?
    var imageURL: URL?
    var pricesByBranch: [Branch: Decimal]
    var stockByBranch: [Branch: Int]
    var reorderPointByBranch: [Branch: Int]
    var lastRestockDate: Date?

    /// Precio especifico para una sucursal. Si no existe, devuelve cero para impedir ventas con precio ambiguo.
    func price(for branch: Branch) -> Decimal {
        pricesByBranch[branch] ?? 0
    }

    /// Existencia especifica por sucursal.
    func stock(for branch: Branch) -> Int {
        stockByBranch[branch] ?? 0
    }

    /// Determina si una sucursal esta por debajo de su punto de reorden.
    func isLowStock(at branch: Branch) -> Bool {
        stock(for: branch) <= (reorderPointByBranch[branch] ?? 0)
    }
}

/// Usuario de la app: dueña, editor, colaborador o cliente.
struct AppUser: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var fullName: String
    var email: String
    var role: UserRole
    var assignedBranch: Branch?
    var isActive: Bool
}

/// Linea de venta para POS o carrito global.
struct SaleLineItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var productID: UUID
    var productName: String
    var branch: Branch
    var quantity: Int
    var unitPrice: Decimal

    var subtotal: Decimal {
        unitPrice * Decimal(quantity)
    }
}

/// Venta registrada en POS. Sirve para cortes, cambios, devoluciones y reportes.
struct Sale: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var folio: String
    var branch: Branch
    var collaboratorName: String
    var items: [SaleLineItem]
    var paymentMethod: PaymentMethod
    var paidAmount: Decimal
    var createdAt: Date

    var total: Decimal {
        items.reduce(0) { $0 + $1.subtotal }
    }

    var changeDue: Decimal {
        max(paidAmount - total, 0)
    }
}

/// Archivo enviado a preparacion de impresion.
struct PrintDocument: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var fileName: String
    var sourceType: String
    var pageCount: Int
    var blankPagesRemoved: Int
    var repeatCopies: Int
    var compressedSizeInMB: Double
    var status: WorkOrderStatus
}

/// Pedido o trabajo especial visible para clientes y sucursal.
struct WorkOrder: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var folio: String
    var branch: Branch
    var customerName: String
    var status: WorkOrderStatus
    var documents: [PrintDocument]
    var createdAt: Date
}

/// Evidencia de limpieza para RRHH y comunicacion interna.
struct CleaningTask: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var collaboratorName: String
    var branch: Branch
    var shift: WorkShift
    var evidenceDescription: String
    var completedAt: Date?
}

/// Peticion interna de insumos no vendibles.
struct InternalSupplyRequest: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var itemName: String
    var urgency: UrgencyLevel
    var branch: Branch
    var collaboratorName: String
    var shift: WorkShift
    var requestedAt: Date
    var ownerComment: String?
    var isApproved: Bool?
}

/// Conciliacion manual de pagos por transferencia o voucher.
struct PaymentReconciliation: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var saleFolio: String
    var branch: Branch
    var method: PaymentMethod
    var evidenceFileName: String
    var isMatched: Bool
    var createdAt: Date
}

/// Metricas principales del dashboard administrativo.
struct AdminDashboardSnapshot: Codable, Hashable, Sendable {
    var todaySalesAmount: Decimal
    var cashInDrawer: Decimal
    var pendingBindingJobs: Int
    var lowStockCount: Int
    var tonerAlertCount: Int
    var topProductNames: [String]
    var pendingQuotes: Int
}

/// Tipo de cliente para segmentar tienda, CRM y comunicacion.
enum CustomerType: String, CaseIterable, Identifiable, Codable, Sendable {
    case student
    case teacher
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .student:
            return "Alumno"
        case .teacher:
            return "Maestro"
        case .other:
            return "Otro"
        }
    }
}

/// Escuelas atendidas por Kopion y La Capital del Cafe.
enum School: String, CaseIterable, Identifiable, Codable, Sendable {
    case escaSantoTomas
    case cecyt1
    case ese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .escaSantoTomas:
            return "ESCA - Escuela Superior de Comercio y Administracion Unidad Santo Tomas"
        case .cecyt1:
            return "CECyT 1 - Centro de Estudios Cientificos y Tecnologicos No. 1 Gonzalo Vazquez Vela IPN"
        case .ese:
            return "ESE - Escuela Superior de Economia"
        }
    }

    var linkedBranch: Branch {
        switch self {
        case .escaSantoTomas:
            return .kopionESCA
        case .cecyt1:
            return .kopionCECyT1
        case .ese:
            return .cafeESE
        }
    }
}

/// Perfil capturado para clientes antes de entrar a tienda virtual.
struct CustomerLoginProfile: Codable, Hashable, Sendable {
    var firstName: String
    var lastName: String
    var email: String
    var customerType: CustomerType
    var school: School
}

/// Perfil capturado para empleados, editores o dueña desde el registro de sucursal.
struct StaffLoginProfile: Codable, Hashable, Sendable {
    var email: String
    var firstName: String = ""
    var lastName: String = ""
    var branch: Branch
    var requestedRole: UserRole
}

/// Sesion autenticada que determina a que area entra el usuario.
struct AuthSession: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var email: String
    var role: UserRole
    var branch: Branch?
    var school: School?
    var displayName: String
    var authenticatedWithGoogle: Bool
}
