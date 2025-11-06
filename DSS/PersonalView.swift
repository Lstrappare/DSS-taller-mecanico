import SwiftUI
import SwiftData

// --- MODO DEL MODAL ---
// Usaremos esto para decirle al modal si estamos Añadiendo o Editando
enum ModalMode: Identifiable {
    case add
    case edit(Personal)
    
    // Identificador para el .sheet()
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let personal): return personal.dni // <-- ¡ESTA ES LA CORRECCIÓN!
        }
    }
}


// --- VISTA PRINCIPAL ---
struct PersonalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Personal.nombre) private var personal: [Personal]
    
    // Este State controlará qué modal mostrar (añadir o editar)
    @State private var modalMode: ModalMode?

    var body: some View {
        VStack(alignment: .leading) {
            // --- Cabecera ---
            HStack {
                Text("Gestión de personal")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Button {
                    modalMode = .add // Abre el modal en modo "Add"
                } label: {
                    Label("Añadir personal", systemImage: "plus")
                        .font(.headline).padding(.vertical, 10).padding(.horizontal)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)
            
            Text("Gestiona tu equipo de trabajo del taller.")
                .font(.title3).foregroundColor(.gray).padding(.bottom, 20)
            
            // --- Lista del Personal (Actualizada) ---
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(personal) { mecanico in
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(mecanico.nombre)
                                    .font(.title2).fontWeight(.semibold)
                                
                                // Muestra Nivel y Especialidades
                                Text("\(mecanico.nivelHabilidad.rawValue) | \(mecanico.especialidades.joined(separator: ", "))")
                                    .font(.headline)
                                    .foregroundColor(Color("MercedesPetrolGreen"))
                                
                                Text("Email: \(mecanico.email.isEmpty ? "N/A" : mecanico.email)")
                                    .font(.body).foregroundColor(.gray)
                                Text("DNI: \(mecanico.dni)")
                                    .font(.body).foregroundColor(.gray)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 8) {
                                                            
                                                            // --- LÓGICA DE 3 ESTADOS ---
                                                            if mecanico.estaEnHorario {
                                                                // Si está en turno, revisa si está ocupado
                                                                if mecanico.estaDisponible {
                                                                    Text("Disponible")
                                                                        .font(.headline)
                                                                        .foregroundColor(.green)
                                                                } else {
                                                                    Text("Ocupado (En Servicio)")
                                                                        .font(.headline)
                                                                        .foregroundColor(.red)
                                                                }
                                                            } else {
                                                                // Si no está en turno, no importa nada más
                                                                Text("Fuera de Turno")
                                                                    .font(.headline)
                                                                    .foregroundColor(.gray)
                                                            }
                                                            // --- FIN DE LA LÓGICA ---
                                                            
                                                            Text("Turno: \(mecanico.horaEntrada) - \(mecanico.horaSalida)")
                                                                .font(.body).foregroundColor(.gray)
                                                        }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("MercedesCard"))
                        .cornerRadius(10)
                        // --- ¡AQUÍ ESTÁ LA MAGIA! ---
                        // Al tocar la tarjeta, abre el modal en modo "Edit"
                        .onTapGesture {
                            modalMode = .edit(mecanico)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(30)
        // --- MODAL MEJORADO ---
        // Usa .sheet(item:...) para pasar el modo (add/edit) al formulario
        .sheet(item: $modalMode) { incomingMode in
            PersonalFormView(mode: incomingMode) // Llama a la nueva vista de formulario
        }
    }
}


// --- VISTA DEL FORMULARIO (ADD/EDIT) ---
// Movimos el formulario a su propia vista para que sea más limpio
// --- VISTA DEL FORMULARIO (ADD/EDIT) ---
fileprivate struct PersonalFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: ModalMode
    
    // States para los campos
    @State private var nombre = ""
    @State private var email = ""
    @State private var dni = ""
    
    // --- CAMBIO AQUÍ ---
    // (Usamos Strings para los TextFields de números)
    @State private var horaEntradaString = "9"
    @State private var horaSalidaString = "18"
    
    @State private var nivelHabilidad: NivelHabilidad = .aprendiz
    @State private var especialidadesString = ""
    @State private var estaDisponible = true
    
    // Debe ser let en un View (se establece en init)
    private let mecanicoAEditar: Personal?
    
    var formTitle: String {
        switch mode {
        case .add: return "Add New Staff"
        case .edit: return "Edit Staff"
        }
    }
    
    // Inicializador
    init(mode: ModalMode) {
        self.mode = mode
        
        if case .edit(let personal) = mode {
            self.mecanicoAEditar = personal
            _nombre = State(initialValue: personal.nombre)
            _email = State(initialValue: personal.email)
            _dni = State(initialValue: personal.dni)
            // --- CAMBIO AQUÍ ---
            _horaEntradaString = State(initialValue: "\(personal.horaEntrada)")
            _horaSalidaString = State(initialValue: "\(personal.horaSalida)")
            _nivelHabilidad = State(initialValue: personal.nivelHabilidad)
            _especialidadesString = State(initialValue: personal.especialidades.joined(separator: ", "))
            _estaDisponible = State(initialValue: personal.estaDisponible)
        } else {
            self.mecanicoAEditar = nil
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(formTitle)
                .font(.largeTitle).fontWeight(.bold)
            
            // Formulario
            TextField("Name", text: $nombre)
            TextField("Email", text: $email)
            TextField("DNI", text: $dni).disabled(mecanicoAEditar != nil)
            
            // --- CAMPO DE HORARIO ACTUALIZADO ---
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
            // --- FIN DEL CAMBIO ---

            Picker("Nivel de Habilidad", selection: $nivelHabilidad) {
                ForEach(NivelHabilidad.allCases, id: \.self) { nivel in
                    Text(nivel.rawValue).tag(nivel)
                }
            }
            .pickerStyle(.segmented)
            
            TextField("Especialidades (separadas por coma, ej: Motor, Frenos)", text: $especialidadesString)
            
            Toggle("Disponible (no está en un servicio)", isOn: $estaDisponible)
            
            // ... (Botones de Cancelar, Borrar, Guardar) ...
            HStack {
                Button("Cancel") { dismiss() }
                .buttonStyle(.plain).padding().foregroundColor(.gray)
                
                if case .edit(let mecanico) = mode {
                    Button("Delete", role: .destructive) {
                        eliminarMecanico(mecanico)
                    }
                    .buttonStyle(.plain).padding().foregroundColor(.red)
                }
                Spacer()
                Button(mecanicoAEditar == nil ? "Add Staff" : "Save Changes") {
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
    
    // --- Lógica del Formulario (Actualizada) ---
    
    func guardarCambios() {
        // Validamos los nuevos campos de hora
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
            // MODO EDITAR
            mecanico.nombre = nombre
            mecanico.email = email
            mecanico.horaEntrada = horaEntrada // <-- CAMBIADO
            mecanico.horaSalida = horaSalida   // <-- CAMBIADO
            mecanico.nivelHabilidad = nivelHabilidad
            mecanico.especialidades = especialidadesArray
            mecanico.estaDisponible = estaDisponible
        } else {
            // MODO AÑADIR
            let nuevoMecanico = Personal(
                nombre: nombre,
                email: email,
                dni: dni,
                horaEntrada: horaEntrada, // <-- CAMBIADO
                horaSalida: horaSalida,   // <-- CAMBIADO
                nivelHabilidad: nivelHabilidad,
                especialidades: especialidadesArray,
                estaDisponible: estaDisponible
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
