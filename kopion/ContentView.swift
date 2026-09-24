//
//  ContentView.swift
//  kopion
//
//  Pantalla inicial de Kopion.
//  Presenta el acceso a todos los modulos solicitados y deja visible que la app
//  opera con sucursales separadas para precios, stock y pedidos.
//

import SwiftUI

/// Modulos principales definidos en el alcance del proyecto.
enum AppModule: String, CaseIterable, Identifiable {
    case dashboard
    case printPreparation
    case customerPortal
    case analytics
    case catalog
    case pos
    case operations
    case payments

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard administrador"
        case .printPreparation:
            return "PDF e impresion"
        case .customerPortal:
            return "Portal cliente"
        case .analytics:
            return "Analitica y alertas"
        case .catalog:
            return "Catalogo centralizado"
        case .pos:
            return "POS empleados"
        case .operations:
            return "Recepcion y RRHH"
        case .payments:
            return "Gestion de pagos"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard:
            return "Ventas, caja, pedidos, stock bajo y toner"
        case .printPreparation:
            return "Conversion, fusion, compresion y canvas"
        case .customerPortal:
            return "CRM, tienda digital, promociones y pedidos"
        case .analytics:
            return "Tinta, stock, regresion basica y reportes PDF"
        case .catalog:
            return "Productos, codigos, imagenes, precios y stock"
        case .pos:
            return "Cobro rapido, tickets, cambios y devoluciones"
        case .operations:
            return "Mercancia, limpieza, insumos, vales y checador"
        case .payments:
            return "Transferencias, vouchers y folios de venta"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "rectangle.grid.2x2"
        case .printPreparation:
            return "doc.richtext"
        case .customerPortal:
            return "person.crop.circle.badge.checkmark"
        case .analytics:
            return "chart.xyaxis.line"
        case .catalog:
            return "shippingbox"
        case .pos:
            return "cart"
        case .operations:
            return "checklist"
        case .payments:
            return "creditcard"
        }
    }

    var tint: Color {
        switch self {
        case .dashboard:
            return .blue
        case .printPreparation:
            return .purple
        case .customerPortal:
            return .pink
        case .analytics:
            return .green
        case .catalog:
            return .orange
        case .pos:
            return .indigo
        case .operations:
            return .teal
        case .payments:
            return .mint
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Sucursales") {
                    ForEach(Branch.allCases) { branch in
                        ModuleRow(
                            title: branch.displayName,
                            detail: "Precios, stock, ventas y pedidos se calculan por separado",
                            systemImage: "storefront",
                            tint: .blue
                        )
                    }
                }

                Section("Modulos") {
                    ForEach(AppModule.allCases) { module in
                        NavigationLink(value: module) {
                            ModuleRow(
                                title: module.title,
                                detail: module.subtitle,
                                systemImage: module.systemImage,
                                tint: module.tint
                            )
                        }
                    }
                }

                Section("Reglas base activas") {
                    ModuleRow(title: "Concurrencia", detail: "isLoading, isSubmitting, cancelacion y debounce por busqueda", systemImage: "bolt.horizontal.circle", tint: .yellow)
                    ModuleRow(title: "Red segura", detail: "Idempotencia, bloqueo de duplicados, 429 y Retry-After", systemImage: "network.badge.shield.half.filled", tint: .green)
                    ModuleRow(title: "Fase 1 pagos", detail: "Conciliacion manual de transferencias y vouchers", systemImage: "doc.text.magnifyingglass", tint: .orange)
                }
            }
            .navigationTitle("Kopion")
            .navigationDestination(for: AppModule.self) { module in
                destination(for: module)
            }
        }
    }

    /// Enruta cada modulo a su vista principal.
    @ViewBuilder
    private func destination(for module: AppModule) -> some View {
        switch module {
        case .dashboard:
            AdminDashboardView()
        case .printPreparation:
            PrintPreparationView()
        case .customerPortal:
            CustomerPortalView()
        case .analytics:
            AnalyticsView()
        case .catalog:
            CatalogView()
        case .pos:
            POSView()
        case .operations:
            OperationsView()
        case .payments:
            PaymentsView()
        }
    }
}

#Preview {
    ContentView()
}
