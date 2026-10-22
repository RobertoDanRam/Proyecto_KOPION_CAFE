//
//  PaymentsView.swift
//  kopion / Modulos / Pagos
//

import Combine
import SwiftUI

struct PaymentsView: View {
    @StateObject private var viewModel = PaymentsViewModel()

    var body: some View {
        List {

            Section("Conciliación manual") {
                if viewModel.estaCargando { ProgressView() }

                ForEach(viewModel.conciliaciones) { item in
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
        .task { viewModel.cargar() }
        .onDisappear { viewModel.cancelar() }
    }
}
