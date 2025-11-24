import SwiftUI
import SwiftData
internal import Combine

// --- VISTA PRINCIPAL DE "EN PROCESO" + PROGRAMADOS ---
struct EnProcesoView: View {
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppNavigationState
    
    // --- CONSULTAS ---
    @Query private var personal: [Personal]
    @Query private var productos: [Producto]
    @Query(sort: \ServicioEnProceso.horaFinEstimada) private var todosLosTickets: [ServicioEnProceso]
    
    @State private var searchQuery = ""
    @State private var filtroUrgencia: UrgenciaFiltro = .todos
    
    // Modales
    @State private var servicioACerrar: ServicioEnProceso?
    @State private var ticketAReprogramar: ServicioEnProceso?
    @State private var alertaError: String?
    @State private var mostrandoAlerta = false
    
    enum UrgenciaFiltro: String, CaseIterable, Identifiable {
        case todos = "Todos"
        case menosDe30 = "< 30 min"
        case vencidos = "Vencidos"
        case hoy = "Hoy"
        var id: String { rawValue }
    }
    
    // Derivados por estado
    private var ticketsProgramados: [ServicioEnProceso] {
        baseFiltrado(todosLosTickets.filter { $0.estado == .programado })
            .sorted { (a, b) in
                let ai = a.fechaProgramadaInicio ?? a.horaInicio
                let bi = b.fechaProgramadaInicio ?? b.horaInicio
                return ai < bi
            }
    }
    private var ticketsEnProceso: [ServicioEnProceso] {
        baseFiltrado(todosLosTickets.filter { $0.estado == .enProceso })
            .sorted { $0.horaFinEstimada < $1.horaFinEstimada }
    }
    
    // Filtro de texto y urgencia compartido
    private func baseFiltrado(_ lista: [ServicioEnProceso]) -> [ServicioEnProceso] {
        let base: [ServicioEnProceso]
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            base = lista
        } else {
            let q = searchQuery.lowercased()
            base = lista.filter { s in
                let nombreServicioMatch = s.nombreServicio.lowercased().contains(q)
                let placasMatch = s.vehiculo?.placas.lowercased().contains(q) ?? false
                let clienteMatch = s.vehiculo?.cliente?.nombre.lowercased().contains(q) ?? false
                let mecanicoMatch = s.nombreMecanicoAsignado.lowercased().contains(q) ||
                                    (s.nombreMecanicoSugerido?.lowercased().contains(q) ?? false)
                return nombreServicioMatch || placasMatch || clienteMatch || mecanicoMatch
            }
        }
        switch filtroUrgencia {
        case .todos:
            return base
        case .menosDe30:
            return base.filter { $0.estado == .enProceso && $0.tiempoRestanteSegundos > 0 && $0.tiempoRestanteSegundos <= 1800 }
        case .vencidos:
            // Solo aplica a en proceso (programados no tienen “restante” hasta iniciar)
            return base.filter { $0.estado == .enProceso && $0.tiempoRestanteSegundos == 0 }
        case .hoy:
            let cal = Calendar.current
            return base.filter {
                if $0.estado == .programado {
                    if let f = $0.fechaProgramadaInicio {
                        return cal.isDateInToday(f)
                    }
                    return false
                } else {
                    return cal.isDateInToday($0.horaFinEstimada)
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // --- Cabecera ---
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Servicios")
                        .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                    HStack(spacing: 10) {
                        Label("\(ticketsEnProceso.count) en proceso", systemImage: "hammer.circle.fill")
                            .font(.subheadline).foregroundColor(.gray)
                        Label("\(ticketsProgramados.count) programado\(ticketsProgramados.count == 1 ? "" : "s")", systemImage: "calendar.badge.clock")
                            .font(.subheadline).foregroundColor(.gray)
                        if let masCercano = ticketsEnProceso.map(\.horaFinEstimada).min() {
                            let restante = max(0, masCercano.timeIntervalSinceNow)
                            Label("Próximo fin: \(formatearTiempoCorto(segundos: restante))", systemImage: "clock.badge.checkmark")
                                .font(.subheadline).foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
                // Filtros rápidos
                Picker("Urgencia", selection: $filtroUrgencia) {
                    ForEach(UrgenciaFiltro.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 340)
            }
            .padding(.bottom, 4)
            
            // --- Buscador ---
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color("MercedesPetrolGreen"))
                TextField("Buscar por Placa, Cliente, Servicio o Mecánico...", text: $searchQuery)
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
            
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Sección Programados
                    sectionHeader("Programados", count: ticketsProgramados.count, systemImage: "calendar.badge.clock")
                    if ticketsProgramados.isEmpty {
                        emptySection(texto: "No hay servicios programados en este filtro.")
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 18)], spacing: 18) {
                            ForEach(ticketsProgramados) { ticket in
                                ProgramadoCard(
                                    ticket: ticket,
                                    onIniciarAhora: { iniciarTicketAhora(ticket) },
                                    onReprogramar: { ticketAReprogramar = ticket },
                                    onCancelar: { cancelarTicket(ticket) }
                                )
                            }
                        }
                    }
                    
                    // Sección En Proceso
                    sectionHeader("En Proceso", count: ticketsEnProceso.count, systemImage: "timer")
                    if ticketsEnProceso.isEmpty {
                        emptySection(texto: "No hay servicios en proceso en este filtro.")
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 18)], spacing: 18) {
                            ForEach(ticketsEnProceso) { servicio in
                                ServicioEnProcesoCard(servicio: servicio) {
                                    servicioACerrar = servicio
                                }
                            }
                        }
                    }
                }
                .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        // Modales
        .sheet(item: $servicioACerrar) { servicio in
            CierreServicioModalView(
                servicio: servicio,
                personal: personal,
                modelContext: modelContext
            )
        }
        .sheet(item: $ticketAReprogramar) { ticket in
            ProgramarTicketModal(
                ticket: ticket,
                personal: personal,
                productos: productos,
                todosLosTickets: todosLosTickets,
                modelContext: modelContext
            )
        }
        .alert("Operación no completada", isPresented: $mostrandoAlerta, presenting: alertaError) { _ in
            Button("OK") { }
        } message: { mensaje in
            Text(mensaje)
        }
    }
    
    // MARK: - Acciones Programados
    
    private func iniciarTicketAhora(_ ticket: ServicioEnProceso) {
        // 1) Recalcular candidato actual sin solapes y en turno
        let ahora = Date()
        let fin = ahora.addingTimeInterval(ticket.duracionHoras * 3600)
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: ahora)
        let startHour = cal.component(.hour, from: ahora)
        let endHour = cal.component(.hour, from: fin)
        
        let candidatosBase = personal.filter { mec in
            mec.rol == .mecanicoFrenos || true // no conocemos el rol del servicio aquí; usamos sugerido/asignado
        }
        // Intentar usar el sugerido primero si existe y está disponible
        let candidatosElegibles = candidatosBase.filter { mec in
            // Si el ticket tiene sugerido, prioricemos ese RFC
            let coincideSugerido = (ticket.rfcMecanicoSugerido == nil) || (ticket.rfcMecanicoSugerido == mec.rfc)
            let horarioOK = mec.diasLaborales.contains(weekday) && (mec.horaEntrada <= startHour) && (mec.horaSalida >= endHour)
            let sinSolape = !ServicioEnProceso.existeSolape(paraRFC: mec.rfc, inicio: ahora, fin: fin, tickets: todosLosTickets)
            return coincideSugerido && horarioOK && (mec.estado == .disponible) && sinSolape
        }
        guard let mecanico = candidatosElegibles.first ?? personal.first(where: { $0.rfc == ticket.rfcMecanicoSugerido ?? "" && $0.estado == .disponible }) else {
            alertaError = "No hay mecánico disponible para iniciar en este momento sin solapes."
            mostrandoAlerta = true
            return
        }
        
        // 2) Validar stock contra productosConsumidos
        for nombre in ticket.productosConsumidos {
            guard let p = productos.first(where: { $0.nombre == nombre }) else {
                alertaError = "Producto '\(nombre)' no encontrado en inventario."
                mostrandoAlerta = true
                return
            }
            // Nota: no tenemos cantidades por producto en el ticket (solo nombres). Si deseas precisión,
            // guarda cantidades por ingrediente en el ticket. De momento, asumimos cantidad 1.0 como mínima.
            // Para ser conservadores: no bloqueamos aquí si no hay datos de cantidades.
            // Si quisieras validar fuerte, necesitaríamos cantidades.
            if p.cantidad <= 0 {
                alertaError = "Stock insuficiente para '\(p.nombre)'."
                mostrandoAlerta = true
                return
            }
        }
        
        // 3) Descontar inventario (asumimos 1 unidad por producto por limitación actual)
        for nombre in ticket.productosConsumidos {
            if let p = productos.first(where: { $0.nombre == nombre }) {
                p.cantidad = max(0, p.cantidad - 1)
            }
        }
        
        // 4) Cambiar estado del mecánico y del ticket
        mecanico.estado = .ocupado
        
        ticket.estado = .enProceso
        ticket.rfcMecanicoAsignado = mecanico.rfc
        ticket.nombreMecanicoAsignado = mecanico.nombre
        ticket.horaInicio = ahora
        ticket.horaFinEstimada = fin
        
        let registro = DecisionRecord(
            fecha: Date(),
            titulo: "Iniciado: \(ticket.nombreServicio)",
            razon: "Ticket iniciado para [\(ticket.vehiculo?.placas ?? "N/A")] por \(mecanico.nombre).",
            queryUsuario: "Inicio manual de ticket programado"
        )
        modelContext.insert(registro)
    }
    
    private func cancelarTicket(_ ticket: ServicioEnProceso) {
        ticket.estado = .cancelado
        let registro = DecisionRecord(
            fecha: Date(),
            titulo: "Cancelado: \(ticket.nombreServicio)",
            razon: "Se canceló el ticket programado para [\(ticket.vehiculo?.placas ?? "N/A")].",
            queryUsuario: "Cancelación de ticket"
        )
        modelContext.insert(registro)
    }
    
    // MARK: - UI Helpers
    
    private func sectionHeader(_ titulo: String, count: Int, systemImage: String) -> some View {
        HStack {
            Label("\(titulo) (\(count))", systemImage: systemImage)
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    private func emptySection(texto: String) -> some View {
        HStack {
            Image(systemName: "tray")
                .foregroundColor(.gray)
            Text(texto)
                .foregroundColor(.gray)
            Spacer()
        }
        .padding()
        .background(Color("MercedesCard"))
        .cornerRadius(10)
    }
    
    private func formatearTiempoCorto(segundos: Double) -> String {
        let m = Int(segundos) / 60
        let h = m / 60
        let rm = m % 60
        if h > 0 { return "\(h)h \(rm)m" }
        return "\(m)m"
    }
}

// --- TARJETA PARA PROGRAMADOS ---
fileprivate struct ProgramadoCard: View {
    let ticket: ServicioEnProceso
    var onIniciarAhora: () -> Void
    var onReprogramar: () -> Void
    var onCancelar: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ticket.nombreServicio)
                        .font(.title3).fontWeight(.semibold)
                    if let v = ticket.vehiculo {
                        HStack(spacing: 6) {
                            badge(text: "[\(v.placas)]", icon: "number.square.fill")
                            badge(text: "\(v.marca) \(v.modelo)", icon: "car.fill")
                        }
                        .padding(.top, 2)
                        if let cliente = v.cliente?.nombre, !cliente.isEmpty {
                            Label("Cliente: \(cliente)", systemImage: "person.text.rectangle")
                                .font(.caption).foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let nombreSugerido = ticket.nombreMecanicoSugerido {
                        Label(nombreSugerido, systemImage: "person.fill")
                            .font(.subheadline)
                            .foregroundColor(Color("MercedesPetrolGreen"))
                    } else {
                        Label("Sin sugerencia", systemImage: "person.fill.questionmark")
                            .font(.subheadline).foregroundColor(.yellow)
                    }
                    let inicio = ticket.fechaProgramadaInicio ?? ticket.horaInicio
                    Label("Inicio: \(inicio.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar")
                        .font(.caption).foregroundColor(.gray)
                    Text("Duración: \(ticket.duracionHoras, specifier: "%.1f") h")
                        .font(.caption).foregroundColor(.gray)
                }
            }
            Divider().opacity(0.5)
            HStack(spacing: 8) {
                Button {
                    onIniciarAhora()
                } label: {
                    Label("Iniciar ahora", systemImage: "play.circle.fill")
                        .font(.subheadline)
                        .padding(.vertical, 8).padding(.horizontal, 10)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button {
                    onReprogramar()
                } label: {
                    Label("Reprogramar", systemImage: "calendar.badge.plus")
                        .font(.subheadline)
                        .padding(.vertical, 8).padding(.horizontal, 10)
                        .background(Color.blue.opacity(0.25))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button {
                    onCancelar()
                } label: {
                    Label("Cancelar", systemImage: "xmark.circle.fill")
                        .font(.subheadline)
                        .padding(.vertical, 8).padding(.horizontal, 10)
                        .background(Color.red.opacity(0.25))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color("MercedesCard"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color("MercedesBackground").opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
    }
    
    private func badge(text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color("MercedesBackground"))
        .cornerRadius(6)
        .foregroundColor(.white)
    }
}

// --- MODAL PARA REPROGRAMAR TICKET EXISTENTE ---
fileprivate struct ProgramarTicketModal: View {
    @Environment(\.dismiss) private var dismiss
    
    let ticket: ServicioEnProceso
    let personal: [Personal]
    let productos: [Producto]
    let todosLosTickets: [ServicioEnProceso]
    let modelContext: ModelContext
    
    // Estado UI
    @State private var fechaInicio: Date
    @State private var candidato: Personal?
    @State private var conflictoMensaje: String?
    @State private var stockAdvertencia: String?
    
    init(ticket: ServicioEnProceso,
         personal: [Personal],
         productos: [Producto],
         todosLosTickets: [ServicioEnProceso],
         modelContext: ModelContext) {
        self.ticket = ticket
        self.personal = personal
        self.productos = productos
        self.todosLosTickets = todosLosTickets
        self.modelContext = modelContext
        
        _fechaInicio = State(initialValue: ticket.fechaProgramadaInicio ?? Date().addingTimeInterval(2 * 3600))
        _candidato = State(initialValue: nil)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Reprogramar Ticket")
                .font(.title2).fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(ticket.nombreServicio)
                    .font(.headline).fontWeight(.semibold)
                if let v = ticket.vehiculo {
                    HStack(spacing: 8) {
                        chip(text: "[\(v.placas)]", systemImage: "number.square.fill")
                        chip(text: "\(v.marca) \(v.modelo) (\(v.anio))", systemImage: "car.fill")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color("MercedesCard"))
            .cornerRadius(10)
            
            // Fecha
            VStack(alignment: .leading, spacing: 8) {
                Text("Fecha y hora de inicio").font(.headline)
                DatePicker("Inicio", selection: $fechaInicio, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .onChange(of: fechaInicio) { _, _ in recalcularCandidato() }
                Text("Fin estimado: \(fechaInicio.addingTimeInterval(ticket.duracionHoras * 3600).formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundColor(.gray)
            }
            .padding()
            .background(Color("MercedesCard"))
            .cornerRadius(10)
            
            // Candidato y advertencias
            VStack(alignment: .leading, spacing: 8) {
                Text("Candidato sugerido").font(.headline)
                if let c = candidato {
                    HStack {
                        Image(systemName: "person.fill")
                        Text(c.nombre).fontWeight(.semibold)
                        Spacer()
                        Text(c.rol.rawValue).font(.caption2).foregroundColor(.gray)
                    }
                    .padding(8).background(Color("MercedesBackground")).cornerRadius(8)
                } else {
                    Text("No se encontró un candidato disponible para ese horario sin solapes. Intenta otro horario.")
                        .font(.caption).foregroundColor(.red)
                }
                
                if let conflictoMensaje {
                    Label(conflictoMensaje, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                if let stockAdvertencia {
                    Label(stockAdvertencia, systemImage: "shippingbox.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color("MercedesCard"))
            .cornerRadius(10)
            
            // Acciones
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .foregroundColor(.gray)
                Spacer()
                Button {
                    guardarReprogramacion()
                } label: {
                    Label("Guardar Programación", systemImage: "calendar.badge.checkmark")
                        .font(.headline)
                        .padding()
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(candidato == nil)
                .opacity((candidato == nil) ? 0.6 : 1.0)
            }
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 520)
        .background(Color("MercedesBackground"))
        .cornerRadius(12)
        .preferredColorScheme(.dark)
        .onAppear { recalcularCandidato() }
    }
    
    private func chip(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption2)
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color("MercedesBackground"))
        .cornerRadius(8)
    }
    
    private func recalcularCandidato() {
        conflictoMensaje = nil
        stockAdvertencia = nil
        
        let cal = Calendar.current
        let endDate = fechaInicio.addingTimeInterval(ticket.duracionHoras * 3600)
        let weekday = cal.component(.weekday, from: fechaInicio)
        let startHour = cal.component(.hour, from: fechaInicio)
        let endHour = cal.component(.hour, from: endDate)
        
        // Aquí no tenemos el Servicio catálogo original con rol/especialidad.
        // Usamos el rol y disponibilidad del personal; si quieres filtrar por rol,
        // podrías guardar rol requerido en el ticket al crearlo.
        let candidatosBase = personal.filter { mec in
            mec.diasLaborales.contains(weekday) &&
            (mec.horaEntrada <= startHour) && (mec.horaSalida >= endHour)
        }
        
        let candidatosSinSolape = candidatosBase.filter {
            !ServicioEnProceso.existeSolape(paraRFC: $0.rfc, inicio: fechaInicio, fin: endDate, tickets: todosLosTickets)
        }
        
        // Priorizar sugerido si está disponible
        if let rfcSug = ticket.rfcMecanicoSugerido,
           let sug = candidatosSinSolape.first(where: { $0.rfc == rfcSug }) {
            candidato = sug
        } else {
            candidato = candidatosSinSolape.sorted { $0.nombre < $1.nombre }.first
        }
        
        if candidato == nil && !candidatosBase.isEmpty {
            conflictoMensaje = "Todos los candidatos tienen solapes en ese horario."
        } else if candidatosBase.isEmpty {
            conflictoMensaje = "No hay candidatos con turno adecuado."
        }
        
        // Advertencia de stock (informativa)
        var faltantes: [String] = []
        for nombre in ticket.productosConsumidos {
            if let p = productos.first(where: { $0.nombre == nombre }), p.cantidad <= 0 {
                faltantes.append(nombre)
            }
        }
        if !faltantes.isEmpty {
            stockAdvertencia = "Stock insuficiente hoy para: \(faltantes.joined(separator: ", ")). No se reserva; se validará al iniciar."
        }
    }
    
    private func guardarReprogramacion() {
        guard let candidato else { return }
        ticket.estado = .programado
        ticket.fechaProgramadaInicio = fechaInicio
        ticket.rfcMecanicoSugerido = candidato.rfc
        ticket.nombreMecanicoSugerido = candidato.nombre
        
        let registro = DecisionRecord(
            fecha: Date(),
            titulo: "Reprogramado: \(ticket.nombreServicio)",
            razon: "Sugerido para \(candidato.nombre) el \(fechaInicio.formatted(date: .abbreviated, time: .shortened)) para vehículo [\(ticket.vehiculo?.placas ?? "N/A")].",
            queryUsuario: "Reprogramación de Ticket"
        )
        modelContext.insert(registro)
        dismiss()
    }
}

// --- TARJETA DE "TICKET" EN PROCESO (existente, se mantiene) ---
struct ServicioEnProcesoCard: View {
    let servicio: ServicioEnProceso
    var onTerminar: () -> Void
    
    @State private var segundosRestantes: Double
    @State private var confirmando = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(servicio: ServicioEnProceso, onTerminar: @escaping () -> Void) {
        self.servicio = servicio
        self.onTerminar = onTerminar
        _segundosRestantes = State(initialValue: servicio.tiempoRestanteSegundos)
    }
    
    private var progreso: Double {
        // 1.0 cuando recién inicia, 0.0 al terminar
        let total = max(1, servicio.horaFinEstimada.timeIntervalSince(servicio.horaInicio))
        let restante = max(0, servicio.horaFinEstimada.timeIntervalSinceNow)
        return max(0, min(1, restante / total))
    }
    
    private var colorUrgencia: Color {
        if segundosRestantes == 0 { return .red }
        if segundosRestantes <= 1800 { return .yellow }
        return Color("MercedesPetrolGreen")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(servicio.nombreServicio)
                        .font(.title3).fontWeight(.semibold)
                    if let vehiculo = servicio.vehiculo {
                        HStack(spacing: 6) {
                            badge(text: "[\(vehiculo.placas)]", icon: "number.square.fill")
                            badge(text: "\(vehiculo.marca) \(vehiculo.modelo)", icon: "car.fill")
                        }
                        .padding(.top, 2)
                        if let cliente = vehiculo.cliente?.nombre, !cliente.isEmpty {
                            Label("Cliente: \(cliente)", systemImage: "person.text.rectangle")
                                .font(.caption).foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Label(servicio.nombreMecanicoAsignado, systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    Label("Fin: \(servicio.horaFinEstimada.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                        .font(.caption).foregroundColor(.gray)
                }
            }
            
            // Contador
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Tiempo restante")
                        .font(.caption).foregroundColor(.gray)
                    Spacer()
                    Text(segundosRestantes == 0 ? "Vencido" : estadoUrgenciaTexto())
                        .font(.caption2)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(colorUrgencia.opacity(0.18))
                        .foregroundColor(colorUrgencia)
                        .cornerRadius(6)
                }
                HStack(alignment: .lastTextBaseline) {
                    Text(formatearTiempo(segundos: segundosRestantes))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    ProgressView(value: 1 - progreso)
                        .progressViewStyle(.linear)
                        .tint(colorUrgencia)
                        .frame(width: 120)
                }
            }
            
            Divider().opacity(0.5)
            
            // Botón terminar con confirmación inline
            if confirmando {
                HStack(spacing: 10) {
                    Button {
                        onTerminar()
                    } label: {
                        Label("Confirmar cierre", systemImage: "checkmark.circle.fill")
                            .font(.subheadline).padding(.vertical, 8).padding(.horizontal, 10)
                            .background(Color("MercedesPetrolGreen"))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    Button {
                        withAnimation(.spring(response: 0.25)) { confirmando = false }
                    } label: {
                        Label("Cancelar", systemImage: "xmark")
                            .font(.subheadline).padding(.vertical, 8).padding(.horizontal, 10)
                            .background(Color.gray.opacity(0.25))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Button {
                    withAnimation(.spring(response: 0.25)) { confirmando = true }
                } label: {
                    Label(segundosRestantes == 0 ? "Finalizar (Tiempo agotado)" : "Terminar Trabajo Ahora",
                          systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(segundosRestantes == 0 ? Color.red.opacity(0.35) : Color.gray.opacity(0.35))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color("MercedesCard"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(colorUrgencia.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        .onReceive(timer) { _ in
            if segundosRestantes > 0 {
                segundosRestantes -= 1
            } else {
                timer.upstream.connect().cancel()
            }
        }
    }
    
    private func estadoUrgenciaTexto() -> String {
        if segundosRestantes <= 0 { return "Vencido" }
        if segundosRestantes <= 600 { return "Crítico" }
        if segundosRestantes <= 1800 { return "Pronto" }
        return "En tiempo"
    }
    
    private func badge(text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color("MercedesBackground"))
        .cornerRadius(6)
        .foregroundColor(.white)
    }
    
    func formatearTiempo(segundos: Double) -> String {
        let horas = Int(segundos) / 3600
        let minutos = (Int(segundos) % 3600) / 60
        let segs = Int(segundos) % 60
        return String(format: "%02i:%02i:%02i", horas, minutos, segs)
    }
}


// --- MODAL DE CIERRE (existente, se mantiene) ---
fileprivate struct CierreServicioModalView: View {
    @Environment(\.dismiss) private var dismiss
    
    let servicio: ServicioEnProceso
    let personal: [Personal]
    let modelContext: ModelContext
    
    @State private var observaciones = ""
    @State private var mostrandoConfirmacion = false
    
    var body: some View {
        VStack(spacing: 18) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cierre de Servicio")
                        .font(.largeTitle).fontWeight(.bold)
                    Text(servicio.nombreServicio)
                        .font(.title3).foregroundColor(.gray)
                }
                Spacer()
                estadoChip
            }
            
            // Resumen
            resumenView
            
            // Observaciones
            VStack(alignment: .leading, spacing: 8) {
                Text("Observaciones (Opcional)")
                    .font(.headline)
                Text("Añade notas útiles sobre el servicio (p. ej. 'Se cambiaron tornillos extra').")
                    .font(.subheadline).foregroundColor(.gray)
                TextEditor(text: $observaciones)
                    .frame(minHeight: 140)
                    .font(.body)
                    .padding(8)
                    .background(Color("MercedesBackground"))
                    .cornerRadius(10)
            }
            
            Spacer(minLength: 0)
            
            // Acciones
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain)
                    .padding()
                    .foregroundColor(.gray)
                Spacer()
                Button {
                    if mostrandoConfirmacion {
                        completarServicio()
                    } else {
                        withAnimation(.spring(response: 0.25)) { mostrandoConfirmacion = true }
                    }
                } label: {
                    Label(mostrandoConfirmacion ? "Confirmar cierre" : "Confirmar y Cerrar Servicio",
                          systemImage: mostrandoConfirmacion ? "archivebox" : "archivebox.fill")
                        .font(.headline)
                        .padding()
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .frame(minWidth: 560, minHeight: 520)
        .background(Color("MercedesCard"))
        .cornerRadius(15)
        .preferredColorScheme(.dark)
        .textFieldStyle(PlainTextFieldStyle())
    }
    
    private var estadoChip: some View {
        let restante = servicio.tiempoRestanteSegundos
        let color: Color = restante == 0 ? .red : (restante <= 1800 ? .yellow : Color("MercedesPetrolGreen"))
        let texto: String = restante == 0 ? "Vencido" : (restante <= 600 ? "Crítico" : (restante <= 1800 ? "Pronto" : "En tiempo"))
        return Text(texto)
            .font(.caption)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .cornerRadius(8)
    }
    
    private var resumenView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .foregroundColor(Color("MercedesPetrolGreen"))
                VStack(alignment: .leading, spacing: 2) {
                    if let v = servicio.vehiculo {
                        Text("[\(v.placas)] \(v.marca) \(v.modelo)")
                            .font(.headline)
                        Text("Cliente: \(v.cliente?.nombre ?? "N/A")")
                            .font(.caption).foregroundColor(.gray)
                    } else {
                        Text("Vehículo: N/A").font(.headline)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Label(servicio.nombreMecanicoAsignado, systemImage: "person.fill")
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    Text("Inicio: \(servicio.horaInicio.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundColor(.gray)
                    Text("Fin estimado: \(servicio.horaFinEstimada.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundColor(.gray)
                }
            }
            Divider().opacity(0.5)
            HStack {
                Label("Tiempo restante", systemImage: "clock")
                    .foregroundColor(.gray)
                Spacer()
                Text(formatearTiempo(segundos: servicio.tiempoRestanteSegundos))
                    .font(.system(.title3, design: .monospaced)).bold()
            }
        }
        .padding(12)
        .background(Color("MercedesBackground"))
        .cornerRadius(10)
    }
    
    // --- LÓGICA DE CIERRE FINAL ---
    func completarServicio() {
        if let mecanico = personal.first(where: { $0.rfc == servicio.rfcMecanicoAsignado }) {
            mecanico.estado = .disponible
        }
        
        let registro = DecisionRecord(
            fecha: Date(),
            titulo: "Completado: \(servicio.nombreServicio)",
            razon: """
            Vehículo: [\(servicio.vehiculo?.placas ?? "N/A")] - \(servicio.vehiculo?.cliente?.nombre ?? "N/A")
            Asignado a: \(servicio.nombreMecanicoAsignado)
            Observaciones: \(observaciones.isEmpty ? "Sin observaciones." : observaciones)
            """,
            queryUsuario: "Cierre de Servicio"
        )
        modelContext.insert(registro)
        modelContext.delete(servicio)
        dismiss()
    }
    
    private func formatearTiempo(segundos: Double) -> String {
        let horas = Int(segundos) / 3600
        let minutos = (Int(segundos) % 3600) / 60
        let segs = Int(segundos) % 60
        return String(format: "%02i:%02i:%02i", horas, minutos, segs)
    }
}
