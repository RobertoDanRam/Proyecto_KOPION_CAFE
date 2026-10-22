//
//  CatalogView.swift
//  kopion / Modulos / Catalogo
//

import Combine
import SwiftUI

struct CatalogView: View {
    @StateObject private var viewModel = CatalogViewModel()

    var body: some View {
        List {

            Section("Sucursal") {
                Picker("Sucursal", selection: $viewModel.sucursalSeleccionada) {
                    ForEach(Branch.allCases) { sucursal in
                        Text(sucursal.displayName).tag(sucursal)
                    }
                }
            }

            Section("Productos") {
                if viewModel.estaCargando { ProgressView() }

                ForEach(viewModel.productos) { producto in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(producto.name).font(.headline)
                        Text(producto.category)
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Text(CurrencyFormatter.pesos(producto.price(for: viewModel.sucursalSeleccionada)))
                            Spacer()
                            Text("Stock: \(producto.stock(for: viewModel.sucursalSeleccionada))")
                                .foregroundStyle(
                                    producto.isLowStock(at: viewModel.sucursalSeleccionada) ? .red : .secondary
                                )
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Catálogo")
        .searchable(text: $viewModel.textoBusqueda, prompt: "Buscar producto o código")
        .task { viewModel.cargar() }
        .onDisappear { viewModel.cancelar() }
    }
}
