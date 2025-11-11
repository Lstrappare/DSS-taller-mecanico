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
    @AppStorage("user_dni") private var userDni = ""
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("user_recovery_key") private var userRecoveryKey = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true

    // --- States de la Vista ---
    @State private var fullName = ""
    @State private var dni = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // --- ESTADO DE ERROR (¡NUEVO!) ---
    @State private var errorMsg: String? // Para mostrar errores de validación
    
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
                    CustomField(title: "Clave Única de Registro de Población (CURP):", placeholder: "18 caracteres", text: $dni, systemImage: "document.fill")
                    CustomSecureField(title: "Contraseña:", placeholder: "********", text: $password, systemImage: "lock.fill")
                    CustomSecureField(title: "Confirmar Contraseña:", placeholder: "********", text: $confirmPassword, systemImage: "lock.rotation")
                    
                    if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                        Text("⚠️ Las contraseñas no coinciden")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
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
                .disabled(password.isEmpty || password != confirmPassword)
            }
            .padding(50)
            .frame(width: 450, height: 580) // Un poco más alto para el error
        }
        // (Ya no necesitamos .alert(isPresented: $showingError))
        
        // --- MODALES ---
        .sheet(isPresented: $showingRecoveryKeyModal) {
            recoveryKeyModalView()
        }
        .sheet(isPresented: $showingTouchIDPrompt) {
            touchIDPromptModal()
        }
    }
    
    // --- LÓGICA DE REGISTRO (¡ACTUALIZADA!) ---
    func register() {
        
        // 1. Resetear el error
        errorMsg = nil
        
        // --- 2. VALIDACIÓN DE FORMATO ---
        
        // --- Validación de Nombre ---
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameParts = trimmedName.split(separator: " ").filter { !$0.isEmpty }
        let regex = "^[A-Za-zÁÉÍÓÚáéíóúÑñ ]+$"
        
        if !NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmedName) {
            errorMsg = "El nombre solo debe contener letras y espacios."
            return
        }

        // Validar número mínimo de palabras
        if nameParts.count < 2 {
            errorMsg = "El nombre completo debe tener al menos 2 palabras (ej. José Cisneros Torres)."
            return
        }

        // Validar que cada palabra tenga al menos 3 letras
        for part in nameParts {
            if part.count < 3 {
                errorMsg = "Cada palabra debe tener al menos 3 letras (ej. Max Verstapen Torres)."
                return
            }
        }
        
        // Validación de DNI/CURP (18 caracteres)
        // --- Validación de CURP ---
        let dniTrimmed = dni.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        let curpRegex = #"^[A-Z]{1}[AEIOUX]{1}[A-Z]{2}\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])[HM]{1}(AS|BC|BS|CC|CL|CM|CS|CH|DF|DG|GT|GR|HG|JC|MC|MN|MS|NT|NL|OC|PL|QT|QR|SP|SL|SR|TC|TS|TL|VZ|YN|ZS|NE)[B-DF-HJ-NP-TV-Z]{3}[A-Z\d]{1}\d{1}$"#

        let predicate = NSPredicate(format: "SELF MATCHES %@", curpRegex)

        if !predicate.evaluate(with: dniTrimmed) {
            errorMsg = "El CURP no tiene un formato válido. Ejemplo: CATT040903HDFRRS09"
            return
        }

        // --- 3. SI TODO ES VÁLIDO, PROCEDE ---
        
        // Genera la Llave (esto se mueve al modal)
        
        // Guarda los datos en AppStorage
        userName = fullName
        userDni = dniTrimmed // Guarda la versión sin espacios
        userPassword = password
        
        // Muestra el primer modal (el de la llave)
        showingRecoveryKeyModal = true
    }
    
    // --- VISTA DEL MODAL DE LLAVE (Sin cambios) ---
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
            let newKey = generateRecoveryKey()
            keyToDisplay = newKey
            userRecoveryKey = newKey
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
