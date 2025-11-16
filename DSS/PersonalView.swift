import SwiftUI
import SwiftData
import LocalAuthentication

// --- MODO DEL MODAL ---
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

// --- VISTA PRINCIPAL ---
struct PersonalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Personal.nombre) private var personal: [Personal]
    
    @State private var modalMode: ModalMode?
    @State private var searchQuery = ""
    @State private var filtroRol: Rol? = nil
    @State private var filtroEstado: EstadoEmpleado? = nil
    
    var filteredPersonal: [Personal] {
        var base = personal
        
        // Filtro de texto
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let q = searchQuery.lowercased()
            base = base.filter { mec in
                mec.nombre.lowercased().contains(q) ||
                mec.dni.lowercased().contains(q) ||
                mec.rol.rawValue.lowercased().contains(q) ||
                mec.especialidades.contains(where: { $0.lowercased().contains(q) })
            }
        }
        // Filtro por rol
        if let filtroRol { base = base.filter { $0.rol == filtroRol } }
        // Filtro por estado
        if let filtroEstado { base = base.filter { $0.estado == filtroEstado } }
        
        return base
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Cabecera con métricas y CTA
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Gestión de Personal")
                        .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                    HStack(spacing: 10) {
                        Label("\(personal.count) empleado\(personal.count == 1 ? "" : "s")", systemImage: "person.2.fill")
                            .font(.subheadline).foregroundColor(.gray)
                        let disponibles = personal.filter { $0.estado == .disponible && $0.estaEnHorario }.count
                        Label("\(disponibles) disponibles ahora", systemImage: "checkmark.seal.fill")
                            .font(.subheadline).foregroundColor(.gray)
                    }
                }
                Spacer()
                Button {
                    modalMode = .add
                } label: {
                    Label("Añadir Personal", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding(.vertical, 10).padding(.horizontal, 14)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            
            // Buscador
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color("MercedesPetrolGreen"))
                TextField("Buscar por Nombre, DNI, Rol o Especialidad...", text: $searchQuery)
                    .textFieldStyle(PlainTextFieldStyle())
                    .animation(.easeInOut(duration: 0.15), value: searchQuery)
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color("MercedesCard"))
            .cornerRadius(10)
            
            // Filtros rápidos
            HStack(spacing: 12) {
                Picker("Rol", selection: Binding(
                    get: { filtroRol ?? Rol?.none ?? nil },
                    set: { newValue in filtroRol = newValue }
                )) {
                    Text("Todos los Roles").tag(Rol?.none)
                    ForEach(Rol.allCases, id: \.self) { r in
                        Text(r.rawValue).tag(Rol?.some(r))
                    }
                }
                .pickerStyle(.menu)
                
                Picker("Estado", selection: Binding(
                    get: { filtroEstado ?? EstadoEmpleado?.none ?? nil },
                    set: { newValue in filtroEstado = newValue }
                )) {
                    Text("Todos los Estados").tag(EstadoEmpleado?.none)
                    ForEach(EstadoEmpleado.allCases, id: \.self) { e in
                        Text(e.rawValue).tag(EstadoEmpleado?.some(e))
                    }
                }
                .pickerStyle(.menu)
                
                if filtroRol != nil || filtroEstado != nil {
                    Button {
                        withAnimation {
                            filtroRol = nil
                            filtroEstado = nil
                        }
                    } label: {
                        Label("Limpiar filtros", systemImage: "line.3.horizontal.decrease.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.gray)
                }
                Spacer()
            }
            
            // Lista
            ScrollView {
                LazyVStack(spacing: 14) {
                    if filteredPersonal.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        ForEach(filteredPersonal) { mecanico in
                            PersonalCard(mecanico: mecanico) {
                                modalMode = .edit(mecanico)
                            }
                            .onTapGesture { modalMode = .edit(mecanico) }
                        }
                    }
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(30)
        .sheet(item: $modalMode) { incomingMode in
            PersonalFormView(mode: incomingMode)
                .environment(\.modelContext, modelContext)
        }
    }
    
    // Empty state agradable
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(Color("MercedesPetrolGreen"))
            Text(searchQuery.isEmpty ? "No hay personal registrado aún." :
                 "No se encontraron empleados para “\(searchQuery)”.")
                .font(.headline)
                .foregroundColor(.gray)
            if searchQuery.isEmpty {
                Text("Añade tu primer empleado para comenzar a asignar servicios.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    func colorParaEstado(_ estado: EstadoEmpleado) -> Color {
        switch estado {
        case .disponible: return .green
        case .ocupado: return .red
        case .descanso: return .yellow
        case .ausente: return .gray
        }
    }
}

// Tarjeta individual de personal
fileprivate struct PersonalCard: View {
    let mecanico: Personal
    var onEdit: () -> Void
    
    var estadoColor: Color {
        switch mecanico.estado {
        case .disponible: return .green
        case .ocupado: return .red
        case .descanso: return .yellow
        case .ausente: return .gray
        }
    }
    
    var avatarText: String {
        let comps = mecanico.nombre.split(separator: " ")
        let first = comps.first?.first.map(String.init) ?? ""
        let last = comps.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(Color("MercedesBackground"))
                        .frame(width: 44, height: 44)
                    Text(avatarText)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(mecanico.nombre)
                            .font(.title3).fontWeight(.semibold)
                        Spacer()
                        Text(mecanico.estaEnHorario ? mecanico.estado.rawValue : "Fuera de Turno")
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background((mecanico.estaEnHorario ? estadoColor : .gray).opacity(0.18))
                            .foregroundColor(mecanico.estaEnHorario ? estadoColor : .gray)
                            .cornerRadius(6)
                        
                        // Botón Editar
                        Button {
                            onEdit()
                        } label: {
                            Label("Editar", systemImage: "pencil")
                                .font(.subheadline)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color("MercedesBackground"))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack(spacing: 8) {
                        chip(text: mecanico.rol.rawValue, icon: "person.badge.shield.checkmark.fill")
                        Text("Turno: \(mecanico.horaEntrada) - \(mecanico.horaSalida)")
                            .font(.caption).foregroundColor(.gray)
                    }
                }
            }
            
            // Contacto
            HStack(spacing: 12) {
                Link(destination: URL(string: "mailto:\(mecanico.email)")!) {
                    Label(mecanico.email, systemImage: "envelope.fill")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(Color("MercedesPetrolGreen"))
                
                if mecanico.telefonoActivo && !mecanico.telefono.isEmpty {
                    Link(destination: URL(string: "tel:\(mecanico.telefono)")!) {
                        Label(mecanico.telefono, systemImage: "phone.fill")
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                } else {
                    Label("Tel: N/A", systemImage: "phone.fill")
                        .font(.caption).foregroundColor(.gray)
                }
                
                Spacer()
                Text("CURP: \(mecanico.dni)")
                    .font(.caption).foregroundColor(.gray)
            }
            
            // Especialidades como chips
            if !mecanico.especialidades.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(mecanico.especialidades, id: \.self) { esp in
                            Text(esp)
                                .font(.caption2)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color("MercedesBackground"))
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("MercedesCard"))
        .cornerRadius(12)
    }
    
    private func chip(text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color("MercedesBackground"))
        .cornerRadius(8)
        .foregroundColor(.white)
    }
}

// --- VISTA DEL FORMULARIO ---
fileprivate struct PersonalFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true

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
    @State private var telefono = ""
    @State private var telefonoActivo = false
    
    // States para Seguridad y Errores
    @State private var isDniUnlocked = false
    @State private var showingAuthModal = false
    @State private var authError = ""
    @State private var passwordAttempt = ""
    @State private var errorMsg: String?
    
    // Validaciones en línea simples
    private var nombreInvalido: Bool {
        nombre.trimmingCharacters(in: .whitespaces).split(separator: " ").count < 2
    }
    private var emailInvalido: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || !trimmed.contains("@")
    }
    private var dniInvalido: Bool {
        dni.trimmingCharacters(in: .whitespaces).count != 18
    }
    private var horasInvalidas: Bool {
        !(Int(horaEntradaString).map { (0...23).contains($0) } ?? false) ||
        !(Int(horaSalidaString).map { (0...23).contains($0) } ?? false)
    }
    
    private enum AuthReason {
        case unlockDNI, deleteEmployee
    }
    @State private var authReason: AuthReason = .unlockDNI
    
    private var mecanicoAEditar: Personal?
    var formTitle: String { (mode == .add) ? "Añadir Personal" : "Editar Personal" }
    
    init(mode: ModalMode) {
        self.mode = mode
        
        if case .edit(let personal) = mode {
            self.mecanicoAEditar = personal
            _nombre = State(initialValue: personal.nombre)
            _email = State(initialValue: personal.email)
            _dni = State(initialValue: personal.dni)
            _telefono = State(initialValue: personal.telefono)
            _telefonoActivo = State(initialValue: personal.telefonoActivo)
            _horaEntradaString = State(initialValue: "\(personal.horaEntrada)")
            _horaSalidaString = State(initialValue: "\(personal.horaSalida)")
            _rol = State(initialValue: personal.rol)
            _estado = State(initialValue: personal.estado)
            _especialidadesString = State(initialValue: personal.especialidades.joined(separator: ", "))
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Título compacto
            VStack(spacing: 4) {
                Text(formTitle)
                    .font(.title).fontWeight(.bold)
                Text("Completa los datos. Los campos marcados con • son obligatorios.")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            .padding(.top, 14)
            .padding(.bottom, 8)

            Form {
                // Información Personal
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionHeader(title: "Datos de Identidad", subtitle: nil)
                        // Dos columnas
                        HStack(spacing: 16) {
                            FormField(title: "• Nombre Completo", placeholder: "ej. José Cisneros Torres", text: $nombre)
                                .validationHint(isInvalid: nombreInvalido, message: "Escribe nombre y apellido.")
                            FormField(title: "• Email", placeholder: "ej. jose@taller.com", text: $email)
                                .validationHint(isInvalid: emailInvalido, message: "Ingresa un email válido.")
                        }
                        if case .edit = mode, !email.isEmpty {
                            Link("Enviar correo a \(email)", destination: URL(string: "mailto:\(email)")!)
                                .buttonStyle(.plain)
                                .font(.caption2)
                                .foregroundColor(Color("MercedesPetrolGreen"))
                        }
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("• CURP/DNI")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Image(systemName: isDniUnlocked ? "lock.open.fill" : "lock.fill")
                                        .foregroundColor(isDniUnlocked ? .green : .red)
                                        .font(.caption)
                                }
                                HStack(spacing: 8) {
                                    ZStack(alignment: .leading) {
                                        TextField("", text: $dni)
                                            .disabled(mecanicoAEditar != nil && !isDniUnlocked)
                                            .padding(10)
                                            .background(Color("MercedesBackground").opacity(0.9))
                                            .cornerRadius(8)
                                        if dni.isEmpty {
                                            Text("18 caracteres")
                                                .foregroundColor(Color.white.opacity(0.35))
                                                .padding(.horizontal, 14)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                    if mecanicoAEditar != nil {
                                        Button {
                                            if isDniUnlocked { isDniUnlocked = false }
                                            else {
                                                authReason = .unlockDNI
                                                showingAuthModal = true
                                            }
                                        } label: {
                                            Text(isDniUnlocked ? "Bloquear" : "Desbloquear")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(isDniUnlocked ? .green : .red)
                                    }
                                }
                                if dniInvalido {
                                    Text("Debe tener 18 caracteres.")
                                        .font(.caption2)
                                        .foregroundColor(.red.opacity(0.9))
                                } else if mecanicoAEditar != nil && !isDniUnlocked {
                                    Text("Campo protegido. Desbloquéalo para editar.")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                FormField(title: "Teléfono", placeholder: "10 dígitos", text: $telefono)
                                Toggle("Teléfono activo para contacto", isOn: $telefonoActivo)
                                    .toggleStyle(.switch)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                // Horario y Rol
                Section {
                    SectionHeader(title: "Horario y Rol", subtitle: nil)
                    HStack(spacing: 16) {
                        FormField(title: "• Entrada (0-23)", placeholder: "ej. 9", text: $horaEntradaString)
                        FormField(title: "• Salida (0-23)", placeholder: "ej. 18", text: $horaSalidaString)
                    }
                    if horasInvalidas {
                        Text("Las horas deben estar entre 0 y 23.")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.top, 2)
                    }
                    HStack(spacing: 16) {
                        Picker("Rol", selection: $rol) {
                            ForEach(Rol.allCases, id: \.self) { rol in
                                Text(rol.rawValue).tag(rol)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        Picker("Estado", selection: $estado) {
                            ForEach(EstadoEmpleado.allCases, id: \.self) { estado in
                                Text(estado.rawValue).tag(estado)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // Especialidades
                Section {
                    SectionHeader(title: "Especialidades", subtitle: "Separa por comas. Ej: Motor, Frenos, Suspensión")
                    FormField(title: "Especialidades", placeholder: "Motor, Frenos, Suspensión", text: $especialidadesString)
                    
                    let chips = especialidadesString
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    if !chips.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(chips, id: \.self) { chip in
                                    Text(chip)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color("MercedesCard"))
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .textFieldStyle(PlainTextFieldStyle())
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            
            if let errorMsg {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.vertical, 6)
            }
            
            // Barra de Botones
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .foregroundColor(.gray)
                
                if case .edit = mode {
                    Button("Eliminar", role: .destructive) {
                        authReason = .deleteEmployee
                        showingAuthModal = true
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .foregroundColor(.red)
                }
                Spacer()
                Button(mecanicoAEditar == nil ? "Guardar y Añadir" : "Guardar Cambios") {
                    guardarCambios()
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .foregroundColor(Color("MercedesPetrolGreen"))
                .cornerRadius(8)
                .disabled(nombreInvalido || emailInvalido || dniInvalido || horasInvalidas)
                .opacity((nombreInvalido || emailInvalido || dniInvalido || horasInvalidas) ? 0.6 : 1.0)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 720, minHeight: 480, maxHeight: 600)
        .cornerRadius(15)
        .sheet(isPresented: $showingAuthModal) {
            authModalView()
        }
    }
    
    // Modal de Autenticación
    @ViewBuilder
    func authModalView() -> some View {
        let prompt = (authReason == .unlockDNI) ?
            "Autoriza para editar el DNI/CURP." :
            "Autoriza para ELIMINAR a este empleado."
        
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Autorización Requerida").font(.title).fontWeight(.bold)
                Text(prompt)
                    .font(.callout)
                    .foregroundColor(authReason == .deleteEmployee ? .red : .gray)
                
                if isTouchIDEnabled {
                    Button { Task { await authenticateWithTouchID() } } label: {
                        Label("Usar Huella (Touch ID)", systemImage: "touchid")
                            .font(.headline).padding().frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    Text("o").foregroundColor(.gray)
                }
                
                Text("Usa tu contraseña de administrador:").font(.subheadline)
                SecureField("Contraseña", text: $passwordAttempt)
                    .padding(10).background(Color("MercedesCard")).cornerRadius(8)
                
                if !authError.isEmpty {
                    Text(authError).font(.caption2).foregroundColor(.red)
                }
                
                Button { authenticateWithPassword() } label: {
                    Label("Autorizar con Contraseña", systemImage: "lock.fill")
                        .font(.headline).padding().frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.4)).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(28)
        }
        .frame(minWidth: 520, minHeight: 380)
        .preferredColorScheme(.dark)
        .onAppear { authError = ""; passwordAttempt = "" }
    }
    
    // Lógica del Formulario (idéntica)
    func guardarCambios() {
        errorMsg = nil
        let trimmedName = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameParts = trimmedName.split(separator: " ").filter { !$0.isEmpty }

        guard nameParts.count >= 2 else {
            errorMsg = "El nombre completo debe tener al menos 2 palabras."
            return
        }

        for part in nameParts {
            if part.count < 3 {
                errorMsg = "Cada palabra del nombre debe tener al menos 3 letras."
                return
            }
        }
        let dniTrimmed = dni.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        let dniRegex = #"^[A-Z]{1}[AEIOU]{1}[A-Z]{2}\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])[HM]{1}(AS|BC|BS|CC|CL|CM|CS|CH|DF|DG|GT|GR|HG|JC|MC|MN|MS|NT|NL|OC|PL|QT|QR|SP|SL|SR|TC|TS|TL|VZ|YN|ZS|NE)[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9]{1}\d{1}$"#

        let dniPredicate = NSPredicate(format: "SELF MATCHES %@", dniRegex)

        guard dniTrimmed.count == 18 else {
            errorMsg = "El CURP debe tener 18 caracteres."
            return
        }

        guard dniPredicate.evaluate(with: dniTrimmed) else {
            errorMsg = "El CURP no tiene un formato válido."
            return
        }
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let emailRegex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)

        guard !emailTrimmed.isEmpty else {
            errorMsg = "El correo electrónico es obligatorio."
            return
        }

        guard emailPredicate.evaluate(with: emailTrimmed) else {
            errorMsg = "El correo electrónico no tiene un formato válido."
            return
        }
        let telefonoTrimmed = telefono.trimmingCharacters(in: .whitespacesAndNewlines)

        if telefonoActivo && telefonoTrimmed.isEmpty {
            errorMsg = "El teléfono no puede estar vacío si está marcado como 'Activo'."
            return
        }

        let telefonoRegex = #"^[0-9\s\-\(\)]+$"#
        let telefonoPredicate = NSPredicate(format: "SELF MATCHES %@", telefonoRegex)

        guard telefonoPredicate.evaluate(with: telefonoTrimmed) else {
            errorMsg = "El teléfono solo puede contener números, espacios, guiones o paréntesis."
            return
        }

        let digitos = telefonoTrimmed.filter { $0.isNumber }

        guard digitos.count >= 10 && digitos.count <= 15 else {
            errorMsg = "El teléfono debe tener entre 10 y 15 dígitos."
            return
        }
        guard let horaEntrada = Int(horaEntradaString),
              let horaSalida = Int(horaSalidaString),
              (0...23).contains(horaEntrada), (0...23).contains(horaSalida) else {
            errorMsg = "Las horas deben ser números válidos entre 0 y 23."
            return
        }
        
        let especialidadesArray = especialidadesString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        if let mecanico = mecanicoAEditar {
            mecanico.nombre = nombre
            mecanico.email = emailTrimmed
            mecanico.dni = dniTrimmed
            mecanico.telefono = telefonoTrimmed
            mecanico.telefonoActivo = telefonoActivo
            mecanico.horaEntrada = horaEntrada
            mecanico.horaSalida = horaSalida
            mecanico.rol = rol
            mecanico.estado = estado
            mecanico.especialidades = especialidadesArray
        } else {
            let nuevoMecanico = Personal(
                nombre: nombre,
                email: emailTrimmed,
                dni: dniTrimmed,
                telefono: telefonoTrimmed,
                telefonoActivo: telefonoActivo,
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
    
    // Autenticación
    func authenticateWithTouchID() async {
        let context = LAContext()
        let reason = (authReason == .unlockDNI) ? "Autoriza la edición del DNI/CURP." : "Autoriza la ELIMINACIÓN del empleado."
        do {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                if success { await MainActor.run { onAuthSuccess() } }
            }
        } catch { await MainActor.run { authError = "Huella no reconocida." } }
    }
    
    func authenticateWithPassword() {
        if passwordAttempt == userPassword {
            onAuthSuccess()
        } else {
            authError = "Contraseña incorrecta."
            passwordAttempt = ""
        }
    }
    
    func onAuthSuccess() {
        switch authReason {
        case .unlockDNI:
            isDniUnlocked = true
        case .deleteEmployee:
            if case .edit(let mecanico) = mode {
                eliminarMecanico(mecanico)
            }
        }
        showingAuthModal = false
        authError = ""
        passwordAttempt = ""
    }
}

// --- Helpers de UI ---
fileprivate struct SectionHeader: View {
    var title: String
    var subtitle: String?
    var body: some View {
        HStack {
            Text(title).font(.headline).foregroundColor(.white)
            Spacer()
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle).font(.caption2).foregroundColor(.gray)
            }
        }
        .padding(.bottom, 2)
    }
}

fileprivate struct FormField: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            
            ZStack(alignment: .leading) {
                TextField("", text: $text)
                    .padding(8)
                    .background(Color("MercedesBackground").opacity(0.9))
                    .cornerRadius(8)
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(Color.white.opacity(0.35))
                        .padding(.horizontal, 12)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

fileprivate extension View {
    func validationHint(isInvalid: Bool, message: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            self
            if isInvalid {
                Text(message)
                    .font(.caption2)
                    .foregroundColor(.red.opacity(0.9))
            }
        }
    }
}
