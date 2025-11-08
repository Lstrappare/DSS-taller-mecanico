import SwiftUI
import SwiftData

// (El enum ServiceModalMode no cambia)
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

// --- VISTA PRINCIPAL (Actualizada) ---
struct ServiciosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Servicio.nombre) private var servicios: [Servicio]
    
    @State private var modalMode: ServiceModalMode?

    var body: some View {
        VStack(alignment: .leading) {
            // ... (Cabecera no cambia)
            HStack {
                Text("Gestión de servicios")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Button { modalMode = .add }
                label: {
                    Label("Añadir Servicio", systemImage: "plus")
                        .font(.headline).padding(.vertical, 10).padding(.horizontal)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)
            Text("Registra que servicios ofreces en el taller.")
                .font(.title3).foregroundColor(.gray).padding(.bottom, 20)
            
            // --- Lista de Servicios (Actualizada) ---
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(servicios) { servicio in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(servicio.nombre)
                                .font(.title2).fontWeight(.semibold)
                            Text(servicio.descripcion)
                                .font(.body).foregroundColor(.gray)
                            Divider()
                            
                            // Requerimientos
                            Text("Requerimientos:").font(.headline)
                            HStack {
                                Label(servicio.especialidadRequerida, systemImage: "wrench.and.screwdriver.fill")
                                Label(servicio.nivelMinimoRequerido.rawValue, systemImage: "person.badge.shield.checkmark.fill")
                            }
                            .font(.subheadline)
                            .foregroundColor(Color("MercedesPetrolGreen"))
                            
                            // Muestra los ingredientes y sus cantidades
                            Text("Productos: \(formatearIngredientes(servicio.ingredientes))")
                                .font(.subheadline).foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("MercedesCard"))
                        .cornerRadius(10)
                        .onTapGesture { modalMode = .edit(servicio) }
                    }
                }
            }
            Spacer()
        }
        .padding(30)
        .sheet(item: $modalMode) { mode in
            ServicioFormView(mode: mode)
        }
    }
    
    // Helper para mostrar "Filtro (1.00), Aceite (4.50)"
    func formatearIngredientes(_ ingredientes: [Ingrediente]) -> String {
        return ingredientes.map { "\($0.nombreProducto) (\(String(format: "%.2f", $0.cantidadUsada)))" }
                           .joined(separator: ", ")
    }
}


// --- VISTA DEL FORMULARIO (¡EL GRAN CAMBIO!) ---
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
    @State private var nivelMinimoRequerido: NivelHabilidad = .aprendiz
    @State private var precioString = ""
    @State private var duracionString = "1.0"
    
    // --- NUEVO STATE PARA INGREDIENTES ---
    // Un diccionario temporal para guardar las cantidades
    @State private var cantidadesProductos: [String: Double] = [:]
    
    @State private var especialidadesDisponibles: [String] = []
    
    // Deriva el servicio a editar desde mode (evita stored property adicional)
    private var servicioAEditar: Servicio? {
        if case .edit(let servicio) = mode { return servicio }
        return nil
    }
    
    var formTitle: String { (servicioAEditar == nil) ? "Añadir nuevo servicio" : "Editar servicio" }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(formTitle).font(.largeTitle).fontWeight(.bold)
            
            TextField("Nombre del servicio", text: $nombre).disabled(servicioAEditar != nil)
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
            Picker("Nivel Mínimo Requerido", selection: $nivelMinimoRequerido) {
                ForEach(NivelHabilidad.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            
            // --- NUEVA LISTA DE PRODUCTOS ---
            VStack(alignment: .leading) {
                Text("Productos Requeridos (Ingresa la cantidad a usar)").font(.headline)
                List(productos) { producto in
                    HStack {
                        Text("\(producto.nombre) (\(producto.unidadDeMedida))")
                        Spacer()
                        // Un TextField para cada producto
                        TextField("0.0", text: Binding(
                            get: {
                                cantidadesProductos[producto.nombre].map { String(format: "%.2f", $0) } ?? ""
                            },
                            set: {
                                cantidadesProductos[producto.nombre] = Double($0) ?? 0
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
            
            // --- Botones de Acción ---
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding().foregroundColor(.gray)
                if case .edit(let servicio) = mode {
                    Button("Eliminar", role: .destructive) { eliminarServicio(servicio) }
                    .buttonStyle(.plain).padding().foregroundColor(.red)
                }
                Spacer()
                Button(servicioAEditar == nil ? "Añadir Servicios" : "Guardar Cambios") {
                    guardarCambios()
                }
                .buttonStyle(.plain).padding()
                .foregroundColor(Color("MercedesPetrolGreen")).cornerRadius(8)
            }
            .padding(.top, 30)
        }
        .padding(20)
        .background(Color("MercedesBackground"))
        .cornerRadius(15)
        .preferredColorScheme(.dark)
        .textFieldStyle(PlainTextFieldStyle())
        .padding()
        .background(Color("MercedesCard"))

        .onAppear {
            // Construye especialidades
            let todasLasHabilidades = personal.flatMap { $0.especialidades }
            especialidadesDisponibles = Array(Set(todasLasHabilidades)).sorted()
            if servicioAEditar == nil, let primera = especialidadesDisponibles.first {
                especialidadRequerida = primera
            }
            
            // Inicializa estados según modo
            if let servicio = servicioAEditar {
                nombre = servicio.nombre
                descripcion = servicio.descripcion
                especialidadRequerida = servicio.especialidadRequerida
                nivelMinimoRequerido = servicio.nivelMinimoRequerido
                precioString = "\(servicio.precioAlCliente)"
                duracionString = "\(servicio.duracionHoras)"
                let cantidades = Dictionary(uniqueKeysWithValues: servicio.ingredientes.map { ($0.nombreProducto, $0.cantidadUsada) })
                cantidadesProductos = cantidades
            } else {
                // Defaults para "add"
                if precioString.isEmpty { precioString = "" }
                if duracionString.isEmpty { duracionString = "1.0" }
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
        
        // Convierte el diccionario [String: Double] al array [Ingrediente]
        let ingredientesArray: [Ingrediente] = cantidadesProductos.compactMap { (nombre, cantidad) in
            guard cantidad > 0 else { return nil }
            return Ingrediente(nombreProducto: nombre, cantidadUsada: cantidad)
        }
        
        if let servicio = servicioAEditar {
            // MODO EDITAR
            servicio.descripcion = descripcion
            servicio.especialidadRequerida = especialidadRequerida
            servicio.nivelMinimoRequerido = nivelMinimoRequerido
            servicio.precioAlCliente = precio
            servicio.duracionHoras = duracion
            servicio.ingredientes = ingredientesArray
        } else {
            // MODO AÑADIR
            let nuevoServicio = Servicio(
                nombre: nombre,
                descripcion: descripcion,
                especialidadRequerida: especialidadRequerida,
                nivelMinimoRequerido: nivelMinimoRequerido,
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
