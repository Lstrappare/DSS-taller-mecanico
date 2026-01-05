//
//  AuthView.swift
//  DSS
//
// Copyright © 2026 José Manuel Cisneros Valero
// Licensed under the Apache License, Version 2.0

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
