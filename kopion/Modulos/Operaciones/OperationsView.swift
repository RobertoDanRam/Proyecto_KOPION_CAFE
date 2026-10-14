//
//  OperationsView.swift
//  kopion / Modules / Operations
//
//  Módulo 6: Recepción de mercancía, RRHH y comunicación interna.
//  Checklist de limpieza con evidencia, peticiones de insumos, vales de caja y checador.
//

import Combine
import SwiftUI

struct OperationsView: View {
    @StateObject private var viewModel = OperationsViewModel()

    var body: some View {
        List {

            // MARK: Recepción y herramientas de comunicación
            Section("Recepción y comunicación") {
                ModuleRow(title: "One-click approval", detail: "Empleados escanean entradas · dueña aprueba remoto", systemImage: "checkmark.circle", tint: .green)
                ModuleRow(title: "Checador", detail: "Entrada/salida con foto del lugar de trabajo (cámara, no galería)", systemImage: "clock.badge.checkmark", tint: .blue)
                ModuleRow(title: "Vales de caja", detail: "Salidas para proveedores o adelantos de nómina", systemImage: "person.text.rectangle", tint: .orange)
            }

            // MARK: Checklist de limpieza con evidencia
            Section("Checklist de limpieza") {
                if viewModel.isLoading { ProgressView() }

                ForEach(viewModel.cleaningTasks) { item in
                    ModuleRow(
                        title: item.title,
                        detail: "\(item.branch.shortName) · \(item.shift.displayName) · \(item.evidenceDescription)",
                        systemImage: item.completedAt == nil ? "camera" : "checkmark.seal",
                        tint: item.completedAt == nil ? .orange : .green
                    )
                }
            }

            // MARK: Peticiones de insumos internos
            Section("Insumos internos") {
                ForEach(viewModel.supplyRequests) { request in
                    ModuleRow(
                        title: request.itemName,
                        detail: "\(request.branch.shortName) · Urgencia \(request.urgency.displayName)",
                        systemImage: "exclamationmark.bubble",
                        tint: request.urgency == .high ? .red : .blue
                    )
                }
            }
        }
        .navigationTitle("Operaciones")
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
    }
}
