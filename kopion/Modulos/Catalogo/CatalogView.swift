//
//  CatalogView.swift
//  kopion / Modules / Catalog
//
//  Módulo 4: Catálogo centralizado.
//  Muestra productos con precio y stock diferenciados por sucursal.
//  La barra de búsqueda usa debounce de 0.5 s vía CatalogViewModel.
//

import Combine
import SwiftUI

struct CatalogView: View {
    @StateObject private var viewModel = CatalogViewModel()

    var body: some View {
        List {

            // MARK: Selector de sucursal — cambia precios y stock
            Section("Sucursal") {
                Picker("Sucursal", selection: $viewModel.selectedBranch) {
                    ForEach(Branch.allCases) { branch in
                        Text(branch.displayName).tag(branch)
                    }
                }
            }

            // MARK: Lista de productos
            Section("Productos") {
                if viewModel.isLoading { ProgressView() }

                ForEach(viewModel.products) { product in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(product.name).font(.headline)
                        Text(product.category)
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Text(CurrencyFormatter.pesos(product.price(for: viewModel.selectedBranch)))
                            Spacer()
                            // Stock en rojo si está por debajo del punto de reorden.
                            Text("Stock: \(product.stock(for: viewModel.selectedBranch))")
                                .foregroundStyle(
                                    product.isLowStock(at: viewModel.selectedBranch) ? .red : .secondary
                                )
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Catálogo")
        .searchable(text: $viewModel.searchText, prompt: "Buscar producto o código")
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
    }
}
