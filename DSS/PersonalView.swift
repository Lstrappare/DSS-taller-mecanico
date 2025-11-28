// the entire code of the file with your changes goes here.
// Do not skip over anything.
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
        
        // Filtro alta/baja
        if incluirDadosDeBaja == false {
            base = base.filter { $0.activo }
        }
        
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
        
        // Ordenamiento similar a InventarioView
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
            // Header compacto como en InventarioView
            header
            
            // Barra única: búsqueda + orden + filtros + limpiar
            filtrosView
            
            // Lista
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Contador de resultados
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
    
    // Header compacto (alineado al de InventarioView)
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
    
    // Filtros compactos (patrón InventarioView)
    private var filtrosView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Buscar
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
                
                // Orden
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
                
                // Rol
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
                
                // Estado
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
                
                // Alta/Baja
                Toggle(isOn: $incluirDadosDeBaja) {
                    Text("Incluir dados de baja")
                }
                .toggleStyle(.switch)
                .help("Muestra también a los empleados dados de baja")
                
                // Filtros activos + limpiar
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
    
    // Empty state agradable
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

// Tarjeta individual de personal (estilo alineado a InventarioView)
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
                        Text(mecanico.estaEnHorario ? mecanico.estado.rawValue : "Fuera de Turno")
                            .font(.caption2)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background((mecanico.estaEnHorario ? estadoColor : .gray).opacity(0.18))
                            .foregroundColor(mecanico.estaEnHorario ? estadoColor : .gray)
                            .cornerRadius(6)
                        
                        // Botón Editar
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
                        // NUEVO: comisiones acumuladas
                        chip(text: "Comisiones: $\(mecanico.comisiones, default: "%.2f")", icon: "dollarsign.circle.fill")
                    }
                    if !mecanico.activo, let f = mecanico.fechaBaja {
                        Text("Fecha de baja: \(f.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Contacto
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
    
    // Trabajo
    @State private var rol: Rol = .ayudante
    @State private var especialidadesString = ""
    @State private var fechaIngreso = Date()
    @State private var tipoContrato: TipoContrato = .indefinido
    @State private var horaEntradaString = "9"
    @State private var horaSalidaString = "18"
    @State private var diasLaborales: Set<Int> = [2,3,4,5,6] // L-V
    
    // Alta/Baja
    @State private var activo: Bool = true
    @State private var fechaBaja: Date? = nil
    
    // Nómina (configuración)
    @State private var prestacionesMinimas = true
    @State private var tipoSalario: TipoSalario = .minimo
    @State private var frecuenciaPago: FrecuenciaPago = .quincena
    @State private var salarioMinimoReferenciaString = "248.93"
    @State private var comisionesString = "0.00"
    @State private var factorIntegracionString = "1.0452"
    
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
    @State private var horasSemanalesRequeridas: Double = 0
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
    private var nombreValidationMessage: String? {
        validateNombreCompleto(nombre)
    }
    private var nombreInvalido: Bool {
        nombreValidationMessage != nil
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
    private var curpInvalido: Bool {
        let trimmed = curp.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false } // Opcional
        return !CURPValidator.isValidCURP(trimmed)
    }
    private var horasInvalidas: Bool {
        guard let he = Int(horaEntradaString), let hs = Int(horaSalidaString),
              (0...23).contains(he), (0...23).contains(hs) else { return true }
        return he == hs
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
    private var sinDiasLaborales: Bool {
        diasLaborales.isEmpty
    }
    
    // Validación de teléfono
    private var telefonoInvalido: Bool {
        if !telefonoActivo { return false }
        let trimmed = telefono.trimmingCharacters(in: .whitespacesAndNewlines)
        // Simple validación de 10 dígitos
        let regex = #"^\d{10}$"#
        let pred = NSPredicate(format: "SELF MATCHES %@", regex)
        return !pred.evaluate(with: trimmed)
    }
    
    // Helpers de promedio de comisiones
    private var diasPromedio: Double {
        switch frecuenciaPago {
        case .quincena: return 15.0
        case .mes: return 30.4
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Título y leyendas
            VStack(spacing: 4) {
                Text(formTitle)
                    .font(.title).fontWeight(.bold)
                Text("Completa los datos. Los campos marcados con '•' son obligatorios.")
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
                            .validationHint(isInvalid: nombreInvalido, message: nombreValidationMessage ?? "")
                        FormField(title: "• Email", placeholder: "ej. jose@taller.com", text: $email)
                            .validationHint(isInvalid: emailInvalido, message: "Ingresa un email válido.")
                    }
                    HStack(spacing: 16) {
                        FormField(title: "Teléfono", placeholder: "10 dígitos", text: $telefono)
                            .disabled(!telefonoActivo)
                            .opacity(telefonoActivo ? 1.0 : 0.6)
                            .validationHint(isInvalid: telefonoInvalido, message: "Debe tener 10 dígitos.")
                        
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
                        .validationHint(isInvalid: curpInvalido, message: "CURP inválida. Verifica formato y dígito verificador.")
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
                        FormField(title: "• Entrada (0-23)", placeholder: "ej. 9", text: $horaEntradaString)
                            .validationHint(isInvalid: horasInvalidas, message: "0 a 23 y distinto de salida.")
                        FormField(title: "• Salida (0-23)", placeholder: "ej. 18", text: $horaSalidaString)
                            .validationHint(isInvalid: horasInvalidas, message: "0 a 23 y distinto de entrada.")
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
                
                // Sección: Estado laboral (Alta/Baja)
                Section {
                    SectionHeader(title: "Estado laboral", subtitle: "Dar de baja / Dar de alta")
                    HStack(spacing: 10) {
                        Text(activo ? "Activo" : "De baja")
                            .font(.headline)
                            .foregroundColor(activo ? .green : .red)
                        if let f = fechaBaja, !activo {
                            Text("Baja desde: \(f.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        if activo {
                            Button {
                                // Dar de baja: no elimina datos; no se considera para asignaciones
                                activo = false
                                fechaBaja = Date()
                            } label: {
                                Label("Dar de baja", systemImage: "person.fill.xmark")
                                    .font(.subheadline)
                                    .padding(.vertical, 6).padding(.horizontal, 10)
                                    .background(Color.red.opacity(0.22))
                                    .foregroundColor(.red)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .help("No se eliminarán los datos; no se considerará para asignación de servicios.")
                        } else {
                            Button {
                                // Dar de alta: vuelve a considerarse para asignaciones y actualiza fechaIngreso
                                activo = true
                                fechaBaja = nil
                                fechaIngreso = Date()
                            } label: {
                                Label("Dar de alta", systemImage: "person.fill.checkmark")
                                    .font(.subheadline)
                                    .padding(.vertical, 6).padding(.horizontal, 10)
                                    .background(Color("MercedesPetrolGreen"))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .help("Se actualizará la fecha de ingreso al día de hoy.")
                        }
                    }
                    Text("Nota: No se eliminarán los datos. Mientras esté de baja, no se le tomará en cuenta para la asignación de servicios.")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                // Sección: Nómina (config y cálculo)
                Section {
                    SectionHeader(title: "Nómina", subtitle: "Cálculos aproximados con SBC dinámico")
                    Toggle("Prestaciones mínimas", isOn: $prestacionesMinimas)
                    
                    HStack(spacing: 16) {
                        // Tipo de salario reducido a 2 opciones (UI)
                        Picker("• Tipo de salario", selection: $tipoSalario) {
                            Text(TipoSalario.minimo.rawValue).tag(TipoSalario.minimo)
                            Text(TipoSalario.mixto.rawValue).tag(TipoSalario.mixto)
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
                        FormField(title: "• Factor de Integración", placeholder: "ej. 1.0452", text: $factorIntegracionString)
                            .validationHint(isInvalid: factorIntegracionInvalido, message: "Debe ser > 0.")
                    }
                    
                    // Comisiones: editable si tipoSalario == .mixto; de solo lectura si .minimo (visibilidad)
                    if tipoSalario == .mixto {
                        HStack(spacing: 16) {
                            FormField(title: "• Comisiones (acumuladas)", placeholder: "0.00", text: $comisionesString)
                                .validationHint(isInvalid: comisionesInvalidas, message: "Número válido.")
                            Text("El monto se incrementa automáticamente al completar servicios (mano de obra).")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else {
                        // Solo lectura para visibilidad cuando es salario mínimo
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Comisiones acumuladas (solo lectura)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text(String(format: "$%.2f", Double(comisionesString.replacingOccurrences(of: ",", with: ".")) ?? 0))
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color("MercedesBackground").opacity(0.9))
                                    .cornerRadius(8)
                            }
                            Text("Visible aunque el tipo de salario sea mínimo.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
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
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if tipoSalario == .mixto {
                                HStack(spacing: 8) {
                                    Text("El ISR es aproximado. Debe verificarse con la tabla oficial del SAT.")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                    Link("SAT", destination: URL(string: "https://www.sat.gob.mx/portal/public/home")!)
                                        .font(.caption2)
                                        .foregroundColor(Color("MercedesPetrolGreen"))
                                }
                            }
                            Text("Cálculos aproximados. Verifique datos reales con instituciones oficiales.")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
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
                
                // Sección: Asistencia (solo botón de ausencia)
                Section {
                    SectionHeader(title: "Asistencia (automática)", subtitle: "Acciones del día")
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
            .onChange(of: salarioMinimoReferenciaString) { _, _ in recalcularNominaPreview() }
            .onChange(of: prestacionesMinimas) { _, _ in recalcularNominaPreview() }
            .onChange(of: tipoSalario) { _, _ in
                recalcularNominaPreview()
            }
            .onChange(of: frecuenciaPago) { _, _ in recalcularNominaPreview() }
            .onChange(of: comisionesString) { _, _ in recalcularNominaPreview() }
            .onChange(of: factorIntegracionString) { _, _ in recalcularNominaPreview() }
            // Limitar a 21 letras (ignora espacios, guiones y apóstrofos) en vivo
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
                .foregroundColor(Color("MercedesPetrolGreen"))
                .cornerRadius(8)
                .disabled(nombreInvalido || emailInvalido || rfcInvalido || horasInvalidas || salarioMinimoInvalido || sinDiasLaborales || comisionesInvalidas || factorIntegracionInvalido || telefonoInvalido || curpInvalido)
                .opacity((nombreInvalido || emailInvalido || rfcInvalido || horasInvalidas || salarioMinimoInvalido || sinDiasLaborales || comisionesInvalidas || factorIntegracionInvalido || telefonoInvalido || curpInvalido) ? 0.6 : 1.0)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 800, minHeight: 600, maxHeight: 600)
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
        
        // Validación de nombre con reglas nuevas
        if let msg = validateNombreCompleto(nombre) {
            errorMsg = msg
            return
        }
        // Normalizar nombre a Título Propio
        let nombreNormalizado = titleCasedName(nombre)
        
        // Parse
        guard let horaEntrada = Int(horaEntradaString),
              let horaSalida = Int(horaSalidaString),
              (0...23).contains(horaEntrada),
              (0...23).contains(horaSalida) else {
            errorMsg = "Las horas deben ser números válidos entre 0 y 23."
            return
        }
        // Rechazar duración cero
        guard horaEntrada != horaSalida else {
            errorMsg = "La hora de entrada y salida no pueden ser iguales."
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
        
        // Validación de duplicidad de RFC
        let rfcToValidate = rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let descriptor = FetchDescriptor<Personal>(
            predicate: #Predicate { $0.rfc == rfcToValidate }
        )
        do {
            let duplicates = try modelContext.fetch(descriptor)
            if let current = mecanicoAEditar {
                // Edición: Verificar si existe otro registro con el mismo RFC (excluyendo el actual)
                if duplicates.contains(where: { $0.persistentModelID != current.persistentModelID }) {
                    errorMsg = "El RFC ya está registrado en otro personal."
                    return
                }
            } else {
                // Nuevo: Verificar si ya existe algún registro con ese RFC
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
        
        // Especialidades
        let especialidadesArray = especialidadesString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Actualización de snapshots vía modelo
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
            mec.estado = estado
            mec.especialidades = especialidadesArray
            mec.tipoContrato = tipoContrato
            mec.horaEntrada = horaEntrada
            mec.horaSalida = horaSalida
            mec.diasLaborales = Array(diasLaborales).sorted()
            
            // Alta/Baja
            mec.activo = activo
            mec.fechaBaja = fechaBaja
            mec.fechaIngreso = fechaIngreso
            
            mec.prestacionesMinimas = prestacionesMinimas
            mec.tipoSalario = tipoSalario
            mec.frecuenciaPago = frecuenciaPago
            mec.salarioMinimoReferencia = salarioMinimoRef
            mec.factorIntegracion = factorIntegracionValor
            mec.comisiones = (tipoSalario == .mixto) ? comisionesValor : comisionesValor // mantenemos el valor acumulado
            
            // Delega el cálculo al modelo (también guarda snapshots)
            mec.recalcularYActualizarSnapshots()
            
            // Sincroniza estados de preview con el modelo (por consistencia)
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
            let nuevo = Personal(
                rfc: rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
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
                
                // Alta/Baja
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
            // Recalcular con el modelo para asegurar consistencia
            nuevo.recalcularYActualizarSnapshots()
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
    
    // Recalcular preview de nómina (live) usando funciones del modelo
    func recalcularNominaPreview() {
        let sm = Double(salarioMinimoReferenciaString.replacingOccurrences(of: ",", with: ".")) ?? 0
        let factor = max(Double(factorIntegracionString.replacingOccurrences(of: ",", with: ".")) ?? 1.0452, 0.0001)
        let com = (Double(comisionesString.replacingOccurrences(of: ",", with: ".")) ?? 0)
        let salarioDiarioBase = sm
        let promCom = (tipoSalario == .mixto) ? (com / diasPromedio) : 0
        
        let sbcCalc = Personal.calcularSBC(salarioDiario: salarioDiarioBase, comisionesPromedioDiarias: promCom, factorIntegracion: factor)
        let (obrera, patronal, imssTotal) = Personal.calcularIMSS(desdeSBC: sbcCalc, salarioDiario: salarioDiarioBase, prestacionesMinimas: prestacionesMinimas)
        let isr = Personal.calcularISR(salarioDiario: salarioDiarioBase, comisionesPromedioDiarias: promCom, tipoSalario: tipoSalario)
        
        let ingresoMensual = (salarioDiarioBase * 30.4) + (tipoSalario == .mixto ? com : 0)
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
    
    // MARK: - Nombre: validación y normalización (con guiones/apóstrofos y minúsculas para artículos)
    
    // Reglas:
    // - Solo letras (incluye acentos y Ñ), espacios, guion (-) y apóstrofo (’ o ').
    // - Entre 1 y 4 palabras separadas por espacios.
    // - Cada subparte (separada por guion o apóstrofo) debe tener al menos 3 letras,
    //   EXCEPTO artículos/preposiciones comunes: de, del, la, los, las, y, o (se aceptan aunque tengan <3).
    // - Máximo 21 letras (contando solo letras, no separadores).
    private func validateNombreCompleto(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "El nombre no puede estar vacío." }
        
        // Aceptar letras (con acentos y Ñ), espacios, guion y apóstrofo (recto y tipográfico)
        let regex = #"^[A-Za-zÁÉÍÓÚÜáéíóúüÑñ '\-’]+$"#
        if NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed) == false {
            return "El nombre solo debe contener letras, espacios, guion (-) y apóstrofo (')."
        }
        
        // Límite de 21 letras (ignora separadores)
        let lettersCount = trimmed.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        if lettersCount > 21 {
            return "Máximo 21 letras (se ignoran espacios y separadores)."
        }
        
        // Palabras por espacios (1...4)
        let words = trimmed.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        if words.isEmpty { return "El nombre no puede estar vacío." }
        if words.count > 4 { return "Máximo 4 palabras en el nombre." }
        
        // Lista blanca de artículos/preposiciones cortas permitidas
        let whitelist = Set(["de", "del", "la", "los", "las", "y", "o"])
        
        // Validar subpartes por guion o apóstrofo
        for word in words {
            // Separar por '-' o apóstrofos (recto y tipográfico)
            let subparts = word.split(whereSeparator: { $0 == "-" || $0 == "'" || $0 == "’" }).map { String($0) }
            for sub in subparts {
                // Contar solo letras
                let subLetters = sub.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
                // Si es una palabra corta en whitelist, permitir aunque tenga < 3 letras
                if whitelist.contains(sub.lowercased()) { continue }
                if subLetters < 3 {
                    return "Cada parte del nombre debe tener al menos 3 letras (p. ej., María-José, O’Connor)."
                }
            }
        }
        return nil
    }
    
    // Title Case:
    // - Capitaliza la primera letra de cada subparte (separada por guion/apóstrofo) con locale es_MX.
    // - Mantiene en minúsculas las palabras cortas de la whitelist si NO son la primera palabra.
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
            // Si la palabra completa es de la whitelist y no es la primera, dejar en minúsculas
            if index > 0 && whitelist.contains(lowerWord) {
                resultWords.append(lowerWord)
                continue
            }
            // Capitalizar subpartes separadas por guion/apóstrofo, preservando los separadores originales
            var rebuilt = ""
            var buffer = ""
            var separators: [Character] = []
            for ch in word {
                if ch == "-" || ch == "'" || ch == "’" {
                    separators.append(ch)
                    // cierra buffer actual como subparte
                    let titled = titleCase(subpart: buffer, locale: locale)
                    rebuilt += titled
                    rebuilt.append(ch)
                    buffer = ""
                } else {
                    buffer.append(ch)
                }
            }
            // último buffer
            let titledLast = titleCase(subpart: buffer, locale: locale)
            rebuilt += titledLast
            
            // Si la palabra no tenía guiones/apóstrofos, rebuilt es el título normal
            // Si la palabra era de whitelist y no es la primera, ya la tratamos arriba
            // Asegurar que la primera palabra siempre va capitalizada
            if index == 0 && whitelist.contains(lowerWord) {
                // Primera palabra en whitelist: capitalizar normal
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
    
    // Recorta una cadena para que tenga como máximo 'maxLetters' letras (ignora separadores)
    private func limitNameToMaxLetters(_ value: String, maxLetters: Int) -> String {
        guard maxLetters > 0 else { return "" }
        var count = 0
        var result = ""
        for ch in value {
            if String(ch).unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) {
                if count < maxLetters {
                    result.append(ch)
                    count += 1
                } else {
                    // si excede, saltamos letras extra
                    continue
                }
            } else {
                // permitir separadores (espacios, guiones, apóstrofos y otros no letras)
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
    // Validación nombre
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

