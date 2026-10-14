//
//  POSView.swift
//  kopion / Modules / POS
//
//  Módulo 5: POS exclusivo de empleados.
//  Cobro rápido, pistola lectora, ventas recientes, devoluciones y cambios.
//  El botón de cobro se deshabilita con isSubmitting para evitar doble registro.
//

import Combine
import SwiftUI

struct POSView: View {
    @StateObject private var viewModel = POSViewModel()

    var body: some View {
        List {

            // MARK: Sucursal y cobro rápido
            Section("Sucursal y cobro") {
                Picker("Sucursal", selection: $viewModel.selectedBranch) {
                    ForEach(Branch.allCases) { branch in
                        Text(branch.shortName).tag(branch)
                    }
                }

                TextField("Pago recibido", text: $viewModel.paidAmountText)
                    .keyboardType(.decimalPad)

                // Botón deshabilitado mientras isSubmitting para evitar doble cobro.
                Button {
                    viewModel.registerSampleSale()
                } label: {
                    Label(
                        viewModel.isSubmitting ? "Cobrando…" : "Registrar venta rápida",
                        systemImage: "cart.badge.plus"
                    )
                }
                .disabled(viewModel.isSubmitting)

                if viewModel.isSubmitting {
                    ProgressView("Registrando venta")
                }
            }

            // MARK: Flujos POS disponibles
            Section("Flujos POS") {
                ModuleRow(title: "Pistola lectora", detail: "Preparado para entrada por código de barras", systemImage: "barcode.viewfinder", tint: .blue)
                ModuleRow(title: "Cantidad al agregar", detail: "Base para preguntar cantidad por producto", systemImage: "number", tint: .orange)
                ModuleRow(title: "Devoluciones y cambios", detail: "Motivos, ajuste de caja y diferencias de precio", systemImage: "arrow.triangle.2.circlepath", tint: .purple)
            }

            // MARK: Ventas recientes (reimpresión y pre-corte)
            Section("Ventas recientes") {
                if viewModel.isLoading { ProgressView() }

                ForEach(viewModel.recentSales) { sale in
                    ModuleRow(
                        title: sale.folio,
                        detail: "\(sale.branch.shortName) · \(CurrencyFormatter.pesos(sale.total)) · Cambio: \(CurrencyFormatter.pesos(sale.changeDue))",
                        systemImage: "ticket",
                        tint: .green
                    )
                }
            }
        }
        .navigationTitle("POS")
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
        .alert("Aviso", isPresented: errorBinding(for: viewModel)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
