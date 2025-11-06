//
//  AuthView.swift
//  DSS
//
//  Created by Jose Cisneros on 04/11/25.
//

import SwiftUI

struct AuthView: View {
    // Controla si mostramos Login (false) o Register (true)
    @State private var showingRegisterView = false
    
    var body: some View {
        if showingRegisterView {
            // Muestra la vista de Registro
            RegisterView()
        } else {
            // Muestra la vista de Login
            LoginView()
        }
    }
}
