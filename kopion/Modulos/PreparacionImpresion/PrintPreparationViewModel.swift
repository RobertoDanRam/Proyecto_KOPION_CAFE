//en 
//  PrintPreparationViewModel.swift
//  kopion / Modulos / PreparacionImpresion
//

import Combine
import Foundation
import PDFKit
import SwiftUI
import UIKit

@MainActor
final class PrintPreparationViewModel: LoadableViewModel {

    // MARK: - Perfil de sesión

    /// Perfil del usuario autenticado (nil = invitado).
    var perfilUsuario: UserProfile?
    /// Perfil invitado (nil = usuario autenticado).
    @Published var perfilInvitado: PerfilInvitado?
    /// true cuando el usuario ya se identificó (autenticado o invitado confirmado).
    @Published var estaIdentificado = false

    // MARK: - Documentos del pedido

    @Published var documentos: [DocumentoAdjunto] = []
    @Published var documentoEditandoId: UUID?

    // MARK: - Configuración global (aplica a todos si el usuario no personaliza)

    @Published var configuracionGlobal = ConfiguracionImpresion()
    @Published var usarConfiguracionGlobal = true

    // MARK: - Sucursal destino

    @Published var sucursalDestino: Branch = .kopionESCA

    // MARK: - Flujo de pantallas

    @Published var mostrarResumen        = false
    @Published var mostrarPedidosEnviados = false
    @Published var urlPDFFinal: URL?

    // MARK: - Pedidos enviados

    @Published private(set) var pedidosEnviados: [PedidoImpresion] = []

    // MARK: - Computed

    var nombreCliente: String {
        if let p = perfilUsuario { return p.nombreCompleto }
        if let i = perfilInvitado { return "\(i.nombre) \(i.apellidos)".trimmingCharacters(in: .whitespaces) }
        return "Invitado"
    }

    var codigoSeguimiento: String {
        perfilInvitado?.codigoSeguimiento ?? String(perfilUsuario?.id.prefix(8) ?? "--------").uppercased()
    }

    /// Tipo de cliente que se guarda en el pedido para mostrarlo en recepción.
    var tipoClientePedido: CustomerType {
        perfilInvitado?.tipoCliente ?? .other
    }

    var tieneDocumentos: Bool { !documentos.isEmpty }

    var totalPaginas: Int {
        documentos.reduce(0) { $0 + $1.numeroPaginas * $1.configuracion.copias }
    }

    var costoTotal: Decimal {
        documentos.reduce(0) { $0 + $1.costoTotal }
    }

    /// Tamaños disponibles según el perfil del usuario.
    var tamañosDisponibles: [TamañoPagina] {
        let esPersonal = perfilUsuario.map {
            $0.rol == .colaborador || $0.rol == .editor || $0.rol == .administrador
        } ?? false
        return TamañoPagina.disponibles(para: perfilUsuario?.sucursal, esPersonal: esPersonal)
    }

    /// Sucursal fija del usuario (no puede cambiarla). nil = sin restricción.
    var sucursalFija: Branch? {
        // Usuario autenticado: su sucursal asignada.
        if let perfil = perfilUsuario, let sucursal = perfil.sucursal.sucursalApp {
            return sucursal
        }
        // Invitado: la sucursal derivada de su escuela.
        if let invitado = perfilInvitado {
            return invitado.escuela.linkedBranch
        }
        return nil
    }

    /// true si la sucursal del usuario es ESE (sin impresoras).
    var sucursalSinImpresoras: Bool {
        perfilUsuario?.sucursal == .eseCafe
    }

    // MARK: - Init

    override init() { super.init() }

    func configurar(perfil: UserProfile?) {
        self.perfilUsuario = perfil
        self.estaIdentificado = perfil != nil
        if let sucursal = perfil?.sucursal.sucursalApp {
            self.sucursalDestino = sucursal
        }
    }

    // MARK: - Identificación de invitado

    func confirmarInvitado(nombre: String, apellidos: String, tipo: CustomerType, escuela: School) {
        let codigo = PerfilInvitado.generarCodigo()
        perfilInvitado = PerfilInvitado(
            nombre:            nombre,
            apellidos:         apellidos,
            tipoCliente:       tipo,
            escuela:           escuela,
            codigoSeguimiento: codigo
        )
        sucursalDestino = escuela.linkedBranch
        estaIdentificado = true
    }

    // MARK: - Gestión de documentos

    func agregarDocumento(tipo: TipoArchivo, nombre: String = "") -> UUID {
        var doc = DocumentoAdjunto(nombre: nombre.isEmpty ? tipo.rawValue : nombre, tipo: tipo)
        if usarConfiguracionGlobal { doc.configuracion = configuracionGlobal }
        documentos.append(doc)
        return doc.id
    }

    func eliminarDocumento(id: UUID) {
        documentos.removeAll { $0.id == id }
    }

    func moverDocumento(desde origen: IndexSet, hasta destino: Int) {
        documentos.move(fromOffsets: origen, toOffset: destino)
    }

    func actualizarConfiguracion(id: UUID, config: ConfiguracionImpresion) {
        guard let idx = documentos.firstIndex(where: { $0.id == id }) else { return }
        documentos[idx].configuracion = config
    }

    func aplicarConfiguracionGlobalATodos() {
        for i in documentos.indices {
            documentos[i].configuracion = configuracionGlobal
        }
    }

    // MARK: - Imágenes en lienzo

    func agregarImagenesADocumento(id: UUID, imagenes: [UIImage]) {
        guard let idx = documentos.firstIndex(where: { $0.id == id }) else { return }
        let tamañoHoja = documentos[idx].configuracion.tamañoPagina.tamaño
        for imagen in imagenes {
            let anchoInicial = tamañoHoja.width * 0.4
            let escala = anchoInicial / imagen.size.width
            let tamañoInicial = CGSize(width: anchoInicial, height: imagen.size.height * escala)
            let offsetX = CGFloat.random(in: -30...30)
            let offsetY = CGFloat.random(in: -30...30)
            let posicion = CGPoint(x: tamañoHoja.width / 2 + offsetX, y: tamañoHoja.height / 2 + offsetY)
            documentos[idx].imagenesLienzo.append(ImagenEnLienzo(imagen: imagen, posicion: posicion, tamaño: tamañoInicial))
        }
        // Generar PDF del lienzo automáticamente.
        Task { await generarPDFLienzo(idDocumento: id) }
    }

    func moverImagenEnLienzo(idDoc: UUID, idImagen: UUID, a posicion: CGPoint) {
        guard let di = documentos.firstIndex(where: { $0.id == idDoc }),
              let ii = documentos[di].imagenesLienzo.firstIndex(where: { $0.id == idImagen }) else { return }
        documentos[di].imagenesLienzo[ii].posicion = posicion
    }

    func redimensionarImagenEnLienzo(idDoc: UUID, idImagen: UUID, tamaño: CGSize) {
        guard let di = documentos.firstIndex(where: { $0.id == idDoc }),
              let ii = documentos[di].imagenesLienzo.firstIndex(where: { $0.id == idImagen }) else { return }
        let min: CGFloat = 40
        documentos[di].imagenesLienzo[ii].tamaño = CGSize(width: max(min, tamaño.width), height: max(min, tamaño.height))
    }

    func eliminarImagenEnLienzo(idDoc: UUID, idImagen: UUID) {
        guard let di = documentos.firstIndex(where: { $0.id == idDoc }) else { return }
        documentos[di].imagenesLienzo.removeAll { $0.id == idImagen }
        Task { await generarPDFLienzo(idDocumento: idDoc) }
    }

    // MARK: - Procesamiento de PDFs adjuntos

    /// Carga un PDF adjunto, extrae miniaturas de páginas para reordenamiento.
    func cargarPDF(id: UUID, url: URL) async {
        guard let idx = documentos.firstIndex(where: { $0.id == id }) else { return }
        guard let pdfDoc = PDFDocument(url: url) else {
            documentos[idx].advertencia = "No se pudo leer el PDF."
            return
        }
        documentos[idx].urlPDF = url
        documentos[idx].nombre = url.deletingPathExtension().lastPathComponent
        var paginas: [PaginaPDF] = []
        for i in 0..<pdfDoc.pageCount {
            let miniatura = await Self.miniaturaPagina(pdfDoc: pdfDoc, indice: i)
            paginas.append(PaginaPDF(indice: i, miniatura: miniatura))
        }
        documentos[idx].paginas = paginas
    }

    // MARK: - Reordenamiento público (llamado desde OrdenadorPDFView)

    /// Regenera el PDF con el orden actual de páginas del documento.
    /// Expuesto como `func` público para que OrdenadorPDFView lo llame tras mover o eliminar.
    func regenerarPDFOrdenado(idDocumento: UUID) async {
        await reordenarPDF(idDocumento: idDocumento)
    }

    func reordenarPaginasPDF(idDoc: UUID, desde origen: IndexSet, hasta destino: Int) {
        guard let idx = documentos.firstIndex(where: { $0.id == idDoc }) else { return }
        documentos[idx].paginas.move(fromOffsets: origen, toOffset: destino)
        Task { await reordenarPDF(idDocumento: idDoc) }
    }

    // MARK: - Conversión de Office a PDF (usando UIDocumentInteractionController / QuickLook)
    // En iOS la conversión real de .docx/.xlsx requiere un servidor o librería de terceros.
    // Aquí generamos un PDF placeholder con instrucciones y marcamos la advertencia.

    func procesarArchivoOffice(id: UUID, url: URL, tipo: TipoArchivo) async {
        guard let idx = documentos.firstIndex(where: { $0.id == id }) else { return }
        documentos[idx].nombre = url.deletingPathExtension().lastPathComponent

        // Intentar leer como PDF si ya fue convertido externamente.
        if let pdfDoc = PDFDocument(url: url) {
            documentos[idx].urlPDF = url
            var paginas: [PaginaPDF] = []
            for i in 0..<pdfDoc.pageCount {
                let miniatura = await Self.miniaturaPagina(pdfDoc: pdfDoc, indice: i)
                paginas.append(PaginaPDF(indice: i, miniatura: miniatura))
            }
            documentos[idx].paginas = paginas
            return
        }

        // Generar PDF placeholder con instrucciones.
        let urlPlaceholder = await Self.generarPDFPlaceholder(nombre: url.lastPathComponent, tipo: tipo)
        documentos[idx].urlPDF = urlPlaceholder
        documentos[idx].paginas = [PaginaPDF(indice: 0)]

        if tipo == .excel {
            documentos[idx].advertencia =
                "Para Excel: antes de subir ve a Archivo → Imprimir → configura el tamaño de hoja, " +
                "activa 'Ajustar hoja en una página' y elige si es a una o doble cara. " +
                "Luego exporta como PDF y súbelo aquí."
        } else {
            documentos[idx].advertencia =
                "Archivo Office detectado. Para mejor resultado expórtalo como PDF desde la app de Office antes de subirlo."
        }
    }

    // MARK: - Generación del PDF final

    func generarPDFFinal() {
        guard tieneDocumentos else {
            mensajeError = "Agrega al menos un documento antes de enviar."
            return
        }
        let docsConPDF = documentos.filter { $0.urlPDF != nil }
        guard !docsConPDF.isEmpty else {
            mensajeError = "Ningún documento tiene PDF generado aún. Espera a que terminen de procesarse."
            return
        }
        estaEnviando = true
        mensajeError = nil

        Task.detached(priority: .userInitiated) { [docs = docsConPDF] in
            let url = await Self.fusionarPDFs(documentos: docs)
            await MainActor.run {
                self.urlPDFFinal = url
                self.estaEnviando = false
                if url == nil {
                    self.mensajeError = "No se pudo generar el PDF final. Inténtalo de nuevo."
                } else {
                    self.mostrarResumen = true
                }
            }
        }
    }

    func enviarPedido() {
        guard let url = urlPDFFinal else { return }
        let pedido = PedidoImpresion(
            id:                UUID(),
            codigoSeguimiento: codigoSeguimiento,
            sucursal:          sucursalDestino,
            documentos:        documentos,
            urlPDFFinal:       url,
            estado:            .enviado,
            creadoEn:          .now,
            nombreCliente:     nombreCliente,
            tipoCliente:       tipoClientePedido
        )
        pedidosEnviados.insert(pedido, at: 0)
        limpiarPedido()
    }

    func limpiarPedido() {
        documentos        = []
        urlPDFFinal       = nil
        mostrarResumen    = false
        mensajeError      = nil
    }

    // MARK: - Helpers privados (off main thread)

    private func generarPDFLienzo(idDocumento: UUID) async {
        guard let idx = documentos.firstIndex(where: { $0.id == idDocumento }) else { return }
        let imagenes  = documentos[idx].imagenesLienzo
        let tamHoja   = documentos[idx].configuracion.tamañoPagina.tamaño
        guard !imagenes.isEmpty else { return }

        let url = await Self.renderizarLienzoAPDF(imagenes: imagenes, tamañoHoja: tamHoja)
        if let url {
            documentos[idx].urlPDF = url
            documentos[idx].paginas = [PaginaPDF(indice: 0)]
        }
    }

    private func reordenarPDF(idDocumento: UUID) async {
        guard let idx = documentos.firstIndex(where: { $0.id == idDocumento }),
              let urlOriginal = documentos[idx].urlPDF,
              let pdfOriginal = PDFDocument(url: urlOriginal) else { return }

        let ordenNuevo = documentos[idx].paginas.map { $0.indiceOriginal }
        let url = await Self.reordenarPaginasPDF(pdfOriginal: pdfOriginal, orden: ordenNuevo)
        if let url { documentos[idx].urlPDF = url }
    }

    private static func miniaturaPagina(pdfDoc: PDFDocument, indice: Int) async -> UIImage? {
        guard let pagina = pdfDoc.page(at: indice) else { return nil }
        let rect = pagina.bounds(for: .mediaBox)
        let escala: CGFloat = 0.3
        let tamaño = CGSize(width: rect.width * escala, height: rect.height * escala)
        let renderer = UIGraphicsImageRenderer(size: tamaño)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: tamaño))
            ctx.cgContext.scaleBy(x: escala, y: escala)
            pagina.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }

    private static func renderizarLienzoAPDF(imagenes: [ImagenEnLienzo], tamañoHoja: CGSize) async -> URL? {
        let nombre = "lienzo-\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombre)
        let bounds = CGRect(origin: .zero, size: tamañoHoja)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                UIColor.white.setFill()
                UIRectFill(bounds)
                // UIGraphicsPDFRenderer usa coordenadas UIKit (Y hacia abajo),
                // igual que SwiftUI, por lo que NO hay que invertir el eje Y.
                for item in imagenes {
                    let cgCtx = ctx.cgContext
                    cgCtx.saveGState()
                    // Trasladar al centro de la imagen, rotar y dibujar.
                    cgCtx.translateBy(x: item.posicion.x, y: item.posicion.y)
                    cgCtx.rotate(by: CGFloat(item.rotacion.radians))
                    let rect = CGRect(
                        x: -item.tamaño.width  / 2,
                        y: -item.tamaño.height / 2,
                        width:  item.tamaño.width,
                        height: item.tamaño.height
                    )
                    item.imagen.draw(in: rect)
                    cgCtx.restoreGState()
                }
            }
            return url
        } catch { return nil }
    }

    private static func reordenarPaginasPDF(pdfOriginal: PDFDocument, orden: [Int]) async -> URL? {
        let nuevo = PDFDocument()
        for (nuevoIdx, originalIdx) in orden.enumerated() {
            guard let pagina = pdfOriginal.page(at: originalIdx) else { continue }
            nuevo.insert(pagina, at: nuevoIdx)
        }
        let nombre = "reordenado-\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombre)
        return nuevo.write(to: url) ? url : nil
    }

    private static func fusionarPDFs(documentos: [DocumentoAdjunto]) async -> URL? {
        let fusionado = PDFDocument()
        var paginaActual = 0
        for doc in documentos {
            guard let urlPDF = doc.urlPDF,
                  let pdfDoc = PDFDocument(url: urlPDF) else { continue }
            let copias = max(1, doc.configuracion.copias)
            for _ in 0..<copias {
                // Respetar orden de páginas del documento.
                let indices = doc.paginas.isEmpty
                    ? Array(0..<pdfDoc.pageCount)
                    : doc.paginas.map { $0.indiceOriginal }
                for idx in indices {
                    guard let pagina = pdfDoc.page(at: idx) else { continue }
                    fusionado.insert(pagina, at: paginaActual)
                    paginaActual += 1
                }
            }
        }
        guard fusionado.pageCount > 0 else { return nil }
        let nombre = "pedido-\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombre)
        return fusionado.write(to: url) ? url : nil
    }

    private static func generarPDFPlaceholder(nombre: String, tipo: TipoArchivo) async -> URL? {
        let texto = tipo == .excel
            ? "Excel: \(nombre)\n\nAntes de imprimir configura en Excel:\n• Archivo → Imprimir\n• Tamaño de hoja correcto\n• Ajustar hoja en una página\n• Una cara o doble cara\nLuego exporta como PDF y súbelo aquí."
            : "Archivo Office: \(nombre)\n\nPara mejor resultado exporta como PDF desde la app de Office antes de subirlo."

        let bounds = CGRect(origin: .zero, size: TamañoPagina.carta.tamaño)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let nombre2 = "placeholder-\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombre2)
        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                UIColor.white.setFill()
                UIRectFill(bounds)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14),
                    .foregroundColor: UIColor.darkText
                ]
                texto.draw(in: bounds.insetBy(dx: 40, dy: 60), withAttributes: attrs)
            }
            return url
        } catch { return nil }
    }
}
