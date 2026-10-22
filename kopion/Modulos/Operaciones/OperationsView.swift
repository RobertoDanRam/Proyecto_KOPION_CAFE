//
//  OperationsView.swift
//  kopion / Modulos / Operaciones
//

import Combine
import SwiftUI

struct OperationsView: View {
    @StateObject private var viewModel = OperationsViewModel()

    var body: some View {
        List {

            Section("Recepción y comunicación") {
                ModuleRow(title: "One-click approval", detail: "Empleados escanean entradas · dueña aprueba remoto", systemImage: "checkmark.circle", tint: .green)
                ModuleRow(title: "Checador", detail: "Entrada/salida con foto del lugar de trabajo (cámara, no galería)", systemImage: "clock.badge.checkmark", tint: .blue)
                ModuleRow(title: "Vales de caja", detail: "Salidas para proveedores o adelantos de nómina", systemImage: "person.text.rectangle", tint: .orange)
            }

            Section("Checklist de limpieza") {
                if viewModel.estaCargando { ProgressView() }

                ForEach(viewModel.tareasLimpieza) { tarea in
                    ModuleRow(
                        title: tarea.title,
                        detail: "\(tarea.branch.shortName) · \(tarea.shift.displayName) · \(tarea.evidenceDescription)",
                        systemImage: tarea.completedAt == nil ? "camera" : "checkmark.seal",
                        tint: tarea.completedAt == nil ? .orange : .green
                    )
                }
            }

            Section("Insumos internos") {
                ForEach(viewModel.solicitudesInsumos) { solicitud in
                    ModuleRow(
                        title: solicitud.itemName,
                        detail: "\(solicitud.branch.shortName) · Urgencia \(solicitud.urgency.displayName)",
                        systemImage: "exclamationmark.bubble",
                        tint: solicitud.urgency == .high ? .red : .blue
                    )
                }
            }
        }
        .navigationTitle("Operaciones")
        .task { viewModel.cargar() }
        .onDisappear { viewModel.cancelar() }
    }
}
