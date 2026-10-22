//
//  POSView.swift
//  kopion / Modulos / PuntoDeVenta
//

import Combine
import SwiftUI

struct POSView: View {
    @StateObject private var viewModel = POSViewModel()

    var body: some View {
        List {

            Section("Sucursal y cobro") {
                Picker("Sucursal", selection: $viewModel.sucursalSeleccionada) {
                    ForEach(Branch.allCases) { sucursal in
                        Text(sucursal.shortName).tag(sucursal)
                    }
                }

                TextField("Pago recibido", text: $viewModel.textoPagoRecibido)
                    .keyboardType(.decimalPad)

                Button {
                    viewModel.registrarVentaRapida()
                } label: {
                    Label(
                        viewModel.estaEnviando ? "Cobrando…" : "Registrar venta rápida",
                        systemImage: "cart.badge.plus"
                    )
                }
                .disabled(viewModel.estaEnviando)

                if viewModel.estaEnviando {
                    ProgressView("Registrando venta")
                }
            }

            Section("Flujos POS") {
                ModuleRow(title: "Pistola lectora", detail: "Preparado para entrada por código de barras", systemImage: "barcode.viewfinder", tint: .blue)
                ModuleRow(title: "Cantidad al agregar", detail: "Base para preguntar cantidad por producto", systemImage: "number", tint: .orange)
                ModuleRow(title: "Devoluciones y cambios", detail: "Motivos, ajuste de caja y diferencias de precio", systemImage: "arrow.triangle.2.circlepath", tint: .purple)
            }

            Section("Ventas recientes") {
                if viewModel.estaCargando { ProgressView() }

                ForEach(viewModel.ventasRecientes) { venta in
                    ModuleRow(
                        title: venta.folio,
                        detail: "\(venta.branch.shortName) · \(CurrencyFormatter.pesos(venta.total)) · Cambio: \(CurrencyFormatter.pesos(venta.changeDue))",
                        systemImage: "ticket",
                        tint: .green
                    )
                }
            }
        }
        .navigationTitle("POS")
        .task { viewModel.cargar() }
        .onDisappear { viewModel.cancelar() }
        .alert("Aviso", isPresented: enlaceError(para: viewModel)) {
            Button("OK") { viewModel.limpiarError() }
        } message: {
            Text(viewModel.mensajeError ?? "")
        }
    }
}
