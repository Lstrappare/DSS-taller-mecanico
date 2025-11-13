import SwiftUI
import SwiftData // Para borrar la base de datos
import LocalAuthentication

// Enum para saber por qué pedimos autorización
fileprivate enum AuthReason {
    case changePassword
    case changeDNI
    case editPersonalInfo
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
    
    // --- NUEVO: buffers y validaciones ---
    @State private var pendingNewDni: String? = nil
    @State private var nameValidationError: String = ""
    @State private var curpValidationError: String = ""
    @State private var dniChangePendingInfo: String = ""
    @State private var touchIDAvailable: Bool = true
    
    // --- NUEVO: modo edición de información personal ---
    @State private var isEditingPersonalInfo: Bool = false
    @State private var originalName: String = ""
    @State private var originalDni: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                
                // --- Cabecera ---
                Text("Configuración de la cuenta")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Text("Maneja tu cuenta a tus preferencias.")
                    .font(.title3).foregroundColor(.gray)
                
                // --- Tarjeta 1: Personal Information ---
                FormCardView(title: "Información personal", icon: "person.fill") {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Actualiza tus datos personales")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                            if !isEditingPersonalInfo {
                                Button {
                                    // Solicitar autorización para habilitar edición
                                    authReason = .editPersonalInfo
                                    showingAuthModal = true
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                        .font(.caption)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(Color("MercedesCard"))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        HStack(spacing: 20) {
                            FormField(title: "Nombre Completo", text: $name)
                                .onChange(of: name) { oldValue, newValue in
                                    nameValidationError = validateFullName(newValue)
                                }
                                .disabled(!isEditingPersonalInfo)
                                .opacity(isEditingPersonalInfo ? 1.0 : 0.6)
                        }
                        if !nameValidationError.isEmpty {
                            Text(nameValidationError)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        // CURP editable solo en modo edición
                        FormField(title: "DNI/CURP", text: $dni)
                            .onChange(of: dni) { _, newValue in
                                curpValidationError = validateCURP(newValue)
                            }
                            .disabled(!isEditingPersonalInfo)
                            .opacity(isEditingPersonalInfo ? 1.0 : 0.6)
                        
                        if !curpValidationError.isEmpty {
                            Text(curpValidationError)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        if !dniChangePendingInfo.isEmpty {
                            Text(dniChangePendingInfo)
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        
                        HStack {
                            if isEditingPersonalInfo {
                                Button {
                                    // Cancelar edición y restaurar valores originales
                                    name = originalName
                                    dni = originalDni
                                    nameValidationError = ""
                                    curpValidationError = ""
                                    dniChangePendingInfo = ""
                                    isEditingPersonalInfo = false
                                } label: {
                                    Text("Cancelar")
                                        .font(.headline)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: 120)
                                        .background(Color.gray.opacity(0.3))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Spacer()
                            
                            // Mostrar el botón Guardar solo en modo edición
                            if isEditingPersonalInfo {
                                FormButton(title: "Guardar cambios") {
                                    savePersonalInfo()
                                }
                                .disabled(!canSavePersonalInfo || (isEditingPersonalInfo && (!nameValidationError.isEmpty || !curpValidationError.isEmpty)))
                            }
                        }
                    }
                }
                
                // --- Tarjeta 2: Security Settings (NUEVO DISEÑO) ---
                FormCardView(title: "Configuración de la seguridad de la cuenta", icon: "shield.fill") {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // --- Toggle de Touch ID ---
                        Toggle(isOn: $isTouchIDEnabled) {
                            Text("Activar el Touch ID")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        // --- Leyenda de Recuperación ---
                        Text("Activa Touch ID para autorizar acciones (como cambiar tu contraseña) sin tener que escribirla. Si olvidas tu contraseña, esta es una forma de recuperarla.")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Divider()
                        
                        // --- Botón de Cambiar Contraseña ---
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Cambiar Contraseña")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Se te pedirá tu contraseña actual o tu huella.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Button("Cambiar...") {
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
                FormCardView(title: "Zona de peligro", icon: "exclamationmark.triangle.fill", isDanger: true) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Eliminar Cuenta")
                                .font(.headline)
                                .foregroundColor(Color.red.opacity(0.9))
                            Text("Esto eliminará permanentemente tu cuenta y todos los datos del negocio (Personal, Inventario, Decisiones). Esta acción no se puede deshacer.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button("Eliminar...") {
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
            originalName = userName
            originalDni = userDni
            nameValidationError = validateFullName(name)
            curpValidationError = validateCURP(dni)
            // Detectar si hay biometría
            let context = LAContext()
            var error: NSError?
            touchIDAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
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
                .foregroundColor(Color("MercedesPetrolGreen"))
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
            prompt: authReasonPrompt,
            error: authError,
            passwordAttempt: $passwordAttempt,
            isTouchIDEnabled: isTouchIDEnabled && touchIDAvailable, // Pasa el estado del Toggle y disponibilidad
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
        ModalView(title: "Cambiar Contraseña") {
            VStack(spacing: 15) {
                Text("Ingresa tu nueva contraseña.").font(.headline)
                SecureField("Nueva Contraseña", text: $newPassword)
                SecureField("Repite la nueva contraseña", text: $confirmPassword)
                
                // Validaciones
                if !newPassword.isEmpty && newPassword == userPassword {
                    Text("La nueva contraseña no puede ser igual a la actual.")
                        .font(.caption).foregroundColor(.yellow)
                }
                if !newPassword.isEmpty && newPassword != confirmPassword {
                    Text("Las contraseñas no coinciden.")
                        .font(.caption).foregroundColor(.red)
                }
                
                FormButton(title: "Guardar nueva contraseña") {
                    userPassword = newPassword
                    alertMessage = "¡Contraseña actualizada!"
                    showingSaveAlert = true
                    // Limpia y cierra
                    newPassword = ""; confirmPassword = ""
                    showingChangePasswordModal = false
                }
                .disabled(newPassword.isEmpty || newPassword != confirmPassword || newPassword == userPassword)
            }
        }
    }
    
    // Modal 3: Pide DNI y Contraseña para BORRAR
    @ViewBuilder
    func deleteAccountModalView() -> some View {
        ModalView(title: "Eliminar Cuenta", isDanger: true) {
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
    
    // Validación del nombre: exactamente 3 palabras, cada una con >= 3 letras
    func validateFullName(_ value: String) -> String {
        let parts = value
            .split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard parts.count == 3 else {
            return "El nombre debe ser exactamente 3 palabras."
        }
        for p in parts {
            if p.count < 3 {
                return "Cada palabra del nombre debe tener al menos 3 letras."
            }
        }
        return ""
    }
    
    // Validación de CURP (formato oficial de 18 caracteres)
    // Estructura: 4 letras + 6 dígitos de fecha + 1 letra H/M + 5 letras (incluye entidad y consonantes internas) + 2 alfanuméricos
    func validateCURP(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return "La CURP no puede estar vacía." }
        // Regex común para CURP
        // 1-4: letras; 5-10: fecha YYMMDD; 11: H/M; 12-13: entidad; 14-16: consonantes internas; 17-18: homoclave/ dígito verificador
        let pattern = #"^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]{2}$"#
        if trimmed.count != 18 { return "La CURP debe tener 18 caracteres." }
        if trimmed.range(of: pattern, options: .regularExpression) == nil {
            return "Formato de CURP inválido."
        }
        return ""
    }
    
    var canSavePersonalInfo: Bool {
        nameValidationError.isEmpty && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func savePersonalInfo() {
        // Validar nombre
        let nameError = validateFullName(name)
        nameValidationError = nameError
        guard nameError.isEmpty else { return }
        
        // Validar CURP
        let curpError = validateCURP(dni)
        curpValidationError = curpError
        guard curpError.isEmpty else { return }
        
        // Si el DNI/CURP cambió, pedimos autorización adicional
        if dni != userDni {
            pendingNewDni = dni
            dniChangePendingInfo = "Se requiere autorización para aplicar el nuevo DNI/CURP."
            authReason = .changeDNI
            showingAuthModal = true
            // Guardamos el nombre de una vez (no requiere auth)
            userName = name
            alertMessage = "Nombre actualizado. Falta autorizar el cambio de DNI/CURP."
            showingSaveAlert = true
            // Mantener en modo edición hasta que autorice el cambio de CURP
            originalName = userName
            // No cerramos edición aún
        } else {
            // No cambió el DNI, guardamos directo
            userName = name
            alertMessage = "Información Personal Guardada"
            showingSaveAlert = true
            dniChangePendingInfo = ""
            // Salir de modo edición
            isEditingPersonalInfo = false
            originalName = userName
            originalDni = userDni
        }
    }

    // Lógica de Autenticación
    
    var authReasonPrompt: String {
        switch authReason {
        case .changePassword:
            return "Autoriza para continuar con el cambio de contraseña."
        case .changeDNI:
            return "Autoriza para aplicar el nuevo DNI/CURP."
        case .editPersonalInfo:
            return "Autoriza para editar tu información personal."
        case .none:
            return "Autoriza para continuar con la acción."
        }
    }
    
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
        case .changeDNI:
            if let newDni = pendingNewDni {
                userDni = newDni
                dni = newDni
                alertMessage = "DNI/CURP actualizado."
                showingSaveAlert = true
                pendingNewDni = nil
                dniChangePendingInfo = ""
                // Si estábamos en modo edición esperando esta autorización, cerramos edición
                isEditingPersonalInfo = false
                originalDni = userDni
            }
        case .editPersonalInfo:
            // Habilitar edición de Nombre y CURP
            isEditingPersonalInfo = true
            // Guardar originales para poder cancelar
            originalName = name
            originalDni = dni
        case .none:
            break
        }
        authReason = .none
        authError = ""
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
        .cornerRadius(15)
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
