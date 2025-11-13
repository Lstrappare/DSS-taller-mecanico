import SwiftUI
import SwiftData
import LocalAuthentication // Necesario para seguridad

// --- Enums para controlar los Modales ---
fileprivate enum ModalMode: Identifiable {
    case addClienteConVehiculo
    case editCliente(Cliente)
    case addVehiculo(Cliente)
    case editVehiculo(Vehiculo)
    
    var id: String {
        switch self {
        case .addClienteConVehiculo: return "addClienteConVehiculo"
        case .editCliente(let cliente): return cliente.telefono
        case .addVehiculo(let cliente): return "addVehiculoA-\(cliente.telefono)"
        case .editVehiculo(let vehiculo): return vehiculo.placas
        }
    }
}

// --- VISTA PRINCIPAL (Con Buscador) ---
struct GestionClientesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cliente.nombre) private var clientes: [Cliente]
    
    @State private var modalMode: ModalMode?
    @State private var searchQuery = ""
    
    var filteredClientes: [Cliente] {
        if searchQuery.isEmpty {
            return clientes
        } else {
            let query = searchQuery.lowercased()
            return clientes.filter { cliente in
                let nombreMatch = cliente.nombre.lowercased().contains(query)
                let telefonoMatch = cliente.telefono.lowercased().contains(query)
                let emailMatch = cliente.email.lowercased().contains(query)
                return nombreMatch || telefonoMatch || emailMatch
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            // Cabecera
            HStack {
                Text("Gestión de Clientes y Vehículos")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Button {
                    modalMode = .addClienteConVehiculo
                } label: {
                    Label("Añadir Cliente", systemImage: "person.badge.plus")
                        .font(.headline).padding(.vertical, 10).padding(.horizontal)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)
            
            Text("Registra y administra tus clientes y sus vehículos.")
                .font(.title3).foregroundColor(.gray).padding(.bottom, 20)
            
            // Buscador
            TextField("Buscar por Nombre, Teléfono o Email...", text: $searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                .padding(.bottom, 20)
            
            // --- Lista de Clientes (con Links) ---
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(filteredClientes) { cliente in
                        VStack(alignment: .leading) {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(cliente.nombre)
                                        .font(.title2).fontWeight(.semibold)
                                    // Link de Teléfono
                                    Link(destination: URL(string: "tel:\(cliente.telefono)")!) {
                                        Label(cliente.telefono, systemImage: "phone.fill")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(Color("MercedesPetrolGreen"))
                                    
                                    // Link de Email
                                    if cliente.email.isEmpty {
                                        Label("Sin email", systemImage: "envelope.fill")
                                    } else {
                                        Link(destination: URL(string: "mailto:\(cliente.email)")!) {
                                            Label(cliente.email, systemImage: "envelope.fill")
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(Color("MercedesPetrolGreen"))
                                    }
                                }
                                .font(.body)
                                
                                Spacer()
                                
                                Button {
                                    modalMode = .editCliente(cliente)
                                } label: {
                                    Image(systemName: "pencil")
                                    Text("Editar Cliente")
                                }.buttonStyle(.plain)
                            }
                            
                            Divider().padding(.vertical, 5)
                            
                            // Lista de Vehículos
                            Text("Vehículos Registrados:").font(.headline)
                            if cliente.vehiculos.isEmpty {
                                Text("No hay vehículos registrados para este cliente.")
                                    .font(.subheadline).foregroundColor(.gray)
                            } else {
                                ForEach(cliente.vehiculos) { vehiculo in
                                    HStack {
                                        Text("[\(vehiculo.placas)]")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(Color("MercedesPetrolGreen"))
                                        Text("\(vehiculo.marca) \(vehiculo.modelo) (\(String(vehiculo.anio)))")
                                        Spacer()
                                        Button {
                                            modalMode = .editVehiculo(vehiculo)
                                        } label: {
                                            Image(systemName: "pencil.circle")
                                            Text("Editar Auto")
                                        }.buttonStyle(.plain).foregroundColor(.gray)
                                    }
                                }
                            }
                            
                            Button {
                                modalMode = .addVehiculo(cliente)
                            } label: {
                                Label("Añadir Vehículo", systemImage: "car.badge.plus")
                                    .font(.headline)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 10)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("MercedesCard"))
                        .cornerRadius(10)
                    }
                }
            }
            Spacer()
        }
        .padding(30)
        .sheet(item: $modalMode) { mode in
            // Pasa el environment a TODOS los modales
            switch mode {
            case .addClienteConVehiculo:
                ClienteConVehiculoFormView()
                    .environment(\.modelContext, modelContext)
            case .editCliente(let cliente):
                ClienteFormView(cliente: cliente)
                    .environment(\.modelContext, modelContext)
            case .addVehiculo(let cliente):
                VehiculoFormView(cliente: cliente)
                    .environment(\.modelContext, modelContext)
            case .editVehiculo(let vehiculo):
                VehiculoFormView(vehiculo: vehiculo)
                    .environment(\.modelContext, modelContext)
            }
        }
    }
}


// --- 1. FORMULARIO COMBINADO (ADD CLIENTE + VEHÍCULO) (¡ACTUALIZADO!) ---
fileprivate struct ClienteConVehiculoFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // States
    @State private var nombre = ""
    @State private var telefono = ""
    @State private var email = ""
    @State private var placas = ""
    @State private var marca = ""
    @State private var modelo = ""
    @State private var anioString = ""
    @State private var errorMsg: String?
    
    // Bools de Validación
    private var nombreInvalido: Bool {
        nombre.trimmingCharacters(in: .whitespaces).split(separator: " ").count < 2
    }
    private var telefonoInvalido: Bool {
        telefono.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var placasInvalidas: Bool {
        placas.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var anioInvalido: Bool {
        Int(anioString) == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Añadir Nuevo Cliente").font(.title).fontWeight(.bold)
                Text("Completa los datos. Los campos marcados con • son obligatorios.")
                    .font(.footnote).foregroundColor(.gray)
            }
            .padding(.top, 14).padding(.bottom, 8)
            
            Form {
                Section {
                    SectionHeader(title: "Datos del Cliente", subtitle: nil)
                    FormField(title: "• Nombre Completo", placeholder: "ej. José Cisneros Torres", text: $nombre)
                        .validationHint(isInvalid: nombreInvalido, message: "Escribe nombre y apellido.")
                    HStack(spacing: 16) {
                        FormField(title: "• Teléfono (ID Único)", placeholder: "10 dígitos", text: $telefono)
                            .validationHint(isInvalid: telefonoInvalido, message: "El teléfono es obligatorio.")
                        FormField(title: "Email (Opcional)", placeholder: "ej. jose@cliente.com", text: $email)
                    }
                }
                
                Section {
                    SectionHeader(title: "Datos del Primer Vehículo", subtitle: nil)
                    HStack(spacing: 16) {
                        FormField(title: "• Placas (ID Único)", placeholder: "ej. ABC-123", text: $placas)
                            .validationHint(isInvalid: placasInvalidas, message: "Las placas son obligatorias.")
                        FormField(title: "• Año", placeholder: "ej. 2020", text: $anioString)
                            .validationHint(isInvalid: anioInvalido, message: "Debe ser un número.")
                    }
                    HStack(spacing: 16) {
                        FormField(title: "• Marca", placeholder: "ej. Nissan", text: $marca)
                        FormField(title: "• Modelo", placeholder: "ej. Versa", text: $modelo)
                    }
                }
            }
            .textFieldStyle(PlainTextFieldStyle())
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            
            if let errorMsg {
                Text(errorMsg)
                    .font(.caption).foregroundColor(.red).padding(.vertical, 6)
            }

            // Botones
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding(.vertical, 6).padding(.horizontal, 8).foregroundColor(.gray)
                Spacer()
                Button("Guardar Cliente y Vehículo") {
                    guardarCambios()
                }
                .buttonStyle(.plain).padding(.vertical, 8).padding(.horizontal, 12)
                .foregroundColor(Color("MercedesPetrolGreen")).cornerRadius(8)
                .disabled(nombreInvalido || telefonoInvalido || placasInvalidas || anioInvalido)
                .opacity((nombreInvalido || telefonoInvalido || placasInvalidas || anioInvalido) ? 0.6 : 1.0)
            }
            .padding(.horizontal).padding(.bottom, 8)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 700, minHeight: 500, maxHeight: 600)
        .cornerRadius(15)
    }
    
    func guardarCambios() {
        errorMsg = nil
        let nombreTrimmed = nombre.trimmingCharacters(in: .whitespaces)
        let telefonoTrimmed = telefono.trimmingCharacters(in: .whitespaces)
        let placasTrimmed = placas.trimmingCharacters(in: .whitespaces)
        let marcaTrimmed = marca.trimmingCharacters(in: .whitespaces)
        let modeloTrimmed = modelo.trimmingCharacters(in: .whitespaces)

        // Validación
        guard nombreTrimmed.split(separator: " ").count >= 2 else {
            errorMsg = "El Nombre Completo debe tener al menos 2 palabras."
            return
        }
        guard !telefonoTrimmed.isEmpty else {
            errorMsg = "El Teléfono no puede estar vacío."
            return
        }
        guard !placasTrimmed.isEmpty else {
            errorMsg = "Las Placas no pueden estar vacías."
            return
        }
        guard !marcaTrimmed.isEmpty, !modeloTrimmed.isEmpty else {
            errorMsg = "La Marca y el Modelo son obligatorios."
            return
        }
        guard let anio = Int(anioString) else {
            errorMsg = "El Año debe ser un número."
            return
        }
        
        let nuevoCliente = Cliente(nombre: nombreTrimmed, telefono: telefonoTrimmed, email: email.trimmingCharacters(in: .whitespaces))
        let nuevoVehiculo = Vehiculo(placas: placasTrimmed, marca: marcaTrimmed, modelo: modeloTrimmed, anio: anio)
        
        nuevoVehiculo.cliente = nuevoCliente
        nuevoCliente.vehiculos.append(nuevoVehiculo)
        
        modelContext.insert(nuevoCliente)
        dismiss()
    }
}


// --- 2. FORMULARIO DE CLIENTE (SOLO EDITAR) (¡ACTUALIZADO!) ---
fileprivate struct ClienteFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true

    @Bindable var cliente: Cliente

    // States para Seguridad y Errores
    @State private var isTelefonoUnlocked = false
    @State private var showingAuthModal = false
    @State private var authError = ""
    @State private var passwordAttempt = ""
    @State private var errorMsg: String?
    
    private enum AuthReason {
        case unlockTelefono, deleteCliente
    }
    @State private var authReason: AuthReason = .unlockTelefono
    
    private var nombreInvalido: Bool {
        cliente.nombre.trimmingCharacters(in: .whitespaces).split(separator: " ").count < 2
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Editar Cliente").font(.title).fontWeight(.bold)
                .padding(.top, 14).padding(.bottom, 8)
            
            Form {
                Section {
                    SectionHeader(title: "Datos del Cliente", subtitle: nil)
                    FormField(title: "• Nombre Completo", placeholder: "ej. José Cisneros", text: $cliente.nombre)
                        .validationHint(isInvalid: nombreInvalido, message: "Escribe nombre y apellido.")
                    
                    // Teléfono con Candado
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("• Teléfono (ID Único)").font(.caption).foregroundColor(.gray)
                            Image(systemName: isTelefonoUnlocked ? "lock.open.fill" : "lock.fill")
                                .foregroundColor(isTelefonoUnlocked ? .green : .red)
                                .font(.caption)
                        }
                        HStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                TextField("", text: $cliente.telefono)
                                    .disabled(!isTelefonoUnlocked)
                                    .padding(8).background(Color("MercedesBackground").opacity(0.9)).cornerRadius(8)
                                if cliente.telefono.isEmpty {
                                    Text("10 dígitos")
                                        .foregroundColor(Color.white.opacity(0.35))
                                        .padding(.horizontal, 12).allowsHitTesting(false)
                                }
                            }
                            Button {
                                if isTelefonoUnlocked { isTelefonoUnlocked = false }
                                else {
                                    authReason = .unlockTelefono
                                    showingAuthModal = true
                                }
                            } label: {
                                Text(isTelefonoUnlocked ? "Bloquear" : "Desbloquear")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(isTelefonoUnlocked ? .green : .red)
                        }
                        .validationHint(isInvalid: cliente.telefono.isEmpty, message: "El teléfono no puede estar vacío.")
                    }
                    
                    FormField(title: "Email (Opcional)", placeholder: "ej. jose@cliente.com", text: $cliente.email)
                }
            }
            .textFieldStyle(PlainTextFieldStyle())
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            if let errorMsg {
                Text(errorMsg)
                    .font(.caption).foregroundColor(.red).padding(.vertical, 6)
            }
            
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding(.vertical, 6).padding(.horizontal, 8).foregroundColor(.gray)
                Button("Eliminar", role: .destructive) {
                    authReason = .deleteCliente
                    showingAuthModal = true
                }
                .buttonStyle(.plain).padding(.vertical, 6).padding(.horizontal, 8).foregroundColor(.red)
                Spacer()
                Button("Guardar Cambios") {
                    let nameParts = cliente.nombre.trimmingCharacters(in: .whitespaces).split(separator: " ")
                    if nameParts.count >= 2 {
                        dismiss()
                    } else {
                        errorMsg = "El Nombre Completo debe tener al menos 2 palabras."
                    }
                }
                .buttonStyle(.plain).padding(.vertical, 8).padding(.horizontal, 12)
                .foregroundColor(Color("MercedesPetrolGreen")).cornerRadius(8)
                .disabled(nombreInvalido)
                .opacity(nombreInvalido ? 0.6 : 1.0)
            }
            .padding(.horizontal).padding(.bottom, 8)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 700, minHeight: 450, maxHeight: 600)
        .cornerRadius(15)
        .sheet(isPresented: $showingAuthModal) {
            authModalView()
        }
    }
    
    // Modal de Autenticación
    @ViewBuilder
    func authModalView() -> some View {
        let prompt = (authReason == .unlockTelefono) ? "Autoriza para editar el Teléfono." : "¡Acción irreversible! Autoriza para ELIMINAR a este cliente."
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Autorización Requerida").font(.title).fontWeight(.bold)
                Text(prompt)
                    .font(.callout).foregroundColor(authReason == .deleteCliente ? .red : .gray)
                if isTouchIDEnabled {
                    Button { Task { await authenticateWithTouchID() } } label: {
                        Label("Usar Huella (Touch ID)", systemImage: "touchid")
                            .font(.headline).padding().frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                    }.buttonStyle(.plain)
                    Text("o").foregroundColor(.gray)
                }
                Text("Usa tu contraseña de administrador:").font(.subheadline)
                SecureField("Contraseña", text: $passwordAttempt)
                    .padding(10).background(Color("MercedesCard")).cornerRadius(8)
                if !authError.isEmpty {
                    Text(authError).font(.caption2).foregroundColor(.red)
                }
                Button { authenticateWithPassword() } label: {
                    Label("Autorizar con Contraseña", systemImage: "lock.fill")
                        .font(.headline).padding().frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.4)).foregroundColor(.white).cornerRadius(8)
                }.buttonStyle(.plain)
            }
            .padding(28)
        }
        .frame(minWidth: 520, minHeight: 380)
        .preferredColorScheme(.dark)
        .onAppear { authError = ""; passwordAttempt = "" }
    }
    
    // Lógica de Autenticación
    func authenticateWithTouchID() async {
        let context = LAContext()
        let reason = (authReason == .unlockTelefono) ? "Autoriza la edición del Teléfono." : "Autoriza la ELIMINACIÓN del cliente."
        do {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                if success { await MainActor.run { onAuthSuccess() } }
            }
        } catch { await MainActor.run { authError = "Huella no reconocida." } }
    }
    
    func authenticateWithPassword() {
        if passwordAttempt == userPassword { onAuthSuccess() }
        else { authError = "Contraseña incorrecta."; passwordAttempt = "" }
    }
    
    func onAuthSuccess() {
        switch authReason {
        case .unlockTelefono:
            isTelefonoUnlocked = true
        case .deleteCliente:
            modelContext.delete(cliente)
            dismiss()
        }
        showingAuthModal = false
        authError = ""
        passwordAttempt = ""
    }
}


// --- 3. FORMULARIO DE VEHÍCULO (AÑADIR 2do+ / EDITAR) (¡ACTUALIZADO!) ---
fileprivate struct VehiculoFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true

    @State private var vehiculo: Vehiculo
    private var clientePadre: Cliente?
    private var esModoEdicion: Bool
    
    // States para Seguridad y Errores
    @State private var isPlacasUnlocked = false
    @State private var showingAuthModal = false
    @State private var authError = ""
    @State private var passwordAttempt = ""
    @State private var errorMsg: String?
    
    private enum AuthReason {
        case unlockPlacas, deleteVehiculo
    }
    @State private var authReason: AuthReason = .unlockPlacas
    
    var formTitle: String { esModoEdicion ? "Editar Vehículo" : "Añadir Nuevo Vehículo" }
    
    // Bools de Validación
    private var placasInvalida: Bool {
        vehiculo.placas.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var anioInvalido: Bool {
        vehiculo.anio <= 1900 // Un año razonable
    }
    
    init(cliente: Cliente) {
        self.clientePadre = cliente
        self._vehiculo = State(initialValue: Vehiculo(placas: "", marca: "", modelo: "", anio: 2020))
        self.esModoEdicion = false
    }
    
    init(vehiculo: Vehiculo) {
        self._vehiculo = State(initialValue: vehiculo)
        self.clientePadre = vehiculo.cliente
        self.esModoEdicion = true
    }
    
    // Binding para el año (convierte Int a String)
    private var anioString: Binding<String> {
        Binding(
            get: { String(vehiculo.anio) },
            set: { vehiculo.anio = Int($0) ?? 0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(formTitle).font(.title).fontWeight(.bold)
                .padding(.top, 14).padding(.bottom, 8)
            
            Form {
                Section {
                    Text("Cliente: \(clientePadre?.nombre ?? "Error")")
                        .font(.headline).foregroundColor(.gray)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("• Placas (ID Único)").font(.caption).foregroundColor(.gray)
                            if esModoEdicion {
                                Image(systemName: isPlacasUnlocked ? "lock.open.fill" : "lock.fill")
                                    .foregroundColor(isPlacasUnlocked ? .green : .red)
                                    .font(.caption)
                            }
                        }
                        HStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                TextField("", text: $vehiculo.placas)
                                    .disabled(esModoEdicion && !isPlacasUnlocked)
                                    .padding(8).background(Color("MercedesBackground").opacity(0.9)).cornerRadius(8)
                                if vehiculo.placas.isEmpty {
                                    Text("ej. ABC-123-D")
                                        .foregroundColor(Color.white.opacity(0.35))
                                        .padding(.horizontal, 12).allowsHitTesting(false)
                                }
                            }
                            if esModoEdicion {
                                Button {
                                    if isPlacasUnlocked { isPlacasUnlocked = false }
                                    else {
                                        authReason = .unlockPlacas
                                        showingAuthModal = true
                                    }
                                } label: {
                                    Text(isPlacasUnlocked ? "Bloquear" : "Desbloquear")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(isPlacasUnlocked ? .green : .red)
                            }
                        }
                        .validationHint(isInvalid: placasInvalida, message: "Las placas son obligatorias.")
                    }
                
                    HStack(spacing: 16) {
                        FormField(title: "• Marca", placeholder: "ej. Nissan", text: $vehiculo.marca)
                        FormField(title: "• Modelo", placeholder: "ej. Versa", text: $vehiculo.modelo)
                        FormField(title: "• Año", placeholder: "ej. 2020", text: anioString)
                            .validationHint(isInvalid: anioInvalido, message: "Año no válido.")
                    }
                }
            }
            .textFieldStyle(PlainTextFieldStyle())
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            
            if let errorMsg {
                Text(errorMsg)
                    .font(.caption).foregroundColor(.red).padding(.vertical, 6)
            }
            
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding(.vertical, 6).padding(.horizontal, 8).foregroundColor(.gray)
                if esModoEdicion {
                    Button("Eliminar", role: .destructive) {
                        authReason = .deleteVehiculo
                        showingAuthModal = true
                    }
                    .buttonStyle(.plain).padding(.vertical, 6).padding(.horizontal, 8).foregroundColor(.red)
                }
                Spacer()
                Button(esModoEdicion ? "Guardar Cambios" : "Añadir Vehículo") {
                    guardarCambios()
                }
                .buttonStyle(.plain).padding(.vertical, 8).padding(.horizontal, 12)
                .foregroundColor(Color("MercedesPetrolGreen")).cornerRadius(8)
                .disabled(placasInvalida || anioInvalido || vehiculo.marca.isEmpty || vehiculo.modelo.isEmpty)
                .opacity((placasInvalida || anioInvalido || vehiculo.marca.isEmpty || vehiculo.modelo.isEmpty) ? 0.6 : 1.0)
            }
            .padding(.horizontal).padding(.bottom, 8)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 700, minHeight: 450, maxHeight: 600)
        .cornerRadius(15)
        .sheet(isPresented: $showingAuthModal) {
            authModalView()
        }
    }
    
    // Modal de Autenticación
    @ViewBuilder
    func authModalView() -> some View {
        let prompt = (authReason == .unlockPlacas) ? "Autoriza para editar las Placas." : "Autoriza para ELIMINAR este vehículo."
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Autorización Requerida").font(.title).fontWeight(.bold)
                Text(prompt)
                    .font(.callout).foregroundColor(authReason == .deleteVehiculo ? .red : .gray)
                if isTouchIDEnabled {
                    Button { Task { await authenticateWithTouchID() } } label: {
                        Label("Usar Huella (Touch ID)", systemImage: "touchid")
                            .font(.headline).padding().frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                    }.buttonStyle(.plain)
                    Text("o").foregroundColor(.gray)
                }
                Text("Usa tu contraseña de administrador:").font(.subheadline)
                SecureField("Contraseña", text: $passwordAttempt)
                    .padding(10).background(Color("MercedesCard")).cornerRadius(8)
                if !authError.isEmpty {
                    Text(authError).font(.caption2).foregroundColor(.red)
                }
                Button { authenticateWithPassword() } label: {
                    Label("Autorizar con Contraseña", systemImage: "lock.fill")
                        .font(.headline).padding().frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.4)).foregroundColor(.white).cornerRadius(8)
                }.buttonStyle(.plain)
            }
            .padding(28)
        }
        .frame(minWidth: 520, minHeight: 380)
        .preferredColorScheme(.dark)
        .onAppear { authError = ""; passwordAttempt = "" }
    }
    
    // Lógica de Guardar/Auth
    func guardarCambios() {
        errorMsg = nil
        
        let placasTrimmed = vehiculo.placas.trimmingCharacters(in: .whitespaces)
        let marcaTrimmed = vehiculo.marca.trimmingCharacters(in: .whitespaces)
        let modeloTrimmed = vehiculo.modelo.trimmingCharacters(in: .whitespaces)
        
        guard !placasTrimmed.isEmpty else {
            errorMsg = "Las placas no pueden estar vacías."
            return
        }
        guard !marcaTrimmed.isEmpty, !modeloTrimmed.isEmpty else {
            errorMsg = "La Marca y el Modelo son obligatorios."
            return
        }
        guard vehiculo.anio > 1900 && vehiculo.anio <= (Calendar.current.component(.year, from: Date()) + 1) else {
            errorMsg = "Por favor, ingresa un año válido."
            return
        }
        
        vehiculo.placas = placasTrimmed
        vehiculo.marca = marcaTrimmed
        vehiculo.modelo = modeloTrimmed
        
        if !esModoEdicion {
            vehiculo.cliente = clientePadre
            clientePadre?.vehiculos.append(vehiculo)
            modelContext.insert(vehiculo)
        }
        dismiss()
    }
    
    func authenticateWithTouchID() async {
        let context = LAContext()
        let reason = (authReason == .unlockPlacas) ? "Autoriza la edición de las Placas." : "Autoriza la ELIMINACIÓN del vehículo."
        do {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                if success { await MainActor.run { onAuthSuccess() } }
            }
        } catch { await MainActor.run { authError = "Huella no reconocida." } }
    }
    
    func authenticateWithPassword() {
        if passwordAttempt == userPassword { onAuthSuccess() }
        else { authError = "Contraseña incorrecta."; passwordAttempt = "" }
    }
    
    func onAuthSuccess() {
        switch authReason {
        case .unlockPlacas:
            isPlacasUnlocked = true
        case .deleteVehiculo:
            modelContext.delete(vehiculo)
            dismiss()
        }
        showingAuthModal = false
        authError = ""
        passwordAttempt = ""
    }
}


// --- VISTAS HELPER REUTILIZABLES (¡NUEVAS!) ---
fileprivate struct SectionHeader: View {
    var title: String
    var subtitle: String?
    var body: some View {
        HStack {
            Text(title).font(.headline).foregroundColor(.white)
            Spacer()
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle).font(.caption2).foregroundColor(.gray)
            }
        }
        .padding(.bottom, 2)
    }
}

fileprivate struct FormField: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            
            ZStack(alignment: .leading) {
                TextField("", text: $text)
                    .padding(8)
                    .background(Color("MercedesBackground").opacity(0.9))
                    .cornerRadius(8)
                
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(Color.white.opacity(0.35))
                        .padding(.horizontal, 12)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

fileprivate extension View {
    func validationHint(isInvalid: Bool, message: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            self
            if isInvalid {
                Text(message)
                    .font(.caption2)
                    .foregroundColor(.red.opacity(0.9))
            }
        }
    }
}
