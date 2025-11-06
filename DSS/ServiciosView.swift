import SwiftUI
import SwiftData

// --- MODO DEL MODAL ---
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


// --- VISTA PRINCIPAL ---
struct ServiciosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Servicio.nombre) private var servicios: [Servicio]
    
    @State private var modalMode: ServiceModalMode?

    var body: some View {
        VStack(alignment: .leading) {
            // --- Cabecera ---
            HStack {
                Text("Services Management")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Button {
                    modalMode = .add
                } label: {
                    Label("Add Service", systemImage: "plus")
                        .font(.headline).padding(.vertical, 10).padding(.horizontal)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)
            
            Text("Define your service offerings")
                .font(.title3).foregroundColor(.gray).padding(.bottom, 20)
            
            // --- Lista de Servicios ---
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
                            
                            // Requerimientos
                            Text("Requerimientos:")
                                .font(.headline)
                            HStack {
                                Label(servicio.especialidadRequerida, systemImage: "wrench.and.screwdriver.fill")
                                Label(servicio.nivelMinimoRequerido.rawValue, systemImage: "person.badge.shield.checkmark.fill")
                            }
                            .font(.subheadline)
                            .foregroundColor(Color("MercedesPetrolGreen"))
                            
                            Text("Productos: \(servicio.productosRequeridos.joined(separator: ", "))")
                                .font(.subheadline).foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("MercedesCard"))
                        .cornerRadius(10)
                        .onTapGesture {
                            modalMode = .edit(servicio) // Abre el modal en modo "Edit"
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(30)
        .sheet(item: $modalMode) { mode in
            ServicioFormView(mode: mode) // Llama al formulario
        }
    }
}


// --- VISTA DEL FORMULARIO (ADD/EDIT) ---
fileprivate struct ServicioFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Consultamos Productos y Personal para los Pickers
    @Query private var productos: [Producto]
    @Query private var personal: [Personal]

    let mode: ServiceModalMode
    
    // States para los campos
    @State private var nombre = ""
    @State private var descripcion = ""
    @State private var especialidadRequerida = ""
    @State private var nivelMinimoRequerido: NivelHabilidad = .aprendiz
    @State private var precioString = ""
    
    @State private var duracionString = "1.0"
    
    // State para el selector de productos
    @State private var productosSeleccionados: Set<String> = []
    
    // State para el selector de especialidad
    @State private var especialidadesDisponibles: [String] = []

    private var servicioAEditar: Servicio?
    
    var formTitle: String {
        switch mode {
        case .add: return "Add New Service"
        case .edit: return "Edit Service"
        }
    }
    
    // Inicializador
    init(mode: ServiceModalMode) {
        self.mode = mode
        
        if case .edit(let servicio) = mode {
            self.servicioAEditar = servicio
            // Pre-llenamos los campos
            _nombre = State(initialValue: servicio.nombre)
            _descripcion = State(initialValue: servicio.descripcion)
            _especialidadRequerida = State(initialValue: servicio.especialidadRequerida)
            _nivelMinimoRequerido = State(initialValue: servicio.nivelMinimoRequerido)
            _precioString = State(initialValue: "\(servicio.precioAlCliente)")
            _duracionString = State(initialValue: "\(servicio.duracionHoras)")
            _productosSeleccionados = State(initialValue: Set(servicio.productosRequeridos))
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(formTitle)
                .font(.largeTitle).fontWeight(.bold)
            
            // --- Formulario ---
            TextField("Service Name (ej. Cambio de Frenos)", text: $nombre).disabled(servicioAEditar != nil)
            TextField("Descripción", text: $descripcion)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Precio Mano de Obra").font(.caption).foregroundColor(.gray)
                    TextField("Precio", text: $precioString)
                }
                VStack(alignment: .leading) {
                    Text("Duración Estimada (Horas)").font(.caption).foregroundColor(.gray)
                    TextField("ej. 2.5", text: $duracionString) // <-- CAMPO AÑADIDO
                }
            }
            
            Divider()
            
            // --- Selección de Requerimientos ---
            Text("Requerimientos").font(.headline)
            
            // Picker de Especialidad (¡INTELIGENTE!)
            Picker("Especialidad Requerida", selection: $especialidadRequerida) {
                Text("Ninguna").tag("")
                ForEach(especialidadesDisponibles, id: \.self) { especialidad in
                    Text(especialidad).tag(especialidad)
                }
            }
            
            // Picker de Nivel
            Picker("Nivel Mínimo Requerido", selection: $nivelMinimoRequerido) {
                ForEach(NivelHabilidad.allCases, id: \.self) { nivel in
                    Text(nivel.rawValue).tag(nivel)
                }
            }
            .pickerStyle(.segmented)
            
            // --- Selección de Productos (¡MÚLTIPLE!) ---
            VStack(alignment: .leading) {
                Text("Productos Requeridos").font(.headline)
                List(productos) { producto in
                    HStack {
                        Text(producto.nombre)
                        Spacer()
                        if productosSeleccionados.contains(producto.nombre) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color("MercedesPetrolGreen"))
                        }
                    }
                    .contentShape(Rectangle()) // Hace toda la fila clickeable
                    .onTapGesture {
                        if productosSeleccionados.contains(producto.nombre) {
                            productosSeleccionados.remove(producto.nombre)
                        } else {
                            productosSeleccionados.insert(producto.nombre)
                        }
                    }
                }
                .frame(minHeight: 150) // Le da un tamaño a la lista
                .background(Color("MercedesCard"))
                .cornerRadius(8)
            }
            
            // --- Botones de Acción ---
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain).padding().foregroundColor(.gray)
                
                if case .edit(let servicio) = mode {
                    Button("Delete", role: .destructive) {
                        eliminarServicio(servicio)
                    }
                    .buttonStyle(.plain).padding().foregroundColor(.red)
                }
                
                Spacer()
                
                Button(servicioAEditar == nil ? "Add Service" : "Save Changes") {
                    guardarCambios()
                }
                .buttonStyle(.plain).padding()
                .foregroundColor(Color("MercedesPetrolGreen")).cornerRadius(8)
            }
            .padding(.top, 30)
        }
        .padding(40)
        .background(Color("MercedesBackground"))
        .cornerRadius(15)
        .preferredColorScheme(.dark)
        .textFieldStyle(PlainTextFieldStyle())
        .padding()
        .background(Color("MercedesCard"))
        .cornerRadius(15)
        .onAppear {
            // ¡Pre-calcula la lista de especialidades disponibles!
            // Recorre todo el personal, toma sus especialidades y crea una lista única
            let todasLasHabilidades = personal.flatMap { $0.especialidades }
            especialidadesDisponibles = Array(Set(todasLasHabilidades)).sorted()
            
            // Si estamos en modo 'add', selecciona la primera por defecto
            if servicioAEditar == nil, let primera = especialidadesDisponibles.first {
                especialidadRequerida = primera
            }
        }
    }
    
    // --- Lógica del Formulario ---
    
    func guardarCambios() {
            // Validamos también la duración
            guard let precio = Double(precioString),
                  let duracion = Double(duracionString), // <-- VALIDACIÓN AÑADIDA
                  !nombre.isEmpty,
                  !especialidadRequerida.isEmpty else {
                print("Error: Campos inválidos")
                return
            }
        
        let productosArray = Array(productosSeleccionados)
        
        if let servicio = servicioAEditar {
            // MODO EDITAR
            servicio.descripcion = descripcion
            servicio.especialidadRequerida = especialidadRequerida
            servicio.nivelMinimoRequerido = nivelMinimoRequerido
            servicio.precioAlCliente = precio
            servicio.productosRequeridos = productosArray
            servicio.duracionHoras = duracion
        } else {
            // MODO AÑADIR
            let nuevoServicio = Servicio(
                nombre: nombre,
                descripcion: descripcion,
                especialidadRequerida: especialidadRequerida,
                nivelMinimoRequerido: nivelMinimoRequerido,
                productosRequeridos: productosArray,
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
}
