import SwiftUI
import LocalAuthentication

struct LoginView: View {
    
    // --- Almacenamiento de la App ---
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    
    // Datos del Usuario
    @AppStorage("user_dni") private var userDni = ""
    @AppStorage("user_email") private var userEmail = ""
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true
    @AppStorage("user_recovery_key") private var userRecoveryKey = "" // <-- La Llave

    // --- States de la Vista ---
    @State private var loginInput = "" // Acepta Email o DNI
    @State private var password = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // --- States para Modales de Recuperación ---
    @State private var showingRecoveryModal = false    // Modal 1: Pide la llave
    @State private var recoveryKeyAttempt = ""
    @State private var recoveryDniAttempt = ""
    @State private var recoveryError = ""
    
    @State private var showingResetPasswordModal = false // Modal 2: Pide nueva pass
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    var body: some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 20) {
                // ... (VStack de Login - no cambia) ...
                Image(systemName: "car.fill").font(.system(size: 40)).foregroundColor(Color("MercedesPetrolGreen"))
                Text("Sistema de soporte de decisiones").font(.title).fontWeight(.bold).foregroundColor(.white)
                Text("para taller mecánico").font(.title2).foregroundColor(.white).padding(.bottom, 30)
                
                VStack(alignment: .leading, spacing: 15) {
                    TextField("Email o DNI/CURP", text: $loginInput)
                    SecureField("Password", text: $password)
                }
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                
                Button { login() }
                label: {
                    Text("Login")
                        .font(.headline).padding(.vertical, 12).frame(maxWidth: .infinity)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.top)
                
                // Botón de Recuperación
                Button("Olvidé mi contraseña") {
                    showingRecoveryModal = true // Abre el Modal 1
                }
                .buttonStyle(.plain)
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.top, 5)

                if isTouchIDEnabled {
                    // ... (Sección de Touch ID - no cambia) ...
                    Text("o").foregroundColor(.gray).padding(.top)
                    Button { Task { await authenticateWithTouchID() } }
                    label: { Image(systemName: "touchid").font(.largeTitle).foregroundColor(.gray) }
                    .buttonStyle(.plain)
                }
            }
            .padding(50)
            .frame(width: 450, height: 500)
        }
        .alert("Error de Inicio de Sesión", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage) }
        
        // --- Modales de Recuperación ---
        .sheet(isPresented: $showingRecoveryModal) {
            recoveryModalView() // Modal 1
        }
        .sheet(isPresented: $showingResetPasswordModal) {
            resetPasswordModalView() // Modal 2
        }
        .onAppear {
            if isTouchIDEnabled {
                Task { await authenticateWithTouchID() }
            }
        }
    }
    
    // --- VISTA DEL MODAL 1: PEDIR LLAVE ---
    @ViewBuilder
    func recoveryModalView() -> some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Recuperar Cuenta")
                    .font(.largeTitle).fontWeight(.bold)
                Text("Ingresa tu DNI/CURP y tu Llave de Recuperación de 16 dígitos.")
                    .font(.headline).foregroundColor(.gray).multilineTextAlignment(.center)
                
                TextField("DNI/CURP", text: $recoveryDniAttempt)
                TextField("Llave de Recuperación (ej. A1B2 - ...)", text: $recoveryKeyAttempt)
                
                if !recoveryError.isEmpty {
                    Text(recoveryError).font(.caption).foregroundColor(.red)
                }
                
                Button {
                    validateRecoveryKey()
                } label: {
                    Text("Verificar")
                        .font(.headline).padding().frame(maxWidth: .infinity)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }.buttonStyle(.plain)
            }
            .padding(40)
        }
        .frame(minWidth: 500, minHeight: 350)
        .preferredColorScheme(.dark)
        .textFieldStyle(PlainTextFieldStyle())
        .padding(12)
        .background(Color("MercedesCard"))
        .cornerRadius(8)
        .onAppear { recoveryError = "" }
    }
    
    // --- VISTA DEL MODAL 2: RESETEAR CONTRASEÑA ---
    @ViewBuilder
    func resetPasswordModalView() -> some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Establecer Nueva Contraseña")
                    .font(.largeTitle).fontWeight(.bold)
                Text("Ingresa tu nueva contraseña.")
                    .font(.headline).foregroundColor(.gray).multilineTextAlignment(.center)
                
                SecureField("Nueva Contraseña", text: $newPassword)
                SecureField("Confirmar Nueva Contraseña", text: $confirmPassword)
                
                if !newPassword.isEmpty && newPassword != confirmPassword {
                    Text("Las contraseñas no coinciden.")
                        .font(.caption).foregroundColor(.red)
                }
                
                Button {
                    setNewPassword()
                } label: {
                    Text("Guardar y Entrar")
                        .font(.headline).padding().frame(maxWidth: .infinity)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }.buttonStyle(.plain)
                .disabled(newPassword.isEmpty || newPassword != confirmPassword)
            }
            .padding(40)
        }
        .frame(minWidth: 500, minHeight: 350)
        .preferredColorScheme(.dark)
        .textFieldStyle(PlainTextFieldStyle())
        .padding(12)
        .background(Color("MercedesCard"))
        .cornerRadius(8)
    }

    
    // --- LÓGICA DE LOGIN (Actualizada) ---
    func login() {
        let emailMatch = loginInput.lowercased() == userEmail.lowercased() && !userEmail.isEmpty
        let dniMatch = loginInput == userDni && !userDni.isEmpty
        
        if (emailMatch || dniMatch) && password == userPassword {
            isLoggedIn = true
        } else {
            errorMessage = "Email/DNI o contraseña incorrectos."
            showingError = true
        }
    }
    
    // --- LÓGICA DE RECUPERACIÓN (Actualizada) ---
    func validateRecoveryKey() {
        // Comparamos los inputs (ignorando espacios en la llave)
        let keyAttempt = recoveryKeyAttempt.replacingOccurrences(of: " ", with: "")
        let savedKey = userRecoveryKey.replacingOccurrences(of: " ", with: "")
        
        if keyAttempt == savedKey && !savedKey.isEmpty && recoveryDniAttempt == userDni {
            // ¡Éxito! Cierra Modal 1, Abre Modal 2
            showingRecoveryModal = false
            showingResetPasswordModal = true
        } else {
            recoveryError = "DNI o Llave de Recuperación incorrectos."
        }
    }
    
    func setNewPassword() {
        // Guarda la nueva contraseña
        userPassword = newPassword
        
        // Cierra el modal y loguea al usuario
        showingResetPasswordModal = false
        isLoggedIn = true
    }
    
    // --- LÓGICA DE TOUCH ID (Sin cambios) ---
    func authenticateWithTouchID() async {
        // ... (Esta lógica es idéntica a la que teníamos)
        guard isTouchIDEnabled, !userDni.isEmpty else { return }
        let context = LAContext()
        let reason = "Inicia sesión con tu huella para acceder al DSS."
        do {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                if success {
                    await MainActor.run { isLoggedIn = true }
                }
            }
        } catch {
            print("Autenticación fallida o cancelada.")
        }
    }
}
