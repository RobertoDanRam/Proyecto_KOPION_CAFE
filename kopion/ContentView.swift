//
//  ContentView.swift
//  kopion
//
//  Entrada principal de la app.
//  La primera pantalla que ve cualquier usuario es Acceso Login; los módulos quedan
//  protegidos para abrirse después de autenticar y resolver el rol del usuario.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            AccesoLoginView()
        }
    }
}

#Preview {
    ContentView()
}
