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

// --- ENUM FILTROS PERSONAL ---
fileprivate enum PersonalFilterOption: Identifiable, Hashable {
    case todosActivos
    case porRol(Rol)
    case porEstado(EstadoEmpleado)
    case dadosDeBaja

    var id: String {
        switch self {
        case .todosActivos: return "todos"
        case .dadosDeBaja: return "baja"
        case .porRol(let r): return "rol_\(r.rawValue)"
        case .porEstado(let e): return "estado_\(e.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .todosActivos: return "Todos (Activos)"
        case .dadosDeBaja: return "Dados de Baja"
        case .porRol(let r): return r.rawValue
        case .porEstado(let e): return e.rawValue
        }
    }
}

// --- VISTA PRINCIPAL ---
struct PersonalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Personal.nombre) private var personal: [Personal]
    
    @State private var modalMode: ModalMode?
    @State private var searchQuery = ""
    @State private var selectedFilter: PersonalFilterOption = .todosActivos
    
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
        
        // Filtro unificado
        switch selectedFilter {
        case .todosActivos:
            base = base.filter { $0.activo }
        case .dadosDeBaja:
            base = base.filter { !$0.activo }
        case .porRol(let rol):
            base = base.filter { $0.activo && $0.rol == rol }
        case .porEstado(let estado):
            base = base.filter { $0.activo && $0.estado == estado }
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
            PersonalFormView(mode: incomingMode, parentMode: $modalMode)
                .environment(\.modelContext, modelContext)
                .id(incomingMode.id)
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
                // Barra de busqueda
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    TextField("Buscar...", text: $searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.subheadline)
                    if !searchQuery.isEmpty {
                        Button { searchQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                
                // Ordenar
                Menu {
                    Picker("Ordenar por", selection: $sortOption) {
                        ForEach(SortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    Button {
                        withAnimation { sortAscending.toggle() }
                    } label: {
                        Label(sortAscending ? "Ascendente" : "Descendente", systemImage: sortAscending ? "arrow.up" : "arrow.down")
                    }
                } label: {
                    Text(" Ordenar")
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.subheadline)
                        .padding(8)
                        .background(Color("MercedesCard"))
                        .cornerRadius(8)
                        .foregroundColor(Color("MercedesPetrolGreen"))
                }

                // Filtro Unificado
                Menu {
                    Picker("Filtro General", selection: $selectedFilter) {
                        Text("Todos (Activos)").tag(PersonalFilterOption.todosActivos)
                        
                        Divider()
                        
                        ForEach(Rol.allCases, id: \.self) { rol in
                            Text(rol.rawValue).tag(PersonalFilterOption.porRol(rol))
                        }
                        
                        Divider()
                        
                        Text("Dados de Baja").tag(PersonalFilterOption.dadosDeBaja)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(selectedFilter.title)
                            .lineLimit(1)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color("MercedesCard"))
                    .cornerRadius(8)
                    .foregroundColor(selectedFilter == .todosActivos ? .primary : Color("MercedesPetrolGreen"))
                }
                .menuStyle(.borderlessButton)
                .frame(minWidth: 140)

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
    @Query private var allPersonal: [Personal]
    @Query private var serviciosEnProceso: [ServicioEnProceso]
    
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true

    let mode: ModalMode
    @Binding var parentMode: ModalMode?
    
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
    @State private var especialidadesList: [String] = []
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
    @State private var contratoAdjuntoPath = "" // Nuevo
    
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
    @State private var pendingApplyAllRole: Rol? // Nuevo: para scopear la alerta
    @State private var showingApplyAllAlert: Bool = false
    @State private var postApplyAllAction: (() -> Void)? = nil

    // Alerta genérica de validación
    @State private var showingValidationAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    private var mecanicoAEditar: Personal?
    var formTitle: String { (mode == .add) ? "Añadir Personal" : "Editar Personal" }
    
    // Lógica para detectar duplicado por nombre
    private var productoExistenteConMismoNombre: Personal? {
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if nombreLimpio.isEmpty { return nil }
        
        // Buscar coincidencia exacta insensible a mayúsculas
        if let encontrado = allPersonal.first(where: { $0.nombre.lowercased() == nombreLimpio }) {
            // Si estamos editando, ignorar si es el mismo que estamos editando
            if let actual = mecanicoAEditar, actual.id == encontrado.id {
                return nil
            }
            return encontrado
        }
        return nil
    }
    
    // Lógica para detectar duplicado por RFC
    private var personalExistenteConMismoRFC: Personal? {
        let rfcLimpio = rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if rfcLimpio.isEmpty { return nil }
        
        // Buscar coincidencia exacta
        if let encontrado = allPersonal.first(where: { $0.rfc.uppercased() == rfcLimpio }) {
            // Si estamos editando, ignorar si es el mismo que estamos editando
            if let actual = mecanicoAEditar, actual.id == encontrado.id {
                return nil
            }
            return encontrado
        }
        return nil
    }

    // Sugerencias de especialidades existentes
    private var allExistingSpecialties: [String] {
        let unique = Set(allPersonal.flatMap { $0.especialidades })
        return Array(unique).sorted()
    }
    
    init(mode: ModalMode, parentMode: Binding<ModalMode?>) {
        self.mode = mode
        self._parentMode = parentMode
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
            _especialidadesList = State(initialValue: personal.especialidades)
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
            _contratoAdjuntoPath = State(initialValue: personal.contratoAdjuntoPath ?? "") // Init nuevo
            
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
    private var nombreLettersCount: Int {
        nombre.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
    }
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
        // Debe ser número y > 0
        guard let val = Double(salarioMinimoReferenciaString.replacingOccurrences(of: ",", with: ".")) else { return true }
        return val <= 0
    }
    private var comisionesInvalidas: Bool {
        // Si el salario es mínimo, no se consideran comisiones (oculto y deshabilitado), no invalidar por ello
        if mecanicoAEditar == nil ? (tipoSalarioSeleccion == .minimo) : (tipoSalario == .minimo) {
            return false
        }
        return Double(comisionesString.replacingOccurrences(of: ",", with: ".")) == nil
    }
    private var factorIntegracionInvalido: Bool {
        Double(factorIntegracionString.replacingOccurrences(of: ",", with: ".")) == nil || (Double(factorIntegracionString.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0
    }
    private var sinDiasLaborales: Bool { diasLaborales.isEmpty }
    // NUEVO: Mínimo 6 días laborables
    private var diasInsuficientes: Bool { diasLaborales.count != 6 }
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
    private var especialidadesInvalidas: Bool {
        especialidadesList.isEmpty
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
        if case .add = mode { return false }
        return true
    }
    private var puedeMarcarAusencia: Bool {
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
                        FormField(title: "• Nombre completo", placeholder: "ej. José Cisneros Torres", text: $nombre, characterLimit: 80, customCount: nombreLettersCount)
                            .validationHint(isInvalid: nombreInvalido, message: nombreValidationMessage ?? "")
                        
                        // Botón para editar el existente si hay duplicado
                        if let existente = productoExistenteConMismoNombre {
                            Button {
                                // Cambiar a modo edición del producto existente
                                // Esto cerrará el sheet actual y abrirá uno nuevo debido al cambio de ID
                                parentMode = .edit(existente)
                            } label: {
                                HStack {
                                    Image(systemName: "pencil.circle.fill")
                                    Text("Editar '\(existente.nombre)' existente")
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                        }
                        VStack(alignment: .leading, spacing: 16) {
                            FormField(title: "• Correo electrónico", placeholder: "ej. jose@taller.com", text: $email, characterLimit: 60, customCount: email.count)
                            .validationHint(isInvalid: emailInvalido, message: "Ingresa un correo válido.")
                            .onChange(of: email) { _, newValue in
                                if newValue.count > 60 {
                                    email = String(newValue.prefix(60))
                                }
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("¿Tiene teléfono celular?", isOn: $telefonoActivo)
                                    .toggleStyle(.switch)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                
                                if telefonoActivo {
                                    FormField(title: "• Teléfono (10 dígitos)", placeholder: "ej. 5512345678", text: $telefono, characterLimit: 10, customCount: telefono.count)
                                        .validationHint(isInvalid: telefonoInvalido, message: "Debe tener 10 dígitos.")
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
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
                            
                            // Botón para editar el existente si hay duplicado por RFC
                            if let existenteRFC = personalExistenteConMismoRFC {
                                Button {
                                    parentMode = .edit(existenteRFC)
                                } label: {
                                    Text("Este RFC ya se ha registrado.")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    HStack {
                                        Image(systemName: "pencil.circle.fill")
                                        Text("Editar '\(existenteRFC.nombre)' (RFC existente)")
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 2)
                            }
                        }
                        FormField(title: "CURP (opcional)", placeholder: "18 caracteres", text: $curp)
                            .validationHint(isInvalid: curpInvalido, message: "CURP inválida. Verifica formato y dígito verificador.")
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // 3. Puesto
                    VStack(alignment: .leading, spacing: 20) {
                        SectionHeader(title: "3. Puesto", subtitle: "Definición de rol y perfil profesional")
                        
                        // Selector de Rol (Grid Visual)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("• Selecciona el Rol")
                                .font(.caption).foregroundColor(rolNoSeleccionado ? .red : .gray)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                                ForEach(Rol.allCases, id: \.self) { roleItem in
                                    RoleSelectionCard(
                                        rol: roleItem,
                                        isSelected: (mecanicoAEditar == nil ? (rolSeleccion == roleItem) : (rol == roleItem)),
                                        action: {
                                            if mecanicoAEditar == nil {
                                                rolSeleccion = roleItem
                                            } else {
                                                rol = roleItem
                                            }
                                        }
                                    )
                                }
                            }
                            if rolNoSeleccionado {
                                Text("Debes seleccionar un rol para continuar.")
                                    .font(.caption2).foregroundColor(.red)
                            }
                        }
                        
                        Divider().background(Color.gray.opacity(0.2))
                        
                        // Especialidades (Tags interactivas)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("• Especialidades")
                                .font(.caption).foregroundColor(especialidadesInvalidas ? .red : .gray)
                            
                            TagInputView(
                                tags: $especialidadesList,
                                placeholder: "Escribe una especialidad y presiona Enter...",
                                error: especialidadesInvalidas,
                                availableTags: allExistingSpecialties // Autocompletado
                            )
                            
                            if especialidadesInvalidas {
                                Text("Añade al menos una especialidad (ej. 'Frenos', 'Motor').")
                                    .font(.caption2).foregroundColor(.red)
                            }
                        }
                        
                        Divider().background(Color.gray.opacity(0.2))
                        
                        // Fecha de Ingreso y Contrato (Layout mejorado)
                        HStack(alignment: .top, spacing: 24) {
                            // Fecha de Ingreso
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Fecha de Ingreso")
                                    .font(.caption).foregroundColor(.gray)
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(Color("MercedesPetrolGreen"))
                                    DatePicker("", selection: $fechaIngreso, displayedComponents: .date)
                                        .padding(2)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(10)
                                .background(Color("MercedesBackground"))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Tipo de Contrato
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Tipo de Contrato")
                                    .font(.caption).foregroundColor(tipoContratoNoSeleccionado ? .red : .gray)
                                
                                Menu {
                                    ForEach(TipoContrato.allCases, id: \.self) { tc in
                                        Button {
                                            if mecanicoAEditar == nil {
                                                tipoContratoSeleccion = tc
                                            } else {
                                                tipoContrato = tc
                                            }
                                        } label: {
                                            if (mecanicoAEditar == nil ? tipoContratoSeleccion : tipoContrato) == tc {
                                                Label(tc.rawValue, systemImage: "checkmark")
                                            } else {
                                                Text(tc.rawValue)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text((mecanicoAEditar == nil ? tipoContratoSeleccion?.rawValue : tipoContrato.rawValue) ?? "Seleccionar...")
                                            .foregroundColor((mecanicoAEditar == nil && tipoContratoSeleccion == nil) ? .gray : .primary)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(12)
                                    .background(Color("MercedesBackground"))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(tipoContratoNoSeleccionado ? Color.red.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
                                    )

                                }
                                .buttonStyle(.plain)
                                
                                if tipoContratoNoSeleccionado {
                                    Text("Requerido.")
                                        .font(.caption2).foregroundColor(.red)
                                }
                            }
                            .frame(maxWidth: .infinity)
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
                                    isInvalid: diasInsuficientes,
                                    message: "Debes seleccionar exactamente 6 días laborables."
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
                        SectionHeader(title: "5. Nómina", subtitle: "Configuración salarial")
                        
                        HStack(alignment: .top, spacing: 24) {
                            // Tipo de Salario
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Tipo de Salario")
                                    .font(.caption).foregroundColor(tipoSalarioNoSeleccionado ? .red : .gray)
                                
                                if mecanicoAEditar == nil {
                                    SalaryTypeSegment(selection: $tipoSalarioSeleccion)
                                } else {
                                    SalaryTypeSegment(selection: .constant(nil), selectionBinding: $tipoSalario)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Frecuencia de Pago
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Frecuencia de Pago")
                                    .font(.caption).foregroundColor(frecuenciaPagoNoSeleccionada ? .red : .gray)
                                
                                if mecanicoAEditar == nil {
                                    PaymentFrequencyChips(
                                        selected: frecuenciaPagoSeleccion,
                                        onSelect: { frecuenciaPagoSeleccion = $0 }
                                    )
                                } else {
                                    PaymentFrequencyChips(
                                        selected: frecuenciaPago,
                                        onSelect: { frecuenciaPago = $0 }
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        Divider().background(Color.gray.opacity(0.1))
                        
                        HStack(alignment: .top, spacing: 24) {
                            // Salario Mínimo
                            VStack(alignment: .leading, spacing: 4) {
                                FormField(title: "• Salario mínimo de referencia", placeholder: "ej. 248.93", text: $salarioMinimoReferenciaString)
                                    .validationHint(isInvalid: salarioMinimoInvalido, message: "Debe ser > 0.")
                                
                                Link("Consultar tablas vigentes (CONASAMI)", destination: URL(string: "https://www.gob.mx/conasami")!)
                                    .font(.caption2)
                                    .foregroundColor(Color("MercedesPetrolGreen"))
                                    .padding(.leading, 4)
                            }
                            
                            // Factor Integración
                            VStack(alignment: .leading, spacing: 4) {
                                FormField(title: "• Factor de integración", placeholder: "ej. 1.0452", text: $factorIntegracionString)
                                    .validationHint(isInvalid: factorIntegracionInvalido, message: "Debe ser > 0.")
                                Text("Usado para cálculo SBC")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 4)
                            }
                        }
                        
                        HStack(spacing: 24) {
                            // Prestaciones (Switch mejorado)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• Prestaciones")
                                    .font(.caption).foregroundColor(.gray)
                                BenefitsSegment(prestacionesMinimas: $prestacionesMinimas)
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Comisiones
                            let isMinInAdd = (mecanicoAEditar == nil ? (tipoSalarioSeleccion == .minimo) : false)
                            let isMinInEdit = (mecanicoAEditar != nil ? (tipoSalario == .minimo) : false)
                            let showComisiones = !(isMinInAdd || isMinInEdit)
                            
                            VStack(alignment: .leading, spacing: 0) {
                                // FormField ya incluye label
                                FormField(title: "• Comisiones acumuladas", placeholder: "0.00", text: $comisionesString)
                                    .validationHint(isInvalid: comisionesInvalidas, message: "Número válido.")
                            }
                            .frame(maxWidth: .infinity)
                            .opacity(showComisiones ? 1 : 0)
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
                            .stroke(Color("MercedesPetrolGreen").opacity(0.5), lineWidth: 1)
                    )
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // 7. Documentación con Drag & Drop
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "7. Documentación (arrastra y suelta)", subtitle: "Se guardará en la carpeta de la app")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 10) {
                            DocumentDropField(
                                title: "INE (PDF/Word/Img)",
                                currentPath: $ineAdjuntoPath,
                                rfcProvider: currentRFCForFiles,
                                suggestedFileName: "INE",
                                personName: nombre,
                                onDelete: { deleteCurrentFile(&ineAdjuntoPath) },
                                onReveal: { revealInFinder(ineAdjuntoPath) },
                                onDroppedAndSaved: { newPath in ineAdjuntoPath = newPath }
                            )
                            DocumentDropField(
                                title: "Comprobante de domicilio (PDF/Word/Img)",
                                currentPath: $comprobanteDomicilioPath,
                                rfcProvider: currentRFCForFiles,
                                suggestedFileName: "Domicilio",
                                personName: nombre, // Nuevo
                                onDelete: { deleteCurrentFile(&comprobanteDomicilioPath) },
                                onReveal: { revealInFinder(comprobanteDomicilioPath) },
                                onDroppedAndSaved: { newPath in comprobanteDomicilioPath = newPath }
                            )
                            DocumentDropField(
                                title: "Comprobante de estudios (PDF/Word/Img)",
                                currentPath: $comprobanteEstudiosPath,
                                rfcProvider: currentRFCForFiles,
                                suggestedFileName: "Estudios",
                                personName: nombre, // Nuevo
                                onDelete: { deleteCurrentFile(&comprobanteEstudiosPath) },
                                onReveal: { revealInFinder(comprobanteEstudiosPath) },
                                onDroppedAndSaved: { newPath in comprobanteEstudiosPath = newPath }
                            )
                            DocumentDropField(
                                title: "Contrato (PDF/Word/Img)", // Nuevo campo
                                currentPath: $contratoAdjuntoPath,
                                rfcProvider: currentRFCForFiles,
                                suggestedFileName: "Contrato",
                                personName: nombre, // Nuevo
                                onDelete: { deleteCurrentFile(&contratoAdjuntoPath) },
                                onReveal: { revealInFinder(contratoAdjuntoPath) },
                                onDroppedAndSaved: { newPath in contratoAdjuntoPath = newPath }
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
                                    if let errorAusencia = validarAusencia() {
                                        alertTitle = "No se puede marcar ausencia"
                                        alertMessage = errorAusencia
                                        showingValidationAlert = true
                                    } else {
                                        authReason = .markAbsence
                                        showingAuthModal = true
                                    }
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
                                if let errorEliminar = validarEliminacion() {
                                    alertTitle = "No se puede eliminar"
                                    alertMessage = errorEliminar
                                    showingValidationAlert = true
                                } else {
                                    authReason = .deleteEmployee
                                    showingAuthModal = true
                                }
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
                let limited = limitNameToMaxLetters(newValue, maxLetters: 80)
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
                            // Validar antes de togglear
                            if activo {
                                // Intenta dar de baja
                                if let errorBaja = validarBaja() {
                                    alertTitle = "No se puede dar de baja"
                                    alertMessage = errorBaja
                                    showingValidationAlert = true
                                    return
                                }
                            }
                            // Si pasa, mostrar confirmación
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
                    diasInsuficientes ||
                    comisionesInvalidas ||
                    factorIntegracionInvalido ||
                    telefonoInvalido ||
                    curpInvalido ||
                    rolNoSeleccionado ||
                    tipoContratoNoSeleccionado ||
                    frecuenciaPagoNoSeleccionada ||
                    tipoSalarioNoSeleccionado ||
                    especialidadesInvalidas
                )
                .opacity(
                    (nombreInvalido ||
                     emailInvalido ||
                     rfcInvalido ||
                     horasInvalidas ||
                     salarioMinimoInvalido ||
                     diasInsuficientes ||
                     comisionesInvalidas ||
                     factorIntegracionInvalido ||
                     telefonoInvalido ||
                     curpInvalido ||
                     rolNoSeleccionado ||
                     tipoContratoNoSeleccionado ||
                     frecuenciaPagoNoSeleccionada ||
                     tipoSalarioNoSeleccionado ||
                     especialidadesInvalidas) ? 0.6 : 1.0
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
        .alert(
            "Aplicar cambios a todos los \(pendingApplyAllRole?.rawValue ?? "empleados")",
            isPresented: $showingApplyAllAlert
        ) {
            Button("Aplicar a todos los \(pendingApplyAllRole?.rawValue ?? "empleados")") {
                let newSMI = pendingApplyAllSMI
                let newFactor = pendingApplyAllFactor
                let targetRole = pendingApplyAllRole
                Task {
                    await applyToAllEmployees(newSMI: newSMI, newFactor: newFactor, role: targetRole)
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
            
            let roleName = pendingApplyAllRole?.rawValue ?? "este rol"
            Text("Detectamos cambios en:\n\(parts.joined(separator: "\n"))\n¿Quieres aplicar estos valores a todos los empleados con el rol '\(roleName)'?")
        }
        .alert(alertTitle, isPresented: $showingValidationAlert) {
            Button("Entendido", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Gestión de Archivos
    
    private func currentRFCForFiles() -> String {
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
        
        // Intentar borrar archivo físico
        try? FileManager.default.removeItem(atPath: path)
        
        // Siempre limpiar la referencia en UI, incluso si el archivo ya no existía
        // Esto soluciona el bug de "archivo borrado manualmente"
        pathBinding = ""
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
        
        let newSMI = Double(salarioMinimoReferenciaString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let newFactor = Double(factorIntegracionString.replacingOccurrences(of: ",", with: ".")) ?? 0
        
        let currentSMI = mecanicoAEditar?.salarioMinimoReferencia
        let currentFactor = mecanicoAEditar?.factorIntegracion
        
        var willAsk = false
        var smiToApply: Double?
        var factorToApply: Double?
        
        if mecanicoAEditar == nil {
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
        
        postApplyAllAction = { guardarCambios() }
        
        if willAsk {
            pendingApplyAllSMI = smiToApply
            pendingApplyAllFactor = factorToApply
            // Capturar el rol actual
            pendingApplyAllRole = (mecanicoAEditar == nil) ? rolSeleccion : rol
            showingApplyAllAlert = true
        } else {
            guardarCambios()
        }
    }
    
    // Aplica a todos los empleados del mismo rol y recalcula snapshots
    private func applyToAllEmployees(newSMI: Double?, newFactor: Double?, role: Rol?) async {
        do {
            let descriptor = FetchDescriptor<Personal>()
            let todos = try modelContext.fetch(descriptor)
            for mec in todos {
                 // Si se especificó un rol, filtrar
                if let r = role, mec.rol != r { continue }
                
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
        
        if diasLaborales.count != 6 {
            errorMsg = "Debes seleccionar exactamente 6 días laborables."
            return
        }
        
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
        guard (6...20).contains(horaEntrada), (6...20).contains(horaSalida) else {
            errorMsg = "Turno diurno obligatorio: horas entre 06 y 20."
            return
        }
        guard horaSalida - horaEntrada == 8 else {
            errorMsg = "La jornada debe ser de 8 horas exactas (Salida = Entrada + 8)."
            return
        }
        
        guard let salarioMinimoRef = Double(salarioMinimoReferenciaString.replacingOccurrences(of: ",", with: ".")), salarioMinimoRef > 0 else {
            errorMsg = "Salario mínimo de referencia inválido (debe ser > 0)."
            return
        }
        guard RFCValidator.isValidRFC(rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()) else {
            errorMsg = "RFC inválido."
            return
        }
        
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
        // Comisiones: si salario es mínimo, forzar a 0.
        let isMinSalary = mecanicoAEditar == nil ? (tipoSalarioSeleccion == .minimo) : (tipoSalario == .minimo)
        let comisionesValor: Double = {
            if isMinSalary { return 0.0 }
            return Double(comisionesString.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        }()
        if !isMinSalary && Double(comisionesString.replacingOccurrences(of: ",", with: ".")) == nil {
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
        
        let especialidadesArray = especialidadesList
        
        if especialidadesArray.isEmpty {
            errorMsg = "Debes ingresar al menos una especialidad."
            return
        }
        
        // Cálculos previos
        let salarioDiarioBase = salarioMinimoRef
        let diasProm = (frecuenciaPago == .quincena) ? 15.0 : 30.4
        let comisionesPromDiarias = (!isMinSalary && tipoSalario == .mixto) ? (comisionesValor / diasProm) : 0.0
        let sbcCalculado = Personal.calcularSBC(salarioDiario: salarioDiarioBase, comisionesPromedioDiarias: comisionesPromDiarias, factorIntegracion: factorIntegracionValor)
        let (obrera, patronal, imssTotal) = Personal.calcularIMSS(desdeSBC: sbcCalculado, salarioDiario: salarioDiarioBase, prestacionesMinimas: prestacionesMinimas)
        let isrCalc = Personal.calcularISR(salarioDiario: salarioDiarioBase, comisionesPromedioDiarias: comisionesPromDiarias, tipoSalario: tipoSalario)
        
        let ingresoMensualBruto = (salarioDiarioBase * 30.4) + ((tipoSalario == .mixto && !isMinSalary) ? comisionesValor : 0.0)
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
            mec.salarioMinimoReferencia = salarioDiarioBase
            mec.factorIntegracion = factorIntegracionValor
            mec.comisiones = isMinSalary ? 0.0 : comisionesValor
            
            mec.ineAdjuntoPath = ineAdjuntoPath.isEmpty ? nil : ineAdjuntoPath
            mec.comprobanteDomicilioPath = comprobanteDomicilioPath.isEmpty ? nil : comprobanteDomicilioPath
            mec.comprobanteEstudiosPath = comprobanteEstudiosPath.isEmpty ? nil : comprobanteEstudiosPath
            mec.contratoAdjuntoPath = contratoAdjuntoPath.isEmpty ? nil : contratoAdjuntoPath
            
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
            let finalRFC = rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if let temp = tempFolderID, temp.hasPrefix("TEMP-"), finalRFC != temp {
                moveAllDocsIfNeeded(fromTemp: temp, toRFC: finalRFC)
                tempFolderID = nil
                ineAdjuntoPath = updatePathAfterMove(ineAdjuntoPath, from: temp, to: finalRFC)
                comprobanteDomicilioPath = updatePathAfterMove(comprobanteDomicilioPath, from: temp, to: finalRFC)
                comprobanteEstudiosPath = updatePathAfterMove(comprobanteEstudiosPath, from: temp, to: finalRFC)
                contratoAdjuntoPath = updatePathAfterMove(contratoAdjuntoPath, from: temp, to: finalRFC)
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
                estado: estado,
                especialidades: especialidadesArray,
                fechaIngreso: fechaIngreso,
                tipoContrato: tipoContrato,
                diasLaborales: Array(diasLaborales).sorted(),
                activo: activo,
                fechaBaja: fechaBaja,
                prestacionesMinimas: prestacionesMinimas,
                tipoSalario: tipoSalario,
                frecuenciaPago: frecuenciaPago,
                salarioMinimoReferencia: salarioDiarioBase,
                comisiones: isMinSalary ? 0.0 : comisionesValor,
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
                contratoAdjuntoPath: contratoAdjuntoPath.isEmpty ? nil : contratoAdjuntoPath,
                antiguedadDias: 0,
                bloqueoAsistenciaFecha: nil
            )
            nuevo.recalcularYActualizarSnapshots()
            modelContext.insert(nuevo)
        }
        dismiss()
    }
    
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
            try? FileManager.default.removeItem(at: src)
        } catch {
            print("Error moviendo documentos de \(tempFolder) a \(finalRFC): \(error)")
        }
    }
    
    private func updatePathAfterMove(_ oldPath: String, from oldFolder: String, to newFolder: String) -> String {
        guard !oldPath.isEmpty else { return oldPath }
        return oldPath.replacingOccurrences(of: "/\(oldFolder)/", with: "/\(newFolder)/")
    }
    
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
        let registro = empleado.asistencias.first(where: { Calendar.current.isDate($0.fecha, inSameDayAs: hoy) }) ?? {
            let nuevo = AsistenciaDiaria(empleado: empleado, fecha: hoy)
            modelContext.insert(nuevo)
            empleado.asistencias.append(nuevo)
            return nuevo
        }()
        registro.estadoFinal = .ausente
        registro.bloqueada = true
        empleado.bloqueoAsistenciaFecha = hoy
        empleado.estado = .ausente
        asistenciaBloqueada = true
    }
    
    func recalcularNominaPreview() {
        let sm = Double(salarioMinimoReferenciaString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let factor = max(Double(factorIntegracionString.replacingOccurrences(of: ",", with: ".")) ?? 1.0452, 0.0001)
        let com = (Double(comisionesString.replacingOccurrences(of: ",", with: ".")) ?? 0)
        let salarioDiarioBase = sm
        let isMinSalary = mecanicoAEditar == nil ? (tipoSalarioSeleccion == .minimo) : (tipoSalario == .minimo)
        let promCom = (!isMinSalary && (mecanicoAEditar == nil ? (tipoSalarioSeleccion == .mixto) : (tipoSalario == .mixto))) ? (com / diasPromedio) : 0
        
        let sbcCalc = Personal.calcularSBC(salarioDiario: salarioDiarioBase, comisionesPromedioDiarias: promCom, factorIntegracion: factor)
        let (obrera, patronal, imssTotal) = Personal.calcularIMSS(desdeSBC: sbcCalc, salarioDiario: salarioDiarioBase, prestacionesMinimas: prestacionesMinimas)
        let isr = Personal.calcularISR(salarioDiario: salarioDiarioBase, comisionesPromedioDiarias: promCom, tipoSalario: (mecanicoAEditar == nil ? (tipoSalarioSeleccion ?? .minimo) : tipoSalario))
        
        let ingresoMensual = (salarioDiarioBase * 30.4) + ((!isMinSalary && (mecanicoAEditar == nil ? (tipoSalarioSeleccion == .mixto) : (tipoSalario == .mixto))) ? com : 0)
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
    
    private func validateNombreCompleto(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "El nombre no puede estar vacío." }
        let regex = #"^[A-Za-zÁÉÍÓÚÜáéíóúüÑñ '\-’]+$"#
        if NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed) == false {
            return "El nombre solo debe contener letras, espacios, guion (-) y apóstrofo (')."
        }
        let lettersCount = trimmed.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        if lettersCount > 80 {
            return "Máximo 80 letras (se ignoran espacios y separadores)."
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

    // MARK: - Validation Check (Baja / Eliminación / Ausencia)
    
    private func validarBaja() -> String? {
        guard let rfcMec = mecanicoAEditar?.rfc else { return nil }
        // 1. Servicios en curso
        if tieneServiciosActivos(rfc: rfcMec) {
            return "El empleado tiene servicios en curso (En Proceso). Debes completarlos o reasignarlos antes de darlo de baja."
        }
        // 2. Servicios programados futuros
        if tieneServiciosProgramados(rfc: rfcMec) {
            return "El empleado tiene servicios programados a futuro. Debes cancelarlos o reasignarlos."
        }
        return nil
    }
    
    private func validarEliminacion() -> String? {
        guard let rfcMec = mecanicoAEditar?.rfc else { return nil }
        // Misma lógica que baja, no queremos eliminar historial activo
        if tieneServiciosActivos(rfc: rfcMec) {
            return "No se puede eliminar porque está asignado a servicios en curso."
        }
        if tieneServiciosProgramados(rfc: rfcMec) {
            return "No se puede eliminar porque tiene servicios programados a futuro."
        }
        return nil
    }
    
    private func validarAusencia() -> String? {
        guard let mec = mecanicoAEditar else { return nil }
        
        // 1. Servicio activo
        if tieneServiciosActivos(rfc: mec.rfc) {
            return "El empleado tiene un servicio EN PROCESO ahora mismo. No puedes marcarlo como ausente si está trabajando."
        }
        
        // 2. Fuera de turno
        if !mec.estaEnHorario {
            return "El empleado está FUERA DE TURNO. No se puede marcar inasistencia."
        }

        return nil
    }
    
    private func tieneServiciosActivos(rfc: String) -> Bool {
        return serviciosEnProceso.contains { s in
            s.rfcMecanicoAsignado == rfc && s.estado == .enProceso
        }
    }
    
    private func tieneServiciosProgramados(rfc: String) -> Bool {
        return serviciosEnProceso.contains { s in
            // Solo considerar servicios asignados a este RFC
            guard s.rfcMecanicoAsignado == rfc else { return false }
            
            // Ignorar explícitamente cancelados y completados
            // (El bug anterior era que si la fecha era futura, lo contaba aunque estuviera cancelado/completado)
            if s.estado == .cancelado || s.estado == .completado {
                return false
            }
            
            // Retornar true si está programado o si la fecha es futura (siempre que no esté cancelado/finalizado)
            // Nota: Un servicio 'enProceso' se captura en tieneServiciosActivos, 
            // pero si tiene fecha futura podría caer aquí. La distinción es semántica, 
            // lo importante es que bloquée si hay compromiso futuro pendiente.
            return s.estado == .programado || (s.fechaProgramadaInicio ?? Date.distantPast) > Date()
        }
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
    var characterLimit: Int? = nil
    var customCount: Int? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                if let limit = characterLimit {
                    let current = customCount ?? text.count
                    Text("\(current)/\(limit)")
                        .font(.caption2)
                        .foregroundColor(current > limit ? .red : .gray)
                }
            }
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
    var personName: String
    var onDelete: () -> Void
    var onReveal: () -> Void
    var onDroppedAndSaved: (String) -> Void
    
    @State private var isTargeted: Bool = false
    @State private var lastError: String?
    @State private var showingDeleteAlert = false
    
    // Updated: Accept PDF, Images, and Word (doc, docx) - NO ZIP
    private let allowedExtensions: Set<String> = ["pdf", "jpg", "jpeg", "png", "doc", "docx"]
    
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
                                showingDeleteAlert = true
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                            .buttonStyle(.plain)
                            .font(.caption2)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.red.opacity(0.25)).cornerRadius(6)
                            .alert("¿Eliminar documento?", isPresented: $showingDeleteAlert) {
                                Button("Cancelar", role: .cancel) { }
                                Button("Eliminar", role: .destructive) {
                                    onDelete()
                                }
                            } message: {
                                Text("Esta acción no se puede deshacer.")
                            }
                        }
                    }
                }
                .padding(12)
            }
            .frame(height: 96)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
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
        // Solo aceptamos archivos reales (URLs) para garantizar que es "tal cual"
        if let item = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            _ = item.loadObject(ofClass: URL.self) { url, _ in
                guard let srcURL = url else { return }
                saveIncomingFile(srcURL: srcURL)
            }
            return true
        }
        // Si no es un archivo, rechazamos para evitar conversiones implícitas o tipos no deseados
        DispatchQueue.main.async { lastError = "Formato no soportado. Arrastra un archivo válido." }
        return false
    }
    
    private func saveIncomingFile(srcURL: URL) {
        let ext = srcURL.pathExtension.lowercased()
        guard !ext.isEmpty, allowedExtensions.contains(ext) else {
            DispatchQueue.main.async {
                lastError = "Archivo no permitido. Solo: PDF, WORD (doc/docx), JPG, PNG."
            }
            return
        }
        
        let rfcOrTemp = rfcProvider()
        guard let destFolder = FileLocations.folderFor(rfcOrTemp: rfcOrTemp) else {
            DispatchQueue.main.async { lastError = "No se pudo crear carpeta destino." }
            return
        }
        
        let safeName = sanitizeName(personName)
        let finalBaseName = safeName.isEmpty ? suggestedFileName : "\(suggestedFileName)_\(safeName)"
        
        do {
            try FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
            
            let destURL = destFolder.appendingPathComponent("\(finalBaseName).\(ext)")
            
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
    
    private func sanitizeName(_ raw: String) -> String {
        let folded = raw.folding(options: .diacriticInsensitive, locale: .current)
        let alphanumerics = CharacterSet.alphanumerics
        return folded.unicodeScalars.filter { alphanumerics.contains($0) }.map { String($0) }.joined()
    }
}

fileprivate enum FileLocations {
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


// MARK: - Helper Views for New UX

struct RoleSelectionCard: View {
    let rol: Rol
    let isSelected: Bool
    let action: () -> Void
    
    var iconName: String {
        switch rol {
        case .jefeDeTaller: return "person.3.fill"
        case .atencionCliente: return "headset"
        case .mecanicoFrenos: return "wrench.adjustable.fill"
        case .ayudante: return "hammer.fill"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color("MercedesPetrolGreen") : Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .gray)
                }
                
                Text(rol.rawValue)
                    .font(.footnote)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(isSelected ? Color("MercedesPetrolGreen").opacity(0.15) : Color("MercedesBackground"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color("MercedesPetrolGreen") : Color.gray.opacity(0.2), lineWidth: 1.5)
            )
            .shadow(color: isSelected ? Color("MercedesPetrolGreen").opacity(0.2) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct TagInputView: View {
    @Binding var tags: [String]
    var placeholder: String
    var error: Bool
    var availableTags: [String] = [] // Sugerencias
    
    @State private var newTag = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Área de Chips
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text(tag)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Button {
                                    withAnimation {
                                        tags.removeAll { $0 == tag }
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color("MercedesPetrolGreen").opacity(0.2))
                            .foregroundColor(Color("MercedesPetrolGreen"))
                            .cornerRadius(20)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Input Field
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.gray)
                TextField(placeholder, text: $newTag)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        addTag(fromInput: true)
                    }
                    // Nuevo: Capturar Tab para autocompletar
                    .onKeyPress(.tab) {
                        let lowerInput = newTag.lowercased()
                        let matches = availableTags.filter { 
                            $0.lowercased().contains(lowerInput) && !tags.contains($0)
                        }.sorted()
                        
                        if let first = matches.first {
                            addTag(specific: first)
                            return .handled
                        }
                        return .ignored
                    }
                Button {
                    addTag(fromInput: true)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(newTag.isEmpty ? .gray : Color("MercedesPetrolGreen"))
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
            .background(Color("MercedesBackground"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(error ? Color.red.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            // Sugerencias (Fuzzy Matching)
            if !newTag.isEmpty {
                let lowerInput = newTag.lowercased()
                
                // Filtramos y ordenamos por similitud
                let matches = availableTags.filter { tag in
                    if tags.contains(tag) { return false }
                    let dist = lowerInput.levenshteinDistance(to: tag)
                    // Mostrar si contiene el texto O si la distancia es pequeña (<= 3 para typos)
                    return tag.lowercased().contains(lowerInput) || dist <= 3
                }.sorted { t1, t2 in
                    let d1 = lowerInput.levenshteinDistance(to: t1)
                    let d2 = lowerInput.levenshteinDistance(to: t2)
                    
                    // Prioridad: 1. Contiene exacto, 2. Menor distancia Levenshtein
                    let c1 = t1.lowercased().contains(lowerInput)
                    let c2 = t2.lowercased().contains(lowerInput)
                    
                    if c1 && !c2 { return true }
                    if !c1 && c2 { return false }
                    
                    return d1 < d2
                }
                
                if !matches.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(matches, id: \.self) { match in
                                    Button {
                                        addTag(specific: match)
                                    } label: {
                                        Text(match)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .transition(.opacity)
                        
                        Text("Presiona TAB para autocompletar el primero.")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
    
    private func addTag(fromInput: Bool = false, specific: String? = nil) {
        if let specific = specific {
            if !tags.contains(specific) {
                withAnimation {
                    tags.append(specific)
                    newTag = ""
                }
            }
            return
        }
        
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            // Capitalizar primera letra
            let formatted = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
            if !tags.contains(formatted) {
                withAnimation {
                    tags.append(formatted)
                    newTag = ""
                }
            } else {
                newTag = "" // Ya existe
            }
        }
    }
}

struct SalaryTypeSegment: View {
    @Binding var selection: TipoSalario?
    // Opción para modo edición directo (non-optional binding wrapper)
    var selectionBinding: Binding<TipoSalario>? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TipoSalario.allCases, id: \.self) { type in
                let isSelected = (selectionBinding?.wrappedValue == type) || (selection == type)
                
                Button {
                    withAnimation {
                        if let b = selectionBinding { b.wrappedValue = type }
                        else { selection = type }
                    }
                } label: {
                    Text(type.rawValue)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? Color("MercedesPetrolGreen") : Color.clear)
                        .foregroundColor(isSelected ? .white : .gray)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color("MercedesBackground"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct PaymentFrequencyChips: View {
    var selected: FrecuenciaPago?
    var onSelect: (FrecuenciaPago) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(FrecuenciaPago.allCases, id: \.self) { freq in
                let isSelected = (selected == freq)
                Button {
                    onSelect(freq)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                        Text(freq.rawValue)
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color("MercedesPetrolGreen").opacity(0.15) : Color("MercedesBackground"))
                    .foregroundColor(isSelected ? Color("MercedesPetrolGreen") : .gray)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color("MercedesPetrolGreen") : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct BenefitsSegment: View {
    @Binding var prestacionesMinimas: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Opción 1: Mínimas
            Button {
                withAnimation { prestacionesMinimas = true }
            } label: {
                Text("De Ley (Mínimas)")
                    .font(.caption)
                    .fontWeight(prestacionesMinimas ? .semibold : .regular)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(prestacionesMinimas ? Color("MercedesPetrolGreen") : Color.clear)
                    .foregroundColor(prestacionesMinimas ? .white : .gray)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Separator
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)
                .padding(.vertical, 4)
            
            // Opción 2: Superiores
            Button {
                withAnimation { prestacionesMinimas = false }
            } label: {
                Text("Superiores")
                    .font(.caption)
                    .fontWeight(!prestacionesMinimas ? .semibold : .regular)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(!prestacionesMinimas ? Color("MercedesPetrolGreen") : Color.clear)
                    .foregroundColor(!prestacionesMinimas ? .white : .gray)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Color("MercedesBackground"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - String Extension for Fuzzy Matching
extension String {
    func levenshteinDistance(to destination: String) -> Int {
        let s1 = Array(self.lowercased().utf16)
        let s2 = Array(destination.lowercased().utf16)
        
        // Optimización rápida
        if s1 == s2 { return 0 }
        if s1.isEmpty { return s2.count }
        if s2.isEmpty { return s1.count }
        
        let empty = [Int](repeating: 0, count: s2.count)
        var last = [Int](0...s2.count)
        
        for (i, t1) in s1.enumerated() {
            var cur = [i + 1] + empty
            for (j, t2) in s2.enumerated() {
                cur[j + 1] = t1 == t2 ? last[j] : Swift.min(last[j], last[j + 1], cur[j]) + 1
            }
            last = cur
        }
        return last.last ?? 0
    }
}
