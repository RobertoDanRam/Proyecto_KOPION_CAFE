//
//  RecepcionImpresionesView.swift
//  kopion / Modulos / PreparacionImpresion
//

import PDFKit
import QuickLook
import SwiftUI
import UIKit

struct RecepcionImpresionesView: View {
    let sucursal: Branch?
    @StateObject private var viewModel: RecepcionImpresionesViewModel

    init(sucursal: Branch?) {
        self.sucursal = sucursal
        _viewModel = StateObject(wrappedValue: RecepcionImpresionesViewModel(sucursal: sucursal))
    }

    var body: some View {
        Group {
            if let sucursal {
                List {
                    SeccionResumenRecepcion(viewModel: viewModel, sucursal: sucursal)
                    SeccionBusquedaRecepcion(viewModel: viewModel)
                    SeccionPedidosRecepcion(viewModel: viewModel)
                }
                .searchable(text: $viewModel.busqueda, prompt: "Nombre, código o archivo")
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

// MARK: - ViewModel

@MainActor
final class RecepcionImpresionesViewModel: ObservableObject {
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

    func actualizar(_ pedido: PedidoImpresion) {
        guard let indice = pedidos.firstIndex(where: { $0.id == pedido.id }) else { return }
        pedidos[indice] = pedido
    }

    private static func crearPedidosDeMuestra(para sucursal: Branch?) -> [PedidoImpresion] {
        guard let sucursal else { return [] }
        let otraSucursal: Branch = sucursal == .kopionESCA ? .kopionCECyT1 : .kopionESCA

        return [
            crearPedido(
                cliente: "Mariana López",
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
            nombreCliente: cliente
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

enum OrdenRecepcion: String, CaseIterable, Identifiable {
    case recientesPrimero = "Recientes"
    case antiguosPrimero = "Antiguos"
    case mayorCosto = "Mayor costo"
    case masPaginas = "Más páginas"

    var id: String { rawValue }
}

// MARK: - Secciones

private struct SeccionResumenRecepcion: View {
    @ObservedObject var viewModel: RecepcionImpresionesViewModel
    let sucursal: Branch

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(sucursal.displayName, systemImage: "storefront")
                        .font(.headline)
                    Spacer()
                    Text("\(viewModel.totalPendientes) pendientes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                }
                HStack(spacing: 16) {
                    Label("\(viewModel.pedidosFiltrados.count) pedidos", systemImage: "tray.full")
                    Label("\(viewModel.paginasEnCola) pág", systemImage: "doc.text")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

private struct SeccionBusquedaRecepcion: View {
    @ObservedObject var viewModel: RecepcionImpresionesViewModel

    var body: some View {
        Section {
            Picker("Estado", selection: $viewModel.estadoFiltro) {
                ForEach(EstadoRecepcionFiltro.allCases) { filtro in
                    Text(filtro.rawValue).tag(filtro)
                }
            }
            .pickerStyle(.segmented)

            Button {
                withAnimation { viewModel.mostrarFiltrosAvanzados.toggle() }
            } label: {
                Label("Filtros avanzados", systemImage: "line.3.horizontal.decrease.circle")
            }

            if viewModel.mostrarFiltrosAvanzados {
                Picker("Color", selection: $viewModel.colorFiltro) {
                    ForEach(ColorRecepcionFiltro.allCases) { filtro in
                        Text(filtro.rawValue).tag(filtro)
                    }
                }
                Picker("Fecha", selection: $viewModel.fechaFiltro) {
                    ForEach(FechaRecepcionFiltro.allCases) { filtro in
                        Text(filtro.rawValue).tag(filtro)
                    }
                }
                Picker("Orden", selection: $viewModel.orden) {
                    ForEach(OrdenRecepcion.allCases) { orden in
                        Text(orden.rawValue).tag(orden)
                    }
                }
                Stepper("Mínimo páginas: \(viewModel.paginasMinimas)", value: $viewModel.paginasMinimas, in: 0...500, step: 5)
            }
        }
    }
}

private struct SeccionPedidosRecepcion: View {
    @ObservedObject var viewModel: RecepcionImpresionesViewModel

    var body: some View {
        Section("Recibidos") {
            if viewModel.pedidosFiltrados.isEmpty {
                ContentUnavailableView("Sin resultados", systemImage: "doc.text.magnifyingglass")
            } else {
                ForEach(viewModel.pedidosFiltrados) { pedido in
                    NavigationLink {
                        DetallePedidoRecepcionView(pedido: pedido) { actualizado in
                            viewModel.actualizar(actualizado)
                        }
                    } label: {
                        FilaPedidoRecepcion(pedido: pedido)
                    }
                }
            }
        }
    }
}

private struct FilaPedidoRecepcion: View {
    let pedido: PedidoImpresion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(pedido.nombreCliente)
                    .font(.headline)
                    .lineLimit(1)
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
                Label("$\(pedido.costoTotal)", systemImage: "dollarsign.circle")
                Label("\(pedido.documentos.count) archivos", systemImage: "paperclip")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detalle

private struct DetallePedidoRecepcionView: View {
    @State var pedido: PedidoImpresion
    let onActualizar: (PedidoImpresion) -> Void
    @State private var urlPrevisualizacion: URL?
    @State private var documentoEditando: DocumentoAdjunto?

    var body: some View {
        List {
            Section("Pedido") {
                LabeledContent("Cliente", value: pedido.nombreCliente)
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

            if let url = pedido.urlPDFFinal {
                Section("PDF adjunto") {
                    VistaPreviaPDF(url: url)
                        .frame(height: 320)
                        .listRowInsets(.init())

                    Button { urlPrevisualizacion = url } label: {
                        Label("Abrir previsualización", systemImage: "eye")
                    }

                    ShareLink(item: url) {
                        Label("Descargar o compartir PDF", systemImage: "square.and.arrow.down")
                    }
                }
            }

            Section("Especificaciones") {
                LabeledContent("Hojas calculadas", value: "\(pedido.totalPaginas)")
                LabeledContent("Precio calculado", value: "$\(pedido.costoTotal)")
                ForEach(pedido.documentos) { documento in
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
                            Text("Subtotal: $\(documento.costoTotal)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.purple)
                        }
                    }
                }
            }
        }
        .navigationTitle("\(pedido.codigoSeguimiento)")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { onActualizar(pedido) }
        .quickLookPreview($urlPrevisualizacion)
        .sheet(item: $documentoEditando) { documento in
            EditarDocumentoRecepcionView(documento: documento) { actualizado in
                actualizarDocumento(actualizado)
                documentoEditando = nil
            }
        }
    }

    private func actualizarDocumento(_ documento: DocumentoAdjunto) {
        guard let indice = pedido.documentos.firstIndex(where: { $0.id == documento.id }) else { return }
        pedido.documentos[indice] = documento
        onActualizar(pedido)
    }
}

private struct EditarDocumentoRecepcionView: View {
    @State var documento: DocumentoAdjunto
    let onGuardar: (DocumentoAdjunto) -> Void
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
                    LabeledContent("Precio por página", value: "$\(documento.configuracion.modoColor.precioPorPagina(tamaño: documento.configuracion.tamañoPagina))")
                    LabeledContent("Subtotal", value: "$\(documento.costoTotal)")
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
                        onGuardar(documento)
                        cerrar()
                    }
                }
            }
        }
    }
}
