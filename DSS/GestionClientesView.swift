import SwiftUI
import SwiftData
import LocalAuthentication // Necesario para el candado

// --- Enums para controlar los Modales (Sin cambios) ---
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

// --- VISTA PRINCIPAL DE CLIENTES (¡ACTUALIZADA!) ---
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
            // --- Cabecera (Sin cambios) ---
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
            
            // --- Buscador (Sin cambios) ---
            TextField("Buscar por Nombre, Teléfono o Email...", text: $searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                .padding(.bottom, 20)
            
            // --- Lista de Clientes (¡ACTUALIZADA!) ---
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(filteredClientes) { cliente in
                        VStack(alignment: .leading) {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(cliente.nombre)
                                        .font(.title2).fontWeight(.semibold)
                                    
                                    // --- ¡CAMBIO! (Links Clickeables) ---
                                    Link(destination: URL(string: "tel:\(cliente.telefono)")!) {
                                        Label(cliente.telefono, systemImage: "phone.fill")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(Color("MercedesPetrolGreen"))
                                    
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
                            
                            // Botón para Añadir 2do/3er Vehículo
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

    @State private var nombre = ""
    @State private var telefono = ""
    @State private var email = ""
    @State private var placas = ""
    @State private var marca = ""
    @State private var modelo = ""
    @State private var anioString = ""
    
    @State private var errorMsg: String?

    var body: some View {
        FormModal(title: "Añadir Nuevo Cliente", minHeight: 600) {
            
            Section("Datos del Cliente") {
                FormField(title: "Nombre Completo (ej. José Cisneros)", text: $nombre)
                FormField(title: "Teléfono (ID Único)", text: $telefono)
                FormField(title: "Email (Opcional)", text: $email)
            }
            
            Section("Datos del Primer Vehículo") {
                FormField(title: "Placas (ID Único)", text: $placas)
                FormField(title: "Marca", text: $marca)
                FormField(title: "Modelo", text: $modelo)
                FormField(title: "Año", text: $anioString)
            }
            
            if let errorMsg {
                Text(errorMsg).font(.caption).foregroundColor(.red)
            }

            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding().foregroundColor(.gray)
                Spacer()
                Button("Guardar Cliente y Vehículo") {
                    guardarCambios()
                }
                .buttonStyle(.plain).padding()
                .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
            }
        }
    }
    
    func guardarCambios() {
        // --- VALIDACIONES ---
        let nameParts = nombre.trimmingCharacters(in: .whitespaces).split(separator: " ")
        if nameParts.count < 2 {
            errorMsg = "El Nombre Completo debe tener al menos 2 palabras."
            return
        }
        if telefono.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMsg = "El Teléfono no puede estar vacío."
            return
        }
        if placas.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMsg = "Las Placas no pueden estar vacías."
            return
        }
        guard let anio = Int(anioString) else {
            errorMsg = "El Año debe ser un número."
            return
        }
        // --- FIN VALIDACIONES ---
        
        let nuevoCliente = Cliente(nombre: nombre, telefono: telefono, email: email)
        let nuevoVehiculo = Vehiculo(placas: placas, marca: marca, modelo: modelo, anio: anio)
        
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

    // States para el candado
    @State private var isTelefonoUnlocked = false
    @State private var showingAuthModal = false
    @State private var authError = ""
    @State private var passwordAttempt = ""

    var body: some View {
        FormModal(title: "Editar Cliente", minHeight: 400) {
            FormField(title: "Nombre Completo", text: $cliente.nombre)
            
            // --- CAMBIO: Teléfono con Candado 🔒 ---
            HStack {
                FormField(title: "Teléfono", text: $cliente.telefono)
                    .disabled(!isTelefonoUnlocked)
                
                Button {
                    if isTelefonoUnlocked {
                        isTelefonoUnlocked = false
                    } else {
                        showingAuthModal = true
                    }
                } label: {
                    Image(systemName: isTelefonoUnlocked ? "lock.open.fill" : "lock.fill")
                        .foregroundColor(isTelefonoUnlocked ? .green : .red)
                }
                .buttonStyle(.plain)
            }
            if !cliente.telefono.isEmpty {
                Link("Llamar a \(cliente.telefono)", destination: URL(string: "tel:\(cliente.telefono)")!)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                    .padding(.leading, 5)
            }
            
            FormField(title: "Email (Opcional)", text: $cliente.email)
            if !cliente.email.isEmpty {
                Link("Enviar correo a \(cliente.email)", destination: URL(string: "mailto:\(cliente.email)")!)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                    .padding(.leading, 5)
            }
            
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding().foregroundColor(.gray)
                Button("Eliminar", role: .destructive) {
                    modelContext.delete(cliente)
                    dismiss()
                }
                .buttonStyle(.plain).padding().foregroundColor(.red)
                Spacer()
                Button("Guardar Cambios") {
                    // Validar nombre antes de guardar
                    let nameParts = cliente.nombre.trimmingCharacters(in: .whitespaces).split(separator: " ")
                    if nameParts.count >= 2 {
                        dismiss() // SwiftData guarda automáticamente
                    }
                }
                .buttonStyle(.plain).padding()
                .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
            }
            .padding(.top, 10)
        }
        .sheet(isPresented: $showingAuthModal) {
            authModalView()
        }
    }
    
    // --- Modal de Autenticación (¡NUEVO!) ---
    @ViewBuilder
    func authModalView() -> some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Autorización Requerida").font(.largeTitle).fontWeight(.bold)
                Text("Autoriza para editar el Teléfono.").font(.title3).foregroundColor(.gray).padding(.bottom)
                
                if isTouchIDEnabled {
                    Button { Task { await authenticateWithTouchID() } }
                    label: {
                        Label("Usar Huella (Touch ID)", systemImage: "touchid")
                            .font(.headline).padding().frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                    }.buttonStyle(.plain)
                    Text("o").foregroundColor(.gray)
                }
                
                Text("Usa tu contraseña de administrador:").font(.headline)
                SecureField("Contraseña", text: $passwordAttempt)
                    .padding(12).background(Color("MercedesCard")).cornerRadius(8)
                
                if !authError.isEmpty {
                    Text(authError).font(.caption).foregroundColor(.red)
                }
                
                Button { authenticateWithPassword() }
                label: {
                    Label("Autorizar con Contraseña", systemImage: "lock.fill")
                        .font(.headline).padding().frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.4)).foregroundColor(.white).cornerRadius(8)
                }.buttonStyle(.plain)
            }
            .padding(40)
        }
        .frame(minWidth: 500, minHeight: 450)
        .preferredColorScheme(.dark)
        .onAppear { authError = ""; passwordAttempt = "" }
    }
    
    // --- Lógica de Autenticación (¡NUEVA!) ---
    func authenticateWithTouchID() async {
        let context = LAContext()
        let reason = "Autoriza la edición del Teléfono."
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
        isTelefonoUnlocked = true
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
    
    // States para el candado
    @State private var isPlacasUnlocked = false
    @State private var showingAuthModal = false
    @State private var authError = ""
    @State private var passwordAttempt = ""
    
    var formTitle: String { esModoEdicion ? "Editar Vehículo" : "Añadir Nuevo Vehículo" }
    
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
    
    private var anioString: Binding<String> {
        Binding(
            get: { String(vehiculo.anio) },
            set: { vehiculo.anio = Int($0) ?? 2020 }
        )
    }

    var body: some View {
        FormModal(title: formTitle, minHeight: 450) {
            Text("Cliente: \(clientePadre?.nombre ?? "Error")")
                .font(.headline).foregroundColor(.gray)
            
            // --- CAMBIO: Placas con Candado 🔒 ---
            HStack {
                FormField(title: "Placas", text: $vehiculo.placas)
                    .disabled(esModoEdicion && !isPlacasUnlocked)
                
                if esModoEdicion {
                    Button {
                        if isPlacasUnlocked {
                            isPlacasUnlocked = false
                        } else {
                            showingAuthModal = true
                        }
                    } label: {
                        Image(systemName: isPlacasUnlocked ? "lock.open.fill" : "lock.fill")
                            .foregroundColor(isPlacasUnlocked ? .green : .red)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            FormField(title: "Marca", text: $vehiculo.marca)
            FormField(title: "Modelo", text: $vehiculo.modelo)
            FormField(title: "Año", text: anioString)
            
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding().foregroundColor(.gray)
                if esModoEdicion {
                    Button("Eliminar", role: .destructive) {
                        modelContext.delete(vehiculo)
                        dismiss()
                    }
                    .buttonStyle(.plain).padding().foregroundColor(.red)
                }
                Spacer()
                Button(esModoEdicion ? "Guardar Cambios" : "Añadir Vehículo") {
                    guardarCambios()
                }
                .buttonStyle(.plain).padding()
                .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
            }
            .padding(.top, 10)
        }
        .sheet(isPresented: $showingAuthModal) {
            authModalView()
        }
    }
    
    // --- Modal de Autenticación (¡NUEVO!) ---
    @ViewBuilder
    func authModalView() -> some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Autorización Requerida").font(.largeTitle).fontWeight(.bold)
                Text("Autoriza para editar las Placas.").font(.title3).foregroundColor(.gray).padding(.bottom)
                
                if isTouchIDEnabled {
                    Button { Task { await authenticateWithTouchID() } }
                    label: {
                        Label("Usar Huella (Touch ID)", systemImage: "touchid")
                            .font(.headline).padding().frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                    }.buttonStyle(.plain)
                    Text("o").foregroundColor(.gray)
                }
                
                Text("Usa tu contraseña de administrador:").font(.headline)
                SecureField("Contraseña", text: $passwordAttempt)
                    .padding(12).background(Color("MercedesCard")).cornerRadius(8)
                
                if !authError.isEmpty {
                    Text(authError).font(.caption).foregroundColor(.red)
                }
                
                Button { authenticateWithPassword() }
                label: {
                    Label("Autorizar con Contraseña", systemImage: "lock.fill")
                        .font(.headline).padding().frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.4)).foregroundColor(.white).cornerRadius(8)
                }.buttonStyle(.plain)
            }
            .padding(40)
        }
        .frame(minWidth: 500, minHeight: 450)
        .preferredColorScheme(.dark)
        .onAppear { authError = ""; passwordAttempt = "" }
    }
    
    // --- Lógica de Guardar/Auth (¡NUEVA!) ---
    func guardarCambios() {
        guard !vehiculo.placas.isEmpty, !vehiculo.marca.isEmpty else { return }
        
        if !esModoEdicion {
            vehiculo.cliente = clientePadre
            clientePadre?.vehiculos.append(vehiculo)
            modelContext.insert(vehiculo)
        }
        dismiss()
    }
    
    func authenticateWithTouchID() async {
        let context = LAContext()
        let reason = "Autoriza la edición de las Placas."
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
        isPlacasUnlocked = true
        showingAuthModal = false
        authError = ""
        passwordAttempt = ""
    }
}


// --- VISTAS HELPER REUTILIZABLES (Sin cambios) ---
fileprivate struct FormModal<Content: View>: View {
    var title: String
    var minHeight: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.largeTitle).fontWeight(.bold)
            
            Form {
                content()
            }
            .textFieldStyle(PlainTextFieldStyle())
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .padding(30)
        .frame(minWidth: 500, minHeight: minHeight)
        .background(Color("MercedesCard"))
        .cornerRadius(15)
        .preferredColorScheme(.dark)
    }
}

fileprivate struct FormField: View {
    var title: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundColor(.gray)
            TextField("", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(10)
                .background(Color("MercedesBackground"))
                .cornerRadius(8)
        }
    }
}
