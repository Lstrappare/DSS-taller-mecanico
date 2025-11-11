import SwiftUI
import SwiftData

// --- MODO DEL MODAL (Sin cambios) ---
fileprivate enum ModalMode: Identifiable, Equatable {
    case add
    case edit(Personal)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let personal): return personal.dni
        }
    }
}


// --- VISTA PRINCIPAL (¡ACTUALIZADA!) ---
struct PersonalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Personal.nombre) private var personal: [Personal]
    
    @State private var modalMode: ModalMode?
    
    // --- 1. STATE PARA EL BUSCADOR ---
    @State private var searchQuery = ""
    
    // --- 2. LÓGICA DE FILTRADO ---
    var filteredPersonal: [Personal] {
        if searchQuery.isEmpty {
            return personal
        } else {
            let query = searchQuery.lowercased()
            return personal.filter { mec in
                // Revisa nombre, DNI o Rol
                let nombreMatch = mec.nombre.lowercased().contains(query)
                let dniMatch = mec.dni.lowercased().contains(query)
                let rolMatch = mec.rol.rawValue.lowercased().contains(query)
                // Revisa si *alguna* especialidad coincide
                let especialidadMatch = mec.especialidades.contains { $0.lowercased().contains(query) }
                
                return nombreMatch || dniMatch || rolMatch || especialidadMatch
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            // --- Cabecera (Sin cambios) ---
            HStack {
                Text("Gestión de Personal")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Button {
                    modalMode = .add
                } label: {
                    Label("Añadir Personal", systemImage: "plus")
                        .font(.headline).padding(.vertical, 10).padding(.horizontal)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)
            
            Text("Registra tu equipo de trabajo aquí.")
                .font(.title3).foregroundColor(.gray).padding(.bottom, 20)
            
            // --- 3. TEXTFIELD DE BÚSQUEDA ---
            TextField("Buscar por Nombre, DNI, Rol o Especialidad...", text: $searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                .padding(.bottom, 20)
            
            // --- Lista del Personal (Actualizada) ---
            ScrollView {
                LazyVStack(spacing: 15) {
                    // --- 4. USA LA LISTA FILTRADA ---
                    ForEach(filteredPersonal) { mecanico in
                        HStack {
                            // Info Izquierda
                            VStack(alignment: .leading, spacing: 8) {
                                Text(mecanico.nombre)
                                    .font(.title2).fontWeight(.semibold)
                                Text(mecanico.rol.rawValue)
                                    .font(.headline)
                                    .foregroundColor(Color("MercedesPetrolGreen"))
                                Text("Especialidades: \(mecanico.especialidades.joined(separator: ", "))")
                                    .font(.body).foregroundColor(.gray)
                                Text("CURP/DNI: \(mecanico.dni)")
                                    .font(.body).foregroundColor(.gray)
                            }
                            Spacer()
                            
                            // Info Derecha
                            VStack(alignment: .trailing, spacing: 8) {
                                if !mecanico.estaEnHorario {
                                    Text("Fuera de Turno")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                } else {
                                    Text(mecanico.estado.rawValue)
                                        .font(.headline)
                                        .foregroundColor(colorParaEstado(mecanico.estado))
                                }
                                Text("Turno: \(mecanico.horaEntrada) - \(mecanico.horaSalida)")
                                    .font(.body).foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("MercedesCard"))
                        .cornerRadius(10)
                        .onTapGesture {
                            modalMode = .edit(mecanico)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(30)
        .sheet(item: $modalMode) { incomingMode in
            PersonalFormView(mode: incomingMode)
        }
    }
    
    // Helper para dar color al estado
    func colorParaEstado(_ estado: EstadoEmpleado) -> Color {
        switch estado {
        case .disponible: return .green
        case .ocupado: return .red
        case .descanso: return .yellow
        case .ausente: return .gray
        }
    }
}


// --- VISTA DEL FORMULARIO (Sin cambios) ---
// (Esta parte es idéntica a la que ya tenías)
fileprivate struct PersonalFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: ModalMode
    
    // States para los campos
    @State private var nombre = ""
    @State private var email = ""
    @State private var dni = ""
    @State private var horaEntradaString = "9"
    @State private var horaSalidaString = "18"
    @State private var rol: Rol = .ayudante
    @State private var estado: EstadoEmpleado = .disponible
    @State private var especialidadesString = ""
    
    private var mecanicoAEditar: Personal?
    var formTitle: String { (mode == .add) ? "Añadir Personal" : "Editar Personal" }
    
    // Inicializador
    init(mode: ModalMode) {
        self.mode = mode
        
        if case .edit(let personal) = mode {
            self.mecanicoAEditar = personal
            _nombre = State(initialValue: personal.nombre)
            _email = State(initialValue: personal.email)
            _dni = State(initialValue: personal.dni)
            _horaEntradaString = State(initialValue: "\(personal.horaEntrada)")
            _horaSalidaString = State(initialValue: "\(personal.horaSalida)")
            _rol = State(initialValue: personal.rol)
            _estado = State(initialValue: personal.estado)
            _especialidadesString = State(initialValue: personal.especialidades.joined(separator: ", "))
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(formTitle)
                .font(.largeTitle).fontWeight(.bold)
            
            TextField("Nombre Completo", text: $nombre)
            TextField("Email", text: $email)
            TextField("CURP/DNI", text: $dni).disabled(mecanicoAEditar != nil)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Hora Entrada (Formato 24h)").font(.caption).foregroundColor(.gray)
                    TextField("ej. 9", text: $horaEntradaString)
                }
                VStack(alignment: .leading) {
                    Text("Hora Salida (Formato 24h)").font(.caption).foregroundColor(.gray)
                    TextField("ej. 18", text: $horaSalidaString)
                }
            }

            Picker("Rol en el Taller", selection: $rol) {
                ForEach(Rol.allCases, id: \.self) { rol in
                    Text(rol.rawValue).tag(rol)
                }
            }
            .pickerStyle(.menu)
            
            Picker("Estado Actual", selection: $estado) {
                ForEach(EstadoEmpleado.allCases, id: \.self) { estado in
                    Text(estado.rawValue).tag(estado)
                }
            }
            
            TextField("Especialidades (separadas por coma, ej: Motor, Frenos)", text: $especialidadesString)
            
            HStack {
                Button("Cancelar") { dismiss() }
                .buttonStyle(.plain).padding().foregroundColor(.gray)
                
                if case .edit(let mecanico) = mode {
                    Button("Eliminar", role: .destructive) {
                        eliminarMecanico(mecanico)
                    }
                    .buttonStyle(.plain).padding().foregroundColor(.red)
                }
                Spacer()
                Button(mecanicoAEditar == nil ? "Añadir Personal" : "Guardar Cambios") {
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
    }
    
    // --- Lógica del Formulario (Sin cambios) ---
    
    func guardarCambios() {
        guard !nombre.isEmpty, !dni.isEmpty,
              let horaEntrada = Int(horaEntradaString),
              let horaSalida = Int(horaSalidaString) else {
            print("Error: Campos inválidos")
            return
        }
        
        let especialidadesArray = especialidadesString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        if let mecanico = mecanicoAEditar {
            mecanico.nombre = nombre
            mecanico.email = email
            mecanico.horaEntrada = horaEntrada
            mecanico.horaSalida = horaSalida
            mecanico.rol = rol
            mecanico.estado = estado
            mecanico.especialidades = especialidadesArray
        } else {
            let nuevoMecanico = Personal(
                nombre: nombre,
                email: email,
                dni: dni,
                horaEntrada: horaEntrada,
                horaSalida: horaSalida,
                rol: rol,
                estado: estado,
                especialidades: especialidadesArray
            )
            modelContext.insert(nuevoMecanico)
        }
        dismiss()
    }
    
    func eliminarMecanico(_ mecanico: Personal) {
        modelContext.delete(mecanico)
        dismiss()
    }
}
