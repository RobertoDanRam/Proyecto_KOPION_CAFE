//
//  kopionApp.swift
//  kopion
//
//  Punto de entrada de la app.
//  - FirebaseApp.configure() inicializa Firebase con GoogleService-Info.plist.
//  - AuthManager se crea aquí y se inyecta como EnvironmentObject para que
//    ContentView reaccione automáticamente a login, logout y restauración de sesión.
//  - onOpenURL reenvía el callback de Google Sign-In al SDK para completar el flujo OAuth.
//

import FirebaseCore
import GoogleSignIn
import SwiftData
import SwiftUI

@main
struct kopionApp: App {

    // Una sola instancia compartida de AuthManager para toda la app.
    @StateObject private var authManager = AuthManager.shared

    init() {
        // Inicializa Firebase antes de cualquier uso de Auth, Firestore o Analytics.
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inyecta AuthManager en el árbol de vistas.
                // ContentView y cualquier vista hija pueden leerlo con @EnvironmentObject.
                .environmentObject(authManager)
                .modelContainer(for: PedidoLocal.self)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
