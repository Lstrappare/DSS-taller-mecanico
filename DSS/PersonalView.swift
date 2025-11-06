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
                Text("Staff Management")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Button {
                    modalMode = .add // Abre el modal en modo "Add"
                } label: {
                    Label("Add Staff", systemImage: "plus")
                        .font(.headline).padding(.vertical, 10).padding(.horizontal)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)
            
            Text("Manage your team members")
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
                                // Muestra Disponibilidad y Horario
                                Text(mecanico.estaDisponible ? "Disponible" : "Ocupado")
                                    .font(.headline)
                                    .foregroundColor(mecanico.estaDisponible ? .green : .red)
                                Text(mecanico.horario)
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
        .sheet(item: $modalMode) { mode in
            PersonalFormView(mode: mode) // Llama a la nueva vista de formulario
        }
    }
}


// --- VISTA DEL FORMULARIO (ADD/EDIT) ---
// Movimos el formulario a su propia vista para que sea más limpio
struct PersonalFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss // Para cerrar el modal

    let mode: ModalMode
    
    // States para los campos
    @State private var nombre = ""
    @State private var email = ""
    @State private var dni = ""
    @State private var horario = "L-V 9:00-18:00"
    @State private var nivelHabilidad: NivelHabilidad = .aprendiz
    @State private var especialidadesString = ""
    @State private var estaDisponible = true
    
    // El mecánico que estamos editando (si existe)
    private var mecanicoAEditar: Personal?
    
    // Título del Modal
    var formTitle: String {
        switch mode {
        case .add: return "Add New Staff Member"
        case .edit: return "Edit Staff Member"
        }
    }
    
    // Inicializador
    init(mode: ModalMode) {
        self.mode = mode
        
        // Si estamos en modo "Edit", pre-llenamos los campos
        if case .edit(let personal) = mode {
            self.mecanicoAEditar = personal
            // Usamos _variable = State(initialValue: ...) para inicializar
            _nombre = State(initialValue: personal.nombre)
            _email = State(initialValue: personal.email)
            _dni = State(initialValue: personal.dni)
            _horario = State(initialValue: personal.horario)
            _nivelHabilidad = State(initialValue: personal.nivelHabilidad)
            _especialidadesString = State(initialValue: personal.especialidades.joined(separator: ", "))
            _estaDisponible = State(initialValue: personal.estaDisponible)
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
            TextField("Horario (ej. L-V 9-18)", text: $horario)
            
            Picker("Nivel de Habilidad", selection: $nivelHabilidad) {
                ForEach(NivelHabilidad.allCases, id: \.self) { nivel in
                    Text(nivel.rawValue).tag(nivel)
                }
            }
            .pickerStyle(.segmented)
            
            TextField("Especialidades (separadas por coma, ej: Motor, Frenos)", text: $especialidadesString)
            
            Toggle("Está Disponible", isOn: $estaDisponible)
            
            HStack {
                // --- BOTÓN CANCELAR (ACTUALIZADO) ---
                Button("Cancel") { dismiss() }
                .buttonStyle(.plain).padding()
                .foregroundColor(.gray) // <-- Color añadido
                
                // --- BOTÓN BORRAR (ACTUALIZADO) ---
                if case .edit(let mecanico) = mode {
                    Button("Delete", role: .destructive) {
                        eliminarMecanico(mecanico)
                    }
                    .buttonStyle(.plain).padding()
                    .foregroundColor(.red) // <-- Color añadido
                }
                
                Spacer()
                
                // El botón de Guardar/Añadir
                Button(mecanicoAEditar == nil ? "Add Staff" : "Save Changes") {
                    guardarCambios()
                }
                .buttonStyle(.plain).padding()
                .foregroundColor(Color("MercedesPetrolGreen")).cornerRadius(8)
            }
            .padding(.top, 30)
        }
        .padding(40)
        .background(Color("MercedesBackground")) // Fondo principal del modal
        .cornerRadius(15)
        .preferredColorScheme(.dark)
        .textFieldStyle(PlainTextFieldStyle())
        .padding()
        .background(Color("MercedesBackgroundCard")) // Tarjeta interna
        .cornerRadius(15) // <-- Esquinas redondeadas (puedes cambiar de 8 a 15 si te gusta más)
    }
    
    // --- Lógica del Formulario ---
    
    func guardarCambios() {
        if !nombre.isEmpty && !dni.isEmpty {
            // Convertir el string "Frenos, Motor" en un array ["Frenos", "Motor"]
            let especialidadesArray = especialidadesString
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            if let mecanico = mecanicoAEditar {
                // MODO EDITAR
                mecanico.nombre = nombre
                mecanico.email = email
                mecanico.horario = horario
                mecanico.nivelHabilidad = nivelHabilidad
                mecanico.especialidades = especialidadesArray
                mecanico.estaDisponible = estaDisponible
            } else {
                // MODO AÑADIR
                let nuevoMecanico = Personal(
                    nombre: nombre,
                    email: email,
                    dni: dni,
                    horario: horario,
                    nivelHabilidad: nivelHabilidad,
                    especialidades: especialidadesArray,
                    estaDisponible: estaDisponible
                )
                modelContext.insert(nuevoMecanico)
            }
            dismiss()
        }
    }
    
    func eliminarMecanico(_ mecanico: Personal) {
        modelContext.delete(mecanico)
        dismiss()
    }
}
