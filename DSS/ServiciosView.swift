import SwiftUI
import SwiftData

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


// --- VISTA PRINCIPAL (¡ACTUALIZADA!) ---
struct ServiciosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Servicio.nombre) private var servicios: [Servicio]
    
    @State private var modalMode: ServiceModalMode?

    var body: some View {
        VStack(alignment: .leading) {
            // --- Cabecera (Sin cambios) ---
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
            
            // --- Lista de Servicios (¡ACTUALIZADA!) ---
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(servicios) { servicio in
                        // Tarjeta de Servicio
                        VStack(alignment: .leading, spacing: 10) {
                            Text(servicio.nombre)
                                .font(.title2).fontWeight(.semibold)
                            
                            Text(servicio.descripcion)
                                .font(.body).foregroundColor(.gray)
                            
                            Divider()
                            
                            // --- Requerimientos (¡ACTUALIZADO!) ---
                            Text("Requerimientos:")
                                .font(.headline)
                            HStack {
                                Label(servicio.especialidadRequerida, systemImage: "wrench.and.screwdriver.fill")
                                // Muestra el ROL requerido, no el nivel
                                Label(servicio.rolRequerido.rawValue, systemImage: "person.badge.shield.checkmark.fill")
                            }
                            .font(.subheadline)
                            .foregroundColor(Color("MercedesPetrolGreen"))
                            
                            // Muestra los ingredientes (esta lógica no cambia)
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
        }
    }
    
    // Helper para mostrar "Filtro (1.00), Aceite (4.50)"
    func formatearIngredientes(_ ingredientes: [Ingrediente]) -> String {
        return ingredientes.map { "\($0.nombreProducto) (\(String(format: "%.2f", $0.cantidadUsada)))" }
                           .joined(separator: ", ")
    }
}


// --- VISTA DEL FORMULARIO (¡ACTUALIZADA!) ---
fileprivate struct ServicioFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var productos: [Producto]
    @Query private var personal: [Personal]

    let mode: ServiceModalMode
    
    // States para los campos
    @State private var nombre = ""
    @State private var descripcion = ""
    @State private var especialidadRequerida = ""
    
    // --- ¡CAMPO ACTUALIZADO! ---
    @State private var rolRequerido: Rol = .ayudante // Reemplaza a nivelMinimoRequerido
    
    @State private var precioString = ""
    @State private var duracionString = "1.0"
    @State private var cantidadesProductos: [String: Double] = [:]
    @State private var especialidadesDisponibles: [String] = []

    private var servicioAEditar: Servicio?
    var formTitle: String {
        switch mode {
        case .add: return "Añadir Nuevo Servicio"
        case .edit: return "Editar Servicio"
        }
    }
    
    // Inicializador
    init(mode: ServiceModalMode) {
        self.mode = mode
        
        if case .edit(let servicio) = mode {
            self.servicioAEditar = servicio
            _nombre = State(initialValue: servicio.nombre)
            _descripcion = State(initialValue: servicio.descripcion)
            _especialidadRequerida = State(initialValue: servicio.especialidadRequerida)
            
            // --- ¡CAMPO ACTUALIZADO! ---
            _rolRequerido = State(initialValue: servicio.rolRequerido)
            
            _precioString = State(initialValue: "\(servicio.precioAlCliente)")
            _duracionString = State(initialValue: "\(servicio.duracionHoras)")
            let cantidades = Dictionary(uniqueKeysWithValues: servicio.ingredientes.map { ($0.nombreProducto, $0.cantidadUsada) })
            _cantidadesProductos = State(initialValue: cantidades)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(formTitle).font(.largeTitle).fontWeight(.bold)
            
            TextField("Nombre del Servicio", text: $nombre).disabled(servicioAEditar != nil)
            TextField("Descripción", text: $descripcion)
            HStack {
                FormField(title: "Precio Mano de Obra", text: $precioString)
                FormField(title: "Duración Estimada (Horas)", text: $duracionString)
            }
            
            Divider()
            
            // --- Requerimientos (Pickers) ---
            Text("Requerimientos").font(.headline)
            
            Picker("Especialidad Requerida", selection: $especialidadRequerida) {
                Text("Ninguna").tag("")
                ForEach(especialidadesDisponibles, id: \.self) { Text($0).tag($0) }
            }
            
            // --- ¡PICKER ACTUALIZADO! ---
            Picker("Rol Mínimo Requerido", selection: $rolRequerido) {
                ForEach(Rol.allCases, id: \.self) { rol in
                    Text(rol.rawValue).tag(rol)
                }
            }
            
            // --- Lista de Productos (No cambia) ---
            VStack(alignment: .leading) {
                Text("Productos Requeridos (Ingresa la cantidad a usar)").font(.headline)
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
                }
                .frame(minHeight: 150)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
            }
            
            // --- Botones de Acción (No cambia) ---
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
                .foregroundColor(Color("MercedesPetrolGreen")).cornerRadius(8)
            }
            .padding(.top, 20)
        }
        .padding(20)
        .background(Color("MercedesBackground"))
        .cornerRadius(15)
        .preferredColorScheme(.dark)
        .textFieldStyle(PlainTextFieldStyle())
        .padding()
        .background(Color("MercedesCard"))
        .cornerRadius(15)
        .onAppear {
            let todasLasHabilidades = personal.flatMap { $0.especialidades }
            especialidadesDisponibles = Array(Set(todasLasHabilidades)).sorted()
            
            // Si es 'add', pone defaults
            if servicioAEditar == nil {
                rolRequerido = .ayudante // Default a Ayudante
                if let primera = especialidadesDisponibles.first {
                    especialidadRequerida = primera
                }
            }
        }
    }
    
    // --- Lógica del Formulario (Actualizada) ---
    func guardarCambios() {
        guard let precio = Double(precioString),
              let duracion = Double(duracionString),
              !nombre.isEmpty, !especialidadRequerida.isEmpty else {
            print("Error: Campos inválidos")
            return
        }
        
        let ingredientesArray: [Ingrediente] = cantidadesProductos.compactMap { (nombre, cantidad) in
            guard cantidad > 0 else { return nil }
            return Ingrediente(nombreProducto: nombre, cantidadUsada: cantidad)
        }
        
        if let servicio = servicioAEditar {
            // MODO EDITAR
            servicio.descripcion = descripcion
            servicio.especialidadRequerida = especialidadRequerida
            servicio.rolRequerido = rolRequerido // <-- CAMBIADO
            servicio.precioAlCliente = precio
            servicio.duracionHoras = duracion
            servicio.ingredientes = ingredientesArray
        } else {
            // MODO AÑADIR
            let nuevoServicio = Servicio(
                nombre: nombre,
                descripcion: descripcion,
                especialidadRequerida: especialidadRequerida,
                rolRequerido: rolRequerido, // <-- CAMBIADO
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
    
    // Helper view para el formulario
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
