//
//  AdminDashboardView.swift
//  kopion / Modules / Dashboard
//
//  Dashboard principal del administrador.
//  Prioridades visuales según el prompt:
//  ALTA  → ventas del día, caja, pedidos pendientes, alertas stock/tóner.
//  MEDIA → top 5 productos, cotizaciones pendientes.
//  BAJA  → accesos directos (menú secundario, fuera de esta pantalla).
//

import Combine
import SwiftUI

struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminDashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                // MARK: Indicador de carga
                if viewModel.isLoading {
                    ProgressView("Cargando dashboard")
                        .frame(maxWidth: .infinity, minHeight: 120)
                }

                // MARK: Prioridad ALTA — métricas del día
                if let snapshot = viewModel.snapshot {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                        spacing: 12
                    ) {
                        MetricTile(
                            title: "Ventas del día",
                            value: CurrencyFormatter.pesos(snapshot.todaySalesAmount),
                            systemImage: "chart.line.uptrend.xyaxis",
                            tint: .green
                        )
                        MetricTile(
                            title: "Efectivo en caja",
                            value: CurrencyFormatter.pesos(snapshot.cashInDrawer),
                            systemImage: "banknote",
                            tint: .blue
                        )
                        MetricTile(
                            title: "Engargolados pendientes",
                            value: "\(snapshot.pendingBindingJobs)",
                            systemImage: "doc.on.doc",
                            tint: .orange
                        )
                        MetricTile(
                            title: "Alertas stock / tóner",
                            value: "\(snapshot.lowStockCount + snapshot.tonerAlertCount)",
                            systemImage: "exclamationmark.triangle",
                            tint: .red
                        )
                    }

                    // MARK: Prioridad MEDIA — widgets
                    SectionHeader(title: "Prioridad media")
                    VStack(alignment: .leading, spacing: 10) {
                        ModuleRow(
                            title: "Top productos",
                            detail: snapshot.topProductNames.joined(separator: ", "),
                            systemImage: "star",
                            tint: .yellow
                        )
                        ModuleRow(
                            title: "Cotizaciones pendientes",
                            detail: "\(snapshot.pendingQuotes) prospectos por dar seguimiento",
                            systemImage: "person.2",
                            tint: .purple
                        )
                    }
                }

                // MARK: Stock bajo por sucursal
                SectionHeader(title: "Stock bajo por sucursal")
                ForEach(viewModel.lowStockProducts) { product in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(product.name).font(.headline)
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
