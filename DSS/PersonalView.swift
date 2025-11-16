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
        case .edit(let personal): return personal.rfc
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
                mec.rfc.lowercased().contains(q) ||
                mec.curp?.lowercased().contains(q) == true ||
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
                TextField("Buscar por Nombre, RFC, CURP, Rol o Especialidad...", text: $searchQuery)
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
                Text("RFC: \(mecanico.rfc)")
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

// --- VISTA DEL FORMULARIO PROFESIONAL ---
fileprivate struct PersonalFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true

    let mode: ModalMode
    
    // Datos personales
    @State private var nombre = ""
    @State private var email = ""
    @State private var telefono = ""
    @State private var telefonoActivo = false
    @State private var rfc = ""
    @State private var curp = ""
    
    // Trabajo
    @State private var rol: Rol = .ayudante
    @State private var especialidadesString = ""
    @State private var fechaIngreso = Date()
    @State private var tipoContrato: TipoContrato = .indefinido
    @State private var sueldoMensualBrutoString = ""
    @State private var horaEntradaString = "9"
    @State private var horaSalidaString = "18"
    @State private var diasLaborales: Set<Int> = [2,3,4,5,6] // L-V
    
    // Nómina
    @State private var prestacionesMinimas = true
    @State private var tipoSalario: TipoSalario = .minimo
    @State private var frecuenciaPago: FrecuenciaPago = .quincena
    @State private var salarioMinimoReferenciaString = "248.93"
    
    // Documentación
    @State private var ineAdjuntoPath = ""
    @State private var comprobanteDomicilioPath = ""
    @State private var comprobanteEstudiosPath = ""
    
    // Estado operacional
    @State private var estado: EstadoEmpleado = .disponible
    
    // Bloqueos/Seguridad
    @State private var isRFCUnlocked = false
    @State private var showingAuthModal = false
    @State private var authError = ""
    @State private var passwordAttempt = ""
    @State private var errorMsg: String?
    private enum AuthReason { case unlockRFC, deleteEmployee, markAbsence }
    @State private var authReason: AuthReason = .unlockRFC
    
    // Campos automáticos (preview en vivo)
    @State private var salarioDiario: Double = 0
    @State private var sbc: Double = 0
    @State private var isrMensualEstimado: Double = 0
    @State private var imssMensualEstimado: Double = 0
    @State private var cuotaObrera: Double = 0
    @State private var cuotaPatronal: Double = 0
    @State private var sueldoNetoMensual: Double = 0
    @State private var costoRealMensual: Double = 0
    @State private var costoHora: Double = 0
    @State private var horasSemanalesRequeridas: Double = 48
    @State private var manoDeObraSugerida: Double = 0
    
    // Asistencia UI state (simple)
    @State private var estadoAsistenciaHoy: EstadoAsistencia = .incompleto
    @State private var asistenciaBloqueada = false
    
    private var mecanicoAEditar: Personal?
    var formTitle: String { (mode == .add) ? "Añadir Personal" : "Editar Personal" }
    
    init(mode: ModalMode) {
        self.mode = mode
        if case .edit(let personal) = mode {
            self.mecanicoAEditar = personal
            _nombre = State(initialValue: personal.nombre)
            _email = State(initialValue: personal.email)
            _telefono = State(initialValue: personal.telefono)
            _telefonoActivo = State(initialValue: personal.telefonoActivo)
            _rfc = State(initialValue: personal.rfc)
            _curp = State(initialValue: personal.curp ?? "")
            _rol = State(initialValue: personal.rol)
            _estado = State(initialValue: personal.estado)
            _especialidadesString = State(initialValue: personal.especialidades.joined(separator: ", "))
            _fechaIngreso = State(initialValue: personal.fechaIngreso)
            _tipoContrato = State(initialValue: personal.tipoContrato)
            _sueldoMensualBrutoString = State(initialValue: String(format: "%.2f", personal.sueldoMensualBruto))
            _horaEntradaString = State(initialValue: "\(personal.horaEntrada)")
            _horaSalidaString = State(initialValue: "\(personal.horaSalida)")
            _diasLaborales = State(initialValue: Set(personal.diasLaborales))
            
            _prestacionesMinimas = State(initialValue: personal.prestacionesMinimas)
            _tipoSalario = State(initialValue: personal.tipoSalario)
            _frecuenciaPago = State(initialValue: personal.frecuenciaPago)
            _salarioMinimoReferenciaString = State(initialValue: String(format: "%.2f", personal.salarioMinimoReferencia))
            
            _ineAdjuntoPath = State(initialValue: personal.ineAdjuntoPath ?? "")
            _comprobanteDomicilioPath = State(initialValue: personal.comprobanteDomicilioPath ?? "")
            _comprobanteEstudiosPath = State(initialValue: personal.comprobanteEstudiosPath ?? "")
            
            // snapshots
            _salarioDiario = State(initialValue: personal.salarioDiario)
            _sbc = State(initialValue: personal.sbc)
            _isrMensualEstimado = State(initialValue: personal.isrMensualEstimado)
            _imssMensualEstimado = State(initialValue: personal.imssMensualEstimado)
            _cuotaObrera = State(initialValue: personal.cuotaObrera)
            _cuotaPatronal = State(initialValue: personal.cuotaPatronal)
            _sueldoNetoMensual = State(initialValue: personal.sueldoNetoMensual)
            _costoRealMensual = State(initialValue: personal.costoRealMensual)
            _costoHora = State(initialValue: personal.costoHora)
            _horasSemanalesRequeridas = State(initialValue: personal.horasSemanalesRequeridas)
            _manoDeObraSugerida = State(initialValue: personal.manoDeObraSugerida)
        }
    }
    
    // Validaciones
    private var nombreInvalido: Bool {
        nombre.trimmingCharacters(in: .whitespaces).split(separator: " ").count < 2
    }
    private var emailInvalido: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let regex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        let pred = NSPredicate(format: "SELF MATCHES[c] %@", regex)
        return trimmed.isEmpty || !pred.evaluate(with: trimmed)
    }
    private var rfcInvalido: Bool {
        !RFCValidator.isValidRFC(rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
    }
    private var horasInvalidas: Bool {
        !(Int(horaEntradaString).map { (0...23).contains($0) } ?? false) ||
        !(Int(horaSalidaString).map { (0...23).contains($0) } ?? false)
    }
    private var sueldoInvalido: Bool {
        Double(sueldoMensualBrutoString.replacingOccurrences(of: ",", with: ".")) == nil
    }
    private var salarioMinimoInvalido: Bool {
        Double(salarioMinimoReferenciaString.replacingOccurrences(of: ",", with: ".")) == nil
    }
    private var sinDiasLaborales: Bool {
        diasLaborales.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Título y leyendas
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
                // Sección: Datos personales
                Section {
                    SectionHeader(title: "Datos personales", subtitle: nil)
                    HStack(spacing: 16) {
                        FormField(title: "• Nombre Completo", placeholder: "ej. José Cisneros Torres", text: $nombre)
                            .validationHint(isInvalid: nombreInvalido, message: "Escribe nombre y apellido.")
                        FormField(title: "• Email", placeholder: "ej. jose@taller.com", text: $email)
                            .validationHint(isInvalid: emailInvalido, message: "Ingresa un email válido.")
                    }
                    HStack(spacing: 16) {
                        FormField(title: "Teléfono", placeholder: "10 dígitos", text: $telefono)
                        Toggle("Teléfono activo para contacto", isOn: $telefonoActivo)
                            .toggleStyle(.switch)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    // RFC con candado en edición
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("• RFC").font(.caption).foregroundColor(.gray)
                            if mecanicoAEditar != nil {
                                Image(systemName: isRFCUnlocked ? "lock.open.fill" : "lock.fill")
                                    .foregroundColor(isRFCUnlocked ? .green : .red)
                                    .font(.caption)
                            }
                        }
                        HStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                TextField("", text: $rfc)
                                    .disabled(mecanicoAEditar != nil && !isRFCUnlocked)
                                    .padding(10)
                                    .background(Color("MercedesBackground").opacity(0.9))
                                    .cornerRadius(8)
                                if rfc.isEmpty {
                                    Text("13 caracteres (persona física) o 12 (moral)")
                                        .foregroundColor(Color.white.opacity(0.35))
                                        .padding(.horizontal, 14)
                                        .allowsHitTesting(false)
                                }
                            }
                            if mecanicoAEditar != nil {
                                Button {
                                    if isRFCUnlocked { isRFCUnlocked = false }
                                    else {
                                        authReason = .unlockRFC
                                        showingAuthModal = true
                                    }
                                } label: {
                                    Text(isRFCUnlocked ? "Bloquear" : "Desbloquear")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(isRFCUnlocked ? .green : .red)
                            }
                        }
                        .validationHint(isInvalid: rfcInvalido, message: "RFC inválido. Verifica estructura y homoclave.")
                    }
                    FormField(title: "CURP (opcional)", placeholder: "18 caracteres", text: $curp)
                }
                
                // Sección: Trabajo
                Section {
                    SectionHeader(title: "Trabajo", subtitle: nil)
                    HStack(spacing: 16) {
                        Picker("• Rol", selection: $rol) {
                            ForEach(Rol.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        FormField(title: "Especialidades (coma)", placeholder: "Motor, Frenos, Suspensión", text: $especialidadesString)
                    }
                    HStack(spacing: 16) {
                        DatePicker("• Fecha de ingreso", selection: $fechaIngreso, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .frame(maxWidth: .infinity)
                        Picker("• Tipo de contrato", selection: $tipoContrato) {
                            ForEach(TipoContrato.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                    HStack(spacing: 16) {
                        FormField(title: "• Sueldo mensual bruto", placeholder: "ej. 12000.00", text: $sueldoMensualBrutoString)
                            .validationHint(isInvalid: sueldoInvalido, message: "Debe ser un número válido.")
                        FormField(title: "• Entrada (0-23)", placeholder: "ej. 9", text: $horaEntradaString)
                            .validationHint(isInvalid: horasInvalidas, message: "0 a 23.")
                        FormField(title: "• Salida (0-23)", placeholder: "ej. 18", text: $horaSalidaString)
                            .validationHint(isInvalid: horasInvalidas, message: "0 a 23.")
                    }
                    // Días laborables
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• Días laborables").font(.caption).foregroundColor(.gray)
                        DaysSelector(selected: $diasLaborales)
                            .padding(8)
                            .background(Color("MercedesBackground"))
                            .cornerRadius(8)
                            .validationHint(isInvalid: sinDiasLaborales, message: "Selecciona al menos un día.")
                    }
                }
                
                // Sección: Nómina
                Section {
                    SectionHeader(title: "Nómina", subtitle: "Cálculos aproximados. Verifique con fuentes oficiales.")
                    Toggle("Prestaciones mínimas", isOn: $prestacionesMinimas)
                    HStack(spacing: 16) {
                        Picker("• Tipo de salario", selection: $tipoSalario) {
                            ForEach(TipoSalario.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        Picker("• Frecuencia de pago", selection: $frecuenciaPago) {
                            ForEach(FrecuenciaPago.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                    HStack(spacing: 16) {
                        FormField(title: "• Salario mínimo de referencia (editable)", placeholder: "ej. 248.93", text: $salarioMinimoReferenciaString)
                            .validationHint(isInvalid: salarioMinimoInvalido, message: "Número válido.")
                        Link("Tabla oficial de salarios mínimos (CONASAMI)", destination: URL(string: "https://www.gob.mx/conasami/documentos/tabla-de-salarios-minimos-generales-y-profesionales-por-areas-geograficas?idiom=es")!)
                            .font(.caption)
                            .foregroundColor(Color("MercedesPetrolGreen"))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    
                    // Campos automáticos: solo lectura
                    AutoPayrollGrid(
                        salarioDiario: salarioDiario,
                        sbc: sbc,
                        isrMensual: isrMensualEstimado,
                        imssMensual: imssMensualEstimado,
                        cuotaObrera: cuotaObrera,
                        cuotaPatronal: cuotaPatronal,
                        sueldoNetoMensual: sueldoNetoMensual,
                        costoRealMensual: costoRealMensual,
                        costoHora: costoHora,
                        horasSemanalesRequeridas: horasSemanalesRequeridas,
                        manoDeObraSugerida: manoDeObraSugerida
                    )
                    
                    HStack {
                        Button {
                            recalcularNominaPreview()
                        } label: {
                            Label("Recalcular", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .background(Color("MercedesBackground"))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        
                        Text("Cálculos aproximados. Verifique datos reales con instituciones oficiales.")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Spacer()
                    }
                }
                
                // Sección: Documentación
                Section {
                    SectionHeader(title: "Documentación (opcional)", subtitle: "Rutas o identificadores de archivo")
                    HStack(spacing: 16) {
                        FormField(title: "INE", placeholder: "/ruta/al/archivo.pdf", text: $ineAdjuntoPath)
                        FormField(title: "Comprobante de domicilio", placeholder: "/ruta/al/archivo.pdf", text: $comprobanteDomicilioPath)
                        FormField(title: "Comprobante de estudios", placeholder: "/ruta/al/archivo.pdf", text: $comprobanteEstudiosPath)
                    }
                }
                
                // Sección: Asistencia (controles simples)
                Section {
                    SectionHeader(title: "Asistencia (automática)", subtitle: "Botones de jornada")
                    AssistToolbar(
                        estado: $estado,
                        asistenciaBloqueada: $asistenciaBloqueada,
                        onMarcarAusencia: {
                            authReason = .markAbsence
                            showingAuthModal = true
                        }
                    )
                }
            }
            .textFieldStyle(PlainTextFieldStyle())
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .onAppear { recalcularNominaPreview() }
            .onChange(of: sueldoMensualBrutoString) { _, _ in recalcularNominaPreview() }
            .onChange(of: salarioMinimoReferenciaString) { _, _ in recalcularNominaPreview() }
            .onChange(of: prestacionesMinimas) { _, _ in recalcularNominaPreview() }
            .onChange(of: tipoSalario) { _, _ in recalcularNominaPreview() }
            
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
                .disabled(nombreInvalido || emailInvalido || rfcInvalido || horasInvalidas || sueldoInvalido || salarioMinimoInvalido || sinDiasLaborales)
                .opacity((nombreInvalido || emailInvalido || rfcInvalido || horasInvalidas || sueldoInvalido || salarioMinimoInvalido || sinDiasLaborales) ? 0.6 : 1.0)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 800, minHeight: 600, maxHeight: 900)
        .cornerRadius(15)
        .sheet(isPresented: $showingAuthModal) {
            authModalView()
        }
    }
    
    // Modal de Autenticación
    @ViewBuilder
    func authModalView() -> some View {
        let prompt: String = {
            switch authReason {
            case .unlockRFC: return "Autoriza para editar el RFC."
            case .deleteEmployee: return "Autoriza para ELIMINAR a este empleado."
            case .markAbsence: return "Autoriza para marcar AUSENCIA de todo el día."
            }
        }()
        
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
                
                Text("Usa tu contraseña de supervisor/administrador:").font(.subheadline)
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
    
    // Guardar
    func guardarCambios() {
        errorMsg = nil
        
        // Parse
        guard let horaEntrada = Int(horaEntradaString),
              let horaSalida = Int(horaSalidaString),
              (0...23).contains(horaEntrada),
              (0...23).contains(horaSalida) else {
            errorMsg = "Las horas deben ser números válidos entre 0 y 23."
            return
        }
        guard let sueldoMensual = Double(sueldoMensualBrutoString.replacingOccurrences(of: ",", with: ".")) else {
            errorMsg = "Sueldo mensual inválido."
            return
        }
        guard let salarioMinimoRef = Double(salarioMinimoReferenciaString.replacingOccurrences(of: ",", with: ".")) else {
            errorMsg = "Salario mínimo de referencia inválido."
            return
        }
        guard RFCValidator.isValidRFC(rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()) else {
            errorMsg = "RFC inválido."
            return
        }
        
        // Especialidades
        let especialidadesArray = especialidadesString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Recalcular snapshots antes de persistir
        let calc = PayrollCalculatorLite.calculate(
            sueldoMensualBruto: sueldoMensual,
            salarioMinimo: salarioMinimoRef,
            prestacionesMinimas: prestacionesMinimas,
            tipoSalario: tipoSalario
        )
        salarioDiario = calc.salarioDiario
        sbc = calc.sbc
        isrMensualEstimado = calc.isrMensual
        imssMensualEstimado = calc.imssMensual
        cuotaObrera = calc.cuotaObrera
        cuotaPatronal = calc.cuotaPatronal
        sueldoNetoMensual = calc.sueldoNeto
        costoRealMensual = calc.costoReal
        costoHora = calc.costoHora
        horasSemanalesRequeridas = calc.horasSemanales
        manoDeObraSugerida = calc.manoDeObraSugerida
        
        if let mec = mecanicoAEditar {
            mec.nombre = nombre
            mec.email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            mec.telefono = telefono.trimmingCharacters(in: .whitespacesAndNewlines)
            mec.telefonoActivo = telefonoActivo
            if isRFCUnlocked { mec.rfc = rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            mec.curp = curp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : curp.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            mec.rol = rol
            mec.estado = estado
            mec.especialidades = especialidadesArray
            mec.fechaIngreso = fechaIngreso
            mec.tipoContrato = tipoContrato
            mec.sueldoMensualBruto = sueldoMensual
            mec.horaEntrada = horaEntrada
            mec.horaSalida = horaSalida
            mec.diasLaborales = Array(diasLaborales).sorted()
            
            mec.prestacionesMinimas = prestacionesMinimas
            mec.tipoSalario = tipoSalario
            mec.frecuenciaPago = frecuenciaPago
            mec.salarioMinimoReferencia = salarioMinimoRef
            
            mec.salarioDiario = salarioDiario
            mec.sbc = sbc
            mec.isrMensualEstimado = isrMensualEstimado
            mec.imssMensualEstimado = imssMensualEstimado
            mec.cuotaObrera = cuotaObrera
            mec.cuotaPatronal = cuotaPatronal
            mec.sueldoNetoMensual = sueldoNetoMensual
            mec.costoRealMensual = costoRealMensual
            mec.costoHora = costoHora
            mec.horasSemanalesRequeridas = horasSemanalesRequeridas
            mec.manoDeObraSugerida = manoDeObraSugerida
            mec.ultimoCalculoNomina = Date()
        } else {
            let nuevo = Personal(
                rfc: rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                curp: curp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : curp.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                nombre: nombre,
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                telefono: telefono.trimmingCharacters(in: .whitespacesAndNewlines),
                telefonoActivo: telefonoActivo,
                horaEntrada: horaEntrada,
                horaSalida: horaSalida,
                rol: rol,
                estado: estado,
                especialidades: especialidadesArray,
                fechaIngreso: fechaIngreso,
                tipoContrato: tipoContrato,
                sueldoMensualBruto: sueldoMensual,
                diasLaborales: Array(diasLaborales).sorted(),
                prestacionesMinimas: prestacionesMinimas,
                tipoSalario: tipoSalario,
                frecuenciaPago: frecuenciaPago,
                salarioMinimoReferencia: salarioMinimoRef,
                salarioDiario: salarioDiario,
                sbc: sbc,
                isrMensualEstimado: isrMensualEstimado,
                imssMensualEstimado: imssMensualEstimado,
                cuotaObrera: cuotaObrera,
                cuotaPatronal: cuotaPatronal,
                sueldoNetoMensual: sueldoNetoMensual,
                costoRealMensual: costoRealMensual,
                costoHora: costoHora,
                horasSemanalesRequeridas: horasSemanalesRequeridas,
                manoDeObraSugerida: manoDeObraSugerida,
                ultimoCalculoNomina: Date(),
                ineAdjuntoPath: ineAdjuntoPath.isEmpty ? nil : ineAdjuntoPath,
                comprobanteDomicilioPath: comprobanteDomicilioPath.isEmpty ? nil : comprobanteDomicilioPath,
                comprobanteEstudiosPath: comprobanteEstudiosPath.isEmpty ? nil : comprobanteEstudiosPath,
                antiguedadDias: 0,
                bloqueoAsistenciaFecha: nil
            )
            modelContext.insert(nuevo)
        }
        dismiss()
    }
    
    // Autenticación
    func authenticateWithTouchID() async {
        let context = LAContext()
        let reason: String = {
            switch authReason {
            case .unlockRFC: return "Autoriza la edición del RFC."
            case .deleteEmployee: return "Autoriza la ELIMINACIÓN del empleado."
            case .markAbsence: return "Autoriza para marcar AUSENCIA."
            }
        }()
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
        case .unlockRFC:
            isRFCUnlocked = true
        case .deleteEmployee:
            if case .edit(let mecanico) = mode {
                modelContext.delete(mecanico)
            }
            dismiss()
        case .markAbsence:
            marcarAusenciaDiaCompleto()
        }
        showingAuthModal = false
        authError = ""
        passwordAttempt = ""
    }
    
    // Asistencia (simple): marcar ausencia bloqueada todo el día
    func marcarAusenciaDiaCompleto() {
        guard let empleado = mecanicoAEditar ?? nil else { return }
        let hoy = Calendar.current.startOfDay(for: Date())
        // buscar o crear registro del día
        let registro = empleado.asistencias.first(where: { $0.fecha == hoy }) ?? {
            let nuevo = AsistenciaDiaria(empleado: empleado, fecha: hoy)
            modelContext.insert(nuevo)
            empleado.asistencias.append(nuevo)
            return nuevo
        }()
        registro.estadoFinal = .ausente
        registro.bloqueada = true
        empleado.bloqueoAsistenciaFecha = hoy
        asistenciaBloqueada = true
    }
    
    // Recalcular preview de nómina (live)
    func recalcularNominaPreview() {
        let sueldo = Double(sueldoMensualBrutoString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let sm = Double(salarioMinimoReferenciaString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let out = PayrollCalculatorLite.calculate(
            sueldoMensualBruto: sueldo,
            salarioMinimo: sm,
            prestacionesMinimas: prestacionesMinimas,
            tipoSalario: tipoSalario
        )
        salarioDiario = out.salarioDiario
        sbc = out.sbc
        isrMensualEstimado = out.isrMensual
        imssMensualEstimado = out.imssMensual
        cuotaObrera = out.cuotaObrera
        cuotaPatronal = out.cuotaPatronal
        sueldoNetoMensual = out.sueldoNeto
        costoRealMensual = out.costoReal
        costoHora = out.costoHora
        horasSemanalesRequeridas = out.horasSemanales
        manoDeObraSugerida = out.manoDeObraSugerida
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

// Selector de días (1=Dom ... 7=Sáb)
fileprivate struct DaysSelector: View {
    @Binding var selected: Set<Int>
    private let days: [(Int, String)] = [
        (1, "D"), (2, "L"), (3, "M"), (4, "M"), (5, "J"), (6, "V"), (7, "S")
    ]
    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.0) { (value, label) in
                let isOn = selected.contains(value)
                Button {
                    if isOn { selected.remove(value) } else { selected.insert(value) }
                } label: {
                    Text(label)
                        .font(.headline)
                        .frame(width: 28, height: 28)
                        .background(isOn ? Color("MercedesPetrolGreen") : Color("MercedesBackground"))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(weekdayName(value))
            }
        }
    }
    private func weekdayName(_ v: Int) -> String {
        switch v {
        case 1: return "Domingo"
        case 2: return "Lunes"
        case 3: return "Martes"
        case 4: return "Miércoles"
        case 5: return "Jueves"
        case 6: return "Viernes"
        case 7: return "Sábado"
        default: return ""
        }
    }
}

// Grid de campos automáticos
fileprivate struct AutoPayrollGrid: View {
    var salarioDiario: Double
    var sbc: Double
    var isrMensual: Double
    var imssMensual: Double
    var cuotaObrera: Double
    var cuotaPatronal: Double
    var sueldoNetoMensual: Double
    var costoRealMensual: Double
    var costoHora: Double
    var horasSemanalesRequeridas: Double
    var manoDeObraSugerida: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 8) {
                roField("Salario diario", salarioDiario)
                roField("SBC", sbc)
                roField("ISR aprox. (mensual)", isrMensual)
                roField("IMSS aprox. (mensual)", imssMensual)
                roField("Cuota obrera", cuotaObrera)
                roField("Cuota patronal", cuotaPatronal)
                roField("Sueldo neto mensual", sueldoNetoMensual)
                roField("Costo real mensual", costoRealMensual)
                roField("Costo por hora", costoHora)
                roField("Horas semanales requeridas", horasSemanalesRequeridas)
                roField("Mano de obra sugerida", manoDeObraSugerida)
            }
        }
    }
    private func roField(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundColor(.gray)
            Text(value.formatted(.number.precision(.fractionLength(2))))
                .font(.headline)
                .foregroundColor(.white)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("MercedesBackground").opacity(0.6))
                .cornerRadius(8)
        }
    }
}

// Barra de asistencia simplificada
fileprivate struct AssistToolbar: View {
    @Binding var estado: EstadoEmpleado
    @Binding var asistenciaBloqueada: Bool
    var onMarcarAusencia: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button {
                if !asistenciaBloqueada { estado = .disponible }
            } label: { Label("INICIAR JORNADA", systemImage: "play.circle.fill") }
            .buttonStyle(.plain)
            .padding(8).background(Color("MercedesBackground")).cornerRadius(8)
            .foregroundColor(asistenciaBloqueada ? .gray : Color("MercedesPetrolGreen"))
            .disabled(asistenciaBloqueada)
            
            Button {
                if !asistenciaBloqueada { estado = .descanso }
            } label: { Label("PAUSA / COMIDA", systemImage: "pause.circle.fill") }
            .buttonStyle(.plain)
            .padding(8).background(Color("MercedesBackground")).cornerRadius(8)
            .foregroundColor(asistenciaBloqueada ? .gray : .yellow)
            .disabled(asistenciaBloqueada)
            
            Button {
                if !asistenciaBloqueada { estado = .ocupado }
            } label: { Label("OCUPADO / SALIDA", systemImage: "wrench.and.screwdriver") }
            .buttonStyle(.plain)
            .padding(8).background(Color("MercedesBackground")).cornerRadius(8)
            .foregroundColor(asistenciaBloqueada ? .gray : .orange)
            .disabled(asistenciaBloqueada)
            
            Button {
                if !asistenciaBloqueada { estado = .disponible }
            } label: { Label("REANUDAR", systemImage: "arrow.clockwise.circle.fill") }
            .buttonStyle(.plain)
            .padding(8).background(Color("MercedesBackground")).cornerRadius(8)
            .foregroundColor(asistenciaBloqueada ? .gray : .green)
            .disabled(asistenciaBloqueada)
            
            Button {
                if !asistenciaBloqueada { estado = .descanso }
            } label: { Label("FIN JORNADA", systemImage: "stop.circle.fill") }
            .buttonStyle(.plain)
            .padding(8).background(Color("MercedesBackground")).cornerRadius(8)
            .foregroundColor(asistenciaBloqueada ? .gray : .red)
            .disabled(asistenciaBloqueada)
            
            Spacer()
            
            Button {
                onMarcarAusencia()
            } label: {
                Label("Marcar AUSENCIA (supervisor)", systemImage: "lock.shield")
            }
            .buttonStyle(.plain)
            .padding(8)
            .background(Color.red.opacity(0.2))
            .cornerRadius(8)
            .foregroundColor(.red)
        }
        .font(.caption)
    }
}

// --- RFC Validator (estricto básico con homoclave) ---
fileprivate enum RFCValidator {
    // Persona moral: 12; Persona física: 13
    // Estructura: 3-4 letras + fecha (YYMMDD) + homoclave (3 alfanum)
    static func isValidRFC(_ rfc: String) -> Bool {
        let trimmed = rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard (12...13).contains(trimmed.count) else { return false }
        // Regex amplia común en MX
        // Personas morales: ^[A-Z&Ñ]{3}\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])[A-Z0-9]{3}$
        // Personas físicas: ^[A-Z&Ñ]{4}\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])[A-Z0-9]{2}[A0-9]$
        let moral = #"^[A-Z&Ñ]{3}\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])[A-Z0-9]{3}$"#
        let fisica = #"^[A-Z&Ñ]{4}\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])[A-Z0-9]{3}$"#
        let moralPred = NSPredicate(format: "SELF MATCHES %@", moral)
        let fisicaPred = NSPredicate(format: "SELF MATCHES %@", fisica)
        return moralPred.evaluate(with: trimmed) || fisicaPred.evaluate(with: trimmed)
    }
}

// --- PayrollCalculatorLite (aproximado) ---
fileprivate struct PayrollCalculatorLite {
    struct Output {
        let salarioDiario: Double
        let sbc: Double
        let isrMensual: Double
        let imssMensual: Double
        let cuotaObrera: Double
        let cuotaPatronal: Double
        let sueldoNeto: Double
        let costoReal: Double
        let costoHora: Double
        let horasSemanales: Double
        let manoDeObraSugerida: Double
    }
    static func calculate(sueldoMensualBruto: Double, salarioMinimo: Double, prestacionesMinimas: Bool, tipoSalario: TipoSalario) -> Output {
        // Suposiciones simples: 30.4 días/mes, 48h/semana
        let diasMes = 30.4
        let horasSemanales = 48.0
        let salarioDiario = max(salarioMinimo, sueldoMensualBruto / diasMes)
        
        // SBC aproximado: salario diario * factor prestaciones mínimas (ej. 1.0452)
        let factorPrest = prestacionesMinimas ? 1.0452 : 1.0
        let sbc = salarioDiario * factorPrest
        
        // ISR aproximado muy simplificado: 10% sobre excedente de 1 SM (placeholder)
        let isr = max(0, (sueldoMensualBruto - (salarioMinimo * diasMes))) * 0.10
        
        // IMSS aproximado (salud/guarderías) muy simplificado (placeholder)
        let imssTrabajador = sueldoMensualBruto * 0.02
        let imssPatron = sueldoMensualBruto * 0.05
        let imssTotal = imssTrabajador + imssPatron
        
        let cuotaObrera = imssTrabajador
        let cuotaPatronal = imssPatron
        
        let sueldoNeto = max(0, sueldoMensualBruto - isr - cuotaObrera)
        let costoReal = sueldoMensualBruto + cuotaPatronal // sin otras cargas
        
        let horasMes = horasSemanales * 4.0
        let costoHora = horasMes > 0 ? (costoReal / horasMes) : 0
        
        // Mano de obra sugerida: aplicar markup 2.2x como referencia (placeholder)
        let manoObraSugerida = costoHora * 2.2
        
        return Output(
            salarioDiario: salarioDiario,
            sbc: sbc,
            isrMensual: max(0, isr),
            imssMensual: imssTotal,
            cuotaObrera: cuotaObrera,
            cuotaPatronal: cuotaPatronal,
            sueldoNeto: sueldoNeto,
            costoReal: costoReal,
            costoHora: costoHora,
            horasSemanales: horasSemanales,
            manoDeObraSugerida: manoObraSugerida
        )
    }
}
