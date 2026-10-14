//
//  kopionApp.swift
//  kopion
//
//  Created by Roberto Daniel Ramos Flores on 23/09/26.
//

import FirebaseCore
import SwiftUI

@main
struct kopionApp: App {
    /// Inicializa Firebase al arrancar la app.
    /// Firebase lee GoogleService-Info.plist para conectar con tu proyecto.
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
