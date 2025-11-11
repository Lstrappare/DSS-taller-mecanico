import SwiftUI
import SwiftData

// --- Enums para controlar los Modales (¡ACTUALIZADOS!) ---
fileprivate enum ModalMode: Identifiable {
    case addClienteConVehiculo // ¡El nuevo modal combinado!
    case editCliente(Cliente)
    case addVehiculo(Cliente)  // Para 2do, 3er, etc.
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

// --- VISTA PRINCIPAL DE CLIENTES ---
struct GestionClientesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cliente.nombre) private var clientes: [Cliente]
    
    // Un solo State para todos los modales
    @State private var modalMode: ModalMode?

    var body: some View {
        VStack(alignment: .leading) {
            // --- Cabecera ---
            HStack {
                Text("Gestión de Clientes y Vehículos")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Button {
                    // ¡AQUÍ ESTÁ EL CAMBIO!
                    // Llama al nuevo modal combinado
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
            
            // --- Lista de Clientes ---
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(clientes) { cliente in
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
        // --- El .sheet ahora maneja todos los casos ---
        .sheet(item: $modalMode) { mode in
            // Decide qué modal mostrar
            switch mode {
            case .addClienteConVehiculo:
                ClienteConVehiculoFormView() // ¡El nuevo modal!
            case .editCliente(let cliente):
                ClienteFormView(cliente: cliente) // El modal de edición
            case .addVehiculo(let cliente):
                VehiculoFormView(cliente: cliente) // El modal de añadir 2do carro
            case .editVehiculo(let vehiculo):
                VehiculoFormView(vehiculo: vehiculo) // El modal de editar carro
            }
        }
    }
}


// --- 1. NUEVO FORMULARIO COMBINADO (ADD CLIENTE + VEHÍCULO) ---
fileprivate struct ClienteConVehiculoFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // States del Cliente
    @State private var nombre = ""
    @State private var telefono = ""
    @State private var email = ""
    
    // States del Vehículo
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

            // Botones
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
        // Validación
        guard !nombre.isEmpty, !telefono.isEmpty, !placas.isEmpty, !marca.isEmpty, let anio = Int(anioString) else {
            errorMsg = "Por favor, llena todos los campos."
            return
        }
        
        // --- ¡AQUÍ ESTÁ LA LÓGICA COMPLETA! ---
        
        // 1. Crea el Cliente
        let nuevoCliente = Cliente(nombre: nombre, telefono: telefono, email: email)
        
        // 2. Crea el Vehículo
        let nuevoVehiculo = Vehiculo(placas: placas, marca: marca, modelo: modelo, anio: anio)
        
        // 3. ¡ENLAZA AMBOS LADOS!
        nuevoVehiculo.cliente = nuevoCliente      // Lado 1
        nuevoCliente.vehiculos.append(nuevoVehiculo) // Lado 2 (¡La corrección del bug!)
        
        // 4. Guarda (Solo necesitas insertar el "padre", SwiftData maneja el resto)
        modelContext.insert(nuevoCliente)
        
        dismiss()
    }
}


// --- 2. FORMULARIO DE CLIENTE (SOLO EDITAR) ---
fileprivate struct ClienteFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var cliente: Cliente // Se edita directamente

    var body: some View {
        FormModal(title: "Editar Cliente", minHeight: 400) {
            FormField(title: "Nombre Completo", text: $cliente.nombre)
            FormField(title: "Teléfono", text: $cliente.telefono)
                .disabled(true) // No se puede cambiar el ID
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
                    // No se necesita 'guardar', SwiftData lo hace solo.
                    dismiss()
                }
                .buttonStyle(.plain).padding()
                .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
            }
            .padding(.top, 10)
        }
    }
}


// --- 3. FORMULARIO DE VEHÍCULO (AÑADIR 2do+ / EDITAR) ---
fileprivate struct VehiculoFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Dos modos: Añadir 2do carro o Editar uno existente
    @State private var vehiculo: Vehiculo
    private var clientePadre: Cliente?
    private var esModoEdicion: Bool
    
    var formTitle: String { esModoEdicion ? "Editar Vehículo" : "Añadir Nuevo Vehículo" }
    
    // Inicializador para AÑADIR (a un cliente existente)
    init(cliente: Cliente) {
        self.clientePadre = cliente
        self._vehiculo = State(initialValue: Vehiculo(placas: "", marca: "", modelo: "", anio: 2020))
        self.esModoEdicion = false
    }
    
    // Inicializador para EDITAR (un vehículo existente)
    init(vehiculo: Vehiculo) {
        self._vehiculo = State(initialValue: vehiculo)
        self.clientePadre = vehiculo.cliente
        self.esModoEdicion = true
    }
    
    // Binding para el año (convierte Int a String)
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
                .disabled(esModoEdicion) // No se puede cambiar si se está editando
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
            // ¡AQUÍ ESTÁ LA CORRECCIÓN DEL BUG!
            // Enlazamos en AMBOS sentidos
            vehiculo.cliente = clientePadre
            clientePadre?.vehiculos.append(vehiculo)
            modelContext.insert(vehiculo)
        }
        // (Si esModoEdicion, SwiftData guarda los cambios automáticamente)
        dismiss()
    }
}


// --- VISTAS HELPER REUTILIZABLES ---
fileprivate struct FormModal<Content: View>: View {
    var title: String
    var minHeight: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.largeTitle).fontWeight(.bold)
            
            // Usamos un Form para agrupar visualmente
            Form {
                content()
            }
            .textFieldStyle(PlainTextFieldStyle())
            .formStyle(.grouped) // Estilo de secciones
            .scrollContentBackground(.hidden) // Oculta el fondo del Form
        }
        .padding(30)
        .frame(minWidth: 500, minHeight: minHeight)
        .background(Color("MercedesCard")) // Fondo general
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
