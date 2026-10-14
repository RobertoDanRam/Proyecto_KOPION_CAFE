//
//  ViewHelpers.swift
//  kopion / Core / Extensions
//
//  Utilidades compartidas por todas las vistas:
//  - CurrencyFormatter: formatea Decimal a pesos mexicanos.
//  - errorBinding: crea un Binding<Bool> para alertas de error en cualquier LoadableViewModel.
//  - MetricTile / ModuleRow / SectionHeader: componentes visuales reutilizables.
//

import Combine
import SwiftUI

// MARK: - Formateo de moneda

/// Convierte un Decimal al formato de pesos mexicanos (ej. $1,250.00).
enum CurrencyFormatter {
    static func pesos(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "MXN"
        formatter.locale = Locale(identifier: "es_MX")
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
}

// MARK: - Binding de error reutilizable

/// Genera un Binding<Bool> que se activa cuando el ViewModel tiene un errorMessage.
/// Permite usar .alert() en cualquier vista sin repetir lógica.
@MainActor
func errorBinding(for viewModel: LoadableViewModel) -> Binding<Bool> {
    Binding(
        get: { viewModel.errorMessage != nil },
        set: { isPresented in
            if !isPresented { viewModel.clearError() }
        }
    )
}

// MARK: - Componentes visuales compartidos

/// Tarjeta compacta de métrica para dashboards (ventas, caja, alertas, etc.).
struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Fila con ícono, título y detalle. Usada en listas de todos los módulos.
struct ModuleRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
        }
        .padding(.vertical, 6)
    }
}

/// Encabezado de sección dentro de pantallas de trabajo.
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}
