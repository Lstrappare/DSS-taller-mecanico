import SwiftUI
import LocalAuthentication

struct LoginView: View {
    
    // --- Almacenamiento de la App ---
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    
    // Datos del Usuario
    @AppStorage("user_dni") private var userDni = ""     // Ahora guarda RFC
    @AppStorage("user_email") private var userEmail = ""
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true
    @AppStorage("user_recovery_key") private var userRecoveryKey = "" // Llave de recuperación

    // --- States de la Vista ---
    @State private var loginInput = "" // Acepta Email o RFC
    @State private var password = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // --- States para Modales de Recuperación ---
    @State private var showingRecoveryModal = false    // Modal 1: Pide la llave
    @State private var recoveryKeyAttempt = ""
    @State private var recoveryRfcAttempt = ""
    @State private var recoveryError = ""
    
    @State private var showingResetPasswordModal = false // Modal 2: Pide nueva pass
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    var body: some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "car.fill").font(.system(size: 40)).foregroundColor(Color("MercedesPetrolGreen"))
                Text("Sistema de soporte de decisiones").font(.title).fontWeight(.bold).foregroundColor(.white)
                Text("para taller mecánico").font(.title2).foregroundColor(.white).padding(.bottom, 30)
                
                VStack(alignment: .leading, spacing: 15) {
                    TextField("Email o RFC", text: $loginInput)
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
                    Text("o").foregroundColor(.gray).padding(.top)
                    Button { Task { await authenticateWithTouchID() } }
                    label: { Image(systemName: "touchid").font(.largeTitle).foregroundColor(.gray) }
                    .buttonStyle(.plain)
                }
            }
            .padding(50)
            .frame(width: 450, height: 520)
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
        ZZTitledModal(title: "Recuperar Cuenta") {
            VStack(spacing: 12) {
                Text("Ingresa tu RFC y tu Llave de Recuperación de 16 dígitos.")
                    .font(.headline).foregroundColor(.gray).multilineTextAlignment(.center)
                
                TextField("RFC", text: $recoveryRfcAttempt)
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
        }
        .onAppear { recoveryError = "" }
    }
    
    // --- VISTA DEL MODAL 2: RESETEAR CONTRASEÑA ---
    @ViewBuilder
    func resetPasswordModalView() -> some View {
        ZZTitledModal(title: "Establecer Nueva Contraseña") {
            VStack(spacing: 12) {
                Text("Ingresa tu nueva contraseña.")
                    .font(.headline).foregroundColor(.gray).multilineTextAlignment(.center)
                
                SecureField("Nueva Contraseña", text: $newPassword)
                SecureField("Confirmar Nueva Contraseña", text: $confirmPassword)
                
                if !newPassword.isEmpty && newPassword.count < 8 {
                    Text("La contraseña debe tener al menos 8 caracteres.")
                        .font(.caption).foregroundColor(.yellow)
                }
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
                .disabled(!canSaveNewPassword)
            }
        }
    }
    
    private var canSaveNewPassword: Bool {
        return !newPassword.isEmpty && newPassword == confirmPassword && newPassword.count >= 8
    }

    // --- LÓGICA DE LOGIN ---
    func login() {
        let emailMatch = loginInput.lowercased() == userEmail.lowercased() && !userEmail.isEmpty
        let rfcMatch = loginInput.uppercased() == userDni.uppercased() && !userDni.isEmpty
        
        if (emailMatch || rfcMatch) && password == userPassword {
            isLoggedIn = true
        } else {
            errorMessage = "Email/RFC o contraseña incorrectos."
            showingError = true
        }
    }
    
    // --- LÓGICA DE RECUPERACIÓN ---
    func validateRecoveryKey() {
        // Comparamos los inputs (ignorando espacios en la llave)
        let keyAttempt = recoveryKeyAttempt.replacingOccurrences(of: " ", with: "")
        let savedKey = userRecoveryKey.replacingOccurrences(of: " ", with: "")
        
        if keyAttempt == savedKey && !savedKey.isEmpty && recoveryRfcAttempt.uppercased() == userDni.uppercased() {
            showingRecoveryModal = false
            showingResetPasswordModal = true
        } else {
            recoveryError = "RFC o Llave de Recuperación incorrectos."
        }
    }
    
    func setNewPassword() {
        userPassword = newPassword
        showingResetPasswordModal = false
        isLoggedIn = true
    }
    
    // --- LÓGICA DE TOUCH ID ---
    func authenticateWithTouchID() async {
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

// Reutilizamos el medidor ya definido en RegisterView (mismo archivo/alcance si comparten módulo).
// Si da error de símbolo duplicado, mueve el PasswordStrength y PasswordStrengthMeter a un archivo compartido.

fileprivate struct ZZTitledModal<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 20) {
                Text(title).font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                content()
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
}
