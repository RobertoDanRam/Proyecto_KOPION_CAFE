//
//  AnalyticsView.swift
//  kopion / Modulos / Analitica
//

import Combine
import SwiftUI

struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()

    var body: some View {
        List {

            Section("Semáforo operativo") {
                if viewModel.estaCargando { ProgressView() }

                if let resumen = viewModel.resumen {
                    ModuleRow(
                        title: "Tóner",
                        detail: resumen.tonerAlertCount > 0 ? "Atención requerida" : "Nivel estable",
                        systemImage: "printer",
                        tint: resumen.tonerAlertCount > 0 ? .red : .green
                    )
                    ModuleRow(
                        title: "Stock bajo",
                        detail: "\(resumen.lowStockCount) artículos requieren resurtido",
                        systemImage: "shippingbox",
                        tint: resumen.lowStockCount > 0 ? .orange : .green
                    )
                    ModuleRow(
                        title: "PDF automático",
                        detail: "Base lista para generar reporte de stock bajo",
                        systemImage: "doc.badge.gearshape",
                        tint: .blue
                    )
                }
            }

            Section("Proyección de agotamiento") {
                ForEach(viewModel.productosStockBajo) { producto in
                    ModuleRow(
                        title: producto.name,
                        detail: "Modelo aritmético: revisar resurtido esta semana",
                        systemImage: "chart.xyaxis.line",
                        tint: .purple
                    )
                }
            }
        }
        .navigationTitle("Analítica")
        .task { viewModel.cargar() }
        .onDisappear { viewModel.cancelar() }
    }
}
