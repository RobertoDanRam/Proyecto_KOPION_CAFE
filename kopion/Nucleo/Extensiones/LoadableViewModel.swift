//
//  LoadableViewModel.swift
//  kopion / Nucleo / Extensiones
//
//  Clase base para todos los ViewModels del proyecto.
//  Centraliza el estado de carga, envío y mensajes de error,
//  evitando duplicar estas propiedades en cada módulo.
//

import Combine
import Foundation

/// ViewModel base con estado de carga, envío y error compartido.
/// Todos los ViewModels de módulo heredan de esta clase.
@MainActor
class LoadableViewModel: ObservableObject {
    /// Indica que hay una carga de datos en progreso (GET / fetch).
    @Published var estaCargando = false

    /// Indica que hay una acción de escritura en progreso (POST / mutación).
    /// Deshabilita botones de envío para evitar dobles taps.
    @Published var estaEnviando = false

    /// Mensaje de error visible para el usuario. nil = sin error activo.
    @Published var mensajeError: String?

    /// Limpia el error activo (llamado al cerrar la alerta).
    func limpiarError() {
        mensajeError = nil
    }
}
