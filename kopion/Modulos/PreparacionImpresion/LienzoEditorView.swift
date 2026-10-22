//
//  LienzoEditorView.swift
//  kopion / Modulos / PreparacionImpresion
//
//  Lienzo interactivo para posicionar y redimensionar imágenes sobre una hoja.
//

import SwiftUI

struct LienzoEditorView: View {
    @ObservedObject var viewModel: PrintPreparationViewModel
    let idDocumento: UUID
    @State private var imagenSeleccionada: UUID?

    private var documento: DocumentoAdjunto? {
        viewModel.documentos.first { $0.id == idDocumento }
    }

    var body: some View {
        GeometryReader { geo in
            if let doc = documento {
                let tamHoja = doc.configuracion.tamañoPagina.tamaño
                let escala  = escalaParaContenedor(geo.size, hoja: tamHoja)
                let ancho   = tamHoja.width  * escala
                let alto    = tamHoja.height * escala

                ScrollView([.horizontal, .vertical]) {
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: ancho, height: alto)
                            .shadow(color: .black.opacity(0.18), radius: 6, x: 2, y: 2)
                            .onTapGesture { imagenSeleccionada = nil }

                        ForEach(doc.imagenesLienzo) { item in
                            ImagenLienzoItem(
                                item:             item,
                                escala:           escala,
                                estaSeleccionada: imagenSeleccionada == item.id,
                                onSeleccionar:    { imagenSeleccionada = item.id },
                                onMover: { delta in
                                    viewModel.moverImagenEnLienzo(
                                        idDoc:    idDocumento,
                                        idImagen: item.id,
                                        a: CGPoint(
                                            x: item.posicion.x + delta.width  / escala,
                                            y: item.posicion.y + delta.height / escala
                                        )
                                    )
                                },
                                onRedimensionar: { delta in
                                    viewModel.redimensionarImagenEnLienzo(
                                        idDoc:    idDocumento,
                                        idImagen: item.id,
                                        tamaño: CGSize(
                                            width:  item.tamaño.width  + delta.width  / escala,
                                            height: item.tamaño.height + delta.height / escala
                                        )
                                    )
                                },
                                onEliminar: {
                                    viewModel.eliminarImagenEnLienzo(idDoc: idDocumento, idImagen: item.id)
                                }
                            )
                        }
                    }
                    .frame(width: ancho, height: alto)
                    .padding(16)
                }
                .background(Color(.systemGroupedBackground))
            } else {
                ContentUnavailableView("Sin documento", systemImage: "doc.badge.questionmark")
            }
        }
    }

    private func escalaParaContenedor(_ contenedor: CGSize, hoja: CGSize) -> CGFloat {
        let margen: CGFloat = 32
        let eAncho = (contenedor.width  - margen) / hoja.width
        let eAlto  = (contenedor.height - margen) / hoja.height
        return min(eAncho, eAlto, 1.0)
    }
}

// MARK: - Item de imagen

private struct ImagenLienzoItem: View {
    let item: ImagenEnLienzo
    let escala: CGFloat
    let estaSeleccionada: Bool
    let onSeleccionar: () -> Void
    let onMover: (CGSize) -> Void
    let onRedimensionar: (CGSize) -> Void
    let onEliminar: () -> Void

    @GestureState private var arrastre: CGSize = .zero
    @GestureState private var redimension: CGSize = .zero

    var body: some View {
        let anchoE = item.tamaño.width  * escala
        let altoE  = item.tamaño.height * escala
        let xE     = item.posicion.x    * escala
        let yE     = item.posicion.y    * escala

        ZStack(alignment: .bottomTrailing) {
            Image(uiImage: item.imagen)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: anchoE + redimension.width, height: altoE + redimension.height)
                .clipped()
                .rotationEffect(item.rotacion)
                .overlay(estaSeleccionada
                    ? RoundedRectangle(cornerRadius: 2).stroke(Color.accentColor, lineWidth: 2)
                    : nil)
                .gesture(DragGesture()
                    .updating($arrastre) { v, s, _ in s = v.translation }
                    .onEnded { v in onMover(v.translation) })
                .onTapGesture { onSeleccionar() }

            if estaSeleccionada {
                Button(action: onEliminar) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .red)
                }
                .offset(x: 12, y: -anchoE + 12)

                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .padding(6)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
                    .gesture(DragGesture()
                        .updating($redimension) { v, s, _ in s = v.translation }
                        .onEnded { v in onRedimensionar(v.translation) })
            }
        }
        .offset(
            x: xE - anchoE / 2 + arrastre.width,
            y: yE - altoE  / 2 + arrastre.height
        )
        .position(x: 0, y: 0)
    }
}
