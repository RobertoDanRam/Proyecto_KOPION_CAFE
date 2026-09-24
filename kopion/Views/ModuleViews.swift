//
//  ModuleViews.swift
//  kopion
//
//  Vistas SwiftUI iniciales para todos los modulos solicitados.
//  Cada pantalla usa su ViewModel, respeta estados de carga/submision y cancela
//  tareas asincronas al salir para mantener un ciclo de vida limpio.
//

import SwiftUI

/// Formateador compartido para importes en pesos mexicanos.
enum CurrencyFormatter {
    static func pesos(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "MXN"
        formatter.locale = Locale(identifier: "es_MX")
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
}

/// Tarjeta compacta de metrica para dashboards operativos.
struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Fila reutilizable con icono, titulo y detalle.
struct ModuleRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
        }
        .padding(.vertical, 6)
    }
}

/// Dashboard principal del administrador con prioridades altas primero.
struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminDashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if viewModel.isLoading {
                    ProgressView("Cargando dashboard")
                        .frame(maxWidth: .infinity, minHeight: 120)
                }

                if let snapshot = viewModel.snapshot {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        MetricTile(title: "Ventas del dia", value: CurrencyFormatter.pesos(snapshot.todaySalesAmount), systemImage: "chart.line.uptrend.xyaxis", tint: .green)
                        MetricTile(title: "Efectivo en caja", value: CurrencyFormatter.pesos(snapshot.cashInDrawer), systemImage: "banknote", tint: .blue)
                        MetricTile(title: "Engargolados pendientes", value: "\(snapshot.pendingBindingJobs)", systemImage: "doc.on.doc", tint: .orange)
                        MetricTile(title: "Alertas stock/toner", value: "\(snapshot.lowStockCount + snapshot.tonerAlertCount)", systemImage: "exclamationmark.triangle", tint: .red)
                    }

                    SectionHeader(title: "Prioridad media")
                    VStack(alignment: .leading, spacing: 10) {
                        ModuleRow(title: "Top productos", detail: snapshot.topProductNames.joined(separator: ", "), systemImage: "star", tint: .yellow)
                        ModuleRow(title: "Cotizaciones pendientes", detail: "\(snapshot.pendingQuotes) prospectos por dar seguimiento", systemImage: "person.2", tint: .purple)
                    }
                }

                SectionHeader(title: "Stock bajo por sucursal")
                ForEach(viewModel.lowStockProducts) { product in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(product.name)
                            .font(.headline)
                        ForEach(Branch.allCases) { branch in
                            if product.isLowStock(at: branch) {
                                Text("\(branch.shortName): \(product.stock(for: branch)) unidades")
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
        .navigationTitle("Administrador")
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
        .alert("Aviso", isPresented: errorBinding(for: viewModel)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

/// Encabezado visual para secciones dentro de pantallas de trabajo.
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}

/// Modulo de conversion de archivos, fusion PDF y preparacion de impresion.
struct PrintPreparationView: View {
    @StateObject private var viewModel = PrintPreparationViewModel()

    var body: some View {
        List {
            Section("Conversion y reglas PDF") {
                ModuleRow(title: "Word, JPG y PNG a PDF", detail: "Preparacion nativa para imprimir sin retrabajos", systemImage: "doc.richtext", tint: .blue)
                ModuleRow(title: "Paginas blancas", detail: "Conteo de paginas y eliminacion automatica registrada", systemImage: "doc.text.magnifyingglass", tint: .orange)
                ModuleRow(title: "Canvas de imagenes", detail: "Base preparada para redimensionar imagenes antes de imprimir", systemImage: "rectangle.and.hand.point.up.left", tint: .purple)
                ModuleRow(title: "Compresion", detail: "Reduce archivos pesados antes de enviarlos a impresora", systemImage: "arrow.down.doc", tint: .green)
            }

            Section("Documentos en cola") {
                if viewModel.isLoading {
                    ProgressView()
                }

                ForEach(viewModel.documents) { document in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(document.fileName)
                            .font(.headline)
                        Text("\(document.sourceType) - \(document.pageCount) paginas - repetir \(document.repeatCopies)x")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Blancas removidas: \(document.blankPagesRemoved) - Tamano: \(document.compressedSizeInMB, specifier: "%.1f") MB")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Fusion") {
                Button {
                    viewModel.mergeDocuments()
                } label: {
                    Label(viewModel.isSubmitting ? "Fusionando" : "Unir PDFs", systemImage: "doc.on.doc")
                }
                .disabled(viewModel.isSubmitting || viewModel.documents.isEmpty)

                if viewModel.isSubmitting {
                    ProgressView("Preparando archivo")
                }

                if let mergedDocument = viewModel.mergedDocument {
                    ModuleRow(title: mergedDocument.fileName, detail: "\(mergedDocument.pageCount) paginas listas para imprimir", systemImage: "checkmark.seal", tint: .green)
                }
            }
        }
        .navigationTitle("PDF e impresion")
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
    }
}

/// Portal cliente con promociones, pedidos y tienda digital.
struct CustomerPortalView: View {
    @StateObject private var viewModel = CustomerPortalViewModel()

    var body: some View {
        List {
            Section("Promociones") {
                ForEach(viewModel.promotions, id: \.self) { promotion in
                    ModuleRow(title: promotion, detail: "Gestionado por administracion", systemImage: "tag", tint: .pink)
                }
            }

            Section("Tienda y cotizador") {
                ModuleRow(title: "Engargolados", detail: "Precio dinamico por cantidad de hojas", systemImage: "book.closed", tint: .blue)
                ModuleRow(title: "Enmicados", detail: "Credencial, media carta y carta", systemImage: "rectangle.on.rectangle", tint: .cyan)
                ModuleRow(title: "Copias por volumen", detail: "50-99 a $0.70, mas de 100 a $0.50", systemImage: "doc.on.doc", tint: .green)
                ModuleRow(title: "Escaneos", detail: "$3.00 por pagina", systemImage: "scanner", tint: .orange)
            }

            Section("Pedidos") {
                if viewModel.isLoading {
                    ProgressView()
                }

                ForEach(viewModel.workOrders) { order in
                    ModuleRow(title: order.folio, detail: "\(order.customerName) - \(order.branch.shortName) - \(order.status.displayName)", systemImage: "tray.full", tint: .indigo)
                }
            }
        }
        .navigationTitle("Portal cliente")
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
    }
}

/// Analitica de tinta, toner, stock y predicciones basicas.
struct AnalyticsView: View {
    @StateObject private var viewModel = AdminDashboardViewModel()

    var body: some View {
        List {
            Section("Semaforo operativo") {
                if let snapshot = viewModel.snapshot {
                    ModuleRow(title: "Toner", detail: snapshot.tonerAlertCount > 0 ? "Atencion requerida" : "Nivel estable", systemImage: "printer", tint: snapshot.tonerAlertCount > 0 ? .red : .green)
                    ModuleRow(title: "Stock bajo", detail: "\(snapshot.lowStockCount) articulos requieren resurtido", systemImage: "shippingbox", tint: snapshot.lowStockCount > 0 ? .orange : .green)
                    ModuleRow(title: "PDF automatico", detail: "Base lista para generar reporte de stock bajo", systemImage: "doc.badge.gearshape", tint: .blue)
                }
            }

            Section("Proyeccion de agotamiento") {
                ForEach(viewModel.lowStockProducts) { product in
                    ModuleRow(title: product.name, detail: "Modelo aritmetico inicial: revisar resurtido esta semana", systemImage: "chart.xyaxis.line", tint: .purple)
                }
            }
        }
        .navigationTitle("Analitica")
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
    }
}

/// Catalogo centralizado con stock, precios por sucursal y busqueda debounced.
struct CatalogView: View {
    @StateObject private var viewModel = CatalogViewModel()

    var body: some View {
        List {
            Section("Sucursal") {
                Picker("Sucursal", selection: $viewModel.selectedBranch) {
                    ForEach(Branch.allCases) { branch in
                        Text(branch.displayName).tag(branch)
                    }
                }
            }

            Section("Productos") {
                if viewModel.isLoading {
                    ProgressView()
                }

                ForEach(viewModel.products) { product in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(product.name)
                            .font(.headline)
                        Text(product.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(CurrencyFormatter.pesos(product.price(for: viewModel.selectedBranch)))
                            Spacer()
                            Text("Stock: \(product.stock(for: viewModel.selectedBranch))")
                                .foregroundStyle(product.isLowStock(at: viewModel.selectedBranch) ? .red : .secondary)
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Catalogo")
        .searchable(text: $viewModel.searchText, prompt: "Buscar producto o codigo")
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
    }
}

/// POS exclusivo de empleados con cobro rapido y ventas recientes.
struct POSView: View {
    @StateObject private var viewModel = POSViewModel()

    var body: some View {
        List {
            Section("Sucursal y cobro") {
                Picker("Sucursal", selection: $viewModel.selectedBranch) {
                    ForEach(Branch.allCases) { branch in
                        Text(branch.shortName).tag(branch)
                    }
                }
                TextField("Pago recibido", text: $viewModel.paidAmountText)
                    .keyboardType(.decimalPad)

                Button {
                    viewModel.registerSampleSale()
                } label: {
                    Label(viewModel.isSubmitting ? "Cobrando" : "Registrar venta rapida", systemImage: "cart.badge.plus")
                }
                .disabled(viewModel.isSubmitting)

                if viewModel.isSubmitting {
                    ProgressView("Registrando venta")
                }
            }

            Section("Flujos POS") {
                ModuleRow(title: "Pistola lectora", detail: "Preparado para entrada por codigo de barras", systemImage: "barcode.viewfinder", tint: .blue)
                ModuleRow(title: "Cantidad al agregar", detail: "Base para preguntar cantidad por producto", systemImage: "number", tint: .orange)
                ModuleRow(title: "Devoluciones y cambios", detail: "Motivos, ajuste de caja y diferencias de precio", systemImage: "arrow.triangle.2.circlepath", tint: .purple)
            }

            Section("Ventas recientes") {
                if viewModel.isLoading {
                    ProgressView()
                }

                ForEach(viewModel.recentSales) { sale in
                    ModuleRow(title: sale.folio, detail: "\(sale.branch.shortName) - \(CurrencyFormatter.pesos(sale.total)) - Cambio: \(CurrencyFormatter.pesos(sale.changeDue))", systemImage: "ticket", tint: .green)
                }
            }
        }
        .navigationTitle("POS")
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
    }
}

/// Operaciones internas: recepcion, RRHH, limpieza, insumos, vales y checador.
struct OperationsView: View {
    @StateObject private var viewModel = OperationsViewModel()

    var body: some View {
        List {
            Section("Recepcion y comunicacion") {
                ModuleRow(title: "One-click approval", detail: "Empleados escanean entradas y la duena aprueba remoto", systemImage: "checkmark.circle", tint: .green)
                ModuleRow(title: "Checador", detail: "Entrada/salida con foto del lugar de trabajo", systemImage: "clock.badge.checkmark", tint: .blue)
                ModuleRow(title: "Vales de caja", detail: "Salidas para proveedores o adelantos de nomina", systemImage: "person.text.rectangle", tint: .orange)
            }

            Section("Checklist de limpieza") {
                ForEach(viewModel.cleaningTasks) { task in
                    ModuleRow(title: task.title, detail: "\(task.branch.shortName) - \(task.shift.displayName) - \(task.evidenceDescription)", systemImage: task.completedAt == nil ? "camera" : "checkmark.seal", tint: task.completedAt == nil ? .orange : .green)
                }
            }

            Section("Insumos internos") {
                ForEach(viewModel.supplyRequests) { request in
                    ModuleRow(title: request.itemName, detail: "\(request.branch.shortName) - Urgencia \(request.urgency.displayName)", systemImage: "exclamationmark.bubble", tint: request.urgency == .high ? .red : .blue)
                }
            }
        }
        .navigationTitle("Operaciones")
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
    }
}

/// Gestion de pagos y conciliacion de vouchers o transferencias.
struct PaymentsView: View {
    @StateObject private var viewModel = PaymentsViewModel()

    var body: some View {
        List {
            Section("Conciliacion manual") {
                if viewModel.isLoading {
                    ProgressView()
                }

                ForEach(viewModel.reconciliations) { reconciliation in
                    ModuleRow(
                        title: reconciliation.saleFolio,
                        detail: "\(reconciliation.branch.shortName) - \(reconciliation.method.displayName) - \(reconciliation.evidenceFileName)",
                        systemImage: reconciliation.isMatched ? "checkmark.shield" : "doc.badge.clock",
                        tint: reconciliation.isMatched ? .green : .orange
                    )
                }
            }
        }
        .navigationTitle("Pagos")
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
    }
}

/// Crea un Binding reutilizable para alertas de error.
@MainActor
func errorBinding(for viewModel: LoadableViewModel) -> Binding<Bool> {
    Binding(
        get: { viewModel.errorMessage != nil },
        set: { isPresented in
            if !isPresented {
                viewModel.clearError()
            }
        }
    )
}
