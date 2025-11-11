import SwiftUI
import SwiftData

// --- Enums para controlar los Modales ---
fileprivate enum ClienteModalMode: Identifiable {
    case add
    case edit(Cliente)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let cliente): return cliente.telefono
        }
    }
}

fileprivate enum VehiculoModalMode: Identifiable {
    case add(Cliente) // Necesita saber a qué cliente añadirlo
    case edit(Vehiculo)
    
    var id: String {
        switch self {
        case .add: return "addVehiculo"
        case .edit(let vehiculo): return vehiculo.placas
        }
    }
}

// --- VISTA PRINCIPAL DE CLIENTES ---
struct GestionClientesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cliente.nombre) private var clientes: [Cliente]
    
    // States para los modales
    @State private var clienteModal: ClienteModalMode?
    @State private var vehiculoModal: VehiculoModalMode?

    var body: some View {
        VStack(alignment: .leading) {
            // --- Cabecera ---
            HStack {
                Text("Gestión de Clientes y Vehículos")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Button {
                    clienteModal = .add // Abre el modal de "Añadir Cliente"
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
            
            // --- Lista de Clientes ---
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(clientes) { cliente in
                        // Tarjeta de Cliente
                        VStack(alignment: .leading) {
                            HStack {
                                // Info del Cliente
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(cliente.nombre)
                                        .font(.title2).fontWeight(.semibold)
                                    Label(cliente.telefono, systemImage: "phone.fill")
                                    Label(cliente.email.isEmpty ? "Sin email" : cliente.email, systemImage: "envelope.fill")
                                }
                                .font(.body).foregroundColor(.gray)
                                
                                Spacer()
                                
                                // Botón para Editar Cliente
                                Button {
                                    clienteModal = .edit(cliente)
                                } label: {
                                    Image(systemName: "pencil")
                                }.buttonStyle(.plain)
                            }
                            
                            Divider().padding(.vertical, 5)
                            
                            // Lista de Vehículos de este Cliente
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
                                            vehiculoModal = .edit(vehiculo)
                                        } label: {
                                            Image(systemName: "pencil.circle")
                                        }.buttonStyle(.plain).foregroundColor(.gray)
                                    }
                                }
                            }
                            
                            // Botón para Añadir Vehículo a ESTE cliente
                            Button {
                                vehiculoModal = .add(cliente)
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
        // --- Modales ---
        .sheet(item: $clienteModal) { mode in
            ClienteFormView(mode: mode)
        }
        .sheet(item: $vehiculoModal) { mode in
            VehiculoFormView(mode: mode)
        }
    }
}


// --- FORMULARIO DE CLIENTE (ADD/EDIT) ---
fileprivate struct ClienteFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: ClienteModalMode
    
    @State private var nombre = ""
    @State private var telefono = ""
    @State private var email = ""
    
    private var clienteAEditar: Cliente?
    var formTitle: String { (mode == .add) ? "Añadir Nuevo Cliente" : "Editar Cliente" }

    init(mode: ClienteModalMode) {
        self.mode = mode
        if case .edit(let cliente) = mode {
            self.clienteAEditar = cliente
            _nombre = State(initialValue: cliente.nombre)
            _telefono = State(initialValue: cliente.telefono)
            _email = State(initialValue: cliente.email)
        }
    }
    
    var body: some View {
        FormModal(title: formTitle, minHeight: 400) {
            FormField(title: "Nombre Completo", text: $nombre)
            FormField(title: "Teléfono", text: $telefono)
                .disabled(clienteAEditar != nil) // No se puede cambiar el tel (ID)
            FormField(title: "Email (Opcional)", text: $email)
            
            // Botones
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding().foregroundColor(.gray)
                if case .edit(let cliente) = mode {
                    Button("Eliminar", role: .destructive) { eliminarCliente(cliente) }
                    .buttonStyle(.plain).padding().foregroundColor(.red)
                }
                Spacer()
                Button(clienteAEditar == nil ? "Añadir Cliente" : "Guardar Cambios") {
                    guardarCambios()
                }
                .buttonStyle(.plain).padding()
                .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
            }
            .padding(.top, 30)
        }
    }
    
    func guardarCambios() {
        guard !nombre.isEmpty, !telefono.isEmpty else { return }
        
        if let cliente = clienteAEditar {
            cliente.nombre = nombre
            cliente.email = email
        } else {
            let nuevoCliente = Cliente(nombre: nombre, telefono: telefono, email: email)
            modelContext.insert(nuevoCliente)
        }
        dismiss()
    }
    
    func eliminarCliente(_ cliente: Cliente) {
        // SwiftData maneja el borrado en cascada (vehículos)
        modelContext.delete(cliente)
        dismiss()
    }
}


// --- FORMULARIO DE VEHÍCULO (ADD/EDIT) ---
fileprivate struct VehiculoFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: VehiculoModalMode
    
    @State private var placas = ""
    @State private var marca = ""
    @State private var modelo = ""
    @State private var anioString = ""
    
    private var vehiculoAEditar: Vehiculo?
    private var clientePadre: Cliente?
    var formTitle: String { (mode == .add(.init(nombre: "", telefono: ""))) ? "Añadir Nuevo Vehículo" : "Editar Vehículo" }
    
    init(mode: VehiculoModalMode) {
        self.mode = mode
        switch mode {
        case .add(let cliente):
            self.clientePadre = cliente
        case .edit(let vehiculo):
            self.vehiculoAEditar = vehiculo
            self.clientePadre = vehiculo.cliente // El cliente al que pertenece
            _placas = State(initialValue: vehiculo.placas)
            _marca = State(initialValue: vehiculo.marca)
            _modelo = State(initialValue: vehiculo.modelo)
            _anioString = State(initialValue: "\(vehiculo.anio)")
        }
    }
    
    var body: some View {
        FormModal(title: formTitle, minHeight: 450) {
            Text("Cliente: \(clientePadre?.nombre ?? "Error")")
                .font(.headline).foregroundColor(.gray)
            
            FormField(title: "Placas", text: $placas)
                .disabled(vehiculoAEditar != nil) // No se puede cambiar
            FormField(title: "Marca", text: $marca)
            FormField(title: "Modelo", text: $modelo)
            FormField(title: "Año", text: $anioString)
            
            // Botones
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding().foregroundColor(.gray)
                if case .edit(let vehiculo) = mode {
                    Button("Eliminar", role: .destructive) { eliminarVehiculo(vehiculo) }
                    .buttonStyle(.plain).padding().foregroundColor(.red)
                }
                Spacer()
                Button(vehiculoAEditar == nil ? "Añadir Vehículo" : "Guardar Cambios") {
                    guardarCambios()
                }
                .buttonStyle(.plain).padding()
                .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
            }
            .padding(.top, 30)
        }
    }
    
    func guardarCambios() {
        guard !placas.isEmpty, !marca.isEmpty, let anio = Int(anioString) else { return }
        
        if let vehiculo = vehiculoAEditar {
            vehiculo.marca = marca
            vehiculo.modelo = modelo
            vehiculo.anio = anio
        } else if let cliente = clientePadre {
            let nuevoVehiculo = Vehiculo(placas: placas, marca: marca, modelo: modelo, anio: anio)
            // Enlaza el vehículo al cliente
            nuevoVehiculo.cliente = cliente
            modelContext.insert(nuevoVehiculo)
        }
        dismiss()
    }
    
    func eliminarVehiculo(_ vehiculo: Vehiculo) {
        modelContext.delete(vehiculo)
        dismiss()
    }
}


// --- VISTAS HELPER REUTILIZABLES ---

// Un contenedor genérico para los modales
fileprivate struct FormModal<Content: View>: View {
    var title: String
    var minHeight: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.largeTitle).fontWeight(.bold)
            
            content()
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: minHeight)
        .background(Color("MercedesBackground"))
        .cornerRadius(15)
        .preferredColorScheme(.dark)
        .textFieldStyle(PlainTextFieldStyle())
        .padding()
        .background(Color("MercedesCard"))
        .cornerRadius(15)
    }
}

// Un helper para los campos de texto
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