//
//  CustomerPortalView.swift
//  kopion / Modules / CustomerPortal
//
//  Módulo 2: Portal cliente (CRM y tienda digital).
//  Muestra el carrusel de promociones, la tienda/cotizador y el estado de pedidos.
//  El carrito global separa pedidos por sucursal (Kopion ESCA, CECyT 1, ESE Café).
//

import Combine
import SwiftUI

struct CustomerPortalView: View {
    @StateObject private var viewModel = CustomerPortalViewModel()

    var body: some View {
        List {

            // MARK: Carrusel de promociones (gestionado por la dueña)
            Section("Promociones") {
                ForEach(viewModel.promotions, id: \.self) { promo in
                    ModuleRow(title: promo, detail: "Gestionado por administración", systemImage: "tag", tint: .pink)
                }
            }

            // MARK: Tienda digital y cotizador
            Section("Tienda y cotizador") {
                ModuleRow(title: "Engargolados", detail: "Precio dinámico por cantidad de hojas", systemImage: "book.closed", tint: .blue)
                ModuleRow(title: "Enmicados", detail: "Credencial, media carta y carta", systemImage: "rectangle.on.rectangle", tint: .cyan)
                ModuleRow(title: "Copias por volumen", detail: "50-99 a $0.70 · más de 100 a $0.50", systemImage: "doc.on.doc", tint: .green)
                ModuleRow(title: "Escaneos", detail: "$3.00 por página", systemImage: "scanner", tint: .orange)
                ModuleRow(title: "Carrito global", detail: "Separa pedidos por sucursal automáticamente", systemImage: "cart", tint: .indigo)
            }

            // MARK: Pedidos y trabajos especiales
            Section("Pedidos") {
                if viewModel.isLoading { ProgressView() }

                ForEach(viewModel.workOrders) { order in
                    ModuleRow(
                        title: order.folio,
                        detail: "\(order.customerName) · \(order.branch.shortName) · \(order.status.displayName)",
                        systemImage: "tray.full",
                        tint: .indigo
                    )
                }
            }
        }
        .navigationTitle("Portal cliente")
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
    }
}
