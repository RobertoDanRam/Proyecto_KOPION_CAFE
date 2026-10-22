//
//  ConfiguracionImpresionView.swift
//  kopion / Modulos / PreparacionImpresion
//
//  Configuración de impresión: copias, tamaño, color y cara.
//  Puede aplicarse a un documento individual o a todos (configuración global).
//

import QuickLook
import SwiftUI

// MARK: - Configuración individual de un documento

struct ConfiguracionDocumentoView: View {
    @ObservedObject var viewModel: PrintPreparationViewModel
    let idDocumento: UUID
    @Environment(\.dismiss) private var cerrar

    private var indice: Int? {
        viewModel.documentos.firstIndex { $0.id == idDocumento }
    }

    private var config: ConfiguracionImpresion {
        indice.map { viewModel.documentos[$0].configuracion } ?? ConfiguracionImpresion()
    }

    var body: some View {
        NavigationStack {
            Form {
                if let doc = indice.map({ viewModel.documentos[$0] }) {
                    Section("Documento") {
                        LabeledContent("Archivo", value: doc.nombre)
                        LabeledContent("Páginas", value: "\(doc.numeroPaginas)")
                    }
                }

                SeccionConfiguracion(
                    config: Binding(
                        get: { config },
                        set: { nueva in
                            if let idx = indice {
                                viewModel.documentos[idx].configuracion = nueva
                            }
                        }
                    ),
                    tamañosDisponibles: viewModel.tamañosDisponibles
                )

                Section("Costo estimado") {
                    if let idx = indice {
                        let doc = viewModel.documentos[idx]
                        LabeledContent("Páginas × copias", value: "\(doc.numeroPaginas) × \(doc.configuracion.copias)")
                        LabeledContent("Precio por página", value: "$\(doc.configuracion.modoColor.precioPorPagina(tamaño: doc.configuracion.tamañoPagina))")
                        LabeledContent("Subtotal") {
                            Text("$\(doc.costoTotal)")
                                .fontWeight(.semibold)
                                .foregroundStyle(.purple)
                        }
                    }
                }
            }
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                }
            }
        }
    }
}

// MARK: - Configuración global

struct ConfiguracionGlobalView: View {
    @ObservedObject var viewModel: PrintPreparationViewModel
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Aplicar a todos los documentos", isOn: $viewModel.usarConfiguracionGlobal)
                }

                SeccionConfiguracion(
                    config: $viewModel.configuracionGlobal,
                    tamañosDisponibles: viewModel.tamañosDisponibles
                )

                Section {
                    Button {
                        viewModel.aplicarConfiguracionGlobalATodos()
                        cerrar()
                    } label: {
                        Label("Aplicar a todos", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Configuración global")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
            }
        }
    }
}

// MARK: - Sección reutilizable de controles

struct SeccionConfiguracion: View {
    @Binding var config: ConfiguracionImpresion
    let tamañosDisponibles: [TamañoPagina]

    var body: some View {
        Section("Impresión") {
            Stepper("Copias: \(config.copias)", value: $config.copias, in: 1...99)

            Picker("Tamaño de hoja", selection: $config.tamañoPagina) {
                ForEach(tamañosDisponibles) { t in
                    Text(t.rawValue).tag(t)
                }
            }

            Picker("Color", selection: $config.modoColor) {
                ForEach(ModoColor.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }

            Picker("Caras", selection: $config.modoCara) {
                ForEach(ModoCara.allCases) { c in
                    Text(c.rawValue).tag(c)
                }
            }
        }

        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Precios de impresión")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Group {
                    Text("• Carta — B/N $1 · Color $5")
                    Text("• Oficio — B/N $2 · Color $7")
                    Text("• Doble carta — B/N $4 · Color $10")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text("Precio por página impresa, no por hoja.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Resumen final del pedido

struct ResumenPedidoView: View {
    @ObservedObject var viewModel: PrintPreparationViewModel
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            Form {
                // Código de seguimiento.
                Section("Tu código de seguimiento") {
                    HStack {
                        Text(viewModel.codigoSeguimiento)
                            .font(.title2.weight(.bold).monospaced())
                            .foregroundStyle(.purple)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = viewModel.codigoSeguimiento
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                    }
                    Text("Guarda este código para rastrear tu pedido en sucursal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Previsualización del PDF.
                if let url = viewModel.urlPDFFinal {
                    Section("Vista previa") {
                        VistaPreviaPDF(url: url)
                            .frame(height: 280)
                            .listRowInsets(.init())
                    }
                }

                // Resumen de documentos.
                Section("Documentos (\(viewModel.documentos.count))") {
                    ForEach(viewModel.documentos) { doc in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(doc.nombre)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            HStack {
                                Text("\(doc.numeroPaginas) pág · \(doc.configuracion.copias) cop · \(doc.configuracion.modoColor.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("$\(doc.costoTotal)")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Sucursal destino — bloqueada al perfil del usuario.
                Section("Enviar a") {
                    if let sucursalFija = viewModel.sucursalFija {
                        LabeledContent("Sucursal", value: sucursalFija.displayName)
                        Text("La sucursal se asigna automáticamente según tu perfil.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Sucursal", selection: $viewModel.sucursalDestino) {
                            ForEach(Branch.allCases) { s in
                                Text(s.displayName).tag(s)
                            }
                        }
                    }
                }

                // Total.
                Section {
                    HStack {
                        Text("Total estimado")
                            .font(.headline)
                        Spacer()
                        Text("$\(viewModel.costoTotal)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.purple)
                    }
                    Text("Total de páginas: \(viewModel.totalPaginas)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Botón enviar.
                Section {
                    Button {
                        viewModel.enviarPedido()
                        cerrar()
                    } label: {
                        Label("Confirmar y enviar pedido", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Resumen del pedido")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
            }
        }
    }
}
