//
//  LoadableViewModel.swift
//  kopion / Core / Extensions
//
//  Clase base para todos los ViewModels del proyecto.
//  Centraliza el estado de carga (isLoading), envío (isSubmitting) y mensajes de error,
//  evitando duplicar estas propiedades en cada módulo.
//

import Combine
import Foundation

/// ViewModel base con estado de carga, envío y error compartido.
/// Todos los ViewModels de módulo heredan de esta clase.
/// Combine es necesario para que @Published funcione en archivos separados.
@MainActor
class LoadableViewModel: ObservableObject {
    /// Indica que hay una carga de datos en progreso (GET / fetch).
    @Published var isLoading = false

    /// Indica que hay una acción de escritura en progreso (POST / mutación).
    /// Deshabilita botones de envío para evitar dobles taps.
    @Published var isSubmitting = false

    /// Mensaje de error visible para el usuario. nil = sin error activo.
    @Published var errorMessage: String?

    /// Limpia el error activo (llamado al cerrar la alerta).
    func clearError() {
        errorMessage = nil
    }
}
