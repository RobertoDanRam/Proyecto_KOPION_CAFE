//
//  MisPedidosView.swift
//  kopion / Modulos / PortalCliente
//
//  Pedidos en vivo (nube) + historial local (SwiftData).
//  Arquitectura CRM: solo los pedidos "vivos" viven en el servidor.
//  Al completarse se persisten localmente y se eliminan de la cola activa.
//

import Combine
import SwiftData
import SwiftUI

// MARK: - Modelo local SwiftData

@Model
final class PedidoLocal {
    var id: String
    var folio: String
    var nombreArchivo: String
    var fechaEntrega: Date
    var sucursal: String
    var calificacion: Int?

    init(id: String, folio: String, nombreArchivo: String, fechaEntrega: Date, sucursal: String) {
        self.id = id
        self.folio = folio
        self.nombreArchivo = nombreArchivo
        self.fechaEntrega = fechaEntrega
        self.sucursal = sucursal
    }
}

// MARK: - Vista principal

struct MisPedidosView: View {
    @Query(sort: \PedidoLocal.fechaEntrega, order: .reverse) private var historial: [PedidoLocal]
    @Environment(\.modelContext) private var contexto
    @StateObject private var vm = MisPedidosViewModel()

    var body: some View {
        List {
            // Pedidos en vivo
            if !vm.pedidosVivos.isEmpty {
                Section("En curso") {
                    ForEach(vm.pedidosVivos) { orden in
                        FilaPedidoVivo(orden: orden)
                    }
                }
            }

            // Historial local
            Section(historial.isEmpty ? "" : "Historial local") {
                if historial.isEmpty {
                    ContentUnavailableView(
                        "Sin historial",
                        systemImage: "tray",
                        description: Text("Tus pedidos completados aparecerán aquí")
                    )
                } else {
                    ForEach(historial) { pedido in
                        FilaPedidoLocal(pedido: pedido)
                    }
                }
            }
        }
        .navigationTitle("Mis pedidos")
        .overlay { if vm.cargando { ProgressView() } }
        .task { await vm.cargarPedidosVivos() }
        .onChange(of: vm.pedidoParaArchivar) { _, orden in
            guard let orden else { return }
            archivarLocalmente(orden)
            vm.pedidoParaArchivar = nil
        }
    }

    private func archivarLocalmente(_ orden: WorkOrder) {
        let local = PedidoLocal(
            id: orden.id.uuidString,
            folio: orden.folio,
            nombreArchivo: orden.documents.first?.fileName ?? "—",
            fechaEntrega: .now,
            sucursal: orden.branch.displayName
        )
        contexto.insert(local)
    }
}

// MARK: - Subvistas

private struct FilaPedidoVivo: View {
    let orden: WorkOrder

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(colorEstatus(orden.status))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(orden.folio).font(.headline)
                Text(orden.documents.first?.fileName ?? "—")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(orden.status.displayName)
                .font(.caption)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(colorEstatus(orden.status).opacity(0.15))
                .foregroundStyle(colorEstatus(orden.status))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private func colorEstatus(_ status: WorkOrderStatus) -> Color {
        switch status {
        case .received:  .blue
        case .designing: .purple
        case .printing:  .orange
        case .ready:     .green
        case .delivered: .gray
        }
    }
}

private struct FilaPedidoLocal: View {
    let pedido: PedidoLocal
    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(pedido.folio).font(.headline)
                Spacer()
                if let cal = pedido.calificacion {
                    Label("\(cal)", systemImage: "star.fill")
                        .font(.caption).foregroundStyle(.yellow)
                }
            }
            Text(pedido.nombreArchivo).font(.subheadline).foregroundStyle(.secondary)
            Text(Self.fmt.string(from: pedido.fechaEntrega))
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - ViewModel

@MainActor
final class MisPedidosViewModel: ObservableObject {
    @Published private(set) var pedidosVivos: [WorkOrder] = []
    @Published var pedidoParaArchivar: WorkOrder?
    @Published private(set) var cargando = false

    func cargarPedidosVivos() async {
        cargando = true
        // Simula fetch de Firebase: solo estados "vivos"
        try? await Task.sleep(nanoseconds: 300_000_000)
        pedidosVivos = SampleData.workOrders.filter {
            [.received, .designing, .printing, .ready].contains($0.status)
        }
        cargando = false
    }
}
