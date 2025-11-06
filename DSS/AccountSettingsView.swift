import SwiftUI
import SwiftData // Para borrar la base de datos
import LocalAuthentication

// Enum para saber por qué pedimos autorización
fileprivate enum AuthReason {
    case changePassword
    case none
}

struct AccountSettingsView: View {
    
    // --- Contexto y Almacenamiento ---
    @Environment(\.modelContext) private var modelContext
    
    // Almacenamiento del estado de la app
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("hasCompletedRegistration") private var hasCompletedRegistration = false
    
    // Datos del Usuario
    @AppStorage("user_name") private var userName = ""
    @AppStorage("user_dni") private var userDni = ""
    @AppStorage("user_password") private var userPassword = ""
    
    // --- NUEVO: Toggle de Touch ID ---
    // (Por defecto está activado)
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true

    // --- States para los campos de la UI ---
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var dni: String = ""
    
    // --- States para los Modales ---
    @State private var showingSaveAlert = false
    @State private var alertMessage = ""
    
    // 1. Modal de Autorización (para Huella/Pass actual)
    @State private var showingAuthModal = false
    @State private var authReason: AuthReason = .none
    @State private var authError = ""
    @State private var passwordAttempt = "" // Contraseña actual
    
    // 2. Modal para CAMBIAR Contraseña (para Pass nueva)
    @State private var showingChangePasswordModal = false
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    // 3. Modal para ELIMINAR Cuenta
    @State private var showingDeleteAccountModal = false
    @State private var deleteDniAttempt = ""
    @State private var deletePasswordAttempt = ""
    @State private var deleteError = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                
                // --- Cabecera ---
                Text("Account Settings")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Text("Manage your account and business preferences")
                    .font(.title3).foregroundColor(.gray)
                
                // --- Tarjeta 1: Personal Information ---
                FormCardView(title: "Personal Information", icon: "person.fill") {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Update your personal details").font(.subheadline).foregroundColor(.gray)
                        HStack(spacing: 20) {
                            FormField(title: "Full Name", text: $name)
                        }
                        FormField(title: "DNI/CURP (Cannot be changed)", text: $dni)
                            .disabled(true) // DNI no se puede cambiar
                        
                        FormButton(title: "Save Personal Info") {
                            savePersonalInfo()
                        }
                    }
                }
                
                // --- Tarjeta 2: Security Settings (NUEVO DISEÑO) ---
                FormCardView(title: "Security Settings", icon: "shield.fill") {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // --- Toggle de Touch ID ---
                        Toggle(isOn: $isTouchIDEnabled) {
                            Text("Enable Touch ID")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        // --- Leyenda de Recuperación ---
                        Text("Activa Touch ID para autorizar acciones (como cambiar tu contraseña) sin tener que escribirla. Si olvidas tu contraseña, esta es la única forma de recuperarla.")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Divider()
                        
                        // --- Botón de Cambiar Contraseña ---
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Change Password")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Se te pedirá tu contraseña actual o tu huella.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Button("Change...") {
                                // 1. Pone la razón
                                authReason = .changePassword
                                // 2. Abre el modal de AUTORIZACIÓN
                                showingAuthModal = true
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color("MercedesCard"))
                            .cornerRadius(8)
                        }
                    }
                }

                // --- Tarjeta 3: Danger Zone (NUEVO) ---
                FormCardView(title: "Danger Zone", icon: "exclamationmark.triangle.fill", isDanger: true) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Delete Account")
                                .font(.headline)
                                .foregroundColor(Color.red.opacity(0.9))
                            Text("Esto eliminará permanentemente tu cuenta y todos los datos del negocio (Personal, Inventario, Decisiones). Esta acción no se puede deshacer.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button("Delete...") {
                            showingDeleteAccountModal = true
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(Color.red.opacity(0.9))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding(30)
        }
        .onAppear {
            // Cargar los datos guardados
            name = userName
            dni = userDni
        }
        .alert(alertMessage, isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        }
        // --- Los 3 Modales ---
        .sheet(isPresented: $showingAuthModal) { authModalView() } // Modal de Autorización
        .sheet(isPresented: $showingChangePasswordModal) { changePasswordModalView() } // Modal para Contraseña Nueva
        .sheet(isPresented: $showingDeleteAccountModal) { deleteAccountModalView() } // Modal de Borrado
    }
    
    // --- VISTAS REUTILIZABLES (Para la UI Limpia) ---
    
    @ViewBuilder
    func FormCardView<Content: View>(title: String, icon: String, isDanger: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Label(title, systemImage: icon)
                .font(.title2).fontWeight(.bold)
                .foregroundColor(isDanger ? Color.red.opacity(0.9) : .white)
            content()
        }
        .padding()
        .background(Color("MercedesCard"))
        .cornerRadius(15)
    }
    
    @ViewBuilder
    func FormField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundColor(.gray)
            TextField("", text: text)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(10)
                .background(Color("MercedesBackground")) // Fondo más oscuro
                .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    func FormButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .padding(.vertical, 10)
                .frame(maxWidth: 200)
                .background(Color("MercedesPetrolGreen"))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    
    // --- VISTAS DE MODALES ---

    // Modal 1: Pide Huella O Contraseña ACTUAL
    @ViewBuilder
    func authModalView() -> some View {
        AuthModal(
            title: "Autorización Requerida",
            prompt: "Autoriza para continuar con la acción.",
            error: authError,
            passwordAttempt: $passwordAttempt,
            isTouchIDEnabled: isTouchIDEnabled, // Pasa el estado del Toggle
            onAuthTouchID: {
                // Intenta con Huella
                Task { await authenticateWithTouchID() }
            },
            onAuthPassword: {
                // Intenta con Contraseña
                authenticateWithPassword()
            }
        )
        .onAppear { authError = "" }
    }
    
    // Modal 2: Pide la NUEVA contraseña
    @ViewBuilder
    func changePasswordModalView() -> some View {
        ModalView(title: "Change Password") {
            VStack(spacing: 15) {
                Text("Ingresa tu nueva contraseña.").font(.headline)
                SecureField("New Password", text: $newPassword)
                SecureField("Confirm New Password", text: $confirmPassword)
                
                if !newPassword.isEmpty && newPassword != confirmPassword {
                    Text("Las contraseñas no coinciden.")
                        .font(.caption).foregroundColor(.red)
                }
                
                FormButton(title: "Save New Password") {
                    userPassword = newPassword
                    alertMessage = "¡Contraseña actualizada!"
                    showingSaveAlert = true
                    // Limpia y cierra
                    newPassword = ""; confirmPassword = ""
                    showingChangePasswordModal = false
                }
                .disabled(newPassword.isEmpty || newPassword != confirmPassword)
            }
        }
    }
    
    // Modal 3: Pide DNI y Contraseña para BORRAR
    @ViewBuilder
    func deleteAccountModalView() -> some View {
        ModalView(title: "Delete Account", isDanger: true) {
            VStack(spacing: 15) {
                Text("Esta acción es irreversible. Para confirmar, ingresa tu DNI/CURP y tu contraseña actual.")
                    .font(.headline)
                
                TextField("DNI/CURP", text: $deleteDniAttempt)
                SecureField("Contraseña Actual", text: $deletePasswordAttempt)
                
                if !deleteError.isEmpty {
                    Text(deleteError).font(.caption).foregroundColor(.red)
                }
                
                Button {
                    deleteAllData()
                } label: {
                    Text("Confirmar y Eliminar Todo")
                        .font(.headline).padding().frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.8)).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { deleteError = "" }
    }
    
    
    // --- LÓGICA DE LA VISTA ---
    
    func savePersonalInfo() {
        userName = name
        alertMessage = "Información Personal Guardada"
        showingSaveAlert = true
    }

    // Lógica de Autenticación
    
    func authenticateWithTouchID() async {
        let context = LAContext()
        let reason = "Autoriza esta acción en DSS."
        do {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                if success {
                    await MainActor.run { onAuthSuccess() }
                }
            }
        } catch {
            await MainActor.run { authError = "Huella no reconocida." }
        }
    }
    
    func authenticateWithPassword() {
        if passwordAttempt == userPassword {
            onAuthSuccess()
        } else {
            authError = "Contraseña actual incorrecta."
            passwordAttempt = ""
        }
    }
    
    func onAuthSuccess() {
        // Cierra el modal de autorización
        showingAuthModal = false
        passwordAttempt = ""
        
        // Decide qué hacer después
        switch authReason {
        case .changePassword:
            // Abre el modal para la NUEVA contraseña
            showingChangePasswordModal = true
        case .none:
            break
        }
    }
    
    // Lógica de Borrado
    
    func deleteAllData() {
        // 1. Validar credenciales
        guard deleteDniAttempt == userDni && deletePasswordAttempt == userPassword else {
            deleteError = "DNI o contraseña incorrectos."
            return
        }
        
        // 2. Borrar datos de SwiftData (¡con cuidado!)
        do {
            try modelContext.delete(model: Personal.self)
            try modelContext.delete(model: Producto.self)
            try modelContext.delete(model: Servicio.self)
            try modelContext.delete(model: DecisionRecord.self)
        } catch {
            print("Error al borrar la base de datos: \(error)")
        }
        
        // 3. Borrar datos de AppStorage (resetear la app)
        userName = ""
        userDni = ""
        userPassword = ""
        isTouchIDEnabled = true
        hasCompletedRegistration = false // ¡CLAVE! Esto manda al registro
        isLoggedIn = false // ¡CLAVE! Esto cierra sesión
    }
}


// --- VISTAS DE MODALES REUTILIZABLES ---

// Un contenedor de modal genérico
struct ModalView<Content: View>: View {
    var title: String
    var isDanger: Bool = false
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 20) {
                Text(title)
                    .font(.largeTitle).fontWeight(.bold)
                    .foregroundColor(isDanger ? .red : .white)
                content()
            }
            .padding(40)
        }
        .frame(minWidth: 500, minHeight: 400)
        .preferredColorScheme(.dark)
        .textFieldStyle(PlainTextFieldStyle())
        .padding()
        .background(Color("MercedesCard"))
        .cornerRadius(8)
    }
}

// Un modal de autenticación genérico
struct AuthModal: View {
    var title: String
    var prompt: String
    var error: String
    @Binding var passwordAttempt: String
    
    var isTouchIDEnabled: Bool // Para mostrar/ocultar el botón
    
    var onAuthTouchID: () -> Void
    var onAuthPassword: () -> Void
    
    var body: some View {
        ModalView(title: title) {
            Text(prompt).font(.title3).foregroundColor(.gray).padding(.bottom)
            
            if isTouchIDEnabled {
                Button { onAuthTouchID() }
                label: {
                    Label("Usar Huella (Touch ID)", systemImage: "touchid")
                        .font(.headline).padding().frame(maxWidth: .infinity)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }.buttonStyle(.plain)
                
                Text("o").foregroundColor(.gray)
            }
            
            Text("Usa tu contraseña actual:").font(.headline)
            SecureField("Contraseña Actual", text: $passwordAttempt)
            
            if !error.isEmpty {
                Text(error).font(.caption).foregroundColor(.red)
            }
            
            Button { onAuthPassword() }
            label: {
                Label("Autorizar con Contraseña", systemImage: "lock.fill")
                    .font(.headline).padding().frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.4)).foregroundColor(.white).cornerRadius(8)
            }.buttonStyle(.plain)
        }
    }
}
