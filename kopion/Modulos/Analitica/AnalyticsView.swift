//
//  AnalyticsView.swift
//  kopion / Modules / Analytics
//
//  Módulo 3: Analítica, alertas y ML de tóner/stock.
//  Semáforo visual (verde/naranja/rojo), proyección de agotamiento y base para PDF de stock bajo.
//

import Combine
import SwiftUI

struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()

    var body: some View {
        List {

            // MARK: Semáforo operativo (verde = OK, naranja/rojo = atención)
            Section("Semáforo operativo") {
                if viewModel.isLoading { ProgressView() }

                if let snapshot = viewModel.snapshot {
                    ModuleRow(
                        title: "Tóner",
                        detail: snapshot.tonerAlertCount > 0 ? "Atención requerida" : "Nivel estable",
                        systemImage: "printer",
                        tint: snapshot.tonerAlertCount > 0 ? .red : .green
                    )
                    ModuleRow(
                        title: "Stock bajo",
                        detail: "\(snapshot.lowStockCount) artículos requieren resurtido",
                        systemImage: "shippingbox",
                        tint: snapshot.lowStockCount > 0 ? .orange : .green
                    )
                    ModuleRow(
                        title: "PDF automático",
                        detail: "Base lista para generar reporte de stock bajo",
                        systemImage: "doc.badge.gearshape",
                        tint: .blue
                    )
                }
            }

            // MARK: Proyección de agotamiento (modelo aritmético inicial)
            Section("Proyección de agotamiento") {
                ForEach(viewModel.lowStockProducts) { product in
                    ModuleRow(
                        title: product.name,
                        detail: "Modelo aritmético: revisar resurtido esta semana",
                        systemImage: "chart.xyaxis.line",
                        tint: .purple
                    )
                }
            }
        }
        .navigationTitle("Analítica")
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
    }
}
