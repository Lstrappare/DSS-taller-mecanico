//
//  RegisterView.swift
//  DSS
//
// Copyright © 2026 José Manuel Cisneros Valero
// Licensed under the Apache License, Version 2.0

import SwiftUI
import LocalAuthentication
import AppKit

struct CustomField: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    var systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                TextField(placeholder, text: $text)
                    .disableAutocorrection(true)
            }
            .padding(12)
            .cornerRadius(8)
        }
    }
}

struct CustomSecureField: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    var systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                SecureField(placeholder, text: $text)
            }
            .padding(12)
            .cornerRadius(8)
        }
    }
}

struct RegisterView: View {
    
    // --- Almacenamiento de la App ---
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("hasCompletedRegistration") private var hasCompletedRegistration = false
    
    // Datos del Usuario
    @AppStorage("user_name") private var userName = ""
    @AppStorage("user_dni") private var userDni = "" // Guardará RFC a partir de ahora
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("user_recovery_key") private var userRecoveryKey = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true

    // --- States de la Vista ---
    @State private var fullName = ""
    @State private var rfc = "" // reemplaza dni/CURP
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // --- ESTADO DE ERROR ---
    @State private var errorMsg: String?
    
    @State private var showingRecoveryKeyModal = false
    @State private var showingTouchIDPrompt = false
    
    // States del Modal de Llave
    @State private var keyToDisplay = ""
    @State private var recoveryKeyCheckbox = false
    @State private var copiedFeedback = false

    var body: some View {
        ZStack {
            Color("MercedesBackground")
                .ignoresSafeArea()

            VStack(spacing: 25) {
                // --- Encabezado ---
                VStack(spacing: 8) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color("MercedesPetrolGreen"))
                        .shadow(color: Color("MercedesPetrolGreen").opacity(0.4), radius: 6, x: 0, y: 3)
                    
                    Text("Crear Cuenta de Administrador")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Este es el único administrador del negocio.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // --- Formulario ---
                VStack(spacing: 16) {
                    CustomField(title: "Nombre Completo:", placeholder: "Ej. José Cisneros Torres", text: $fullName, systemImage: "person.fill")
                    CustomField(title: "RFC (Persona Física 13 / Moral 12):", placeholder: "Ej. GODE561231GR8", text: $rfc, systemImage: "textformat.123")
                    
                    VStack(spacing: 8) {
                        CustomSecureField(title: "Contraseña:", placeholder: "********", text: $password, systemImage: "lock.fill")
                    }
                    
                    CustomSecureField(title: "Confirmar Contraseña:", placeholder: "********", text: $confirmPassword, systemImage: "lock.rotation")
                    
                    if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                        Text("⚠️ Las contraseñas no coinciden")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                    if !password.isEmpty && password.count < 8 {
                        Text("La contraseña debe tener al menos 8 caracteres.")
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .padding(.top, 2)
                    }
                }
                .padding(20)
                .background(Color("MercedesCard").opacity(0.95))
                .cornerRadius(15)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 6)
                .padding(.horizontal)

                // --- Error general ---
                if let errorMsg {
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 5)
                }

                Button {
                    register()
                } label: {
                    Text("Registrarse")
                        .font(.headline).padding(.vertical, 12).frame(maxWidth: 500)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain).padding(.top)
                .disabled(!canSubmit)
            }
            .padding(50)
            .frame(width: 450, height: 620)
        }
        // --- MODALES ---
        .sheet(isPresented: $showingRecoveryKeyModal) {
            recoveryKeyModalView()
        }
        .sheet(isPresented: $showingTouchIDPrompt) {
            touchIDPromptModal()
        }
    }
    
    private var canSubmit: Bool {
        return !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !rfc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !password.isEmpty &&
               password == confirmPassword &&
               password.count >= 8
    }
    
    // --- LÓGICA DE REGISTRO ---
    func register() {
        errorMsg = nil
        
        // Validación de Nombre
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameParts = trimmedName.split(separator: " ").filter { !$0.isEmpty }
        let regex = "^[A-Za-zÁÉÍÓÚáéíóúÑñ ]+$"
        
        if !NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmedName) {
            errorMsg = "El nombre solo debe contener letras y espacios."
            return
        }
        if nameParts.count < 2 {
            errorMsg = "El nombre completo debe tener al menos 2 palabras (ej. José Cisneros Torres)."
            return
        }
        for part in nameParts {
            if part.count < 3 {
                errorMsg = "Cada palabra debe tener al menos 3 letras (ej. Max Verstappen Torres)."
                return
            }
        }
        
        // Validación de RFC (ultra estricta)
        let rfcTrimmed = rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard RFCValidator.isValidRFC(rfcTrimmed) else {
            errorMsg = "El RFC no es válido. Verifica estructura, fecha y dígito verificador."
            return
        }
        
        // Validación básica de contraseña (longitud mínima)
        guard password.count >= 8 else {
            errorMsg = "La contraseña debe tener al menos 8 caracteres."
            return
        }
        
        // Guarda los datos en AppStorage
        userName = fullName
        userDni = rfcTrimmed
        userPassword = password
        
        // Muestra el modal de llave
        showingRecoveryKeyModal = true
    }
    
    // --- VISTA DEL MODAL DE LLAVE ---
    @ViewBuilder
    func recoveryKeyModalView() -> some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 20) {
                Text("¡IMPORTANTE!")
                    .font(.largeTitle).fontWeight(.bold)
                    .foregroundColor(.yellow)
                Text("Guarda tu Llave de Recuperación")
                    .font(.title2).fontWeight(.bold).foregroundColor(.white)
                HStack(spacing: 15) {
                    Text(keyToDisplay)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        copyToClipboard(text: keyToDisplay)
                        copiedFeedback = true
                    } label: {
                        Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.title)
                            .foregroundColor(copiedFeedback ? .green : Color("MercedesPetrolGreen"))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                Text("Esta es la ÚNICA forma de recuperar tu cuenta si olvidas tu contraseña y no tienes Touch ID. Cópiala o anótala en un lugar seguro.")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.bottom)
                Toggle(isOn: $recoveryKeyCheckbox) {
                    Text("He guardado mi llave en un lugar seguro.")
                        .foregroundColor(.white)
                }
                .toggleStyle(.switch)
                Button {
                    showingRecoveryKeyModal = false
                    showingTouchIDPrompt = true
                } label: {
                    Label("Continuar", systemImage: "arrow.right.circle.fill")
                        .font(.headline).padding().frame(maxWidth: .infinity)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!recoveryKeyCheckbox)
            }
            .padding(40)
        }
        .frame(minWidth: 500, minHeight: 480)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .onAppear {
            let newKey = generateRecoveryKey()
            keyToDisplay = newKey
            userRecoveryKey = newKey
            copiedFeedback = false
            recoveryKeyCheckbox = false
        }
    }
    
    // --- VISTA DEL MODAL DE HUELLA ---
    @ViewBuilder
    func touchIDPromptModal() -> some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 20) {
                Text("¿Activar Touch ID?").font(.largeTitle).fontWeight(.bold)
                Image(systemName: "touchid").font(.system(size: 50)).foregroundColor(Color("MercedesPetrolGreen")).padding()
                Text("¿Quieres usar la huella guardada en esta Mac para iniciar sesión y autorizar acciones?")
                    .font(.headline).foregroundColor(.gray).multilineTextAlignment(.center).padding(.bottom)
                Button { Task { await enableTouchIDAndLogin() } }
                label: {
                    Label("Activar y Entrar", systemImage: "checkmark.seal.fill")
                        .font(.headline).padding().frame(maxWidth: .infinity)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }.buttonStyle(.plain)
                Button {
                    isTouchIDEnabled = false
                    hasCompletedRegistration = true
                    isLoggedIn = true
                } label: {
                    Text("No por ahora, solo iniciar sesión").font(.headline).foregroundColor(.gray)
                }.buttonStyle(.plain)
            }
            .padding(40)
        }
        .frame(minWidth: 500, minHeight: 450)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }
    
    // --- LÓGICA DE HABILITAR HUELLA ---
    func enableTouchIDAndLogin() async {
        let context = LAContext()
        let reason = "Verifica tu huella para activar Touch ID en DSS."
        do {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                await MainActor.run {
                    isTouchIDEnabled = true
                    hasCompletedRegistration = true
                    isLoggedIn = true
                }
            }
        } catch {
            print("Touch ID no se pudo vincular: \(error.localizedDescription)")
            await MainActor.run {
                isTouchIDEnabled = false
                hasCompletedRegistration = true
                isLoggedIn = true
            }
        }
    }
    
    // --- GENERADOR DE LLAVE ---
    func generateRecoveryKey() -> String {
        let segments = (1...4).map { _ in
            (1...4).map { _ in
                String("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()!)
            }.joined()
        }
        return segments.joined(separator: " - ")
    }
    
    // --- FUNCIÓN DE COPIAR ---
    func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
