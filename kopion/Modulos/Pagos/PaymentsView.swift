//
//  PaymentsView.swift
//  kopion / Modules / Payments
//
//  Módulo 7: Gestión de pagos y conciliación manual.
//  Fase 1: vinculación manual de capturas de transferencias o vouchers al folio de venta.
//

import Combine
import SwiftUI

struct PaymentsView: View {
    @StateObject private var viewModel = PaymentsViewModel()

    var body: some View {
        List {

            // MARK: Conciliaciones manuales por folio
            Section("Conciliación manual") {
                if viewModel.isLoading { ProgressView() }

                ForEach(viewModel.reconciliations) { item in
                    ModuleRow(
                        title: item.saleFolio,
                        detail: "\(item.branch.shortName) · \(item.method.displayName) · \(item.evidenceFileName)",
                        systemImage: item.isMatched ? "checkmark.shield" : "doc.badge.clock",
                        tint: item.isMatched ? .green : .orange
                    )
                }
            }
        }
        .navigationTitle("Pagos")
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
    }
}
