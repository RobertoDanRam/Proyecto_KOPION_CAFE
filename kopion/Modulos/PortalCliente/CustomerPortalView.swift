//
//  CustomerPortalView.swift
//  kopion / Modulos / PortalCliente
//

import Combine
import SwiftData
import SwiftUI

struct CustomerPortalView: View {
    let usuario: UserProfile
    @StateObject private var modeloVista = CustomerPortalViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Perfil de usuario
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: "person.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(usuario.nombreCompleto)
                            .font(.headline)
                        Text(usuario.correo)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Acciones principales
                VStack(spacing: 14) {
                    // Enviar archivos
                    NavigationLink { PrintPreparationView() } label: {
                        TarjetaAccion(
                            titulo: "Enviar archivos",
                            subtitulo: "Manda a la cola de impresión",
                            sistemaImagen: "paperplane.fill",
                            color: .blue
                        ) {}
                    }
                    .buttonStyle(.plain)

                    // Mis pedidos y estatus
                    NavigationLink { MisPedidosView() } label: {
                        TarjetaAccion(
                            titulo: "Mis pedidos y estatus",
                            subtitulo: "Consulta tu historial y estado actual",
                            sistemaImagen: "tray.full",
                            color: .indigo
                        ) {}
                    }
                    .buttonStyle(.plain)

                    // Catálogo y cotizador
                    NavigationLink { CatalogView() } label: {
                        TarjetaAccion(
                            titulo: "Catálogo y cotizador",
                            subtitulo: "Explora productos y precios",
                            sistemaImagen: "list.bullet.rectangle.portrait",
                            color: .green
                        ) {}
                    }
                    .buttonStyle(.plain)

                    // Atención y sugerencias
                    NavigationLink { AtencionSugerenciasView() } label: {
                        TarjetaAccion(
                            titulo: "Atención y sugerencias",
                            subtitulo: "Buzón de quejas y comentarios",
                            sistemaImagen: "bubble.left.and.bubble.right.fill",
                            color: .orange
                        ) {}
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Portal cliente")
        .task { modeloVista.cargar() }
        .onDisappear { modeloVista.cancelar() }
    }
}

struct TarjetaAccion: View {
    // Propiedades
    let titulo: String
    let subtitulo: String?
    let sistemaImagen: String
    let color: Color
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: sistemaImagen)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let subtitulo {
                        Text(subtitulo)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
