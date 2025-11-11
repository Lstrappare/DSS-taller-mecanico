import SwiftUI
import SwiftData

// --- MODO DEL MODAL (¡ACTUALIZADO!) ---
fileprivate enum ServiceModalMode: Identifiable {
    case add
    case edit(Servicio)
    case assign(Servicio) // ¡NUEVO MODO!
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let servicio): return servicio.nombre
        case .assign(let servicio): return "assign-\(servicio.nombre)"
        }
    }
}


// --- VISTA PRINCIPAL (¡ACTUALIZADA!) ---
struct ServiciosView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    // Necesitamos acceso a 'seleccion' para navegar
    @EnvironmentObject private var appState: AppNavigationState

    @Query(sort: \Servicio.nombre) private var servicios: [Servicio]
    @State private var modalMode: ServiceModalMode?
    @State private var searchQuery = "" // Para el buscador

    // Filtra los servicios basado en la búsqueda
    var filteredServicios: [Servicio] {
        if searchQuery.isEmpty {
            return servicios
        } else {
            return servicios.filter { $0.nombre.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            // --- Cabecera ---
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
            
            // --- BUSCADOR RÁPIDO (FEEDBACK DE LA PROFESORA) ---
            TextField("Buscar servicio por nombre...", text: $searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                .padding(.bottom, 20)

            
            // --- Lista de Servicios (¡ACTUALIZADA!) ---
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(filteredServicios) { servicio in
                        // Tarjeta de Servicio
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(servicio.nombre)
                                    .font(.title2).fontWeight(.semibold)
                                Spacer()
                                // Botón de Editar (discreto)
                                Button {
                                    modalMode = .edit(servicio)
                                } label: {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Text(servicio.descripcion)
                                .font(.body).foregroundColor(.gray)
                            
                            Divider()
                            
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
                        // ¡ACCIÓN CAMBIADA!
                        .onTapGesture {
                            modalMode = .assign(servicio) // Abre el modal de ASIGNAR
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(30)
        .sheet(item: $modalMode) { mode in
            // El sheet ahora decide qué modal mostrar
            switch mode {
            case .add:
                ServicioFormView(mode: .add)
            case .edit(let servicio):
                ServicioFormView(mode: .edit(servicio))
            case .assign(let servicio):
                // ¡NUEVO MODAL DE ASIGNACIÓN!
                AsignarServicioModal(servicio: servicio, appState: appState)
            }
        }
    }
    
    func formatearIngredientes(_ ingredientes: [Ingrediente]) -> String {
        return ingredientes.map { "\($0.nombreProducto) (\(String(format: "%.2f", $0.cantidadUsada)))" }
                           .joined(separator: ", ")
    }
}


// --- MODAL DE ASIGNACIÓN (¡EL NUEVO "CEREBRO"!) ---
fileprivate struct AsignarServicioModal: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Consultas
    @Query private var personal: [Personal]
    @Query private var productos: [Producto]
    @Query private var vehiculos: [Vehiculo]
    
    var servicio: Servicio
    @ObservedObject var appState: AppNavigationState // Para navegar
    
    // States
    @State private var vehiculoSeleccionadoID: Vehiculo.ID?
    @State private var alertaError: String?
    @State private var mostrandoAlerta = false
    
    var body: some View {
        FormModal(title: "Asignar Servicio", minHeight: 400) {
            
            Text(servicio.nombre)
                .font(.title).fontWeight(.bold)
            Text("Selecciona el vehículo del cliente para este servicio.")
                .font(.headline).foregroundColor(.gray)
            
            // Picker para seleccionar el Vehículo
            Picker("Selecciona un Vehículo", selection: $vehiculoSeleccionadoID) {
                Text("Seleccionar...").tag(nil as Vehiculo.ID?)
                ForEach(vehiculos) { vehiculo in
                    // Muestra Placa y Nombre del dueño
                    Text("[\(vehiculo.placas)] - \(vehiculo.marca) \(vehiculo.modelo) (\(vehiculo.cliente?.nombre ?? "Sin Cliente"))")
                        .tag(vehiculo.id as Vehiculo.ID?)
                }
            }
            .pickerStyle(.menu)
            
            Spacer()
            
            // Botones
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding().foregroundColor(.gray)
                Spacer()
                Button {
                    // ¡Aquí se ejecuta toda la lógica!
                    ejecutarAsignacion()
                } label: {
                    Label("Confirmar y Empezar Trabajo", systemImage: "checkmark.circle.fill")
                        .font(.headline).padding()
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(vehiculoSeleccionadoID == nil)
            }
        }
        .alert("Error de Asignación", isPresented: $mostrandoAlerta, presenting: alertaError) { error in
            Button("OK") { }
        } message: { error in
            Text(error)
        }

    }
    
    // --- LÓGICA DEL DSS (Movida aquí) ---
    func ejecutarAsignacion() {
        
        // 1. Encontrar el Vehículo
        guard let vehiculoID = vehiculoSeleccionadoID,
              let vehiculo = vehiculos.first(where: { $0.id == vehiculoID }) else {
            alertaError = "No se seleccionó un vehículo."
            mostrandoAlerta = true
            return
        }
        
        var _: String? = nil
        
        // 2. Encontrar Candidatos (Personal)
        let candidatos = personal.filter { mec in
            mec.isAsignable &&
            mec.especialidades.contains(servicio.especialidadRequerida) &&
            mec.rol == servicio.rolRequerido
        }
        
        // Elige al mejor (por ahora el primero)
        guard let mecanico = candidatos.sorted(by: { $0.rol.rawValue < $1.rol.rawValue }).first else {
            alertaError = "No se encontraron mecánicos disponibles que cumplan los requisitos de ROL y ESPECIALIDAD."
            mostrandoAlerta = true
            return
        }
        
        // 3. Revisar y Calcular Costos (Productos)
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
        
        // --- ¡ÉXITO! EJECUCIÓN AUTOMÁTICA ---
        
        // 4. Crear el "Ticket"
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
        
        // 5. Ocupar al Mecánico
        mecanico.estado = .ocupado
        
        // 6. Restar del Inventario
        for ingrediente in servicio.ingredientes {
            if let producto = productos.first(where: { $0.nombre == ingrediente.nombreProducto }) {
                producto.cantidad -= ingrediente.cantidadUsada
            }
        }
        
        // 7. Guardar en el Historial de Decisiones
        let costoFormateado = String(format: "%.2f", costoTotalProductos)
        let registro = DecisionRecord(
            fecha: Date(),
            titulo: "Iniciando: \(servicio.nombre)",
            razon: "Asignado a \(mecanico.nombre) para el vehículo [\(vehiculo.placas)]. Costo piezas: $\(costoFormateado)",
            queryUsuario: "Asignación Automática de Servicio"
        )
        modelContext.insert(registro)
        
        // 8. Limpiar y Navegar
        dismiss()
        appState.seleccion = .serviciosEnProceso
    }
}


// --- FORMULARIO DE SERVICIO (ADD/EDIT) ---
// (Esta parte es idéntica a la que ya tenías, solo la pego para que el
// archivo esté completo. No hay cambios aquí.)
fileprivate struct ServicioFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
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

    private var servicioAEditar: Servicio?
    var formTitle: String {
        switch mode {
        case .add: return "Añadir Nuevo Servicio"
        case .edit: return "Editar Servicio"
        case .assign: return "Asignar Servicio" // No se usará, pero completa el enum
        }
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
            Text(formTitle)
                .font(.largeTitle).fontWeight(.bold)
                .padding()
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Detalles del Servicio").font(.headline)
                        FormField(title: "Nombre del Servicio", text: $nombre)
                            .disabled(servicioAEditar != nil)
                        FormField(title: "Descripción", text: $descripcion)
                        HStack {
                            FormField(title: "Precio Mano de Obra ($)", text: $precioString)
                            FormField(title: "Duración (Horas)", text: $duracionString)
                        }
                    }
                    .padding()
                    .background(Color("MercedesBackground"))
                    .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Requerimientos del Personal").font(.headline)
                        Picker("Especialidad Requerida", selection: $especialidadRequerida) {
                            Text("Ninguna").tag("")
                            ForEach(especialidadesDisponibles, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        Picker("Rol Mínimo Requerido", selection: $rolRequerido) {
                            ForEach(Rol.allCases, id: \.self) { rol in
                                Text(rol.rawValue).tag(rol)
                            }
                        }
                    }
                    .padding()
                    .background(Color("MercedesBackground"))
                    .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Productos Requeridos (Ingresa la cantidad)").font(.headline)
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
                        .frame(minHeight: 150, maxHeight: 300)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color("MercedesBackground"))
                    .cornerRadius(10)
                }
                .padding()
            }
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding().foregroundColor(.gray)
                if case .edit(let servicio) = mode {
                    Button("Eliminar", role: .destructive) { eliminarServicio(servicio) }
                    .buttonStyle(.plain).padding().foregroundColor(.red)
                }
                Spacer()
                Button(servicioAEditar == nil ? "Añadir Servicio" : "Guardar Cambios") {
                    guardarCambios()
                }
                .buttonStyle(.plain).padding()
                .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
            }
            .padding()
            .background(Color("MercedesBackground"))
        }
        .background(Color("MercedesCard"))
        .cornerRadius(15)
        .preferredColorScheme(.dark)
        .textFieldStyle(PlainTextFieldStyle())
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
    
    // --- Lógica del Formulario (Sin cambios) ---
    func guardarCambios() {
        guard let precio = Double(precioString),
              let duracion = Double(duracionString),
              !nombre.isEmpty, !especialidadRequerida.isEmpty else { return }
        let ingredientesArray: [Ingrediente] = cantidadesProductos.compactMap { (nombre, cantidad) in
            guard cantidad > 0 else { return nil }
            return Ingrediente(nombreProducto: nombre, cantidadUsada: cantidad)
        }
        if let servicio = servicioAEditar {
            servicio.descripcion = descripcion
            servicio.especialidadRequerida = especialidadRequerida
            servicio.rolRequerido = rolRequerido
            servicio.precioAlCliente = precio
            servicio.duracionHoras = duracion
            servicio.ingredientes = ingredientesArray
        } else {
            let nuevoServicio = Servicio(
                nombre: nombre,
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
}


// --- Formulario Modal Genérico (Lo usamos en Clientes) ---
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
