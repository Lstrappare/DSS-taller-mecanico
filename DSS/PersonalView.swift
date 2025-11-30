// the entire code of the file with your changes goes here.
// Do not skip over anything.
import SwiftUI
import SwiftData
import LocalAuthentication
import UniformTypeIdentifiers

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
    @State private var incluirDadosDeBaja: Bool = false
    
    // Ordenamiento (en línea con InventarioView)
    enum SortOption: String, CaseIterable, Identifiable {
        case nombre = "Nombre"
        case rol = "Rol"
        case estado = "Estado"
        var id: String { rawValue }
    }
    @State private var sortOption: SortOption = .nombre
    @State private var sortAscending: Bool = true
    
    var filteredPersonal: [Personal] {
        var base = personal
        
        if incluirDadosDeBaja == false {
            base = base.filter { $0.activo }
        }
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
        if let filtroRol { base = base.filter { $0.rol == filtroRol } }
        if let filtroEstado { base = base.filter { $0.estado == filtroEstado } }
        
        base.sort { a, b in
            switch sortOption {
            case .nombre:
                let cmp = a.nombre.localizedCaseInsensitiveCompare(b.nombre)
                return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
            case .rol:
                let cmp = a.rol.rawValue.localizedCaseInsensitiveCompare(b.rol.rawValue)
                return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
            case .estado:
                let cmp = a.estado.rawValue.localizedCaseInsensitiveCompare(b.estado.rawValue)
                return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
            }
        }
        return base
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            filtrosView
            ScrollView {
                LazyVStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .foregroundColor(Color("MercedesPetrolGreen"))
                        Text("\(filteredPersonal.count) resultado\(filteredPersonal.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    if filteredPersonal.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    } else {
                        ForEach(filteredPersonal) { mecanico in
                            PersonalCard(mecanico: mecanico) {
                                modalMode = .edit(mecanico)
                            }
                            .onTapGesture { modalMode = .edit(mecanico) }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            LinearGradient(colors: [Color("MercedesBackground"), Color("MercedesBackground").opacity(0.9)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .sheet(item: $modalMode) { incomingMode in
            PersonalFormView(mode: incomingMode)
                .environment(\.modelContext, modelContext)
        }
    }
    
    private var header: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color("MercedesCard"), Color("MercedesBackground").opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                .frame(height: 110)
            
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gestión de Personal")
                        .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    HStack(spacing: 10) {
                        Label("\(personal.count) empleado\(personal.count == 1 ? "" : "s")", systemImage: "person.2.fill")
                            .font(.footnote).foregroundColor(.gray)
                        let disponibles = personal.filter { $0.activo && $0.estado == .disponible && $0.estaEnHorario }.count
                        Label("\(disponibles) disponibles ahora", systemImage: "checkmark.seal.fill")
                            .font(.footnote).foregroundColor(.gray)
                    }
                }
                Spacer()
                Button {
                    modalMode = .add
                } label: {
                    Label("Añadir", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("Registrar nuevo empleado")
            }
            .padding(.horizontal, 12)
        }
    }
    
    private var filtrosView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    TextField("Buscar por Nombre, RFC, CURP, Rol o Especialidad...", text: $searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.subheadline)
                        .animation(.easeInOut(duration: 0.15), value: searchQuery)
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                        .help("Limpiar búsqueda")
                    }
                }
                .padding(8)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                
                HStack(spacing: 6) {
                    Picker("Ordenar", selection: $sortOption) {
                        ForEach(SortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 140)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            sortAscending.toggle()
                        }
                    } label: {
                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                            .font(.subheadline)
                            .padding(6)
                            .background(Color("MercedesCard"))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Cambiar orden \(sortAscending ? "ascendente" : "descendente")")
                }
                
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
                .frame(maxWidth: 220)
                .help("Filtrar por rol")
                
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
                .frame(maxWidth: 240)
                .help("Filtrar por estado")
                
                Toggle(isOn: $incluirDadosDeBaja) {
                    Text("Incluir dados de baja")
                }
                .toggleStyle(.switch)
                .help("Muestra también a los empleados dados de baja")
                
                if filtroRol != nil || filtroEstado != nil || !searchQuery.isEmpty || incluirDadosDeBaja {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("Filtros activos")
                        if let r = filtroRol {
                            Text("Rol: \(r.rawValue)")
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color("MercedesBackground")).cornerRadius(6)
                        }
                        if let e = filtroEstado {
                            Text("Estado: \(e.rawValue)")
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color("MercedesBackground")).cornerRadius(6)
                        }
                        if incluirDadosDeBaja {
                            Text("Incluye de baja")
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color("MercedesBackground")).cornerRadius(6)
                        }
                        if !searchQuery.isEmpty {
                            Text("“\(searchQuery)”")
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color("MercedesBackground")).cornerRadius(6)
                        }
                        Button {
                            withAnimation {
                                filtroRol = nil
                                filtroEstado = nil
                                searchQuery = ""
                                incluirDadosDeBaja = false
                            }
                        } label: {
                            Text("Limpiar")
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .background(Color("MercedesCard"))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.gray)
                        .help("Quitar filtros activos")
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                }
                
                Spacer()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(Color("MercedesPetrolGreen"))
            Text(searchQuery.isEmpty ? "No hay personal registrado aún." :
                 "No se encontraron empleados para “\(searchQuery)”.")
                .font(.subheadline)
                .foregroundColor(.gray)
            if searchQuery.isEmpty {
                Text("Añade tu primer empleado para comenzar a asignar servicios.")
                    .font(.caption2)
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
    
    // Estado efectivo del día: si hay bloqueo hoy o asistencia ausente, mostrar como Ausente/Fuera de Turno
    private var estaBloqueadoHoy: Bool {
        if let f = mecanico.bloqueoAsistenciaFecha {
            return Calendar.current.isDateInToday(f)
        }
        return false
    }
    private var estadoOperativoTexto: String {
        if mecanico.esFuturoIngreso { return "Futuro Ingreso" }
        if !mecanico.estaEnHorario { return "Fuera de Turno" }
        if estaBloqueadoHoy { return "Ausente (bloqueado hoy)" }
        return mecanico.estado.rawValue
    }
    private var estadoOperativoColor: Color {
        if mecanico.esFuturoIngreso { return .indigo }
        if !mecanico.estaEnHorario { return .gray }
        if estaBloqueadoHoy { return .gray }
        return estadoColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                            .font(.headline).fontWeight(.semibold)
                        if !mecanico.activo {
                            Text("De baja")
                                .font(.caption2)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .cornerRadius(6)
                        }
                        Spacer()
                        if mecanico.esFuturoIngreso {
                            Text("Futuro Ingreso")
                                .font(.caption2)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.indigo.opacity(0.18))
                                .foregroundColor(.indigo)
                                .cornerRadius(6)
                        } else {
                            Text(estadoOperativoTexto)
                                .font(.caption2)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(estadoOperativoColor.opacity(0.18))
                                .foregroundColor(estadoOperativoColor)
                                .cornerRadius(6)
                        }
                        Button {
                            onEdit()
                        } label: {
                            Label("Editar", systemImage: "pencil")
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(Color("MercedesBackground"))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 8) {
                        chip(text: mecanico.rol.rawValue, icon: "person.badge.shield.checkmark.fill")
                        Text("Turno: \(mecanico.horaEntrada) - \(mecanico.horaSalida)")
                            .font(.caption2).foregroundColor(.gray)
                        chip(text: "Comisiones: $\(mecanico.comisiones, default: "%.2f")", icon: "dollarsign.circle.fill")
                    }
                    if !mecanico.activo, let f = mecanico.fechaBaja {
                        Text("Fecha de baja: \(f.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            HStack(spacing: 12) {
                if mecanico.email.isEmpty || !mecanico.activo {
                    Label(mecanico.email.isEmpty ? "Email: N/A" : mecanico.email, systemImage: "envelope.fill")
                        .font(.caption2)
                        .foregroundColor(.gray)
                } else {
                    Link(destination: URL(string: "mailto:\(mecanico.email)")!) {
                        Label(mecanico.email, systemImage: "envelope.fill")
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                }
                
                if mecanico.telefonoActivo && !mecanico.telefono.isEmpty && mecanico.activo {
                    Link(destination: URL(string: "tel:\(mecanico.telefono)")!) {
                        Label(mecanico.telefono, systemImage: "phone.fill")
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                } else {
                    Label("Tel: N/A", systemImage: "phone.fill")
                        .font(.caption2).foregroundColor(.gray)
                }
                
                Spacer()
                Text("RFC: \(mecanico.rfc)")
                    .font(.caption2).foregroundColor(.gray)
            }
            
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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Color("MercedesCard")
                LinearGradient(colors: [Color.white.opacity(0.012), Color("MercedesBackground").opacity(0.06)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        )
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
        .opacity(mecanico.activo ? 1.0 : 0.85)
    }
    
    private func chip(text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color("MercedesBackground"))
        .cornerRadius(6)
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
    
    // Trabajo (UI opcional en "add" para forzar selección)
    @State private var rol: Rol = .ayudante
    @State private var rolSeleccion: Rol? = nil
    @State private var especialidadesString = ""
    @State private var fechaIngreso = Date()
    @State private var tipoContrato: TipoContrato = .indefinido
    @State private var tipoContratoSeleccion: TipoContrato? = nil
    @State private var horaEntradaString = ""
    @State private var horaSalidaString = ""
    @State private var diasLaborales: Set<Int> = [] // vacío en "add" para obligar selección
    
    // Alta/Baja
    @State private var activo: Bool = true
    @State private var fechaBaja: Date? = nil
    
    // Nómina (configuración)
    @State private var prestacionesMinimas = true
    @State private var tipoSalario: TipoSalario = .minimo
    @State private var tipoSalarioSeleccion: TipoSalario? = nil
    @State private var frecuenciaPago: FrecuenciaPago = .quincena
    @State private var frecuenciaPagoSeleccion: FrecuenciaPago? = nil
    @State private var salarioMinimoReferenciaString = "248.93"
    @State private var comisionesString = "0.00"
    @State private var factorIntegracionString = "1.0452"
    
    // Documentación (archivos)
    @State private var ineAdjuntoPath = ""
    @State private var comprobanteDomicilioPath = ""
    @State private var comprobanteEstudiosPath = ""
    
    // Estado operacional
    @State private var estado: EstadoEmpleado = .disponible
    @State private var estadoSeleccion: EstadoEmpleado? = nil
    
    // Bloqueos/Seguridad
    @State private var isRFCUnlocked = false
    @State private var showingAuthModal = false
    @State private var showingStatusAlert = false
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
    @State private var horasSemanalesRequeridas: Double = 0
    @State private var manoDeObraSugerida: Double = 0
    
    // Asistencia UI state (simple)
    @State private var estadoAsistenciaHoy: EstadoAsistencia = .incompleto
    @State private var asistenciaBloqueada = false
    
    // Gestión de carpeta temporal para alta sin RFC válido aún
    @State private var tempFolderID: String? = nil
    
    // Opción B: confirmación para aplicar a todos
    @State private var pendingApplyAllSMI: Double?
    @State private var pendingApplyAllFactor: Double?
    @State private var showingApplyAllAlert: Bool = false
    @State private var postApplyAllAction: (() -> Void)? = nil
    
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
            _horaEntradaString = State(initialValue: "\(personal.horaEntrada)")
            _horaSalidaString = State(initialValue: "\(personal.horaSalida)")
            _diasLaborales = State(initialValue: Set(personal.diasLaborales))
            
            _activo = State(initialValue: personal.activo)
            _fechaBaja = State(initialValue: personal.fechaBaja)
            
            _prestacionesMinimas = State(initialValue: personal.prestacionesMinimas)
            let ts: TipoSalario = personal.tipoSalario
            _tipoSalario = State(initialValue: ts)
            _frecuenciaPago = State(initialValue: personal.frecuenciaPago)
            _salarioMinimoReferenciaString = State(initialValue: String(format: "%.2f", personal.salarioMinimoReferencia))
            _comisionesString = State(initialValue: String(format: "%.2f", personal.comisiones))
            _factorIntegracionString = State(initialValue: String(format: "%.4f", personal.factorIntegracion))
            
            _ineAdjuntoPath = State(initialValue: personal.ineAdjuntoPath ?? "")
            _comprobanteDomicilioPath = State(initialValue: personal.comprobanteDomicilioPath ?? "")
            _comprobanteEstudiosPath = State(initialValue: personal.comprobanteEstudiosPath ?? "")
            
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
    private var nombreValidationMessage: String? {
        validateNombreCompleto(nombre)
    }
    private var nombreInvalido: Bool { nombreValidationMessage != nil }
    private var emailInvalido: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let regex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        let pred = NSPredicate(format: "SELF MATCHES[c] %@", regex)
        return trimmed.isEmpty || !pred.evaluate(with: trimmed)
    }
    private var rfcInvalido: Bool {
        !RFCValidator.isValidRFC(rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
    }
    private var curpInvalido: Bool {
        let trimmed = curp.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        return !CURPValidator.isValidCURP(trimmed)
    }
    // NUEVO: Validación diurna y 8 horas exactas (requiere que ambos campos no estén vacíos)
    private var horasInvalidas: Bool {
        guard let he = Int(horaEntradaString), let hs = Int(horaSalidaString) else { return true }
        guard (6...20).contains(he), (6...20).contains(hs) else { return true }
        return hs - he != 8
    }
    private var salarioMinimoInvalido: Bool {
        Double(salarioMinimoReferenciaString.replacingOccurrences(of: ",", with: ".")) == nil
    }
    private var comisionesInvalidas: Bool {
        Double(comisionesString.replacingOccurrences(of: ",", with: ".")) == nil
    }
    private var factorIntegracionInvalido: Bool {
        Double(factorIntegracionString.replacingOccurrences(of: ",", with: ".")) == nil || (Double(factorIntegracionString.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0
    }
    private var sinDiasLaborales: Bool { diasLaborales.isEmpty }
    // NUEVO: Máximo 6 días laborables
    private var diasExcedenLimite: Bool { diasLaborales.count > 6 }
    private var telefonoInvalido: Bool {
        if !telefonoActivo { return false }
        let trimmed = telefono.trimmingCharacters(in: .whitespacesAndNewlines)
        let regex = #"^\d{10}$"#
        let pred = NSPredicate(format: "SELF MATCHES %@", regex)
        return !pred.evaluate(with: trimmed)
    }
    private var diasPromedio: Double {
        switch frecuenciaPago {
        case .quincena: return 15.0
        case .mes: return 30.4
        }
    }
    // NUEVO: Validaciones de selección obligatoria cuando se está añadiendo
    private var rolNoSeleccionado: Bool {
        if mecanicoAEditar != nil { return false }
        return rolSeleccion == nil
    }
    private var tipoContratoNoSeleccionado: Bool {
        if mecanicoAEditar != nil { return false }
        return tipoContratoSeleccion == nil
    }
    private var estadoNoSeleccionado: Bool {
        // Eliminado el uso, pero lo dejamos false para compatibilidad del botón
        false
    }
    private var frecuenciaPagoNoSeleccionada: Bool {
        if mecanicoAEditar != nil { return false }
        return frecuenciaPagoSeleccion == nil
    }
    private var tipoSalarioNoSeleccionado: Bool {
        if mecanicoAEditar != nil { return false }
        return tipoSalarioSeleccion == nil
    }
    
    // Helpers de asistencia/estado del día
    private var hoy: Date { Calendar.current.startOfDay(for: Date()) }
    private var estaBloqueadoHoy: Bool {
        if let f = mecanicoAEditar?.bloqueoAsistenciaFecha {
            return Calendar.current.isDate(f, inSameDayAs: hoy)
        }
        return false
    }
    private var yaAusenteHoy: Bool {
        guard let empleado = mecanicoAEditar else { return false }
        let registro = empleado.asistencias.first { Calendar.current.isDate($0.fecha, inSameDayAs: hoy) }
        return registro?.estadoFinal == .ausente
    }
    private var puedeMostrarAsistencia: Bool {
        if case .add = mode { return false } // Ocultar en alta
        return true
    }
    private var puedeMarcarAusencia: Bool {
        // Solo en edición, si no está ya ausente ni bloqueado hoy
        guard mecanicoAEditar != nil else { return false }
        return !yaAusenteHoy && !estaBloqueadoHoy
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(formTitle)
                    .font(.title).fontWeight(.bold)
                Text("Completa los datos. Los campos marcados con '•' son obligatorios.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                Text("Turno diurno obligatorio (06:00–20:00) y jornada de 8 horas exactas.")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.9))
            }
            .padding(16)

            ScrollView {
                VStack(spacing: 24) {
                    
                    // 1. Identificación y Contacto
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "1. Identificación y Contacto", subtitle: "Datos básicos")
                        FormField(title: "• Nombre completo", placeholder: "ej. José Cisneros Torres", text: $nombre)
                            .validationHint(isInvalid: nombreInvalido, message: nombreValidationMessage ?? "")
                        HStack(spacing: 16) {
                            FormField(title: "• Correo electrónico", placeholder: "ej. jose@taller.com", text: $email)
                                .validationHint(isInvalid: emailInvalido, message: "Ingresa un correo válido.")
                            VStack(alignment: .leading, spacing: 2) {
                                FormField(title: "Teléfono (10 dígitos)", placeholder: "ej. 5512345678", text: $telefono)
                                    .disabled(!telefonoActivo)
                                    .opacity(telefonoActivo ? 1.0 : 0.6)
                                    .validationHint(isInvalid: telefonoInvalido, message: "Debe tener 10 dígitos.")
                                Toggle("Teléfono activo", isOn: $telefonoActivo)
                                    .toggleStyle(.switch)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // 2. Identificadores
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "2. Identificadores Oficiales", subtitle: "RFC y CURP")
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
                                        .textFieldStyle(.plain)
                                        .padding(10)
                                        .frame(maxWidth: .infinity)
                                        .background(Color("MercedesBackground"))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                    if rfc.isEmpty {
                                        Text("13 caracteres (física) o 12 (moral)")
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
                            .validationHint(isInvalid: curpInvalido, message: "CURP inválida. Verifica formato y dígito verificador.")
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // 3. Puesto
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "3. Puesto", subtitle: "Rol y fecha de ingreso")
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("• Rol").font(.caption2).foregroundColor(.gray)
                                if mecanicoAEditar == nil {
                                    Picker("", selection: Binding(
                                        get: { rolSeleccion as Rol? },
                                        set: { rolSeleccion = $0 }
                                    )) {
                                        Text("Selecciona un rol…").tag(Rol?.none)
                                        ForEach(Rol.allCases, id: \.self) { Text($0.rawValue).tag(Rol?.some($0)) }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity)
                                    .padding(4)
                                    .background(Color("MercedesBackground").opacity(0.9))
                                    .cornerRadius(8)
                                    .validationHint(isInvalid: rolNoSeleccionado, message: "Debes seleccionar un rol.")
                                } else {
                                    Picker("", selection: $rol) {
                                        ForEach(Rol.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity)
                                    .padding(4)
                                    .background(Color("MercedesBackground").opacity(0.9))
                                    .cornerRadius(8)
                                }
                            }
                            FormField(title: "Especialidades (coma separadas)", placeholder: "Motor, Frenos...", text: $especialidadesString)
                                .help("Ejemplo: Motor, Frenos. Se guardarán con mayúscula inicial.")
                        }
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("• Fecha de ingreso").font(.caption2).foregroundColor(.gray)
                                DatePicker("", selection: $fechaIngreso, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("• Tipo de contrato").font(.caption2).foregroundColor(.gray)
                                if mecanicoAEditar == nil {
                                    Picker("", selection: Binding(
                                        get: { tipoContratoSeleccion as TipoContrato? },
                                        set: { tipoContratoSeleccion = $0 }
                                    )) {
                                        Text("Selecciona un contrato…").tag(TipoContrato?.none)
                                        ForEach(TipoContrato.allCases, id: \.self) { Text($0.rawValue).tag(TipoContrato?.some($0)) }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity)
                                    .padding(4)
                                    .background(Color("MercedesBackground").opacity(0.9))
                                    .cornerRadius(8)
                                    .validationHint(isInvalid: tipoContratoNoSeleccionado, message: "Debes seleccionar un tipo de contrato.")
                                } else {
                                    Picker("", selection: $tipoContrato) {
                                        ForEach(TipoContrato.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity)
                                    .padding(4)
                                    .background(Color("MercedesBackground").opacity(0.9))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // 4. Horario
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "4. Horario Laboral", subtitle: "Días y horas (diurno 06–20, jornada de 8 h)")
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• Días laborables").font(.caption).foregroundColor(.gray)
                            DaysSelector(selected: $diasLaborales)
                                .padding(8)
                                .background(Color("MercedesBackground"))
                                .cornerRadius(8)
                                .validationHint(
                                    isInvalid: sinDiasLaborales || diasExcedenLimite,
                                    message: sinDiasLaborales
                                    ? "Selecciona al menos un día."
                                    : "Por ley, solo se permiten hasta 6 días laborables por semana."
                                )
                        }
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                FormField(title: "• Entrada (06–20 h)", placeholder: "ej. 9", text: $horaEntradaString)
                                    .validationHint(isInvalid: horasInvalidas, message: "Turno diurno: 06–20 y duración exacta de 8 horas.")
                                Text("Formato 24 horas. Ejemplos válidos: 06–14, 07–15, 12–20.")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                FormField(title: "• Salida (06–20 h)", placeholder: "ej. 17", text: $horaSalidaString)
                                    .validationHint(isInvalid: horasInvalidas, message: "Turno diurno: 06–20 y duración exacta de 8 horas.")
                                Text("Salida = Entrada + 8. No se permiten turnos nocturnos.")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // 5. Nómina
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "5. Nómina", subtitle: "Parámetros y vista previa")
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("• Tipo de salario").font(.caption2).foregroundColor(.gray)
                                if mecanicoAEditar == nil {
                                    Picker("", selection: Binding(
                                        get: { tipoSalarioSeleccion as TipoSalario? },
                                        set: { tipoSalarioSeleccion = $0 }
                                    )) {
                                        Text("Selecciona tipo…").tag(TipoSalario?.none)
                                        ForEach(TipoSalario.allCases, id: \.self) { Text($0.rawValue).tag(TipoSalario?.some($0)) }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity)
                                    .padding(4)
                                    .background(Color("MercedesBackground").opacity(0.9))
                                    .cornerRadius(8)
                                    .validationHint(isInvalid: tipoSalarioNoSeleccionado, message: "Debes seleccionar el tipo de salario (Mínimo o Mixto).")
                                } else {
                                    Picker("", selection: $tipoSalario) {
                                        ForEach(TipoSalario.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity)
                                    .padding(4)
                                    .background(Color("MercedesBackground").opacity(0.9))
                                    .cornerRadius(8)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("• Frecuencia de pago").font(.caption2).foregroundColor(.gray)
                                if mecanicoAEditar == nil {
                                    Picker("", selection: Binding(
                                        get: { frecuenciaPagoSeleccion as FrecuenciaPago? },
                                        set: { frecuenciaPagoSeleccion = $0 }
                                    )) {
                                        Text("Selecciona frecuencia…").tag(FrecuenciaPago?.none)
                                        ForEach(FrecuenciaPago.allCases, id: \.self) { Text($0.rawValue).tag(FrecuenciaPago?.some($0)) }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity)
                                    .padding(4)
                                    .background(Color("MercedesBackground").opacity(0.9))
                                    .cornerRadius(8)
                                    .validationHint(isInvalid: frecuenciaPagoNoSeleccionada, message: "Debes seleccionar la frecuencia de pago.")
                                } else {
                                    Picker("", selection: $frecuenciaPago) {
                                        ForEach(FrecuenciaPago.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity)
                                    .padding(4)
                                    .background(Color("MercedesBackground").opacity(0.9))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                FormField(title: "• Salario mínimo de referencia", placeholder: "ej. 248.93", text: $salarioMinimoReferenciaString)
                                    .validationHint(isInvalid: salarioMinimoInvalido, message: "Número válido.")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Este valor se puede modificar si no coincide con el vigente.")
                                        .font(.caption2).foregroundColor(.gray)
                                    Link("Consultar salario mínimo vigente (CONASAMI)",
                                         destination: URL(string: "https://www.gob.mx/conasami/documentos/tabla-de-salarios-minimos-generales-y-profesionales-por-areas-geograficas?idiom=es")!)
                                        .font(.caption2)
                                        .foregroundColor(Color("MercedesPetrolGreen"))
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                FormField(title: "• Factor de integración", placeholder: "ej. 1.0452", text: $factorIntegracionString)
                                    .validationHint(isInvalid: factorIntegracionInvalido, message: "Debe ser > 0.")
                                Text("Para SBC.")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        HStack(spacing: 16) {
                            Toggle("Prestaciones mínimas", isOn: $prestacionesMinimas)
                                .toggleStyle(.switch)
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Spacer()
                            if (mecanicoAEditar == nil ? (tipoSalarioSeleccion == .mixto) : (tipoSalario == .mixto)) {
                                FormField(title: "• Comisiones acumuladas", placeholder: "0.00", text: $comisionesString)
                                    .frame(width: 180)
                                    .validationHint(isInvalid: comisionesInvalidas, message: "Número válido.")
                            } else {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Comisiones (solo lectura)").font(.caption2).foregroundColor(.gray)
                                    Text(String(format: "$%.2f", Double(comisionesString.replacingOccurrences(of: ",", with: ".")) ?? 0))
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                    
                    // 6. Vista previa
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Vista previa de nómina")
                                .font(.headline)
                                .foregroundColor(Color("MercedesPetrolGreen"))
                            Spacer()
                            Button {
                                recalcularNominaPreview()
                            } label: {
                                Label("Recalcular", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
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
                        Text("Cálculos aproximados. Verificar ISR con tablas oficiales del SAT.")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(16)
                    .background(Color("MercedesBackground").opacity(0.3))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // 7. Documentación con Drag & Drop
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "7. Documentación (arrastra y suelta)", subtitle: "Se guardará en la carpeta de la app")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 10) {
                            DocumentDropField(
                                title: "INE (PDF/imagen/ZIP)",
                                currentPath: $ineAdjuntoPath,
                                rfcProvider: currentRFCForFiles,
                                suggestedFileName: "INE",
                                onDelete: { deleteCurrentFile(&ineAdjuntoPath) },
                                onReveal: { revealInFinder(ineAdjuntoPath) },
                                onDroppedAndSaved: { newPath in ineAdjuntoPath = newPath }
                            )
                            DocumentDropField(
                                title: "Comprobante de domicilio",
                                currentPath: $comprobanteDomicilioPath,
                                rfcProvider: currentRFCForFiles,
                                suggestedFileName: "Domicilio",
                                onDelete: { deleteCurrentFile(&comprobanteDomicilioPath) },
                                onReveal: { revealInFinder(comprobanteDomicilioPath) },
                                onDroppedAndSaved: { newPath in comprobanteDomicilioPath = newPath }
                            )
                            DocumentDropField(
                                title: "Comprobante de estudios",
                                currentPath: $comprobanteEstudiosPath,
                                rfcProvider: currentRFCForFiles,
                                suggestedFileName: "Estudios",
                                onDelete: { deleteCurrentFile(&comprobanteEstudiosPath) },
                                onReveal: { revealInFinder(comprobanteEstudiosPath) },
                                onDroppedAndSaved: { newPath in comprobanteEstudiosPath = newPath }
                            )
                        }
                        Text("Arrastra archivos aquí. Se copiarán a Application Support/MercedesTaller/Personal/<RFC>/")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // 8. Asistencia
                    if puedeMostrarAsistencia {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "8. Asistencia", subtitle: "Acciones rápidas")
                            AssistToolbar(
                                estado: $estado,
                                asistenciaBloqueada: $asistenciaBloqueada,
                                onMarcarAusencia: {
                                    authReason = .markAbsence
                                    showingAuthModal = true
                                }
                            )
                            .opacity(puedeMarcarAusencia ? 1.0 : 0.5)
                            .disabled(!puedeMarcarAusencia)
                            if !puedeMarcarAusencia {
                                Text(estaBloqueadoHoy || yaAusenteHoy ? "Ya se registró inasistencia hoy. No se puede repetir ni cambiar estado." : "")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    // 9. Estado actual (movido abajo y solo en edición)
                    if mecanicoAEditar != nil {
                        Divider().background(Color.gray.opacity(0.3))
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "Estado actual del empleado", subtitle: "Solo lectura")
                            HStack(spacing: 10) {
                                Text(activo ? "Activo" : "De baja")
                                    .font(.headline)
                                    .foregroundColor(activo ? .green : .red)
                                    .frame(width: 80, alignment: .leading)
                                
                                if !activo, let f = fechaBaja {
                                    Text("Desde: \(f.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption2).foregroundColor(.gray)
                                }
                                Spacer()
                                let estadoTexto: String = {
                                    if estaBloqueadoHoy { return "Ausente (bloqueado hoy)" }
                                    return estado.rawValue
                                }()
                                Text(estadoTexto)
                                    .font(.caption2)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color("MercedesBackground"))
                                    .cornerRadius(6)
                                    .overlay(
                                        Group {
                                            if estaBloqueadoHoy {
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.red.opacity(0.4), lineWidth: 1)
                                            }
                                        }
                                    )
                            }
                            if estaBloqueadoHoy {
                                Text("Bloqueado por inasistencia hoy. No se puede cambiar el estado hasta mañana.")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(10)
                        .background(Color("MercedesBackground").opacity(0.5))
                        .cornerRadius(8)
                    }
                    
                    // 10. Zona de Peligro
                    if case .edit = mode {
                        Divider().background(Color.red.opacity(0.3))
                        VStack(spacing: 12) {
                            Text("Esta acción no se puede deshacer y eliminará permanentemente al empleado.")
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                            
                            Button(role: .destructive) {
                                authReason = .deleteEmployee
                                showingAuthModal = true
                            } label: {
                                Label("Eliminar empleado permanentemente", systemImage: "trash.fill")
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 24)
                                    .background(Color.red.opacity(0.15))
                                    .foregroundColor(.red)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.red.opacity(0.5), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(24)
            }
            .onAppear { 
                // En "add", mantener salario por defecto pero obligar selecciones y campos vacíos
                if mecanicoAEditar == nil {
                    rolSeleccion = nil
                    tipoContratoSeleccion = nil
                    // estado inicial oculto en alta, no usar estadoSeleccion
                    estadoSeleccion = nil
                    tipoSalarioSeleccion = nil
                    frecuenciaPagoSeleccion = nil
                    diasLaborales = []
                    horaEntradaString = ""
                    horaSalidaString = ""
                }
                recalcularNominaPreview()
                ensureTempFolderIfNeeded()
            }
            .onChange(of: salarioMinimoReferenciaString) { _, _ in recalcularNominaPreview() }
            .onChange(of: prestacionesMinimas) { _, _ in recalcularNominaPreview() }
            .onChange(of: tipoSalario) { _, _ in recalcularNominaPreview() }
            .onChange(of: frecuenciaPago) { _, _ in recalcularNominaPreview() }
            .onChange(of: comisionesString) { _, _ in recalcularNominaPreview() }
            .onChange(of: factorIntegracionString) { _, _ in recalcularNominaPreview() }
            .onChange(of: nombre) { _, newValue in
                let limited = limitNameToMaxLetters(newValue, maxLetters: 21)
                if limited != newValue { nombre = limited }
            }
            
            if let errorMsg {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.vertical, 6)
            }
            
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text("Cancelar")
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color("MercedesBackground"))
                        .foregroundColor(.gray)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                if mecanicoAEditar != nil {
                    Button {
                        showingStatusAlert = true
                    } label: {
                        Text(activo ? "Dar de baja" : "Reactivar")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(activo ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                            .foregroundColor(activo ? .orange : .green)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(activo ? Color.orange.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .alert(activo ? "¿Dar de baja?" : "¿Reactivar?", isPresented: $showingStatusAlert) {
                        Button(activo ? "Dar de baja" : "Reactivar", role: .destructive) {
                            if activo {
                                activo = false
                                fechaBaja = Date()
                            } else {
                                activo = true
                                fechaBaja = nil
                                fechaIngreso = Date()
                            }
                        }
                        Button("Cancelar", role: .cancel) { }
                    } message: {
                        Text(activo
                             ? "No se borrarán sus datos; solo quedará inactivo. Podrás reactivarlo más adelante."
                             : "El empleado volverá a estar activo y se actualizará su fecha de ingreso.")
                    }
                }
                
                Spacer()
                
                Button {
                    // Opción B: si cambió salario mínimo o factor, pedir confirmación para aplicar a todos y luego guardar
                    prepararApplyAllYGuardar()
                } label: {
                    Text(mecanicoAEditar == nil ? "Guardar y añadir" : "Guardar cambios")
                        .fontWeight(.semibold)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .shadow(color: Color("MercedesPetrolGreen").opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(
                    nombreInvalido ||
                    emailInvalido ||
                    rfcInvalido ||
                    horasInvalidas ||
                    salarioMinimoInvalido ||
                    sinDiasLaborales ||
                    diasExcedenLimite || // NUEVO: no permitir más de 6 días
                    comisionesInvalidas ||
                    factorIntegracionInvalido ||
                    telefonoInvalido ||
                    curpInvalido ||
                    // Nuevas reglas de selección obligatoria en "add"
                    rolNoSeleccionado ||
                    tipoContratoNoSeleccionado ||
                    frecuenciaPagoNoSeleccionada ||
                    tipoSalarioNoSeleccionado
                )
                .opacity(
                    (nombreInvalido ||
                     emailInvalido ||
                     rfcInvalido ||
                     horasInvalidas ||
                     salarioMinimoInvalido ||
                     sinDiasLaborales ||
                     diasExcedenLimite || // NUEVO
                     comisionesInvalidas ||
                     factorIntegracionInvalido ||
                     telefonoInvalido ||
                     curpInvalido ||
                     rolNoSeleccionado ||
                     tipoContratoNoSeleccionado ||
                     frecuenciaPagoNoSeleccionada ||
                     tipoSalarioNoSeleccionado) ? 0.6 : 1.0
                )
            }
            .padding(20)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 800, minHeight: 600, maxHeight: 600)
        .cornerRadius(15)
        .sheet(isPresented: $showingAuthModal) {
            authModalView()
        }
        // Confirmación única para aplicar a todos (Opción B)
        .alert("Aplicar cambios a todos los empleados", isPresented: $showingApplyAllAlert) {
            Button("Aplicar a todos") {
                let newSMI = pendingApplyAllSMI
                let newFactor = pendingApplyAllFactor
                Task {
                    await applyToAllEmployees(newSMI: newSMI, newFactor: newFactor)
                    // Continuar con guardado real
                    postApplyAllAction?()
                }
            }
            Button("Solo a este", role: .cancel) {
                // Guardar sin aplicar global
                postApplyAllAction?()
            }
        } message: {
            let smiTxt = pendingApplyAllSMI.map { String(format: "%.2f", $0) }
            let facTxt = pendingApplyAllFactor.map { String(format: "%.4f", $0) }
            let parts: [String] = [
                smiTxt != nil ? "Salario mínimo: \(smiTxt!)" : nil,
                facTxt != nil ? "Factor de integración: \(facTxt!)" : nil
            ].compactMap { $0 }
            Text("Detectamos cambios en:\n\(parts.joined(separator: "\n"))\n¿Quieres aplicar estos valores a todos los empleados?")
        }
    }
    
    // MARK: - Gestión de Archivos
    
    private func currentRFCForFiles() -> String {
        // En edición, usar el RFC del registro; en alta, usar RFC válido del campo, si no, usar carpeta temporal.
        if let mec = mecanicoAEditar {
            return mec.rfc
        }
        let trimmedRFC = rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if RFCValidator.isValidRFC(trimmedRFC) {
            return trimmedRFC
        }
        if let temp = tempFolderID { return temp }
        let newTemp = "TEMP-\(UUID().uuidString)"
        tempFolderID = newTemp
        return newTemp
    }
    
    private func ensureTempFolderIfNeeded() {
        if mecanicoAEditar == nil, tempFolderID == nil, !RFCValidator.isValidRFC(rfc) {
            tempFolderID = "TEMP-\(UUID().uuidString)"
        }
    }
    
    private func revealInFinder(_ path: String) {
        guard !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }
    
    private func deleteCurrentFile(_ pathBinding: inout String) {
        let path = pathBinding
        guard !path.isEmpty else { return }
        do {
            try FileManager.default.removeItem(atPath: path)
            pathBinding = ""
        } catch {
            print("No se pudo borrar el archivo: \(error)")
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
    
    // Guardar con Opción B (aplicar a todos si procede)
    private func prepararApplyAllYGuardar() {
        errorMsg = nil
        
        // Parse valores nuevos
        let newSMI = Double(salarioMinimoReferenciaString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let newFactor = Double(factorIntegracionString.replacingOccurrences(of: ",", with: ".")) ?? 0
        
        // Valores actuales (para comparación simple)
        let currentSMI = mecanicoAEditar?.salarioMinimoReferencia
        let currentFactor = mecanicoAEditar?.factorIntegracion
        
        var willAsk = false
        var smiToApply: Double?
        var factorToApply: Double?
        
        // Regla: si en el formulario hay un valor distinto al del empleado que editas (o si estás creando),
        // proponemos aplicarlo globalmente.
        if mecanicoAEditar == nil {
            // En alta, si el SMI difiere del promedio (o del PayrollSettings si lo usas), proponemos.
            smiToApply = newSMI
            factorToApply = newFactor
            willAsk = true
        } else {
            if let currentSMI, abs(currentSMI - newSMI) > 0.0001 {
                smiToApply = newSMI
                willAsk = true
            }
            if let currentFactor, abs(currentFactor - newFactor) > 0.0001 {
                factorToApply = newFactor
                willAsk = true
            }
        }
        
        // Acción real de guardado
        postApplyAllAction = { guardarCambios() }
        
        if willAsk {
            pendingApplyAllSMI = smiToApply
            pendingApplyAllFactor = factorToApply
            showingApplyAllAlert = true
        } else {
            guardarCambios()
        }
    }
    
    // Aplica a todos los empleados y recalcula snapshots
    private func applyToAllEmployees(newSMI: Double?, newFactor: Double?) async {
        do {
            let descriptor = FetchDescriptor<Personal>()
            let todos = try modelContext.fetch(descriptor)
            for mec in todos {
                if let s = newSMI { mec.salarioMinimoReferencia = s }
                if let f = newFactor { mec.factorIntegracion = f }
                mec.recalcularYActualizarSnapshots()
            }
        } catch {
            print("Error aplicando a todos los empleados: \(error)")
        }
    }
    
    func guardarCambios() {
        errorMsg = nil
        
        if let msg = validateNombreCompleto(nombre) {
            errorMsg = msg
            return
        }
        let nombreNormalizado = titleCasedName(nombre)
        
        // Regla legal: máximo 6 días laborables
        if diasLaborales.count > 6 {
            errorMsg = "Por ley, solo se permiten hasta 6 días laborables por semana."
            return
        }
        
        // Resolver selecciones obligatorias en "add"
        if mecanicoAEditar == nil {
            if let s = rolSeleccion { rol = s } else {
                errorMsg = "Selecciona un Rol."; return
            }
            if let s = tipoContratoSeleccion { tipoContrato = s } else {
                errorMsg = "Selecciona un Tipo de contrato."; return
            }
            if let s = tipoSalarioSeleccion { tipoSalario = s } else {
                errorMsg = "Selecciona el Tipo de salario."; return
            }
            if let s = frecuenciaPagoSeleccion { frecuenciaPago = s } else {
                errorMsg = "Selecciona la Frecuencia de pago."; return
            }
        }
        
        guard let horaEntrada = Int(horaEntradaString),
              let horaSalida = Int(horaSalidaString) else {
            errorMsg = "Las horas deben ser números válidos."
            return
        }
        // Reglas diurnas: 06–20 y 8 horas exactas
        guard (6...20).contains(horaEntrada), (6...20).contains(horaSalida) else {
            errorMsg = "Turno diurno obligatorio: horas entre 06 y 20."
            return
        }
        guard horaSalida - horaEntrada == 8 else {
            errorMsg = "La jornada debe ser de 8 horas exactas (Salida = Entrada + 8)."
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
        
        // Validación duplicidad RFC
        let rfcToValidate = rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let descriptor = FetchDescriptor<Personal>(
            predicate: #Predicate { $0.rfc == rfcToValidate }
        )
        do {
            let duplicates = try modelContext.fetch(descriptor)
            if let current = mecanicoAEditar {
                if duplicates.contains(where: { $0.persistentModelID != current.persistentModelID }) {
                    errorMsg = "El RFC ya está registrado en otro personal."
                    return
                }
            } else {
                if !duplicates.isEmpty {
                    errorMsg = "El RFC ya está registrado en otro personal."
                    return
                }
            }
        } catch {
            print("Error validando duplicidad de RFC: \(error)")
        }
        if curpInvalido {
            errorMsg = "CURP inválida."
            return
        }
        guard let comisionesValor = Double(comisionesString.replacingOccurrences(of: ",", with: ".")) else {
            errorMsg = "Comisiones inválidas."
            return
        }
        guard let factorIntegracionValor = Double(factorIntegracionString.replacingOccurrences(of: ",", with: ".")), factorIntegracionValor > 0 else {
            errorMsg = "Factor de Integración inválido."
            return
        }
        if telefonoActivo && telefonoInvalido {
            errorMsg = "El teléfono debe tener 10 dígitos si está activo."
            return
        }
        
        let especialidadesArray = especialidadesString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).capitalized }
            .filter { !$0.isEmpty }
        
        // Cálculos previos
        let salarioDiarioBase = salarioMinimoRef
        let diasProm = (frecuenciaPago == .quincena) ? 15.0 : 30.4
        let comisionesPromDiarias = (tipoSalario == .mixto) ? (comisionesValor / diasProm) : 0.0
        let sbcCalculado = Personal.calcularSBC(salarioDiario: salarioDiarioBase, comisionesPromedioDiarias: comisionesPromDiarias, factorIntegracion: factorIntegracionValor)
        let (obrera, patronal, imssTotal) = Personal.calcularIMSS(desdeSBC: sbcCalculado, salarioDiario: salarioDiarioBase, prestacionesMinimas: prestacionesMinimas)
        let isrCalc = Personal.calcularISR(salarioDiario: salarioDiarioBase, comisionesPromedioDiarias: comisionesPromDiarias, tipoSalario: tipoSalario)
        
        let ingresoMensualBruto = (salarioDiarioBase * 30.4) + (tipoSalario == .mixto ? comisionesValor : 0.0)
        let sueldoNeto = max(0, ingresoMensualBruto - isrCalc - obrera)
        let costoReal = ingresoMensualBruto + patronal
        let horasMes = horasSemanalesRequeridas * 4.0
        let costoHoraCalc = horasMes > 0 ? (costoReal / horasMes) : 0
        
        salarioDiario = salarioDiarioBase
        sbc = sbcCalculado
        isrMensualEstimado = max(0, isrCalc)
        imssMensualEstimado = imssTotal
        cuotaObrera = obrera
        cuotaPatronal = patronal
        sueldoNetoMensual = sueldoNeto
        costoRealMensual = costoReal
        costoHora = costoHoraCalc
        manoDeObraSugerida = costoHoraCalc * 2.2
        horasSemanalesRequeridas = 48
        
        if let mec = mecanicoAEditar {
            mec.nombre = nombreNormalizado
            mec.email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            mec.telefono = telefono.trimmingCharacters(in: .whitespacesAndNewlines)
            mec.telefonoActivo = telefonoActivo
            if isRFCUnlocked { mec.rfc = rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            mec.curp = curp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : curp.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            mec.rol = rol
            // Si hoy está bloqueado por ausencia, no permitir cambios de estado; mantener .ausente
            if !estaBloqueadoHoy {
                mec.estado = estado
            } else {
                mec.estado = .ausente
            }
            mec.especialidades = especialidadesArray
            mec.tipoContrato = tipoContrato
            mec.horaEntrada = horaEntrada
            mec.horaSalida = horaSalida
            mec.diasLaborales = Array(diasLaborales).sorted()
            mec.activo = activo
            mec.fechaBaja = fechaBaja
            mec.fechaIngreso = fechaIngreso
            mec.prestacionesMinimas = prestacionesMinimas
            mec.tipoSalario = tipoSalario
            mec.frecuenciaPago = frecuenciaPago
            mec.salarioMinimoReferencia = salarioMinimoRef
            mec.factorIntegracion = factorIntegracionValor
            mec.comisiones = comisionesValor
            
            // Asignar rutas de documentos
            mec.ineAdjuntoPath = ineAdjuntoPath.isEmpty ? nil : ineAdjuntoPath
            mec.comprobanteDomicilioPath = comprobanteDomicilioPath.isEmpty ? nil : comprobanteDomicilioPath
            mec.comprobanteEstudiosPath = comprobanteEstudiosPath.isEmpty ? nil : comprobanteEstudiosPath
            
            // Si veníamos de carpeta temporal y ahora hay RFC definitivo distinto, mover archivos
            if let temp = tempFolderID, temp.hasPrefix("TEMP-"), mec.rfc != temp {
                moveAllDocsIfNeeded(fromTemp: temp, toRFC: mec.rfc)
                tempFolderID = nil
            }
            
            mec.recalcularYActualizarSnapshots()
            
            salarioDiario = mec.salarioDiario
            sbc = mec.sbc
            isrMensualEstimado = mec.isrMensualEstimado
            imssMensualEstimado = mec.imssMensualEstimado
            cuotaObrera = mec.cuotaObrera
            cuotaPatronal = mec.cuotaPatronal
            sueldoNetoMensual = mec.sueldoNetoMensual
            costoRealMensual = mec.costoRealMensual
            costoHora = mec.costoHora
            horasSemanalesRequeridas = mec.horasSemanalesRequeridas
            manoDeObraSugerida = mec.manoDeObraSugerida
        } else {
            // Crear nuevo y asegurar mover desde TEMP a RFC definitivo si aplicó
            let finalRFC = rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if let temp = tempFolderID, temp.hasPrefix("TEMP-"), finalRFC != temp {
                moveAllDocsIfNeeded(fromTemp: temp, toRFC: finalRFC)
                tempFolderID = nil
                // actualizar paths si movimos
                ineAdjuntoPath = updatePathAfterMove(ineAdjuntoPath, from: temp, to: finalRFC)
                comprobanteDomicilioPath = updatePathAfterMove(comprobanteDomicilioPath, from: temp, to: finalRFC)
                comprobanteEstudiosPath = updatePathAfterMove(comprobanteEstudiosPath, from: temp, to: finalRFC)
            }
            
            let nuevo = Personal(
                rfc: finalRFC,
                curp: curp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : curp.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                nombre: nombreNormalizado,
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                telefono: telefono.trimmingCharacters(in: .whitespacesAndNewlines),
                telefonoActivo: telefonoActivo,
                horaEntrada: horaEntrada,
                horaSalida: horaSalida,
                rol: rol,
                estado: estado, // en alta no se muestra ni obliga, se usa .disponible por default del estado actual o el binding
                especialidades: especialidadesArray,
                fechaIngreso: fechaIngreso,
                tipoContrato: tipoContrato,
                diasLaborales: Array(diasLaborales).sorted(),
                activo: activo,
                fechaBaja: fechaBaja,
                prestacionesMinimas: prestacionesMinimas,
                tipoSalario: tipoSalario,
                frecuenciaPago: frecuenciaPago,
                salarioMinimoReferencia: salarioMinimoRef,
                comisiones: (Double(comisionesString.replacingOccurrences(of: ",", with: ".")) ?? 0),
                factorIntegracion: factorIntegracionValor,
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
            nuevo.recalcularYActualizarSnapshots()
            modelContext.insert(nuevo)
        }
        dismiss()
    }
    
    // Mueve todos los documentos de una carpeta TEMP a la carpeta del RFC definitivo
    private func moveAllDocsIfNeeded(fromTemp tempFolder: String, toRFC finalRFC: String) {
        guard let src = FileLocations.folderFor(rfcOrTemp: tempFolder),
              let dst = FileLocations.folderFor(rfcOrTemp: finalRFC) else { return }
        do {
            try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
            let items = try FileManager.default.contentsOfDirectory(at: src, includingPropertiesForKeys: nil)
            for file in items {
                let target = dst.appendingPathComponent(file.lastPathComponent)
                if FileManager.default.fileExists(atPath: target.path) {
                    try? FileManager.default.removeItem(at: target)
                }
                try FileManager.default.moveItem(at: file, to: target)
            }
            // Opcional: borrar carpeta temp
            try? FileManager.default.removeItem(at: src)
        } catch {
            print("Error moviendo documentos de \(tempFolder) a \(finalRFC): \(error)")
        }
    }
    
    private func updatePathAfterMove(_ oldPath: String, from oldFolder: String, to newFolder: String) -> String {
        guard !oldPath.isEmpty else { return oldPath }
        return oldPath.replacingOccurrences(of: "/\(oldFolder)/", with: "/\(newFolder)/")
    }
    
    // Autenticación biométrica/contraseña
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
    
    func marcarAusenciaDiaCompleto() {
        guard let empleado = mecanicoAEditar else { return }
        let hoy = Calendar.current.startOfDay(for: Date())
        // Si ya hay registro hoy, úsalo; si no, crear
        let registro = empleado.asistencias.first(where: { Calendar.current.isDate($0.fecha, inSameDayAs: hoy) }) ?? {
            let nuevo = AsistenciaDiaria(empleado: empleado, fecha: hoy)
            modelContext.insert(nuevo)
            empleado.asistencias.append(nuevo)
            return nuevo
        }()
        // Aplicar ausencia y bloquear
        registro.estadoFinal = .ausente
        registro.bloqueada = true
        // Bloquear cambios de estado del empleado durante el día y reflejar estado operativo
        empleado.bloqueoAsistenciaFecha = hoy
        empleado.estado = .ausente
        asistenciaBloqueada = true
    }
    
    // Recalcular preview de nómina
    func recalcularNominaPreview() {
        let sm = Double(salarioMinimoReferenciaString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let factor = max(Double(factorIntegracionString.replacingOccurrences(of: ",", with: ".")) ?? 1.0452, 0.0001)
        let com = (Double(comisionesString.replacingOccurrences(of: ",", with: ".")) ?? 0)
        let salarioDiarioBase = sm
        let promCom = ((mecanicoAEditar == nil ? (tipoSalarioSeleccion == .mixto) : (tipoSalario == .mixto))) ? (com / diasPromedio) : 0
        
        let sbcCalc = Personal.calcularSBC(salarioDiario: salarioDiarioBase, comisionesPromedioDiarias: promCom, factorIntegracion: factor)
        let (obrera, patronal, imssTotal) = Personal.calcularIMSS(desdeSBC: sbcCalc, salarioDiario: salarioDiarioBase, prestacionesMinimas: prestacionesMinimas)
        let isr = Personal.calcularISR(salarioDiario: salarioDiarioBase, comisionesPromedioDiarias: promCom, tipoSalario: (mecanicoAEditar == nil ? (tipoSalarioSeleccion ?? .minimo) : tipoSalario))
        
        let ingresoMensual = (salarioDiarioBase * 30.4) + (((mecanicoAEditar == nil ? (tipoSalarioSeleccion == .mixto) : (tipoSalario == .mixto))) ? com : 0)
        let neto = max(0, ingresoMensual - isr - obrera)
        let costo = ingresoMensual + patronal
        let horasMes = horasSemanalesRequeridas * 4.0
        let costoHoraCalc = horasMes > 0 ? (costo / horasMes) : 0
        let moSug = costoHoraCalc * 2.2
        
        salarioDiario = salarioDiarioBase
        sbc = sbcCalc
        isrMensualEstimado = max(0, isr)
        imssMensualEstimado = imssTotal
        cuotaObrera = obrera
        cuotaPatronal = patronal
        sueldoNetoMensual = neto
        costoRealMensual = costo
        costoHora = costoHoraCalc
        manoDeObraSugerida = moSug
        horasSemanalesRequeridas = 48
    }
    
    // Validación y normalización de nombre
    private func validateNombreCompleto(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "El nombre no puede estar vacío." }
        let regex = #"^[A-Za-zÁÉÍÓÚÜáéíóúüÑñ '\-’]+$"#
        if NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed) == false {
            return "El nombre solo debe contener letras, espacios, guion (-) y apóstrofo (')."
        }
        let lettersCount = trimmed.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        if lettersCount > 21 {
            return "Máximo 21 letras (se ignoran espacios y separadores)."
        }
        let words = trimmed.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        if words.isEmpty { return "El nombre no puede estar vacío." }
        if words.count > 4 { return "Máximo 4 palabras en el nombre." }
        let whitelist = Set(["de", "del", "la", "los", "las", "y", "o"])
        for word in words {
            let subparts = word.split(whereSeparator: { $0 == "-" || $0 == "'" || $0 == "’" }).map { String($0) }
            for sub in subparts {
                let subLetters = sub.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
                if whitelist.contains(sub.lowercased()) { continue }
                if subLetters < 3 {
                    return "Cada parte del nombre debe tener al menos 3 letras (p. ej., María-José, O’Connor)."
                }
            }
        }
        return nil
    }
    private func titleCasedName(_ value: String) -> String {
        let locale = Locale(identifier: "es_MX")
        let whitelist = Set(["de", "del", "la", "los", "las", "y", "o"])
        let words = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0) }
        var resultWords: [String] = []
        for (index, word) in words.enumerated() {
            let lowerWord = word.lowercased(with: locale)
            if index > 0 && whitelist.contains(lowerWord) {
                resultWords.append(lowerWord)
                continue
            }
            var rebuilt = ""
            var buffer = ""
            for ch in word {
                if ch == "-" || ch == "'" || ch == "’" {
                    let titled = titleCase(subpart: buffer, locale: locale)
                    rebuilt += titled
                    rebuilt.append(ch)
                    buffer = ""
                } else {
                    buffer.append(ch)
                }
            }
            let titledLast = titleCase(subpart: buffer, locale: locale)
            rebuilt += titledLast
            if index == 0 && whitelist.contains(lowerWord) {
                resultWords.append(titleCase(subpart: lowerWord, locale: locale))
            } else {
                resultWords.append(rebuilt)
            }
        }
        return resultWords.joined(separator: " ")
    }
    private func titleCase(subpart: String, locale: Locale) -> String {
        guard !subpart.isEmpty else { return subpart }
        let lower = subpart.lowercased(with: locale)
        guard let first = lower.first else { return lower }
        return String(first).uppercased(with: locale) + lower.dropFirst()
    }
    private func limitNameToMaxLetters(_ value: String, maxLetters: Int) -> String {
        guard maxLetters > 0 else { return "" }
        var count = 0
        var result = ""
        for ch in value {
            if String(ch).unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) {
                if count < maxLetters {
                    result.append(ch)
                    count += 1
                } else { continue }
            } else {
                result.append(ch)
            }
        }
        return result
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
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color("MercedesBackground"))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            if !placeholder.isEmpty {
                Text(placeholder)
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
                    .padding(.leading, 4)
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

// Selector de días
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

// Grid de nómina
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
                roField("Salario diario (base)", salarioDiario)
                roField("SBC", sbc)
                roField("IMSS aprox. (mensual)", imssMensual)
                roField("Cuota obrera", cuotaObrera)
                roField("Cuota patronal", cuotaPatronal)
                roField("ISR aprox. (mensual)", isrMensual)
                roField("Sueldo neto mensual", sueldoNetoMensual)
                roField("Costo real mensual", costoRealMensual)
                roField("Costo por hora real", costoHora)
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
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// --- DocumentDropField y utilidades de archivos ---

fileprivate struct DocumentDropField: View {
    var title: String
    @Binding var currentPath: String
    var rfcProvider: () -> String
    var suggestedFileName: String
    var onDelete: () -> Void
    var onReveal: () -> Void
    var onDroppedAndSaved: (String) -> Void
    
    @State private var isTargeted: Bool = false
    @State private var lastError: String?
    
    // Extensiones permitidas
    private let allowedExtensions: Set<String> = ["pdf", "jpg", "jpeg", "png", "zip"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isTargeted ? Color("MercedesPetrolGreen").opacity(0.18) : Color("MercedesBackground").opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isTargeted ? Color("MercedesPetrolGreen") : Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6,4]))
                    )
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    if currentPath.isEmpty {
                        Text("Arrastra el archivo aquí")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text(URL(fileURLWithPath: currentPath).lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    HStack(spacing: 8) {
                        if !currentPath.isEmpty {
                            Button {
                                onReveal()
                            } label: {
                                Label("Mostrar en Finder", systemImage: "folder.fill")
                            }
                            .buttonStyle(.plain)
                            .font(.caption2)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.blue.opacity(0.25)).cornerRadius(6)
                            
                            Button {
                                onDelete()
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                            .buttonStyle(.plain)
                            .font(.caption2)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.red.opacity(0.25)).cornerRadius(6)
                        }
                    }
                }
                .padding(12)
            }
            .frame(height: 96)
            .onDrop(of: [UTType.fileURL.identifier, UTType.data.identifier], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
            if let lastError {
                Text(lastError)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        // Preferir fileURL
        if let item = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            _ = item.loadObject(ofClass: URL.self) { url, _ in
                guard let srcURL = url else { return }
                saveIncomingFile(srcURL: srcURL)
            }
            return true
        }
        // Aceptar datos genéricos (intentamos con extensión segura si es permitida)
        if let item = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.data.identifier) }) {
            _ = item.loadDataRepresentation(forTypeIdentifier: UTType.data.identifier) { data, _ in
                guard let data else { return }
                // Por defecto, usaremos "pdf" como extensión segura si está permitida
                let fallbackExt = "pdf"
                guard allowedExtensions.contains(fallbackExt) else {
                    DispatchQueue.main.async { lastError = "Tipo no permitido." }
                    return
                }
                let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(suggestedFileName)-\(UUID().uuidString).\(fallbackExt)")
                do {
                    try data.write(to: tmpURL)
                    saveIncomingFile(srcURL: tmpURL)
                } catch {
                    DispatchQueue.main.async { lastError = "No se pudo guardar el archivo: \(error.localizedDescription)" }
                }
            }
            return true
        }
        return false
    }
    
    private func saveIncomingFile(srcURL: URL) {
        // Validación por extensión
        let ext = srcURL.pathExtension.lowercased()
        guard !ext.isEmpty, allowedExtensions.contains(ext) else {
            DispatchQueue.main.async {
                lastError = "Tipo de archivo no permitido. Solo: PDF, JPG, JPEG, PNG, ZIP."
            }
            return
        }
        
        let rfcOrTemp = rfcProvider()
        guard let destFolder = FileLocations.folderFor(rfcOrTemp: rfcOrTemp) else {
            DispatchQueue.main.async { lastError = "No se pudo crear carpeta destino." }
            return
        }
        do {
            try FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
            let destURL = destFolder.appendingPathComponent("\(suggestedFileName)-\(UUID().uuidString).\(ext)")
            if FileManager.default.fileExists(atPath: destURL.path) {
                try? FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: srcURL, to: destURL)
            DispatchQueue.main.async {
                currentPath = destURL.path
                onDroppedAndSaved(destURL.path)
                lastError = nil
            }
        } catch {
            DispatchQueue.main.async { lastError = "Error copiando archivo: \(error.localizedDescription)" }
        }
    }
}

fileprivate enum FileLocations {
    // Base: Application Support/MercedesTaller/Personal/<RFC>/
    static func baseAppSupport() -> URL? {
        do {
            let appSupport = try FileManager.default.url(for: .applicationSupportDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor: nil,
                                                         create: true)
            let base = appSupport.appendingPathComponent("MercedesTaller/Personal", isDirectory: true)
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            return base
        } catch {
            print("No se pudo crear Application Support base: \(error)")
            return nil
        }
    }
    
    static func folderFor(rfcOrTemp: String) -> URL? {
        guard let base = baseAppSupport() else { return nil }
        let safeRFC = rfcOrTemp.replacingOccurrences(of: "/", with: "_")
        return base.appendingPathComponent(safeRFC, isDirectory: true)
    }
}

// --- Barra de asistencia ---
fileprivate struct AssistToolbar: View {
    @Binding var estado: EstadoEmpleado
    @Binding var asistenciaBloqueada: Bool
    var onMarcarAusencia: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Spacer()
            Button {
                onMarcarAusencia()
            } label: {
                Label("Marcar ausencia (requiere supervisor)", systemImage: "lock.shield")
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

