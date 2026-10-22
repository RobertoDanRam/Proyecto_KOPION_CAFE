//
//  AdminDashboardView.swift
//  kopion / Modulos / PanelAdministrador
//

import Combine
import SwiftUI

struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminDashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                if viewModel.estaCargando {
                    ProgressView("Cargando dashboard")
                        .frame(maxWidth: .infinity, minHeight: 120)
                }

                if let resumen = viewModel.resumen {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                        spacing: 12
                    ) {
                        MetricTile(
                            title: "Ventas del día",
                            value: CurrencyFormatter.pesos(resumen.todaySalesAmount),
                            systemImage: "chart.line.uptrend.xyaxis",
                            tint: .green
                        )
                        MetricTile(
                            title: "Efectivo en caja",
                            value: CurrencyFormatter.pesos(resumen.cashInDrawer),
                            systemImage: "banknote",
                            tint: .blue
                        )
                        MetricTile(
                            title: "Engargolados pendientes",
                            value: "\(resumen.pendingBindingJobs)",
                            systemImage: "doc.on.doc",
                            tint: .orange
                        )
                        MetricTile(
                            title: "Alertas stock / tóner",
                            value: "\(resumen.lowStockCount + resumen.tonerAlertCount)",
                            systemImage: "exclamationmark.triangle",
                            tint: .red
                        )
                    }

                    SectionHeader(title: "Prioridad media")
                    VStack(alignment: .leading, spacing: 10) {
                        ModuleRow(
                            title: "Top productos",
                            detail: resumen.topProductNames.joined(separator: ", "),
                            systemImage: "star",
                            tint: .yellow
                        )
                        ModuleRow(
                            title: "Cotizaciones pendientes",
                            detail: "\(resumen.pendingQuotes) prospectos por dar seguimiento",
                            systemImage: "person.2",
                            tint: .purple
                        )
                    }
                }

                SectionHeader(title: "Stock bajo por sucursal")
                ForEach(viewModel.productosStockBajo) { producto in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(producto.name).font(.headline)
                        ForEach(Branch.allCases) { sucursal in
                            if producto.isLowStock(at: sucursal) {
                                Text("\(sucursal.shortName): \(producto.stock(for: sucursal)) unidades")
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
        .task { viewModel.cargar() }
        .onDisappear { viewModel.cancelar() }
        .alert("Aviso", isPresented: enlaceError(para: viewModel)) {
            Button("OK") { viewModel.limpiarError() }
        } message: {
            Text(viewModel.mensajeError ?? "")
        }
    }
}
