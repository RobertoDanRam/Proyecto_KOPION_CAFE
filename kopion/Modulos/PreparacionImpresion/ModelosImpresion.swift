//
//  ModelosImpresion.swift
//  kopion / Modulos / PreparacionImpresion
//

import PDFKit
import SwiftUI
import UIKit

// MARK: - Tamaño de página

enum TamañoPagina: String, CaseIterable, Identifiable {
    case carta       = "Carta"
    case oficio      = "Oficio"
    case dobleCarta  = "Doble carta (11×17)"
    case plotter     = "Plotter (60–90 cm)"

    var id: String { rawValue }

    /// Dimensiones en puntos PDF (1 pt = 1/72 pulgada).
    var tamaño: CGSize {
        switch self {
        case .carta:      return CGSize(width: 612,  height: 792)   // 8.5×11 in
        case .oficio:     return CGSize(width: 612,  height: 1008)  // 8.5×14 in
        case .dobleCarta: return CGSize(width: 792,  height: 1224)  // 11×17 in
        case .plotter:    return CGSize(width: 1728, height: 2592)  // 24×36 in (mínimo plotter)
        }
    }

    /// Tamaños disponibles según la sucursal del usuario.
    /// ESE Café no tiene impresoras → devuelve vacío.
    /// ESCA y CECyT 1 tienen carta, oficio y doble carta.
    /// Plotter solo para personal de sucursal (no clientes).
    static func disponibles(para sucursal: UserProfileBranch?, esPersonal: Bool) -> [TamañoPagina] {
        switch sucursal {
        case .eseCafe:
            return []   // Sin impresoras
        case .kopionESCA, .kopionCECyT1:
            var lista: [TamañoPagina] = [.carta, .oficio, .dobleCarta]
            if esPersonal { lista.append(.plotter) }
            return lista
        default:
            // Invitado o sin sucursal: carta y oficio
            return [.carta, .oficio, .dobleCarta]
        }
    }
}

// MARK: - Tipo de archivo adjunto

enum TipoArchivo: String, CaseIterable, Identifiable {
    case pdf         = "PDF"
    case imagenes    = "Imágenes"
    case word        = "Word / PowerPoint"
    case excel       = "Excel"

    var id: String { rawValue }
    var icono: String {
        switch self {
        case .pdf:      return "doc.fill"
        case .imagenes: return "photo.on.rectangle.angled"
        case .word:     return "doc.richtext"
        case .excel:    return "tablecells"
        }
    }
    var tint: Color {
        switch self {
        case .pdf:      return .red
        case .imagenes: return .blue
        case .word:     return .indigo
        case .excel:    return .green
        }
    }
}

// MARK: - Configuración de impresión

enum ModoColor: String, CaseIterable, Identifiable {
    case blancoNegro = "Blanco y negro"
    case color       = "Color"
    var id: String { rawValue }

    /// Precio por página según tamaño de hoja.
    func precioPorPagina(tamaño: TamañoPagina) -> Decimal {
        switch (self, tamaño) {
        case (.blancoNegro, .carta):      return 1
        case (.color,       .carta):      return 5
        case (.blancoNegro, .oficio):     return 2
        case (.color,       .oficio):     return 7
        case (.blancoNegro, .dobleCarta): return 4
        case (.color,       .dobleCarta): return 10
        case (.blancoNegro, .plotter):    return 20
        case (.color,       .plotter):    return 50
        }
    }
}

enum ModoCara: String, CaseIterable, Identifiable {
    case unaCara    = "Una cara"
    case dosCara    = "Doble cara"
    var id: String { rawValue }
}

struct ConfiguracionImpresion: Equatable {
    var copias: Int         = 1
    var tamañoPagina: TamañoPagina = .carta
    var modoColor: ModoColor       = .blancoNegro
    var modoCara: ModoCara         = .unaCara
}

// MARK: - Documento adjunto

/// Un documento que el usuario adjunta al pedido (PDF, imágenes convertidas, Word, Excel).
struct DocumentoAdjunto: Identifiable {
    let id: UUID
    var nombre: String
    var tipo: TipoArchivo
    /// PDF resultante listo para fusionar (puede ser nil mientras se convierte).
    var urlPDF: URL?
    /// Páginas del PDF para previsualización y reordenamiento.
    var paginas: [PaginaPDF]
    var configuracion: ConfiguracionImpresion
    /// Imágenes del lienzo (solo para tipo .imagenes).
    var imagenesLienzo: [ImagenEnLienzo]
    /// Advertencia específica del tipo (ej. Excel grande).
    var advertencia: String?

    var numeroPaginas: Int { paginas.count }

    var costoTotal: Decimal {
        let paginasEfectivas = Decimal(numeroPaginas * configuracion.copias)
        return paginasEfectivas * configuracion.modoColor.precioPorPagina(tamaño: configuracion.tamañoPagina)
    }

    init(nombre: String, tipo: TipoArchivo) {
        self.id              = UUID()
        self.nombre          = nombre
        self.tipo            = tipo
        self.urlPDF          = nil
        self.paginas         = []
        self.configuracion   = ConfiguracionImpresion()
        self.imagenesLienzo  = []
        self.advertencia     = nil
    }
}

/// Una página de un PDF para previsualización y reordenamiento.
struct PaginaPDF: Identifiable {
    let id: UUID
    let indiceOriginal: Int
    var miniatura: UIImage?

    init(indice: Int, miniatura: UIImage? = nil) {
        self.id              = UUID()
        self.indiceOriginal  = indice
        self.miniatura       = miniatura
    }
}

// MARK: - Imagen en lienzo

struct ImagenEnLienzo: Identifiable {
    let id: UUID
    var imagen: UIImage
    var posicion: CGPoint
    var tamaño: CGSize
    var rotacion: Angle

    init(imagen: UIImage, posicion: CGPoint, tamaño: CGSize) {
        self.id       = UUID()
        self.imagen   = imagen
        self.posicion = posicion
        self.tamaño   = tamaño
        self.rotacion = .zero
    }
}

// MARK: - Perfil de usuario invitado

struct PerfilInvitado {
    var nombre: String
    var apellidos: String
    var tipoCliente: CustomerType
    var escuela: School
    /// Código único de seguimiento generado al confirmar el perfil.
    var codigoSeguimiento: String

    static func generarCodigo() -> String {
        let letras = "ABCDEFGHJKLMNPQRSTUVWXYZ"
        let nums   = "23456789"
        let parte1 = String((0..<3).map { _ in letras.randomElement()! })
        let parte2 = String((0..<4).map { _ in nums.randomElement()! })
        let parte3 = String((0..<2).map { _ in letras.randomElement()! })
        return "\(parte1)-\(parte2)-\(parte3)"
    }
}

// MARK: - Pedido de impresión

enum EstadoPedidoImpresion: String {
    case borrador  = "Borrador"
    case enviado   = "Enviado"
    case enProceso = "En proceso"
    case listo     = "Listo"
}

struct PedidoImpresion: Identifiable {
    let id: UUID
    var codigoSeguimiento: String
    var sucursal: Branch
    var documentos: [DocumentoAdjunto]
    var urlPDFFinal: URL?
    var estado: EstadoPedidoImpresion
    var creadoEn: Date
    var nombreCliente: String
    /// Tipo de cliente que envió el pedido: alumno, maestro u otro.
    var tipoCliente: CustomerType

    var totalPaginas: Int {
        documentos.reduce(0) { $0 + $1.numeroPaginas * $1.configuracion.copias }
    }

    var costoTotal: Decimal {
        documentos.reduce(0) { $0 + $1.costoTotal }
    }
}
