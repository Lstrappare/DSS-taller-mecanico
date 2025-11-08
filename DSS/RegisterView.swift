import SwiftUI
import LocalAuthentication
import AppKit

struct RegisterView: View {
    
    // --- Almacenamiento de la App ---
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("hasCompletedRegistration") private var hasCompletedRegistration = false
    
    // Datos del Usuario
    @AppStorage("user_name") private var userName = ""
    @AppStorage("user_dni") private var userDni = ""
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("user_recovery_key") private var userRecoveryKey = ""

    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true

    // --- States de la Vista ---
    @State private var fullName = ""
    @State private var dni = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    @State private var showingError = false
    @State private var errorMessage = ""
    
    @State private var showingRecoveryKeyModal = false
    @State private var showingTouchIDPrompt = false
    
    // --- States del Modal de Llave ---
    @State private var keyToDisplay = "" // <-- La variable que mostrará la llave
    @State private var recoveryKeyCheckbox = false
    @State private var copiedFeedback = false

    var body: some View {
        ZStack {
            // ... (VStack de Registro - no cambia) ...
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "car.fill").font(.system(size: 40)).foregroundColor(Color("MercedesPetrolGreen"))
                Text("Sistema de soporte de deciciones").font(.title).fontWeight(.bold).foregroundColor(.white)
                Text("Crear Cuenta de Administrador del Taller.").font(.body).foregroundColor(.gray).padding(.bottom, 20)
                
                VStack(alignment: .leading, spacing: 15) {
                    TextField("Nombre Completo", text: $fullName)
                    TextField("DNI/CURP", text: $dni)
                    SecureField("Contraseña", text: $password)
                    SecureField("Repita su Contraseña", text: $confirmPassword)
                    
                    if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Las contraseñas no coinciden")
                            .font(.caption).foregroundColor(.red)
                    }
                }
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                
                Button {
                    register()
                } label: {
                    Text("Registro del taller")
                        .font(.headline).padding(.vertical, 12).frame(maxWidth: .infinity)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain).padding(.top)
                .disabled(password.isEmpty || password != confirmPassword)
            }
            .padding(50)
            .frame(width: 450, height: 550)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage) }
        
        // --- MODALES ---
        .sheet(isPresented: $showingRecoveryKeyModal) {
            recoveryKeyModalView() // 1. Muestra la llave
        }
        .sheet(isPresented: $showingTouchIDPrompt) {
            touchIDPromptModal() // 2. Muestra la huella
        }
    }
    
    // --- LÓGICA DE REGISTRO (Actualizada) ---
    func register() {
        guard !dni.isEmpty && !password.isEmpty && !fullName.isEmpty else {
            errorMessage = "Please fill in all fields."
            showingError = true
            return
        }
        
        // 1. Guarda los datos del usuario
        userName = fullName
        userDni = dni
        userPassword = password
        
        // 2. NO genera la llave aquí.
        //    Solo abre el primer modal.
        showingRecoveryKeyModal = true
    }
    
    // --- VISTA DEL MODAL DE LLAVE (¡MEJORADO!) ---
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
                
                // --- NUEVA TARJETA DE LLAVE ---
                VStack(alignment: .leading, spacing: 8) {
                    Label("Tu Llave Única", systemImage: "key.fill")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 15) {
                        // Muestra la llave (que se genera 'onAppear')
                        Text(keyToDisplay)
                            .font(.system(size: 21, weight: .bold, design: .monospaced))
                            .textSelection(.enabled)

                        Spacer()

                        Button {
                            copyToClipboard(text: keyToDisplay)
                            copiedFeedback = true
                        } label: {
                            Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                                .font(.title2)
                                .foregroundColor(copiedFeedback ? .green : Color("MercedesPetrolGreen"))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(Color("MercedesCard"))
                .cornerRadius(10)
                // --- FIN DE LA NUEVA TARJETA ---
                
                Text("Esta es la **ÚNICA** forma de recuperar tu cuenta si olvidas tu contraseña y no tienes Touch ID. Cópiala o anótala en un lugar seguro.")
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
            // --- ¡AQUÍ ESTÁ LA CORRECCIÓN DEL BUG! ---
            // Genera y guarda la llave JUSTO al aparecer el modal
            let newKey = generateRecoveryKey()
            keyToDisplay = newKey
            userRecoveryKey = newKey // Guarda en AppStorage
            
            // Resetea los states del modal
            copiedFeedback = false
            recoveryKeyCheckbox = false
        }
    }
    
    // --- VISTA DEL MODAL DE HUELLA (Sin cambios) ---
    @ViewBuilder
    func touchIDPromptModal() -> some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 20) {
                Text("¿Activar Touch ID?").font(.largeTitle).fontWeight(.bold)
                Image(systemName: "touchid").font(.system(size: 50)).foregroundColor(Color("MercedesPetrolGreen")).padding()
                Text("¿Quieres usar la huella guardada en esta Mac para iniciar sesión y autorizar acciones?").font(.headline).foregroundColor(.gray).multilineTextAlignment(.center).padding(.bottom)
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
    
    // --- LÓGICA DE HABILITAR HUELLA (Sin cambios) ---
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
    
    // --- GENERADOR DE LLAVE (Sin cambios) ---
    func generateRecoveryKey() -> String {
        let segments = (1...4).map { _ in
            (1...4).map { _ in
                String("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()!)
            }.joined()
        }
        return segments.joined(separator: " - ")
    }
    
    // --- FUNCIÓN DE COPIAR (Sin cambios) ---
    func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
