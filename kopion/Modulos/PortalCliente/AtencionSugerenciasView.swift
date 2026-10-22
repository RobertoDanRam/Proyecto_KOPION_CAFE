//
//  AtencionSugerenciasView.swift
//  kopion / Modulos / PortalCliente
//
//  Buzón de quejas/comentarios + flujo proactivo de calificación (estilo Uber).
//  La bandera UserNeedsToRate se guarda en UserDefaults y se dispara al abrir la vista.
//

import Combine
import SwiftUI

// MARK: - Vista principal

struct AtencionSugerenciasView: View {
    @StateObject private var vm = AtencionViewModel()

    var body: some View {
        List {
            Section("Nuevo mensaje") {
                FormularioSugerencia(vm: vm)
            }

            Section("Historial") {
                if vm.mensajes.isEmpty {
                    Text("Aún no has enviado mensajes.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(vm.mensajes) { msg in
                        FilaMensaje(mensaje: msg)
                    }
                }
            }
        }
        .navigationTitle("Atención y sugerencias")
        .sheet(isPresented: $vm.mostrarCalificacion) {
            ModalCalificacion(vm: vm)
                .presentationDetents([.medium])
        }
        .onAppear { vm.verificarCalificacionPendiente() }
    }
}

// MARK: - Formulario

private struct FormularioSugerencia: View {
    @ObservedObject var vm: AtencionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Tipo", selection: $vm.tipoSeleccionado) {
                ForEach(TipoMensaje.allCases) { tipo in
                    Text(tipo.displayName).tag(tipo)
                }
            }
            .pickerStyle(.segmented)

            TextField("Describe tu comentario o queja…", text: $vm.textoMensaje, axis: .vertical)
                .lineLimit(4...6)

            Button {
                vm.enviarMensaje()
            } label: {
                Label("Enviar", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.textoMensaje.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Fila historial

private struct FilaMensaje: View {
    let mensaje: MensajeCliente
    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(mensaje.tipo.displayName, systemImage: mensaje.tipo.icono)
                    .font(.caption)
                    .foregroundStyle(mensaje.tipo.color)
                Spacer()
                Text(Self.fmt.string(from: mensaje.fecha))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            Text(mensaje.texto).font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Modal calificación (estilo Uber)

struct ModalCalificacion: View {
    @ObservedObject var vm: AtencionViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("¡Tu pedido en Kopion ESCA está listo!")
                .font(.title3).bold().multilineTextAlignment(.center)

            Text("¿Cómo calificarías tu experiencia hoy?")
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { estrella in
                    Button {
                        vm.estrellaSeleccionada = estrella
                    } label: {
                        Image(systemName: estrella <= vm.estrellaSeleccionada ? "star.fill" : "star")
                            .font(.system(size: 36))
                            .foregroundStyle(.yellow)
                    }
                    .buttonStyle(.plain)
                }
            }

            if vm.estrellaSeleccionada > 0 && vm.estrellaSeleccionada <= 3 {
                TextField("Lamentamos eso. ¿Qué podemos mejorar?", text: $vm.comentarioCalificacion, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...5)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if vm.estrellaSeleccionada > 0 {
                Button("Enviar calificación") {
                    vm.enviarCalificacion()
                }
                .buttonStyle(.borderedProminent)
                .transition(.opacity)
            }
        }
        .padding(28)
        .animation(.easeInOut, value: vm.estrellaSeleccionada)
    }
}

// MARK: - Modelos locales

enum TipoMensaje: String, CaseIterable, Identifiable {
    case queja, sugerencia, felicitacion

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .queja:        "Queja"
        case .sugerencia:   "Sugerencia"
        case .felicitacion: "Felicitación"
        }
    }

    var icono: String {
        switch self {
        case .queja:        "exclamationmark.bubble"
        case .sugerencia:   "lightbulb"
        case .felicitacion: "hand.thumbsup"
        }
    }

    var color: Color {
        switch self {
        case .queja:        .red
        case .sugerencia:   .blue
        case .felicitacion: .green
        }
    }
}

struct MensajeCliente: Identifiable {
    let id = UUID()
    let tipo: TipoMensaje
    let texto: String
    let fecha: Date
}

// MARK: - ViewModel

@MainActor
final class AtencionViewModel: ObservableObject {
    @Published var tipoSeleccionado: TipoMensaje = .sugerencia
    @Published var textoMensaje = ""
    @Published var mensajes: [MensajeCliente] = []

    // Calificación proactiva
    @Published var mostrarCalificacion = false
    @Published var estrellaSeleccionada = 0
    @Published var comentarioCalificacion = ""

    private let llaveCalificacion = "UserNeedsToRate"

    func verificarCalificacionPendiente() {
        if UserDefaults.standard.bool(forKey: llaveCalificacion) {
            mostrarCalificacion = true
        }
    }

    func enviarMensaje() {
        let texto = textoMensaje.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texto.isEmpty else { return }
        mensajes.insert(MensajeCliente(tipo: tipoSeleccionado, texto: texto, fecha: .now), at: 0)
        textoMensaje = ""
    }

    func enviarCalificacion() {
        // Aquí se enviaría la calificación a Firebase
        UserDefaults.standard.set(false, forKey: llaveCalificacion)
        mostrarCalificacion = false
        estrellaSeleccionada = 0
        comentarioCalificacion = ""
    }

    /// Llamar cuando un pedido cambia a "Entregado" para activar el modal la próxima vez.
    static func marcarPedidoEntregado() {
        UserDefaults.standard.set(true, forKey: "UserNeedsToRate")
    }
}
