import SwiftUI
import SwiftData

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
    
    // --- 1. STATE PARA EL BUSCADOR ---
    @State private var searchQuery = ""
    
    // --- 2. LÓGICA DE FILTRADO (SOLO CLIENTES) ---
    var filteredClientes: [Cliente] {
        if searchQuery.isEmpty {
            return clientes
        } else {
            let query = searchQuery.lowercased()
            return clientes.filter { cliente in
                // Busca por Nombre, Teléfono o Email
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
            
            // --- 3. TEXTFIELD DE BÚSQUEDA ---
            TextField("Buscar por Nombre, Teléfono o Email...", text: $searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                .padding(.bottom, 20)
            
            // --- Lista de Clientes ---
            ScrollView {
                LazyVStack(spacing: 15) {
                    // --- 4. USA LA LISTA FILTRADA ---
                    ForEach(filteredClientes) { cliente in
                        // Tarjeta de Cliente
                        VStack(alignment: .leading) {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(cliente.nombre)
                                        .font(.title2).fontWeight(.semibold)
                                    Label(cliente.telefono, systemImage: "phone.fill")
                                    Label(cliente.email.isEmpty ? "Sin email" : cliente.email, systemImage: "envelope.fill")
                                }
                                .font(.body).foregroundColor(.gray)
                                
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
            switch mode {
            case .addClienteConVehiculo:
                ClienteConVehiculoFormView()
            case .editCliente(let cliente):
                ClienteFormView(cliente: cliente)
            case .addVehiculo(let cliente):
                VehiculoFormView(cliente: cliente)
            case .editVehiculo(let vehiculo):
                VehiculoFormView(vehiculo: vehiculo)
            }
        }
    }
}


// --- 1. FORMULARIO COMBINADO (Sin cambios) ---
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
                FormField(title: "Nombre Completo", text: $nombre)
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
        guard !nombre.isEmpty, !telefono.isEmpty, !placas.isEmpty, !marca.isEmpty, let anio = Int(anioString) else {
            errorMsg = "Por favor, llena todos los campos."
            return
        }
        
        let nuevoCliente = Cliente(nombre: nombre, telefono: telefono, email: email)
        let nuevoVehiculo = Vehiculo(placas: placas, marca: marca, modelo: modelo, anio: anio)
        
        nuevoVehiculo.cliente = nuevoCliente
        nuevoCliente.vehiculos.append(nuevoVehiculo)
        
        modelContext.insert(nuevoCliente)
        
        dismiss()
    }
}


// --- 2. FORMULARIO DE CLIENTE (SOLO EDITAR) (Sin cambios) ---
fileprivate struct ClienteFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var cliente: Cliente

    var body: some View {
        FormModal(title: "Editar Cliente", minHeight: 400) {
            FormField(title: "Nombre Completo", text: $cliente.nombre)
            FormField(title: "Teléfono", text: $cliente.telefono)
                .disabled(true)
            FormField(title: "Email (Opcional)", text: $cliente.email)
            
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
                    dismiss()
                }
                .buttonStyle(.plain).padding()
                .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
            }
            .padding(.top, 10)
        }
    }
}


// --- 3. FORMULARIO DE VEHÍCULO (AÑADIR 2do+ / EDITAR) (Sin cambios) ---
fileprivate struct VehiculoFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var vehiculo: Vehiculo
    private var clientePadre: Cliente?
    private var esModoEdicion: Bool
    
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
            
            FormField(title: "Placas", text: $vehiculo.placas)
                .disabled(esModoEdicion)
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
    }
    
    func guardarCambios() {
        guard !vehiculo.placas.isEmpty, !vehiculo.marca.isEmpty else { return }
        
        if !esModoEdicion {
            vehiculo.cliente = clientePadre
            clientePadre?.vehiculos.append(vehiculo)
            modelContext.insert(vehiculo)
        }
        dismiss()
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
