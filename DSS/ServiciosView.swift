import SwiftUI
import SwiftData
import LocalAuthentication // Necesario para seguridad

// --- MODO DEL MODAL (Sin cambios) ---
fileprivate enum ServiceModalMode: Identifiable {
    case add
    case edit(Servicio)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let servicio): return servicio.nombre
        }
    }
}


// --- VISTA PRINCIPAL (Sin cambios) ---
struct ServiciosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Servicio.nombre) private var servicios: [Servicio]
    
    @State private var modalMode: ServiceModalMode?
    @State private var searchQuery = "" // ¡Añadimos el buscador!
    
    // Filtra los servicios
    var filteredServicios: [Servicio] {
        if searchQuery.isEmpty {
            return servicios
        } else {
            let query = searchQuery.lowercased()
            return servicios.filter {
                $0.nombre.lowercased().contains(query) ||
                $0.rolRequerido.rawValue.lowercased().contains(query) ||
                $0.especialidadRequerida.lowercased().contains(query)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Gestión de Servicios")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Button {
                    modalMode = .add
                } label: {
                    Label("Añadir Servicios", systemImage: "plus")
                        .font(.headline).padding(.vertical, 10).padding(.horizontal)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)
            
            Text("Añade los servicios que ofrece tu taller.")
                .font(.title3).foregroundColor(.gray).padding(.bottom, 20)
            
            // --- ¡BUSCADOR AÑADIDO! ---
            TextField("Buscar por Nombre, Rol o Especialidad...", text: $searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                .padding(.bottom, 20)
            
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(filteredServicios) { servicio in // Usa la lista filtrada
                        VStack(alignment: .leading, spacing: 10) {
                            Text(servicio.nombre)
                                .font(.title2).fontWeight(.semibold)
                            Text(servicio.descripcion)
                                .font(.body).foregroundColor(.gray)
                            Divider()
                            Text("Requerimientos:")
                                .font(.headline)
                            HStack {
                                Label(servicio.especialidadRequerida, systemImage: "wrench.and.screwdriver.fill")
                                Label(servicio.rolRequerido.rawValue, systemImage: "person.badge.shield.checkmark.fill")
                            }
                            .font(.subheadline)
                            .foregroundColor(Color("MercedesPetrolGreen"))
                            Text("Productos: \(formatearIngredientes(servicio.ingredientes))")
                                .font(.subheadline).foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("MercedesCard"))
                        .cornerRadius(10)
                        .onTapGesture {
                            modalMode = .edit(servicio)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(30)
        .sheet(item: $modalMode) { incomingMode in
            ServicioFormView(mode: incomingMode)
                .environment(\.modelContext, modelContext)
        }
    }
    
    func formatearIngredientes(_ ingredientes: [Ingrediente]) -> String {
        return ingredientes.map { "\($0.nombreProducto) (\(String(format: "%.2f", $0.cantidadUsada)))" }
                           .joined(separator: ", ")
    }
}


// --- VISTA DEL FORMULARIO (¡REDISEÑADA!) ---
fileprivate struct ServicioFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true
    
    @Query private var productos: [Producto]
    @Query private var personal: [Personal]

    let mode: ServiceModalMode
    
    // States para los campos
    @State private var nombre = ""
    @State private var descripcion = ""
    @State private var especialidadRequerida = ""
    @State private var rolRequerido: Rol = .ayudante
    @State private var precioString = ""
    @State private var duracionString = "1.0"
    @State private var cantidadesProductos: [String: Double] = [:]
    @State private var especialidadesDisponibles: [String] = []

    // States para Seguridad y Errores
    @State private var isNombreUnlocked = false
    @State private var showingAuthModal = false
    @State private var authError = ""
    @State private var passwordAttempt = ""
    @State private var errorMsg: String?
    
    private enum AuthReason {
        case unlockNombre, deleteServicio
    }
    @State private var authReason: AuthReason = .unlockNombre
    
    private var servicioAEditar: Servicio?
    var formTitle: String {
        switch mode {
        case .add: return "Añadir Nuevo Servicio"
        case .edit: return "Editar Servicio"
        }
    }
    
    // --- Bools de Validación ---
    private var nombreInvalido: Bool {
        nombre.trimmingCharacters(in: .whitespaces).count < 3
    }
    private var precioInvalido: Bool {
        Double(precioString) == nil
    }
    private var duracionInvalida: Bool {
        Double(duracionString) == nil
    }
    private var especialidadInvalida: Bool {
        especialidadRequerida.isEmpty
    }
    
    // Inicializador
    init(mode: ServiceModalMode) {
        self.mode = mode
        
        if case .edit(let servicio) = mode {
            self.servicioAEditar = servicio
            _nombre = State(initialValue: servicio.nombre)
            _descripcion = State(initialValue: servicio.descripcion)
            _especialidadRequerida = State(initialValue: servicio.especialidadRequerida)
            _rolRequerido = State(initialValue: servicio.rolRequerido)
            _precioString = State(initialValue: "\(servicio.precioAlCliente)")
            _duracionString = State(initialValue: "\(servicio.duracionHoras)")
            let cantidades = Dictionary(uniqueKeysWithValues: servicio.ingredientes.map { ($0.nombreProducto, $0.cantidadUsada) })
            _cantidadesProductos = State(initialValue: cantidades)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Título
            VStack(spacing: 4) {
                Text(formTitle).font(.title).fontWeight(.bold)
                Text("Completa los datos. Los campos marcados con • son obligatorios.")
                    .font(.footnote).foregroundColor(.gray)
            }
            .padding(.top, 14).padding(.bottom, 8)

            Form {
                // --- Sección 1: Detalles ---
                Section {
                    SectionHeader(title: "Detalles del Servicio", subtitle: nil)
                    
                    // --- Nombre (ID Único) con Candado ---
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("• Nombre del Servicio").font(.caption).foregroundColor(.gray)
                            if servicioAEditar != nil {
                                Image(systemName: isNombreUnlocked ? "lock.open.fill" : "lock.fill")
                                    .foregroundColor(isNombreUnlocked ? .green : .red)
                                    .font(.caption)
                            }
                        }
                        HStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                TextField("", text: $nombre)
                                    .disabled(servicioAEditar != nil && !isNombreUnlocked)
                                    .padding(8).background(Color("MercedesBackground").opacity(0.9)).cornerRadius(8)
                                if nombre.isEmpty {
                                    Text("ej. Cambio de Frenos Delanteros")
                                        .foregroundColor(Color.white.opacity(0.35))
                                        .padding(.horizontal, 12).allowsHitTesting(false)
                                }
                            }
                            if servicioAEditar != nil {
                                Button {
                                    if isNombreUnlocked { isNombreUnlocked = false }
                                    else {
                                        authReason = .unlockNombre
                                        showingAuthModal = true
                                    }
                                } label: {
                                    Text(isNombreUnlocked ? "Bloquear" : "Desbloquear")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(isNombreUnlocked ? .green : .red)
                            }
                        }
                        .validationHint(isInvalid: nombreInvalido, message: "El nombre debe tener al menos 3 caracteres.")
                    }
                    
                    FormField(title: "Descripción", placeholder: "ej. Reemplazo de balatas y rectificación de discos", text: $descripcion)
                    
                    HStack(spacing: 16) {
                        FormField(title: "• Precio Mano de Obra ($)", placeholder: "ej. 1500", text: $precioString)
                            .validationHint(isInvalid: precioInvalido, message: "Debe ser un número.")
                        FormField(title: "• Duración Estimada (Horas)", placeholder: "ej. 2.5", text: $duracionString)
                            .validationHint(isInvalid: duracionInvalida, message: "Debe ser un número.")
                    }
                }
                
                // --- Sección 2: Requerimientos ---
                Section {
                    SectionHeader(title: "Requerimientos", subtitle: nil)
                    HStack(spacing: 16) {
                        Picker("• Especialidad Requerida", selection: $especialidadRequerida) {
                            Text("Seleccionar...").tag("")
                            ForEach(especialidadesDisponibles, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        
                        Picker("• Rol Requerido", selection: $rolRequerido) {
                            ForEach(Rol.allCases, id: \.self) { rol in
                                Text(rol.rawValue).tag(rol)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // --- Sección 3: Productos ---
                Section {
                    SectionHeader(title: "Productos Requeridos", subtitle: "Ingresa la cantidad a usar por servicio (ej. 0.5)")
                    
                    List(productos) { producto in
                        HStack {
                            Text("\(producto.nombre) (\(producto.unidadDeMedida))")
                            Spacer()
                            TextField("0.0", text: Binding(
                                get: {
                                    cantidadesProductos[producto.nombre].map { String(format: "%.2f", $0) } ?? ""
                                },
                                set: {
                                    cantidadesProductos[producto.nombre] = Double($0)
                                }
                            ))
                            .frame(width: 80)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .listRowBackground(Color("MercedesCard"))
                    }
                    .frame(minHeight: 150, maxHeight: 250)
                }
            }
            .textFieldStyle(PlainTextFieldStyle())
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            
            // Mensaje de Error
            if let errorMsg {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.vertical, 6)
            }
            
            // --- Barra de Botones ---
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding(.vertical, 6).padding(.horizontal, 8).foregroundColor(.gray)
                
                if case .edit = mode {
                    Button("Eliminar", role: .destructive) {
                        authReason = .deleteServicio
                        showingAuthModal = true
                    }
                    .buttonStyle(.plain).padding(.vertical, 6).padding(.horizontal, 8).foregroundColor(.red)
                }
                Spacer()
                Button(servicioAEditar == nil ? "Añadir Servicio" : "Guardar Cambios") {
                    guardarCambios()
                }
                .buttonStyle(.plain).padding(.vertical, 8).padding(.horizontal, 12)
                .foregroundColor(Color("MercedesPetrolGreen")).cornerRadius(8)
                .disabled(nombreInvalido || precioInvalido || duracionInvalida || especialidadInvalida)
                .opacity((nombreInvalido || precioInvalido || duracionInvalida || especialidadInvalida) ? 0.6 : 1.0)
            }
            .padding(.horizontal).padding(.bottom, 8)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 700, minHeight: 600, maxHeight: 750) // Más ancho y corto
        .cornerRadius(15)
        .sheet(isPresented: $showingAuthModal) {
            authModalView()
        }
        .onAppear {
            // Carga las especialidades del personal para el Picker
            let todasLasHabilidades = personal.flatMap { $0.especialidades }
            especialidadesDisponibles = Array(Set(todasLasHabilidades)).sorted()
            
            if servicioAEditar == nil {
                rolRequerido = .ayudante
                if let primera = especialidadesDisponibles.first {
                    especialidadRequerida = primera
                }
            }
        }
    }
    
    // --- VISTA: Modal de Autenticación ---
    @ViewBuilder
    func authModalView() -> some View {
        let prompt = (authReason == .unlockNombre) ?
            "Autoriza para editar el Nombre del Servicio." :
            "Autoriza para ELIMINAR este servicio."
        
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Autorización Requerida").font(.title).fontWeight(.bold)
                Text(prompt)
                    .font(.callout)
                    .foregroundColor(authReason == .deleteServicio ? .red : .gray)
                
                if isTouchIDEnabled {
                    Button { Task { await authenticateWithTouchID() } } label: {
                        Label("Usar Huella (Touch ID)", systemImage: "touchid")
                            .font(.headline).padding().frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                    }
                    .buttonStyle(.plain)
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
                }
                .buttonStyle(.plain)
            }
            .padding(28)
        }
        .frame(minWidth: 520, minHeight: 380)
        .preferredColorScheme(.dark)
        .onAppear { authError = ""; passwordAttempt = "" }
    }
    
    // --- Lógica del Formulario (Validaciones) ---
    func guardarCambios() {
        errorMsg = nil
        let trimmedNombre = nombre.trimmingCharacters(in: .whitespaces)
        
        guard trimmedNombre.count >= 3 else {
            errorMsg = "El nombre del servicio debe tener al menos 3 caracteres."
            return
        }
        guard let precio = Double(precioString), precio >= 0 else {
            errorMsg = "El Precio debe ser un número válido."
            return
        }
        guard let duracion = Double(duracionString), duracion > 0 else {
            errorMsg = "La Duración debe ser un número mayor a 0."
            return
        }
        guard !especialidadRequerida.isEmpty else {
            errorMsg = "Debes seleccionar una Especialidad Requerida."
            return
        }
        
        let ingredientesArray: [Ingrediente] = cantidadesProductos.compactMap { (nombre, cantidad) in
            guard cantidad > 0 else { return nil }
            return Ingrediente(nombreProducto: nombre, cantidadUsada: cantidad)
        }
        
        if let servicio = servicioAEditar {
            servicio.nombre = trimmedNombre
            servicio.descripcion = descripcion
            servicio.especialidadRequerida = especialidadRequerida
            servicio.rolRequerido = rolRequerido
            servicio.precioAlCliente = precio
            servicio.duracionHoras = duracion
            servicio.ingredientes = ingredientesArray
        } else {
            let nuevoServicio = Servicio(
                nombre: trimmedNombre,
                descripcion: descripcion,
                especialidadRequerida: especialidadRequerida,
                rolRequerido: rolRequerido,
                ingredientes: ingredientesArray,
                precioAlCliente: precio,
                duracionHoras: duracion
            )
            modelContext.insert(nuevoServicio)
        }
        dismiss()
    }
    
    func eliminarServicio(_ servicio: Servicio) {
        modelContext.delete(servicio)
        dismiss()
    }
    
    // --- Lógica de Autenticación ---
    func authenticateWithTouchID() async {
        let context = LAContext()
        let reason = (authReason == .unlockNombre) ? "Autoriza la edición del Nombre." : "Autoriza la ELIMINACIÓN del servicio."
        do {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                if success { await MainActor.run { onAuthSuccess() } }
            }
        } catch { await MainActor.run { authError = "Huella no reconocida." } }
    }
    
    func authenticateWithPassword() {
        if passwordAttempt == userPassword {
            onAuthSuccess()
        } else {
            authError = "Contraseña incorrecta."
            passwordAttempt = ""
        }
    }
    
    func onAuthSuccess() {
        switch authReason {
        case .unlockNombre:
            isNombreUnlocked = true
        case .deleteServicio:
            if case .edit(let servicio) = mode {
                eliminarServicio(servicio)
            }
        }
        showingAuthModal = false
        authError = ""
        passwordAttempt = ""
    }
}


// --- Helpers de UI (¡LOS MISMOS QUE EN PERSONALVIEW!) ---
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
