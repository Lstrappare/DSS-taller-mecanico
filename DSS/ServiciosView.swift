import SwiftUI
import SwiftData
import LocalAuthentication

// --- MODO DEL MODAL (Actualizado con assign) ---
fileprivate enum ServiceModalMode: Identifiable {
    case add
    case edit(Servicio)
    case assign(Servicio)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let servicio): return servicio.nombre
        case .assign(let servicio): return "assign-\(servicio.nombre)"
        }
    }
}

// --- VISTA PRINCIPAL (comportamiento de la versión anterior) ---
struct ServiciosView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppNavigationState
    @Query(sort: \Servicio.nombre) private var servicios: [Servicio]
    
    @State private var modalMode: ServiceModalMode?
    @State private var searchQuery = ""
    
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
            
            Text("Selecciona un servicio para asignarlo a un cliente.")
                .font(.title3).foregroundColor(.gray).padding(.bottom, 20)
            
            TextField("Buscar por Nombre, Rol o Especialidad...", text: $searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                .padding(.bottom, 20)
            
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(filteredServicios) { servicio in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(servicio.nombre)
                                    .font(.title2).fontWeight(.semibold)
                                Spacer()
                                Button {
                                    modalMode = .edit(servicio)
                                } label: {
                                    Text("Editar Servicio")
                                    Image(systemName: "pencil")
                                        
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.gray)
                            }
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
                            modalMode = .assign(servicio)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(30)
        .sheet(item: $modalMode) { mode in
            switch mode {
            case .add:
                ServicioFormView(mode: .add)
                    .environment(\.modelContext, modelContext)
            case .edit(let servicio):
                ServicioFormView(mode: .edit(servicio))
                    .environment(\.modelContext, modelContext)
            case .assign(let servicio):
                AsignarServicioModal(servicio: servicio, appState: appState)
                    .environment(\.modelContext, modelContext)
            }
        }
    }
    
    func formatearIngredientes(_ ingredientes: [Ingrediente]) -> String {
        ingredientes.map { "\($0.nombreProducto) (\(String(format: "%.2f", $0.cantidadUsada)))" }
            .joined(separator: ", ")
    }
}

// --- MODAL DE ASIGNACIÓN (UI mejorada, misma lógica) ---
fileprivate struct AsignarServicioModal: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var personal: [Personal]
    @Query private var productos: [Producto]
    @Query private var vehiculos: [Vehiculo]
    
    var servicio: Servicio
    @ObservedObject var appState: AppNavigationState
    
    // UI State
    @State private var vehiculoSeleccionadoID: Vehiculo.ID?
    @State private var searchVehiculo = ""
    @State private var alertaError: String?
    @State private var mostrandoAlerta = false
    
    // Preview calculada
    @State private var candidato: Personal?
    @State private var costoEstimado: Double = 0
    @State private var hayStockInsuficiente: Bool = false
    
    var vehiculosFiltrados: [Vehiculo] {
        if searchVehiculo.trimmingCharacters(in: .whitespaces).isEmpty { return vehiculos }
        let q = searchVehiculo.lowercased()
        return vehiculos.filter { v in
            v.placas.lowercased().contains(q) ||
            v.marca.lowercased().contains(q) ||
            v.modelo.lowercased().contains(q) ||
            (v.cliente?.nombre.lowercased().contains(q) ?? false)
        }
    }
    
    var candidatoColor: Color {
        guard let c = candidato else { return .red }
        switch c.estado {
        case .disponible: return .green
        case .ocupado: return .red
        case .descanso: return .yellow
        case .ausente: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Asignar Servicio")
                .font(.largeTitle).fontWeight(.bold)
            
            // Header con resumen del servicio
            VStack(alignment: .leading, spacing: 8) {
                Text(servicio.nombre)
                    .font(.title2).fontWeight(.semibold)
                HStack(spacing: 8) {
                    chip(text: servicio.rolRequerido.rawValue, systemImage: "person.badge.shield.checkmark.fill")
                    chip(text: servicio.especialidadRequerida, systemImage: "wrench.and.screwdriver.fill")
                    chip(text: String(format: "%.1f h", servicio.duracionHoras), systemImage: "clock")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color("MercedesCard"))
            .cornerRadius(10)
            
            // Selector de vehículo con búsqueda
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Selecciona el Vehículo")
                        .font(.headline)
                    Spacer()
                    // Enlace a Gestión de Clientes
                    Button {
                        appState.seleccion = .gestionClientes
                        dismiss()
                    } label: {
                        Text("Gestionar Clientes y Vehículos")
                            .underline()
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                }
                
                TextField("Buscar por placas, cliente, marca o modelo...", text: $searchVehiculo)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(10)
                    .background(Color("MercedesBackground"))
                    .cornerRadius(8)
                
                // Lista de opciones
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vehiculosFiltrados) { vehiculo in
                            let isSelected = vehiculoSeleccionadoID == vehiculo.id
                            Button {
                                vehiculoSeleccionadoID = vehiculo.id
                                recalcularPreview()
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Text("[\(vehiculo.placas)]")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(Color("MercedesPetrolGreen"))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(vehiculo.marca) \(vehiculo.modelo)")
                                            .font(.headline)
                                        Text("Cliente: \(vehiculo.cliente?.nombre ?? "N/A")")
                                            .font(.caption).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color("MercedesPetrolGreen"))
                                    }
                                }
                                .padding(10)
                                .background(Color("MercedesCard").opacity(isSelected ? 1.0 : 0.6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        if vehiculosFiltrados.isEmpty {
                            Text("No se encontraron vehículos para “\(searchVehiculo)”.")
                                .font(.caption).foregroundColor(.gray).padding(.top, 6)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
            .padding()
            .background(Color("MercedesCard"))
            .cornerRadius(10)
            
            // Candidato y productos
            HStack(alignment: .top, spacing: 16) {
                // Candidato
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Candidato Asignado").font(.headline)
                        Spacer()
                        // Enlace a Gestión de Personal
                        Button {
                            appState.seleccion = .operaciones_personal
                            dismiss()
                        } label: {
                            Text("Gestionar Personal")
                                .underline()
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    }
                    
                    if let c = candidato {
                        HStack {
                            Image(systemName: "person.fill")
                            Text(c.nombre).fontWeight(.semibold)
                            Spacer()
                            Text(c.estado.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(candidatoColor.opacity(0.2))
                                .foregroundColor(candidatoColor)
                                .cornerRadius(6)
                        }
                        .font(.body)
                        Text("Rol: \(c.rol.rawValue)")
                            .font(.caption).foregroundColor(.gray)
                        if !c.especialidades.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(c.especialidades, id: \.self) { esp in
                                        chipSmall(text: esp)
                                    }
                                }
                            }
                        }
                    } else {
                        Text("No hay candidatos disponibles que cumplan rol y especialidad.")
                            .font(.caption).foregroundColor(.red)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("MercedesCard"))
                .cornerRadius(10)
                
                // Productos
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Productos a Consumir").font(.headline)
                        Spacer()
                        // Enlace a Inventario
                        Button {
                            appState.seleccion = .operaciones_inventario
                            dismiss()
                        } label: {
                            Text("Gestionar Inventario")
                                .underline()
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    }
                    
                    if servicio.ingredientes.isEmpty {
                        Text("Este servicio no requiere productos.")
                            .font(.caption).foregroundColor(.gray)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(servicio.ingredientes, id: \.self) { ing in
                                    let prod = productos.first(where: { $0.nombre == ing.nombreProducto })
                                    let stock = prod?.cantidad ?? 0
                                    let unidad = prod?.unidadDeMedida ?? ""
                                    let ok = stock >= ing.cantidadUsada
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(ing.nombreProducto).fontWeight(.semibold)
                                            Text("\(ing.cantidadUsada, specifier: "%.2f") \(unidad) requeridos")
                                                .font(.caption).foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Text("Stock: \(stock, specifier: "%.2f")")
                                            .font(.caption)
                                            .foregroundColor(ok ? .green : .red)
                                        Image(systemName: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                            .foregroundColor(ok ? .green : .red)
                                    }
                                    .padding(8)
                                    .background(Color("MercedesBackground"))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("MercedesCard"))
                .cornerRadius(10)
            }
            
            // Barra inferior
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resumen")
                        .font(.headline)
                    HStack(spacing: 12) {
                        Label("Costo piezas: $\(costoEstimado, specifier: "%.2f")", systemImage: "creditcard")
                        Label("Duración: \(servicio.duracionHoras, specifier: "%.1f") h", systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundColor(.gray)
                }
                Spacer()
                Button {
                    ejecutarAsignacion()
                } label: {
                    Label("Confirmar y Empezar Trabajo", systemImage: "checkmark.circle.fill")
                        .font(.headline).padding()
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(vehiculoSeleccionadoID == nil || candidato == nil || hayStockInsuficiente)
                .opacity((vehiculoSeleccionadoID == nil || candidato == nil || hayStockInsuficiente) ? 0.6 : 1.0)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(minWidth: 700, minHeight: 600)
        .background(Color("MercedesBackground"))
        .cornerRadius(15)
        .preferredColorScheme(.dark)
        .onAppear { recalcularPreview() }
        .onChange(of: vehiculoSeleccionadoID) { _, _ in recalcularPreview() }
        .alert("Error de Asignación", isPresented: $mostrandoAlerta, presenting: alertaError) { _ in
            Button("OK") { }
        } message: { error in
            Text(error)
        }
    }
    
    // Recalcula candidato, costo y stock para pintar la UI
    private func recalcularPreview() {
        // Candidato
        let candidatos = personal.filter { mec in
            mec.isAsignable &&
            mec.especialidades.contains(servicio.especialidadRequerida) &&
            mec.rol == servicio.rolRequerido
        }
        candidato = candidatos.sorted(by: { $0.rol.rawValue < $1.rol.rawValue }).first
        
        // Costo y stock
        var costo: Double = 0
        var stockOK = true
        for ing in servicio.ingredientes {
            guard let p = productos.first(where: { $0.nombre == ing.nombreProducto }) else { continue }
            costo += (p.costo * ing.cantidadUsada)
            if p.cantidad < ing.cantidadUsada { stockOK = false }
        }
        costoEstimado = costo
        hayStockInsuficiente = !stockOK
    }
    
    // Chips helpers
    private func chip(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color("MercedesBackground"))
        .cornerRadius(8)
    }
    private func chipSmall(text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color("MercedesBackground"))
            .cornerRadius(6)
    }
    
    // Lógica de asignación (igual que antes)
    func ejecutarAsignacion() {
        guard let vehiculoID = vehiculoSeleccionadoID,
              let vehiculo = vehiculos.first(where: { $0.id == vehiculoID }) else {
            alertaError = "No se seleccionó un vehículo."
            mostrandoAlerta = true
            return
        }
        
        let candidatos = personal.filter { mec in
            mec.isAsignable &&
            mec.especialidades.contains(servicio.especialidadRequerida) &&
            mec.rol == servicio.rolRequerido
        }
        
        guard let mecanico = candidatos.sorted(by: { $0.rol.rawValue < $1.rol.rawValue }).first else {
            alertaError = "No se encontraron mecánicos disponibles que cumplan los requisitos de ROL y ESPECIALIDAD."
            mostrandoAlerta = true
            return
        }
        
        var costoTotalProductos: Double = 0.0
        for ingrediente in servicio.ingredientes {
            guard let producto = productos.first(where: { $0.nombre == ingrediente.nombreProducto }) else {
                alertaError = "Error de Sistema: El producto '\(ingrediente.nombreProducto)' no fue encontrado en el inventario."
                mostrandoAlerta = true
                return
            }
            guard producto.cantidad >= ingrediente.cantidadUsada else {
                alertaError = "Stock insuficiente de: \(producto.nombre). Se necesitan \(ingrediente.cantidadUsada) \(producto.unidadDeMedida)(s) pero solo hay \(producto.cantidad)."
                mostrandoAlerta = true
                return
            }
            costoTotalProductos += (producto.costo * ingrediente.cantidadUsada)
        }
        
        let nuevoServicio = ServicioEnProceso(
            nombreServicio: servicio.nombre,
            dniMecanicoAsignado: mecanico.dni,
            nombreMecanicoAsignado: mecanico.nombre,
            horaInicio: Date(),
            duracionHoras: servicio.duracionHoras,
            productosConsumidos: servicio.ingredientes.map { $0.nombreProducto },
            vehiculo: vehiculo
        )
        modelContext.insert(nuevoServicio)
        
        mecanico.estado = .ocupado
        
        for ingrediente in servicio.ingredientes {
            if let producto = productos.first(where: { $0.nombre == ingrediente.nombreProducto }) {
                producto.cantidad -= ingrediente.cantidadUsada
            }
        }
        
        let costoFormateado = String(format: "%.2f", costoTotalProductos)
        let registro = DecisionRecord(
            fecha: Date(),
            titulo: "Iniciando: \(servicio.nombre)",
            razon: "Asignado a \(mecanico.nombre) para el vehículo [\(vehiculo.placas)]. Costo piezas: $\(costoFormateado)",
            queryUsuario: "Asignación Automática de Servicio"
        )
        modelContext.insert(registro)
        
        dismiss()
        appState.seleccion = .serviciosEnProceso
    }
}

// --- VISTA DEL FORMULARIO (UI y validaciones actuales conservadas) ---
fileprivate struct ServicioFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true
    
    @Query private var productos: [Producto]
    @Query private var personal: [Personal]

    let mode: ServiceModalMode
    
    @State private var nombre = ""
    @State private var descripcion = ""
    @State private var especialidadRequerida = ""
    @State private var rolRequerido: Rol = .ayudante
    @State private var precioString = ""
    @State private var duracionString = "1.0"
    @State private var cantidadesProductos: [String: Double] = [:]
    @State private var especialidadesDisponibles: [String] = []

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
        case .assign: return "Editar Servicio" // no se usa, pero cumple el enum
        }
    }
    
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
            VStack(spacing: 4) {
                Text(formTitle).font(.title).fontWeight(.bold)
                Text("Completa los datos. Los campos marcados con • son obligatorios.")
                    .font(.footnote).foregroundColor(.gray)
            }
            .padding(.top, 14).padding(.bottom, 8)

            Form {
                Section {
                    SectionHeader(title: "Detalles del Servicio", subtitle: nil)
                    
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
            
            if let errorMsg {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.vertical, 6)
            }
            
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
        .frame(minWidth: 700, minHeight: 600, maxHeight: 750)
        .cornerRadius(15)
        .sheet(isPresented: $showingAuthModal) {
            authModalView()
        }
        .onAppear {
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

// --- Helpers de UI reutilizados ---
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

// --- FormModal usado por AsignarServicioModal ---
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
