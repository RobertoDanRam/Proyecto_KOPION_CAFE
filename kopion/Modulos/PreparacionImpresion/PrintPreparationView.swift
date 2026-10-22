//
//  PrintPreparationView.swift
//  kopion / Modulos / PreparacionImpresion
//

import PDFKit
import PhotosUI
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct PrintPreparationView: View {
    @StateObject private var viewModel = PrintPreparationViewModel()
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        Group {
            if viewModel.sucursalSinImpresoras {
                // ESE Café no tiene impresoras.
                ContentUnavailableView(
                    "Servicio no disponible",
                    systemImage: "printer.fill",
                    description: Text("La sucursal ESE Café no cuenta con impresoras. Visita Kopion ESCA o CECyT 1.")
                )
            } else if !viewModel.estaIdentificado {
                // Pantalla de identificación.
                IdentificacionImpresionView(viewModel: viewModel)
            } else {
                // Editor principal.
                EditorPrincipalView(viewModel: viewModel)
            }
        }
        .navigationTitle("Enviar archivos")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Si ya hay sesión activa, configurar automáticamente.
            if let usuario = authManager.usuarioActual {
                viewModel.configurar(perfil: usuario)
            }
        }
        .sheet(isPresented: $viewModel.mostrarResumen) {
            ResumenPedidoView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.mostrarPedidosEnviados) {
            PedidosEnviadosView(pedidos: viewModel.pedidosEnviados)
        }
        .alert("Aviso", isPresented: enlaceError(para: viewModel)) {
            Button("OK") { viewModel.limpiarError() }
        } message: {
            Text(viewModel.mensajeError ?? "")
        }
        .overlay {
            if viewModel.estaEnviando {
                Color.black.opacity(0.35).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView().tint(.white).scaleEffect(1.4)
                    Text("Generando PDF…")
                        .foregroundStyle(.white)
                        .font(.subheadline.weight(.medium))
                }
                .padding(28)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

// MARK: - Editor principal

private struct EditorPrincipalView: View {
    @ObservedObject var viewModel: PrintPreparationViewModel
    @State private var tipoSeleccionado: TipoArchivo?
    @State private var mostrarConfigGlobal  = false
    @State private var idDocConfigurando: UUID?
    @State private var idDocOrdenando: UUID?
    @State private var idDocLienzo: UUID?

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Encabezado de usuario
            EncabezadoUsuarioView(viewModel: viewModel)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))

            Divider()

            // MARK: Menú de tipos de archivo
            MenuTiposArchivoView(tipoSeleccionado: $tipoSeleccionado, viewModel: viewModel)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))

            Divider()

            // MARK: Lista de documentos adjuntos
            if viewModel.tieneDocumentos {
                ListaDocumentosView(
                    viewModel:          viewModel,
                    idDocConfigurando:  $idDocConfigurando,
                    idDocOrdenando:     $idDocOrdenando,
                    idDocLienzo:        $idDocLienzo
                )
            } else {
                Spacer()
                ContentUnavailableView(
                    "Sin archivos",
                    systemImage: "doc.badge.plus",
                    description: Text("Elige un tipo de archivo arriba para comenzar.")
                )
                Spacer()
            }

            Divider()

            // MARK: Barra inferior con totales y botón enviar
            BarraInferiorView(viewModel: viewModel, mostrarConfigGlobal: $mostrarConfigGlobal)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
        }
        // Sheets de configuración y edición.
        .sheet(item: $idDocConfigurando) { id in
            ConfiguracionDocumentoView(viewModel: viewModel, idDocumento: id)
        }
        .sheet(item: $idDocOrdenando) { id in
            OrdenadorPDFView(viewModel: viewModel, idDocumento: id)
        }
        .sheet(item: $idDocLienzo) { id in
            NavigationStack {
                LienzoEditorView(viewModel: viewModel, idDocumento: id)
                    .navigationTitle("Editor de imágenes")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Listo") { idDocLienzo = nil }
                        }
                    }
            }
        }
        .sheet(isPresented: $mostrarConfigGlobal) {
            ConfiguracionGlobalView(viewModel: viewModel)
        }
        // Selector de tipo de archivo.
        .sheet(item: $tipoSeleccionado) { tipo in
            SelectorArchivoView(viewModel: viewModel, tipo: tipo) {
                tipoSeleccionado = nil
            }
        }
    }
}

// MARK: - Encabezado de usuario

private struct EncabezadoUsuarioView: View {
    @ObservedObject var viewModel: PrintPreparationViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.nombreCliente)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("Código: \(viewModel.codigoSeguimiento)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                viewModel.mostrarPedidosEnviados = true
            } label: {
                Image(systemName: "tray.full")
                    .foregroundStyle(.purple)
            }
            .disabled(viewModel.pedidosEnviados.isEmpty)
        }
    }
}

// MARK: - Menú de tipos de archivo

private struct MenuTiposArchivoView: View {
    @Binding var tipoSeleccionado: TipoArchivo?
    @ObservedObject var viewModel: PrintPreparationViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TipoArchivo.allCases) { tipo in
                    Button {
                        tipoSeleccionado = tipo
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: tipo.icono)
                                .font(.title3)
                                .foregroundStyle(tipo.tint)
                            Text(tipo.rawValue)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                        .frame(width: 80, height: 64)
                        .background(tipo.tint.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Lista de documentos

private struct ListaDocumentosView: View {
    @ObservedObject var viewModel: PrintPreparationViewModel
    @Binding var idDocConfigurando: UUID?
    @Binding var idDocOrdenando: UUID?
    @Binding var idDocLienzo: UUID?

    var body: some View {
        List {
            ForEach(viewModel.documentos) { doc in
                DocumentoFilaView(
                    doc:               doc,
                    onConfigurar:      { idDocConfigurando = doc.id },
                    onOrdenar:         { idDocOrdenando    = doc.id },
                    onEditarLienzo:    { idDocLienzo       = doc.id },
                    onEliminar:        { viewModel.eliminarDocumento(id: doc.id) }
                )
            }
            .onMove { viewModel.moverDocumento(desde: $0, hasta: $1) }
            .onDelete { indices in
                indices.forEach { viewModel.documentos.remove(at: $0) }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }
}

private struct DocumentoFilaView: View {
    let doc: DocumentoAdjunto
    let onConfigurar: () -> Void
    let onOrdenar: () -> Void
    let onEditarLienzo: () -> Void
    let onEliminar: () -> Void

    /// URL del archivo original para QuickLook (Word, Excel, PowerPoint).
    @State private var urlQuickLook: URL?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: doc.tipo.icono)
                .font(.title3)
                .foregroundStyle(doc.tipo.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(doc.nombre)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if doc.urlPDF != nil {
                        Label("\(doc.numeroPaginas) pág", systemImage: "doc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Procesando…", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Text("×\(doc.configuracion.copias) · \(doc.configuracion.modoColor.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let advertencia = doc.advertencia {
                    Label(advertencia, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }

                Text("$\(doc.costoTotal)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.purple)
            }

            Spacer()

            Menu {
                Button { onConfigurar() } label: {
                    Label("Configurar impresión", systemImage: "slider.horizontal.3")
                }
                if doc.tipo == .pdf || doc.tipo == .word || doc.tipo == .excel {
                    Button { onOrdenar() } label: {
                        Label("Ordenar páginas", systemImage: "list.number")
                    }
                }
                if doc.tipo == .imagenes {
                    Button { onEditarLienzo() } label: {
                        Label("Editar lienzo", systemImage: "rectangle.and.pencil.and.ellipsis")
                    }
                }
                // Vista previa nativa con QuickLook para Word, Excel y PowerPoint.
                if (doc.tipo == .word || doc.tipo == .excel), let url = doc.urlPDF {
                    Button { urlQuickLook = url } label: {
                        Label("Vista previa", systemImage: "eye")
                    }
                }
                Divider()
                Button(role: .destructive) { onEliminar() } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        // QuickLook para previsualizar archivos Office nativamente.
        .quickLookPreview($urlQuickLook)
    }
}

// MARK: - Barra inferior

private struct BarraInferiorView: View {
    @ObservedObject var viewModel: PrintPreparationViewModel
    @Binding var mostrarConfigGlobal: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.totalPaginas) páginas")
                    .font(.subheadline.weight(.semibold))
                Text("Total: $\(viewModel.costoTotal)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                mostrarConfigGlobal = true
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)

            Button {
                viewModel.generarPDFFinal()
            } label: {
                Label("Enviar", systemImage: "paperplane.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.tieneDocumentos || viewModel.estaEnviando)
        }
    }
}

// MARK: - Selector de archivo por tipo

struct SelectorArchivoView: View {
    @ObservedObject var viewModel: PrintPreparationViewModel
    let tipo: TipoArchivo
    let alTerminar: () -> Void

    @State private var seleccionFotos: [PhotosPickerItem] = []
    @State private var mostrarPickerArchivo = false
    @State private var idDocNuevo: UUID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: tipo.icono)
                    .font(.system(size: 48))
                    .foregroundStyle(tipo.tint)
                    .padding(.top, 32)

                Text(tipo.rawValue)
                    .font(.title2.weight(.bold))

                descripcionTipo

                accionPrincipal

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("Agregar \(tipo.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { alTerminar() }
                }
            }
        }
        // Cargar fotos seleccionadas.
        .onChange(of: seleccionFotos) { _, nuevas in
            guard !nuevas.isEmpty else { return }
            let id = viewModel.agregarDocumento(tipo: .imagenes, nombre: "Imágenes \(viewModel.documentos.count + 1)")
            idDocNuevo = id
            Task {
                var imgs: [UIImage] = []
                for item in nuevas {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) { imgs.append(img) }
                }
                viewModel.agregarImagenesADocumento(id: id, imagenes: imgs)
                seleccionFotos = []
                alTerminar()
            }
        }
        // Picker de archivos PDF/Office.
        .fileImporter(
            isPresented: $mostrarPickerArchivo,
            allowedContentTypes: tiposUTI,
            allowsMultipleSelection: true
        ) { resultado in
            switch resultado {
            case .success(let urls):
                Task {
                    for url in urls {
                        _ = url.startAccessingSecurityScopedResource()
                        defer { url.stopAccessingSecurityScopedResource() }
                        let id = viewModel.agregarDocumento(tipo: tipo, nombre: url.deletingPathExtension().lastPathComponent)
                        if tipo == .pdf {
                            await viewModel.cargarPDF(id: id, url: url)
                        } else {
                            await viewModel.procesarArchivoOffice(id: id, url: url, tipo: tipo)
                        }
                    }
                    alTerminar()
                }
            case .failure:
                break
            }
        }
    }

    @ViewBuilder
    private var descripcionTipo: some View {
        switch tipo {
        case .pdf:
            Text("Adjunta uno o varios PDFs. Podrás ver miniaturas de cada página y reordenarlas antes de enviar.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        case .imagenes:
            Text("Selecciona imágenes de tu galería y acomódalas en un lienzo tipo Word. Puedes moverlas y redimensionarlas.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        case .word:
            VStack(spacing: 8) {
                Text("Adjunta archivos Word o PowerPoint. Para mejor resultado expórtalos como PDF desde la app de Office antes de subirlos.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        case .excel:
            VStack(alignment: .leading, spacing: 8) {
                Text("Antes de subir tu Excel, configúralo en la app:")
                    .font(.subheadline.weight(.medium))
                ForEach([
                    "1. Ve a Archivo → Imprimir",
                    "2. Elige el tamaño de hoja correcto",
                    "3. Activa 'Ajustar hoja en una página'",
                    "4. Define si es a una o doble cara",
                    "5. Exporta como PDF y súbelo aquí"
                ], id: \.self) { paso in
                    Text(paso)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private var accionPrincipal: some View {
        if tipo == .imagenes {
            PhotosPicker(
                selection: $seleccionFotos,
                maxSelectionCount: 30,
                matching: .images
            ) {
                Label("Seleccionar imágenes", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(tipo.tint)
        } else {
            Button {
                mostrarPickerArchivo = true
            } label: {
                Label("Seleccionar archivos", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(tipo.tint)
        }
    }

    private var tiposUTI: [UTType] {
        switch tipo {
        case .pdf:    return [.pdf]
        case .word:   return [UTType("com.microsoft.word.doc") ?? .data,
                              UTType("org.openxmlformats.wordprocessingml.document") ?? .data,
                              UTType("com.microsoft.powerpoint.ppt") ?? .data,
                              UTType("org.openxmlformats.presentationml.presentation") ?? .data]
        case .excel:  return [UTType("com.microsoft.excel.xls") ?? .data,
                              UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data]
        case .imagenes: return [.image]
        }
    }
}

// MARK: - Pedidos enviados

private struct PedidosEnviadosView: View {
    let pedidos: [PedidoImpresion]
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            List(pedidos) { pedido in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(pedido.codigoSeguimiento)
                            .font(.headline.monospaced())
                            .foregroundStyle(.purple)
                        Spacer()
                        Text(pedido.estado.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(pedido.estado == .enviado ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Text("\(pedido.sucursal.displayName) · \(pedido.totalPaginas) páginas · $\(pedido.costoTotal)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(pedido.nombreCliente)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Pedidos enviados")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                }
            }
            .overlay {
                if pedidos.isEmpty {
                    ContentUnavailableView("Sin pedidos", systemImage: "tray",
                        description: Text("Aún no has enviado ningún pedido."))
                }
            }
        }
    }
}

// MARK: - VistaPreviaPDF (PDFKit wrapper)

struct VistaPreviaPDF: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales       = true
        v.displayMode      = .singlePageContinuous
        v.displayDirection = .vertical
        v.backgroundColor  = UIColor.secondarySystemBackground
        return v
    }
    func updateUIView(_ uiView: PDFView, context: Context) {
        if let doc = PDFDocument(url: url) { uiView.document = doc }
    }
}

// MARK: - UUID como Identifiable para sheet(item:)

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
