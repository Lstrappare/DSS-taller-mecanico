import SwiftUI
import SwiftData // Para borrar la base de datos
import LocalAuthentication

// Enum para saber por qué pedimos autorización
fileprivate enum AuthReason {
    case changePassword
    case changeRFC
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
    @AppStorage("user_dni") private var userRfc = "" // ahora RFC
    @AppStorage("user_password") private var userPassword = ""
    
    // --- NUEVO: Toggle de Touch ID ---
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true

    // --- States para los campos de la UI ---
    @State private var name: String = ""
    @State private var rfc: String = ""
    
    // --- States para los Modales ---
    @State private var showingSaveAlert = false
    @State private var alertMessage = ""
    
    // 1. Modal de Autorización
    @State private var showingAuthModal = false
    @State private var authReason: AuthReason = .none
    @State private var authError = ""
    @State private var passwordAttempt = ""
    
    // 2. Modal para CAMBIAR Contraseña
    @State private var showingChangePasswordModal = false
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    // 3. Modal para ELIMINAR Cuenta
    @State private var showingDeleteAccountModal = false
    @State private var deleteRfcAttempt = ""
    @State private var deletePasswordAttempt = ""
    @State private var deleteError = ""
    
    // --- NUEVO: buffers y validaciones ---
    @State private var pendingNewRFC: String? = nil
    @State private var nameValidationError: String = ""
    @State private var rfcValidationError: String = ""
    @State private var rfcChangePendingInfo: String = ""
    @State private var touchIDAvailable: Bool = true
    
    // --- NUEVO: modo edición de información personal ---
    @State private var isEditingPersonalInfo: Bool = false
    @State private var originalName: String = ""
    @State private var originalRFC: String = ""

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
                        
                        // Nombre
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
                        
                        // RFC
                        FormField(title: "RFC", text: $rfc)
                            .onChange(of: rfc) { _, newValue in
                                rfcValidationError = validateRFC(newValue)
                            }
                            .disabled(!isEditingPersonalInfo)
                            .opacity(isEditingPersonalInfo ? 1.0 : 0.6)
                        
                        if !rfcValidationError.isEmpty {
                            Text(rfcValidationError)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        if !rfcChangePendingInfo.isEmpty {
                            Text(rfcChangePendingInfo)
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        
                        HStack {
                            if isEditingPersonalInfo {
                                Button {
                                    name = originalName
                                    rfc = originalRFC
                                    nameValidationError = ""
                                    rfcValidationError = ""
                                    rfcChangePendingInfo = ""
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
                            
                            if isEditingPersonalInfo {
                                FormButton(title: "Guardar cambios") {
                                    savePersonalInfo()
                                }
                                .disabled(!canSavePersonalInfo || (isEditingPersonalInfo && (!nameValidationError.isEmpty || !rfcValidationError.isEmpty)))
                            }
                        }
                    }
                }
                
                // --- Tarjeta 2: Seguridad ---
                FormCardView(title: "Configuración de la seguridad de la cuenta", icon: "shield.fill") {
                    VStack(alignment: .leading, spacing: 20) {
                        Toggle(isOn: $isTouchIDEnabled) {
                            Text("Activar el Touch ID")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        Text("Activa Touch ID para autorizar acciones (como cambiar tu contraseña) sin tener que escribirla. Si olvidas tu contraseña, esta es una forma de recuperarla.")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Divider()
                        
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
                                authReason = .changePassword
                                showingAuthModal = true
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color("MercedesCard"))
                            .cornerRadius(8)
                        }
                    }
                }

                // --- Tarjeta 3: Danger Zone ---
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
            rfc = userRfc
            originalName = userName
            originalRFC = userRfc
            nameValidationError = validateFullName(name)
            rfcValidationError = validateRFC(rfc)
            // Detectar biometría
            let context = LAContext()
            var error: NSError?
            touchIDAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        }
        .alert(alertMessage, isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        }
        // Modales
        .sheet(isPresented: $showingAuthModal) { authModalView() }
        .sheet(isPresented: $showingChangePasswordModal) { changePasswordModalView() }
        .sheet(isPresented: $showingDeleteAccountModal) { deleteAccountModalView() }
    }
    
    // --- VISTAS REUTILIZABLES ---
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
                .background(Color("MercedesBackground"))
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
    
    // --- MODALES ---
    @ViewBuilder
    func authModalView() -> some View {
        AuthModal(
            title: "Autorización Requerida",
            prompt: authReasonPrompt,
            error: authError,
            passwordAttempt: $passwordAttempt,
            isTouchIDEnabled: isTouchIDEnabled && touchIDAvailable,
            onAuthTouchID: { Task { await authenticateWithTouchID() } },
            onAuthPassword: { authenticateWithPassword() }
        )
        .onAppear { authError = "" }
    }
    
    @ViewBuilder
    func changePasswordModalView() -> some View {
        ModalView(title: "Cambiar Contraseña") {
            VStack(spacing: 15) {
                Text("Ingresa tu nueva contraseña.").font(.headline)
                SecureField("Nueva Contraseña", text: $newPassword)
                SecureField("Repite la nueva contraseña", text: $confirmPassword)
                
                if !newPassword.isEmpty && newPassword == userPassword {
                    Text("La nueva contraseña no puede ser igual a la actual.")
                        .font(.caption).foregroundColor(.yellow)
                }
                if !newPassword.isEmpty && newPassword.count < 8 {
                    Text("La contraseña debe tener al menos 8 caracteres.")
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
                    newPassword = ""; confirmPassword = ""
                    showingChangePasswordModal = false
                }
                .disabled(!canSaveNewPassword)
            }
        }
    }
    
    private var canSaveNewPassword: Bool {
        return !newPassword.isEmpty && newPassword == confirmPassword && newPassword != userPassword && newPassword.count >= 8
    }
    
    @ViewBuilder
    func deleteAccountModalView() -> some View {
        ModalView(title: "Eliminar Cuenta", isDanger: true) {
            VStack(spacing: 15) {
                Text("Esta acción es irreversible. Para confirmar, ingresa tu RFC y tu contraseña actual.")
                    .font(.headline)
                
                TextField("RFC", text: $deleteRfcAttempt)
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
    
    // --- LÓGICA ---
    func validateFullName(_ value: String) -> String {
        let parts = value
            .split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard parts.count >= 2 else {
            return "El nombre debe tener al menos 2 palabras."
        }
        for p in parts where p.count < 3 {
            return "Cada palabra del nombre debe tener al menos 3 letras."
        }
        return ""
    }
    
    func validateRFC(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return "El RFC no puede estar vacío." }
        if !RFCValidator.isValidRFC(trimmed) {
            return "RFC inválido. Verifica estructura, fecha y dígito verificador."
        }
        return ""
    }
    
    var canSavePersonalInfo: Bool {
        nameValidationError.isEmpty && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func savePersonalInfo() {
        let nameError = validateFullName(name)
        nameValidationError = nameError
        guard nameError.isEmpty else { return }
        
        let rfcError = validateRFC(rfc)
        rfcValidationError = rfcError
        guard rfcError.isEmpty else { return }
        
        // Si el RFC cambió, pedimos autorización
        if rfc.uppercased() != userRfc.uppercased() {
            pendingNewRFC = rfc.uppercased()
            rfcChangePendingInfo = "Se requiere autorización para aplicar el nuevo RFC."
            authReason = .changeRFC
            showingAuthModal = true
            userName = name
            alertMessage = "Nombre actualizado. Falta autorizar el cambio de RFC."
            showingSaveAlert = true
            originalName = userName
        } else {
            userName = name
            alertMessage = "Información Personal Guardada"
            showingSaveAlert = true
            rfcChangePendingInfo = ""
            isEditingPersonalInfo = false
            originalName = userName
            originalRFC = userRfc
        }
    }

    var authReasonPrompt: String {
        switch authReason {
        case .changePassword:
            return "Autoriza para continuar con el cambio de contraseña."
        case .changeRFC:
            return "Autoriza para aplicar el nuevo RFC."
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
        showingAuthModal = false
        passwordAttempt = ""
        
        switch authReason {
        case .changePassword:
            showingChangePasswordModal = true
        case .changeRFC:
            if let newRFC = pendingNewRFC {
                userRfc = newRFC
                rfc = newRFC
                alertMessage = "RFC actualizado."
                showingSaveAlert = true
                pendingNewRFC = nil
                rfcChangePendingInfo = ""
                isEditingPersonalInfo = false
                originalRFC = userRfc
            }
        case .editPersonalInfo:
            isEditingPersonalInfo = true
            originalName = name
            originalRFC = rfc
        case .none:
            break
        }
        authReason = .none
        authError = ""
    }
    
    func deleteAllData() {
        guard deleteRfcAttempt.uppercased() == userRfc.uppercased() && deletePasswordAttempt == userPassword else {
            deleteError = "RFC o contraseña incorrectos."
            return
        }
        
        do {
            // Eliminar Modelos Principales
            try modelContext.delete(model: Personal.self)
            try modelContext.delete(model: Producto.self)
            try modelContext.delete(model: Servicio.self)
            try modelContext.delete(model: DecisionRecord.self)
            
            // Eliminar Clientes y Vehículos (NUEVO)
            try modelContext.delete(model: Cliente.self)
            try modelContext.delete(model: Vehiculo.self)
            
            // Eliminar Historial y Memoria de IA (NUEVO)
            try modelContext.delete(model: ChatMessage.self)
            
            // Eliminar Servicios en Proceso y Configuraciones (NUEVO)
            try modelContext.delete(model: ServicioEnProceso.self)
            try modelContext.delete(model: AsistenciaDiaria.self)
            //try modelContext.delete(model: PayrollSettings.self)
            
        } catch {
            print("Error al borrar la base de datos: \(error)")
        }
        
        // Resetear Ganancias Aproximadas (Inventario y Servicios) a 0
        UserDefaults.standard.set(0.0, forKey: "gananciaAcumulada")
        UserDefaults.standard.set(0.0, forKey: "gananciaServiciosAcumulada")
        
        // Resetear Credenciales y Estado
        userName = ""
        userRfc = ""
        userPassword = ""
        isTouchIDEnabled = true
        hasCompletedRegistration = false
        isLoggedIn = false
    }
}

// Reutiliza ModalView y AuthModal ya definidos en este archivo (mantienen la misma API)
