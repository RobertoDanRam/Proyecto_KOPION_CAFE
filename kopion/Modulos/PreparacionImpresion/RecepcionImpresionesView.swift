//
//  RecepcionImpresionesView.swift
//  kopion / Módulos / PreparaciónImpresión
//
//  Recepción de impresión para colaboradores.
//

import Combine
import PDFKit
import QuickLook
import SwiftUI
import UIKit

/// Recepción de impresión filtrada por la sucursal asignada al colaborador.
struct RecepcionImpresionesView: View {
    let sucursal: Branch?
    @StateObject private var modeloVista: RecepcionImpresionesModeloVista

    init(sucursal: Branch?) {
        self.sucursal = sucursal
        _modeloVista = StateObject(wrappedValue: RecepcionImpresionesModeloVista(sucursal: sucursal))
    }

    var body: some View {
        Group {
            if let sucursal {
                List {
                    SeccionResumenRecepcion(modeloVista: modeloVista, sucursal: sucursal)
                    SeccionBusquedaRecepcion(modeloVista: modeloVista)
                    SeccionPedidosRecepcion(modeloVista: modeloVista)
                }
            } else {
                ContentUnavailableView(
                    "Sin sucursal asignada",
                    systemImage: "storefront.slash",
                    description: Text("Este usuario no tiene una sucursal operativa para recibir impresiones.")
                )
            }
        }
        .navigationTitle("Recepción impresiones")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Modelo de vista

/// Controla la lista, búsqueda y filtros de recepción por sucursal.
@MainActor
final class RecepcionImpresionesModeloVista: ObservableObject {
    @Published var busqueda = ""
    @Published var estadoFiltro: EstadoRecepcionFiltro = .todos
    @Published var colorFiltro: ColorRecepcionFiltro = .todos
    @Published var fechaFiltro: FechaRecepcionFiltro = .todos
    @Published var orden: OrdenRecepcion = .recientesPrimero
    @Published var paginasMinimas = 0
    @Published var mostrarFiltrosAvanzados = false
    @Published private(set) var pedidos: [PedidoImpresion]

    let sucursal: Branch?

    init(sucursal: Branch?) {
        self.sucursal = sucursal
        self.pedidos = Self.crearPedidosDeMuestra(para: sucursal)
    }

    /// Pedidos visibles después de aplicar sucursal, búsqueda, filtros y orden.
    var pedidosFiltrados: [PedidoImpresion] {
        var resultado = pedidos

        if let sucursal {
            resultado = resultado.filter { $0.sucursal == sucursal }
        }

        let termino = busqueda.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !termino.isEmpty {
            resultado = resultado.filter { pedido in
                pedido.codigoSeguimiento.lowercased().contains(termino) ||
                pedido.nombreCliente.lowercased().contains(termino) ||
                pedido.documentos.contains { $0.nombre.lowercased().contains(termino) }
            }
        }

        if let estado = estadoFiltro.estado {
            resultado = resultado.filter { $0.estado == estado }
        }

        if let modoColor = colorFiltro.modoColor {
            resultado = resultado.filter { pedido in
                pedido.documentos.contains { $0.configuracion.modoColor == modoColor }
            }
        }

        if let intervalo = fechaFiltro.intervaloFechas {
            resultado = resultado.filter { intervalo.contains($0.creadoEn) }
        }

        if paginasMinimas > 0 {
            resultado = resultado.filter { $0.totalPaginas >= paginasMinimas }
        }

        switch orden {
        case .recientesPrimero:
            resultado.sort { $0.creadoEn > $1.creadoEn }
        case .antiguosPrimero:
            resultado.sort { $0.creadoEn < $1.creadoEn }
        case .mayorCosto:
            resultado.sort { $0.costoTotal > $1.costoTotal }
        case .masPaginas:
            resultado.sort { $0.totalPaginas > $1.totalPaginas }
        }

        return resultado
    }

    var totalPendientes: Int {
        pedidosFiltrados.filter { $0.estado == .enviado || $0.estado == .enProceso }.count
    }

    var paginasEnCola: Int {
        pedidosFiltrados.reduce(0) { $0 + $1.totalPaginas }
    }

    /// Reemplaza un pedido cuando el colaborador edita o cambia su estado.
    func actualizar(_ pedido: PedidoImpresion) {
        guard let indice = pedidos.firstIndex(where: { $0.id == pedido.id }) else { return }
        pedidos[indice] = pedido
    }

    /// Restablece búsqueda, filtros avanzados y orden a sus valores iniciales.
    func limpiarFiltros() {
        busqueda = ""
        estadoFiltro = .todos
        colorFiltro = .todos
        fechaFiltro = .todos
        orden = .recientesPrimero
        paginasMinimas = 0
    }

    /// Crea datos temporales hasta conectar la recepción con Firestore y Storage.
    private static func crearPedidosDeMuestra(para sucursal: Branch?) -> [PedidoImpresion] {
        guard let sucursal else { return [] }
        let otraSucursal: Branch = sucursal == .kopionESCA ? .kopionCECyT1 : .kopionESCA

        return [
            crearPedido(
                cliente: "Mariana López",
                tipoCliente: .student,
                codigo: "ESCA-4821-AK",
                sucursal: sucursal,
                minutosAtras: 8,
                estado: .enviado,
                documentos: [
                    crearDocumento(nombre: "Tarea cálculo integral", tipo: .pdf, paginas: 12, copias: 1, tamaño: .carta, color: .blancoNegro, caras: .dosCara),
                    crearDocumento(nombre: "Portada color", tipo: .imagenes, paginas: 1, copias: 1, tamaño: .carta, color: .color, caras: .unaCara)
                ]
            ),
            crearPedido(
                cliente: "Prof. Daniel Herrera",
                tipoCliente: .teacher,
                codigo: "ESCA-7194-MP",
                sucursal: sucursal,
                minutosAtras: 26,
                estado: .enProceso,
                documentos: [
                    crearDocumento(nombre: "Examen grupo 2RM4", tipo: .pdf, paginas: 36, copias: 2, tamaño: .carta, color: .blancoNegro, caras: .unaCara)
                ]
            ),
            crearPedido(
                cliente: "Ana Robles",
                tipoCliente: .other,
                codigo: "ESCA-2368-QT",
                sucursal: sucursal,
                minutosAtras: 74,
                estado: .enviado,
                documentos: [
                    crearDocumento(nombre: "Lámina proyecto final", tipo: .pdf, paginas: 3, copias: 1, tamaño: .dobleCarta, color: .color, caras: .unaCara)
                ]
            ),
            crearPedido(
                cliente: "Pedido otra sucursal",
                tipoCliente: .student,
                codigo: "CECYT-1188-ZX",
                sucursal: otraSucursal,
                minutosAtras: 12,
                estado: .enviado,
                documentos: [
                    crearDocumento(nombre: "No visible para esta sucursal", tipo: .pdf, paginas: 5, copias: 1, tamaño: .carta, color: .blancoNegro, caras: .unaCara)
                ]
            )
        ]
    }

    private static func crearPedido(
        cliente: String,
        tipoCliente: CustomerType,
        codigo: String,
        sucursal: Branch,
        minutosAtras: Int,
        estado: EstadoPedidoImpresion,
        documentos: [DocumentoAdjunto]
    ) -> PedidoImpresion {
        let url = crearPDFMuestra(codigo: codigo, cliente: cliente, documentos: documentos)
        var docs = documentos
        for indice in docs.indices where docs[indice].urlPDF == nil {
            docs[indice].urlPDF = url
        }
        return PedidoImpresion(
            id: UUID(),
            codigoSeguimiento: codigo,
            sucursal: sucursal,
            documentos: docs,
            urlPDFFinal: url,
            estado: estado,
            creadoEn: Date().addingTimeInterval(TimeInterval(-minutosAtras * 60)),
            nombreCliente: cliente,
            tipoCliente: tipoCliente
        )
    }

    private static func crearDocumento(
        nombre: String,
        tipo: TipoArchivo,
        paginas: Int,
        copias: Int,
        tamaño: TamañoPagina,
        color: ModoColor,
        caras: ModoCara
    ) -> DocumentoAdjunto {
        var documento = DocumentoAdjunto(nombre: nombre, tipo: tipo)
        documento.paginas = (0..<paginas).map { PaginaPDF(indice: $0) }
        documento.configuracion = ConfiguracionImpresion(copias: copias, tamañoPagina: tamaño, modoColor: color, modoCara: caras)
        return documento
    }

    private static func crearPDFMuestra(codigo: String, cliente: String, documentos: [DocumentoAdjunto]) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(codigo)-recepcion.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        do {
            try renderer.writePDF(to: url) { contexto in
                contexto.beginPage()
                let titulo = "Kopion - Pedido \(codigo)"
                let resumen = "Cliente: \(cliente)\nDocumentos: \(documentos.count)\nPáginas: \(documentos.reduce(0) { $0 + $1.numeroPaginas })"
                titulo.draw(at: CGPoint(x: 48, y: 64), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 22)])
                resumen.draw(at: CGPoint(x: 48, y: 112), withAttributes: [.font: UIFont.systemFont(ofSize: 16)])
            }
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Filtros

/// Filtro de estado para separar pedidos enviados, en proceso y listos.
enum EstadoRecepcionFiltro: String, CaseIterable, Identifiable {
    case todos = "Todos"
    case enviados = "Enviados"
    case enProceso = "En proceso"
    case listos = "Listos"

    var id: String { rawValue }

    var estado: EstadoPedidoImpresion? {
        switch self {
        case .todos: return nil
        case .enviados: return .enviado
        case .enProceso: return .enProceso
        case .listos: return .listo
        }
    }
}

/// Filtro de color para localizar trabajos a color o blanco y negro.
enum ColorRecepcionFiltro: String, CaseIterable, Identifiable {
    case todos = "Todos"
    case blancoNegro = "B/N"
    case color = "Color"

    var id: String { rawValue }

    var modoColor: ModoColor? {
        switch self {
        case .todos: return nil
        case .blancoNegro: return .blancoNegro
        case .color: return .color
        }
    }
}

/// Filtro de fecha para acotar la búsqueda en colas grandes.
enum FechaRecepcionFiltro: String, CaseIterable, Identifiable {
    case todos = "Todas"
    case ultimaHora = "Última hora"
    case hoy = "Hoy"

    var id: String { rawValue }

    var intervaloFechas: ClosedRange<Date>? {
        let ahora = Date()
        switch self {
        case .todos:
            return nil
        case .ultimaHora:
            return ahora.addingTimeInterval(-3600)...ahora
        case .hoy:
            let inicio = Calendar.current.startOfDay(for: ahora)
            return inicio...ahora
        }
    }
}

/// Orden disponible para priorizar la atención de trabajos.
enum OrdenRecepcion: String, CaseIterable, Identifiable {
    case recientesPrimero = "Recientes"
    case antiguosPrimero = "Antiguos"
    case mayorCosto = "Mayor costo"
    case masPaginas = "Más páginas"

    var id: String { rawValue }
}

// MARK: - Secciones

/// Resumen superior con sucursal, pedidos visibles y páginas en cola.
private struct SeccionResumenRecepcion: View {
    @ObservedObject var modeloVista: RecepcionImpresionesModeloVista
    let sucursal: Branch

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(sucursal.displayName, systemImage: "storefront")
                        .font(.headline)
                    Spacer()
                    Text("\(modeloVista.totalPendientes) pendientes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                }
                HStack(spacing: 16) {
                    Label("\(modeloVista.pedidosFiltrados.count) pedidos", systemImage: "tray.full")
                    Label("\(modeloVista.paginasEnCola) pág", systemImage: "doc.text")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

/// Buscador principal y filtros avanzados de recepción.
private struct SeccionBusquedaRecepcion: View {
    @ObservedObject var modeloVista: RecepcionImpresionesModeloVista

    var body: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Buscar por nombre, código o archivo", text: $modeloVista.busqueda)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                if !modeloVista.busqueda.isEmpty {
                    Button {
                        modeloVista.busqueda = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Borrar búsqueda")
                }
            }

            Picker("Estado", selection: $modeloVista.estadoFiltro) {
                ForEach(EstadoRecepcionFiltro.allCases) { filtro in
                    Text(filtro.rawValue).tag(filtro)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button {
                    withAnimation { modeloVista.mostrarFiltrosAvanzados.toggle() }
                } label: {
                    Label("Filtros avanzados", systemImage: "line.3.horizontal.decrease.circle")
                }
                Spacer()
                Button {
                    modeloVista.limpiarFiltros()
                } label: {
                    Label("Limpiar filtros", systemImage: "xmark.circle")
                }
                .font(.subheadline.weight(.semibold))
            }

            if modeloVista.mostrarFiltrosAvanzados {
                Picker("Color", selection: $modeloVista.colorFiltro) {
                    ForEach(ColorRecepcionFiltro.allCases) { filtro in
                        Text(filtro.rawValue).tag(filtro)
                    }
                }
                Picker("Fecha", selection: $modeloVista.fechaFiltro) {
                    ForEach(FechaRecepcionFiltro.allCases) { filtro in
                        Text(filtro.rawValue).tag(filtro)
                    }
                }
                Picker("Orden", selection: $modeloVista.orden) {
                    ForEach(OrdenRecepcion.allCases) { orden in
                        Text(orden.rawValue).tag(orden)
                    }
                }
                Stepper("Mínimo páginas: \(modeloVista.paginasMinimas)", value: $modeloVista.paginasMinimas, in: 0...500, step: 5)
            }
        }
    }
}

/// Lista de pedidos recibidos después de aplicar filtros.
private struct SeccionPedidosRecepcion: View {
    @ObservedObject var modeloVista: RecepcionImpresionesModeloVista

    var body: some View {
        Section("Recibidos") {
            if modeloVista.pedidosFiltrados.isEmpty {
                ContentUnavailableView("Sin resultados", systemImage: "doc.text.magnifyingglass")
            } else {
                ForEach(modeloVista.pedidosFiltrados) { pedido in
                    NavigationLink {
                        DetallePedidoRecepcionView(pedido: pedido) { actualizado in
                            modeloVista.actualizar(actualizado)
                        }
                    } label: {
                        FilaPedidoRecepcion(pedido: pedido)
                    }
                }
            }
        }
    }
}

/// Fila compacta con cliente, tipo de usuario, estado y totales.
private struct FilaPedidoRecepcion: View {
    let pedido: PedidoImpresion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(pedido.nombreCliente)
                    .font(.headline)
                    .lineLimit(1)
                Text(pedido.tipoCliente.displayName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.12), in: Capsule())
                Spacer()
                Text(pedido.creadoEn, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Text(pedido.codigoSeguimiento)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.purple)
                Text(pedido.sucursal.shortName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(pedido.estado.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Label("\(pedido.totalPaginas) pág", systemImage: "doc")
                Label(CurrencyFormatter.pesos(pedido.costoTotal), systemImage: "dollarsign.circle")
                Label("\(pedido.documentos.count) archivos", systemImage: "paperclip")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detalle

/// Detalle operativo del pedido: especificaciones, edición, previsualización e impresión.
private struct DetallePedidoRecepcionView: View {
    @State var pedido: PedidoImpresion
    let alActualizar: (PedidoImpresion) -> Void
    @State private var urlPrevisualizacion: URL?
    @State private var documentoEditando: DocumentoAdjunto?
    @State private var documentoEditandoArchivo: DocumentoAdjunto?

    var body: some View {
        List {
            Section("Pedido") {
                LabeledContent("Cliente") {
                    HStack(spacing: 8) {
                        Text(pedido.nombreCliente)
                            .fontWeight(.semibold)
                        Text(pedido.tipoCliente.displayName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.purple)
                    }
                }
                LabeledContent("Sucursal", value: pedido.sucursal.displayName)
                LabeledContent("Hora") { Text(pedido.creadoEn, style: .time) }
                LabeledContent("Código") {
                    Text(pedido.codigoSeguimiento)
                        .font(.body.monospaced().weight(.semibold))
                        .foregroundStyle(.purple)
                }
                Picker("Estado", selection: $pedido.estado) {
                    ForEach([EstadoPedidoImpresion.enviado, .enProceso, .listo], id: \.rawValue) { estado in
                        Text(estado.rawValue).tag(estado)
                    }
                }
            }

            Section("Especificaciones") {
                LabeledContent("Hojas calculadas", value: "\(pedido.totalPaginas)")
                LabeledContent("Precio calculado", value: CurrencyFormatter.pesos(pedido.costoTotal))
                ForEach(pedido.documentos) { documento in
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            documentoEditando = documento
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(documento.nombre)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("\(documento.numeroPaginas) pág · \(documento.configuracion.copias) copias · \(documento.configuracion.tamañoPagina.rawValue) · \(documento.configuracion.modoColor.rawValue) · \(documento.configuracion.modoCara.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Subtotal: \(CurrencyFormatter.pesos(documento.costoTotal))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.purple)
                            }
                        }

                        Button {
                            documentoEditandoArchivo = documento
                        } label: {
                            Label("Editar archivo", systemImage: documento.tipo == .imagenes ? "photo.on.rectangle.angled" : "doc.text.magnifyingglass")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if let url = pedido.urlPDFFinal {
                Section("PDF adjunto") {
                    VistaPreviaPDF(url: url)
                        .frame(height: 320)
                        .listRowInsets(.init())

                    Button {
                        marcarEnProcesoSiHaceFalta()
                        urlPrevisualizacion = url
                    } label: {
                        Label("Abrir previsualización", systemImage: "eye")
                    }

                    Button {
                        imprimir(url: url)
                    } label: {
                        Label("Imprimir", systemImage: "printer")
                    }

                    ShareLink(item: url) {
                        Label("Descargar o compartir PDF", systemImage: "square.and.arrow.down")
                    }
                    .simultaneousGesture(TapGesture().onEnded { marcarListo() })
                }
            }
        }
        .navigationTitle("\(pedido.codigoSeguimiento)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { marcarEnProcesoSiHaceFalta() }
        .onDisappear { alActualizar(pedido) }
        .quickLookPreview($urlPrevisualizacion)
        .sheet(item: $documentoEditando) { documento in
            EditarDocumentoRecepcionView(documento: documento) { actualizado in
                actualizarDocumento(actualizado)
                documentoEditando = nil
            }
        }
        .sheet(item: $documentoEditandoArchivo) { documento in
            EditorArchivoRecepcionView(documento: documento) { actualizado in
                actualizarDocumento(actualizado)
                documentoEditandoArchivo = nil
            }
        }
    }

    /// Guarda en el pedido los cambios de especificaciones o archivo editado.
    private func actualizarDocumento(_ documento: DocumentoAdjunto) {
        guard let indice = pedido.documentos.firstIndex(where: { $0.id == documento.id }) else { return }
        pedido.documentos[indice] = documento
        alActualizar(pedido)
    }

    /// Marca automáticamente el pedido como en proceso al abrirlo por primera vez.
    private func marcarEnProcesoSiHaceFalta() {
        guard pedido.estado == .enviado else { return }
        pedido.estado = .enProceso
        alActualizar(pedido)
    }

    /// Marca automáticamente el pedido como listo al imprimir o descargar.
    private func marcarListo() {
        pedido.estado = .listo
        alActualizar(pedido)
    }

    /// Abre la impresión nativa de iOS usando la configuración disponible del pedido.
    private func imprimir(url: URL) {
        let informacionImpresion = UIPrintInfo(dictionary: nil)
        informacionImpresion.jobName = pedido.codigoSeguimiento
        informacionImpresion.outputType = pedido.documentos.contains { $0.configuracion.modoColor == .color } ? .photo : .general
        informacionImpresion.duplex = pedido.documentos.contains { $0.configuracion.modoCara == .dosCara } ? .longEdge : .none

        let controladorImpresion = UIPrintInteractionController.shared
        controladorImpresion.printInfo = informacionImpresion
        controladorImpresion.printingItem = url
        controladorImpresion.present(animated: true) { _, completado, _ in
            if completado { marcarListo() }
        }
    }
}

/// Editor temporal que reutiliza el lienzo de imágenes o el editor de páginas PDF.
private struct EditorArchivoRecepcionView: View {
    let documento: DocumentoAdjunto
    let alTerminar: (DocumentoAdjunto) -> Void
    @Environment(\.dismiss) private var cerrar
    @StateObject private var modeloEditor = PrintPreparationViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if let doc = modeloEditor.documentos.first {
                    if doc.tipo == .imagenes {
                        LienzoEditorView(viewModel: modeloEditor, idDocumento: doc.id)
                    } else {
                        EditorPDFRecepcionView(modeloVista: modeloEditor, idDocumento: doc.id)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(documento.tipo == .imagenes ? "Editar imágenes" : "Editar PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminar") {
                        terminarEdicion()
                    }
                }
            }
            .onAppear {
                if modeloEditor.documentos.isEmpty {
                    modeloEditor.documentos = [documento]
                }
            }
        }
    }

    /// Cierra el editor y devuelve el documento actualizado al detalle del pedido.
    private func terminarEdicion() {
        guard let actualizado = modeloEditor.documentos.first else { return }
        alTerminar(actualizado)
        cerrar()
    }
}

/// Editor básico de PDF para reordenar o eliminar páginas antes de imprimir.
private struct EditorPDFRecepcionView: View {
    @ObservedObject var modeloVista: PrintPreparationViewModel
    let idDocumento: UUID
    @State private var historial: [[PaginaPDF]] = []
    @State private var paginaAEliminar: PaginaPDF?

    private var indiceDoc: Int? {
        modeloVista.documentos.firstIndex { $0.id == idDocumento }
    }

    private var paginas: [PaginaPDF] {
        indiceDoc.map { modeloVista.documentos[$0].paginas } ?? []
    }

    var body: some View {
        List {
            Section {
                Label("Arrastra para reordenar páginas; desliza una página para eliminarla.", systemImage: "hand.draw")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Label("Para cambios de texto dentro del PDF se requiere regenerar o anotar el archivo; iOS no reescribe texto existente del PDF como Word.", systemImage: "text.magnifyingglass")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if paginas.isEmpty {
                ContentUnavailableView("Sin páginas", systemImage: "doc.badge.questionmark")
            } else {
                ForEach(paginas) { pagina in
                    FilaPaginaRecepcionView(pagina: pagina)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                paginaAEliminar = pagina
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                }
                .onMove { origen, destino in
                    guardarHistorial()
                    guard let indiceDoc else { return }
                    modeloVista.documentos[indiceDoc].paginas.move(fromOffsets: origen, toOffset: destino)
                    Task { await modeloVista.regenerarPDFOrdenado(idDocumento: idDocumento) }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    deshacerUltimoCambio()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(historial.isEmpty)
            }
        }
        .confirmationDialog(
            "¿Eliminar esta página?",
            isPresented: Binding(
                get: { paginaAEliminar != nil },
                set: { if !$0 { paginaAEliminar = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Eliminar página", role: .destructive) {
                if let pagina = paginaAEliminar { eliminarPagina(pagina) }
                paginaAEliminar = nil
            }
            Button("Cancelar", role: .cancel) { paginaAEliminar = nil }
        }
    }

    /// Guarda el estado anterior para deshacer cambios de páginas.
    private func guardarHistorial() {
        guard let indiceDoc else { return }
        historial.append(modeloVista.documentos[indiceDoc].paginas)
        if historial.count > 10 { historial.removeFirst() }
    }

    /// Elimina una página y regenera el PDF temporal.
    private func eliminarPagina(_ pagina: PaginaPDF) {
        guardarHistorial()
        guard let indiceDoc else { return }
        modeloVista.documentos[indiceDoc].paginas.removeAll { $0.id == pagina.id }
        Task { await modeloVista.regenerarPDFOrdenado(idDocumento: idDocumento) }
    }

    /// Restaura el último orden de páginas guardado.
    private func deshacerUltimoCambio() {
        guard let indiceDoc, let anterior = historial.popLast() else { return }
        modeloVista.documentos[indiceDoc].paginas = anterior
        Task { await modeloVista.regenerarPDFOrdenado(idDocumento: idDocumento) }
    }
}

/// Fila visual de una página del PDF dentro del editor.
private struct FilaPaginaRecepcionView: View {
    let pagina: PaginaPDF

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let miniatura = pagina.miniatura {
                    Image(uiImage: miniatura)
                        .resizable()
                        .scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .overlay(Image(systemName: "doc").foregroundStyle(.secondary))
                }
            }
            .frame(width: 52, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(radius: 2)

            Text("Página \(pagina.indiceOriginal + 1)")
                .font(.subheadline.weight(.medium))
        }
        .padding(.vertical, 4)
    }
}

/// Formulario para corregir nombre, copias, tamaño, color y caras.
private struct EditarDocumentoRecepcionView: View {
    @State var documento: DocumentoAdjunto
    let alGuardar: (DocumentoAdjunto) -> Void
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            Form {
                Section("Archivo") {
                    TextField("Nombre", text: $documento.nombre)
                    LabeledContent("Páginas detectadas", value: "\(documento.numeroPaginas)")
                }

                Section("Impresión") {
                    Stepper("Copias: \(documento.configuracion.copias)", value: $documento.configuracion.copias, in: 1...99)
                    Picker("Tamaño", selection: $documento.configuracion.tamañoPagina) {
                        ForEach(TamañoPagina.allCases) { tamaño in
                            Text(tamaño.rawValue).tag(tamaño)
                        }
                    }
                    Picker("Color", selection: $documento.configuracion.modoColor) {
                        ForEach(ModoColor.allCases) { modo in
                            Text(modo.rawValue).tag(modo)
                        }
                    }
                    Picker("Caras", selection: $documento.configuracion.modoCara) {
                        ForEach(ModoCara.allCases) { modo in
                            Text(modo.rawValue).tag(modo)
                        }
                    }
                }

                Section("Cálculo") {
                    LabeledContent("Precio por página", value: CurrencyFormatter.pesos(documento.configuracion.modoColor.precioPorPagina(tamaño: documento.configuracion.tamañoPagina)))
                    LabeledContent("Subtotal", value: CurrencyFormatter.pesos(documento.costoTotal))
                }
            }
            .navigationTitle("Editar especificaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        alGuardar(documento)
                        cerrar()
                    }
                }
            }
        }
    }
}
