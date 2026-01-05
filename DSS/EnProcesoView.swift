//
//  EnProcesoView.swift
//  DSS
//
// Copyright © 2026 José Manuel Cisneros Valero
// Licensed under the Apache License, Version 2.0

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
    @Query private var servicios: [Servicio]
    @Query(sort: \ServicioEnProceso.horaFinEstimada) private var todosLosTickets: [ServicioEnProceso]
    
    @State private var searchQuery = ""
    @State private var filtroUrgencia: UrgenciaFiltro = .todos
    
    // NUEVO: Filtros y Ordenamiento avanzados
    enum SortOption: String, CaseIterable, Identifiable {
        case fechaInicio = "Hora de Inicio"
        case fechaFin = "Fin Estimado"
        case cliente = "Cliente"
        case servicio = "Servicio"
        var id: String { rawValue }
    }
    
    @State private var sortOption: SortOption = .fechaInicio
    @State private var sortAscending: Bool = true
    @State private var filtroMecanico: String = "Todos" // Guarda RFC o "Todos"
    
    // Modales
    @State private var servicioACerrar: ServicioEnProceso?
    @State private var ticketAReprogramar: ServicioEnProceso?
    @State private var alertaError: String?
    @State private var mostrandoAlerta = false
    
    // NUEVO: Confirmación de cancelación de programado
    @State private var ticketACancelar: ServicioEnProceso?
    @State private var mostrandoConfirmacionCancelacion = false
    
    // Timer de auto-inicio (cada 30s revisa programados vencidos)
    private let autoStartTimer = Timer.publish(every: 0, on: .main, in: .common).autoconnect()
    
    enum UrgenciaFiltro: String, CaseIterable, Identifiable {
        case todos = "Todos"
        case menosDe30 = "< 30 min"
        case vencidos = "Vencidos"
        case hoy = "Hoy"
        var id: String { rawValue }
    }
    
    // Derivados por estado
    private var ticketsProgramados: [ServicioEnProceso] {
        ordenarResultados(baseFiltrado(todosLosTickets.filter { $0.estado == .programado }))
    }
    private var ticketsEnProceso: [ServicioEnProceso] {
        ordenarResultados(baseFiltrado(todosLosTickets.filter { $0.estado == .enProceso }))
    }
    
    // Lógica consolidada de ordenamiento
    private func ordenarResultados(_ lista: [ServicioEnProceso]) -> [ServicioEnProceso] {
        lista.sorted { a, b in
            switch sortOption {
            case .fechaInicio:
                let ai = a.fechaProgramadaInicio ?? a.horaInicio
                let bi = b.fechaProgramadaInicio ?? b.horaInicio
                return sortAscending ? (ai < bi) : (ai > bi)
            case .fechaFin:
                return sortAscending ? (a.horaFinEstimada < b.horaFinEstimada) : (a.horaFinEstimada > b.horaFinEstimada)
            case .cliente:
                let ca = a.vehiculo?.cliente?.nombre ?? ""
                let cb = b.vehiculo?.cliente?.nombre ?? ""
                return sortAscending ? (ca.localizedCaseInsensitiveCompare(cb) == .orderedAscending)
                                     : (ca.localizedCaseInsensitiveCompare(cb) == .orderedDescending)
            case .servicio:
                return sortAscending ? (a.nombreServicio.localizedCaseInsensitiveCompare(b.nombreServicio) == .orderedAscending)
                                     : (a.nombreServicio.localizedCaseInsensitiveCompare(b.nombreServicio) == .orderedDescending)
            }
        }
    }
    
    // Filtro de texto y urgencia compartido
    private func baseFiltrado(_ lista: [ServicioEnProceso]) -> [ServicioEnProceso] {
        var base: [ServicioEnProceso]
        
        // 1. Filtro Texto
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
        
        // 2. Filtro Mecánico
        if filtroMecanico != "Todos" {
            base = base.filter { s in
                // Coincidencia exacta por RFC si es posible, o por nombre si guardamos nombre.
                // Como filtroMecanico guarda el nombre (o RFC), lo compararemos.
                // Mejor usar RFC para precisión si tenemos acceso a la lista de personal.
                // Aquí asumiré que filtroMecanico guarda el RFC.
                if let _ = personal.first(where: { $0.rfc == filtroMecanico }) {
                    // Es un RFC válido
                    return s.rfcMecanicoAsignado == filtroMecanico || s.rfcMecanicoSugerido == filtroMecanico
                } else {
                    // Fallback a comparación flexible si fuera texto
                    return true
                }
            }
        }
        
        // 3. Filtro Urgencia
        switch filtroUrgencia {
        case .todos:
            return base
        case .menosDe30:
            return base.filter { $0.estado == .enProceso && $0.tiempoRestanteSegundos > 0 && $0.tiempoRestanteSegundos <= 1800 }
        case .vencidos:
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
        VStack(alignment: .leading, spacing: 12) {
            // Header compacto alineado a ServiciosView
            header
            
            // Barra de búsqueda + filtros compacta
            filtrosView
            
            // Contenido
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    
                    // Contadores globales
                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .foregroundColor(Color("MercedesPetrolGreen"))
                        Text("\(ticketsEnProceso.count + ticketsProgramados.count) resultado\(ticketsEnProceso.count + ticketsProgramados.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    
                    // Sección Programados
                    sectionHeader("Programados", count: ticketsProgramados.count, systemImage: "calendar.badge.clock")
                    if ticketsProgramados.isEmpty {
                        emptySection(texto: searchQuery.isEmpty && filtroUrgencia == .todos && filtroMecanico == "Todos" ? "No hay servicios programados." : "No hay servicios programados con estos filtros.")
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 12)], spacing: 12) {
                            ForEach(ticketsProgramados) { ticket in
                                ProgramadoCard(
                                    ticket: ticket,
                                    onIniciarAhora: { iniciarTicketAhora(ticket) },
                                    onReprogramar: { ticketAReprogramar = ticket },
                                    // NUEVO: solicitar confirmación
                                    onSolicitarCancelar: {
                                        ticketACancelar = ticket
                                        mostrandoConfirmacionCancelacion = true
                                    }
                                )
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Sección En Proceso
                    sectionHeader("En Proceso", count: ticketsEnProceso.count, systemImage: "timer")
                    if ticketsEnProceso.isEmpty {
                        emptySection(texto: searchQuery.isEmpty && filtroUrgencia == .todos && filtroMecanico == "Todos" ? "No hay servicios en proceso." : "No hay servicios en proceso con estos filtros.")
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 12)], spacing: 12) {
                            ForEach(ticketsEnProceso) { servicio in
                                ServicioEnProcesoCard(servicio: servicio) {
                                    servicioACerrar = servicio
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
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
        // Modales
        .sheet(item: $servicioACerrar) { servicio in
            CierreServicioModalView(
                servicio: servicio,
                personal: personal,
                modelContext: modelContext,
                servicios: servicios
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
        // NUEVO: Confirmación de cancelación con mensaje dinámico
        .confirmationDialog(
            "Cancelar servicio programado",
            isPresented: $mostrandoConfirmacionCancelacion,
            titleVisibility: .visible
        ) {
            Button("Cancelar servicio", role: .destructive) {
                if let t = ticketACancelar {
                    cancelarTicket(t)
                }
                ticketACancelar = nil
            }
            Button("Volver", role: .cancel) {
                ticketACancelar = nil
            }
        } message: {
            let nombre = ticketACancelar?.nombreServicio ?? "Servicio"
            let placas = ticketACancelar?.vehiculo?.placas ?? "N/A"
            Text("¿Seguro que quieres cancelar ‘\(nombre)’ para [\(placas)]? Esta acción no se puede deshacer.")
        }
        // Auto-inicio
        .onReceive(autoStartTimer) { _ in
            autoIniciarTicketsProgramadosSiCorresponde()
        }
        .onAppear {
            autoIniciarTicketsProgramadosSiCorresponde()
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header y Filtros (alineados a ServiciosView)
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
                    Text("Servicios en Proceso")
                        .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    HStack(spacing: 10) {
                        Label("\(ticketsEnProceso.count) en proceso", systemImage: "hammer.circle.fill")
                            .font(.footnote).foregroundColor(.gray)
                        Label("\(ticketsProgramados.count) programado\(ticketsProgramados.count == 1 ? "" : "s")", systemImage: "calendar.badge.clock")
                            .font(.footnote).foregroundColor(.gray)
                        if let masCercano = ticketsEnProceso.map(\.horaFinEstimada).min() {
                            let restante = max(0, masCercano.timeIntervalSinceNow)
                            Label("Próximo fin: \(formatearTiempoCorto(segundos: restante))", systemImage: "clock.badge.checkmark")
                                .font(.footnote).foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
        }
    }
    
    // Lista de mecánicos disponibles en el sistema (activos) para el filtro
    private var listaMecanicos: [Personal] {
        personal.filter { $0.activo && $0.rol != .atencionCliente }.sorted { $0.nombre < $1.nombre }
    }
    
    private var filtrosView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Buscar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    TextField("Buscar por Placa, Cliente, Servicio o Mecánico...", text: $searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.subheadline)
                        .animation(.easeInOut(duration: 0.15), value: searchQuery)
                    if !searchQuery.isEmpty {
                        Button {
                            withAnimation { searchQuery = "" }
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
                
                // Menú Unificado de Filtros
                Menu {
                    // Sección 1: Ordenamiento
                    Section("Ordenamiento") {
                        ForEach(SortOption.allCases) { opt in
                            Button {
                                sortOption = opt
                            } label: {
                                if sortOption == opt {
                                    Label(opt.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(opt.rawValue)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Sección 2: Mecánico (Filtrado)
                    Section("Filtrar por Mecánico") {
                        Button {
                            filtroMecanico = "Todos"
                        } label: {
                            if filtroMecanico == "Todos" {
                                Label("Todos", systemImage: "checkmark")
                            } else {
                                Text("Todos")
                            }
                        }
                        ForEach(listaMecanicos) { mec in
                            Button {
                                filtroMecanico = mec.rfc
                            } label: {
                                if filtroMecanico == mec.rfc {
                                    Label(mec.nombre, systemImage: "checkmark")
                                } else {
                                    Text(mec.nombre)
                                }
                            }
                        }
                    }
                     
                    Divider()
                    
                    // Sección 3: Urgencia / Tiempo
                    Section("Tiempo / Estado") {
                        ForEach(UrgenciaFiltro.allCases) { f in
                            Button {
                                filtroUrgencia = f
                            } label: {
                                if filtroUrgencia == f {
                                    Label(f.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(f.rawValue)
                                }
                            }
                        }
                    }
                    
                } label: {
                    HStack(spacing: 6) {
                        // Texto dinámico: Prioridad Mecánico > Urgencia > Orden
                        let labelText: String = {
                            var parts: [String] = []
                            if filtroMecanico != "Todos" {
                                // Buscar nombre para mostrar bonito
                                let nombre = listaMecanicos.first(where: { $0.rfc == filtroMecanico })?.nombre ?? "Mecánico"
                                parts.append(nombre)
                            }
                            if filtroUrgencia != .todos {
                                parts.append(filtroUrgencia.rawValue)
                            }
                            if parts.isEmpty {
                                return "Ordenar por \(sortOption.rawValue)"
                            } else {
                                return parts.joined(separator: " + ")
                            }
                        }()
                        
                        Text(labelText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .font(.subheadline)
                    .padding(8)
                    .background(Color("MercedesCard"))
                    .cornerRadius(8)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 220)
                
                // Botón dirección (Asc/Desc)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sortAscending.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                    }
                    .font(.subheadline)
                    .padding(8)
                    .background(Color("MercedesCard"))
                    .cornerRadius(8)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                }
                .buttonStyle(.plain)
                .help("Cambiar orden \(sortAscending ? "ascendente" : "descendente")")
                
                Spacer()
            }
        }
    }
    
    // MARK: - Auto-inicio programados
    
    private func autoIniciarTicketsProgramadosSiCorresponde() {
        let ahora = Date()
        let pendientes = todosLosTickets.filter {
            $0.estado == .programado && ($0.fechaProgramadaInicio ?? Date.distantFuture) <= ahora
        }
        guard !pendientes.isEmpty else { return }
        for t in pendientes {
            iniciarTicketProgramadoSiEsHora(t, silencioso: true)
        }
    }
    
    // Intenta iniciar un ticket programado. Si silencioso == true, no muestra alertas; solo registra.
    private func iniciarTicketProgramadoSiEsHora(_ ticket: ServicioEnProceso, silencioso: Bool) {
        guard ticket.estado == .programado,
              let inicioProgramado = ticket.fechaProgramadaInicio,
              inicioProgramado <= Date() else { return }
        
        let ahora = Date()
        let fin = ahora.addingTimeInterval(ticket.duracionHoras * 3600)
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: ahora)
        let startHour = cal.component(.hour, from: ahora)
        let endHour = cal.component(.hour, from: fin)
        
        let candidatosBase = personal
        
        let candidatosElegibles = candidatosBase.filter { mec in
            let coincideSugerido = (ticket.rfcMecanicoSugerido == nil) || (ticket.rfcMecanicoSugerido == mec.rfc)
            let horarioOK = mec.diasLaborales.contains(weekday) && (mec.horaEntrada <= startHour) && (mec.horaSalida >= endHour)
            let sinSolape = !ServicioEnProceso.existeSolape(paraRFC: mec.rfc, inicio: ahora, fin: fin, tickets: todosLosTickets)
            return coincideSugerido && horarioOK && (mec.estado == .disponible) && sinSolape
        }
        
        guard let mecanico = candidatosElegibles.first ?? personal.first(where: { $0.rfc == ticket.rfcMecanicoSugerido ?? "" && $0.estado == .disponible }) else {
            if !silencioso {
                alertaError = "No hay mecánico disponible para iniciar el ticket programado."
                mostrandoAlerta = true
            }
            let registro = DecisionRecord(
                fecha: Date(),
                titulo: "Auto-inicio fallido: \(ticket.nombreServicio)",
                razon: "No hay mecánico disponible sin solapes para vehículo [\(ticket.vehiculo?.placas ?? "N/A")]. Se reintentará.",
                queryUsuario: "Scheduler de Programados"
            )
            modelContext.insert(registro)
            return
        }
        
        // Lógica ROBUSTA: Buscar servicio para saber cantidades
        // Si encontramos la definición del servicio, usamos sus ingredientes y cantidades (litros, etc).
        // Si no (ej. borrado), hacemos fallback a "1 unidad por producto" de la lista del ticket.
        if let servicioDef = servicios.first(where: { $0.nombre == ticket.nombreServicio }) {
            // 1. Validar Stock
            for ing in servicioDef.ingredientes {
                guard let p = productos.first(where: { $0.nombre == ing.nombreProducto }) else {
                    if !silencioso {
                        alertaError = "Producto '\(ing.nombreProducto)' no encontrado en inventario."
                        mostrandoAlerta = true
                    }
                    return
                }
                
                let contenidoPorUnidad = max(p.contenidoNeto, 0.0001)
                let totalContenido = p.cantidad * contenidoPorUnidad
                
                if totalContenido < ing.cantidadUsada {
                    if !silencioso {
                        alertaError = "Stock insuficiente para '\(p.nombre)' (Req: \(ing.cantidadUsada), Disp: \(totalContenido))."
                        mostrandoAlerta = true
                    }
                    let registro = DecisionRecord(
                        fecha: Date(),
                        titulo: "Auto-inicio fallido: \(ticket.nombreServicio)",
                        razon: "Stock insuficiente de '\(p.nombre)'.",
                        queryUsuario: "Scheduler de Programados"
                    )
                    modelContext.insert(registro)
                    return
                }
            }
            
            // 2. Consumir Stock
            for ing in servicioDef.ingredientes {
                if let p = productos.first(where: { $0.nombre == ing.nombreProducto }) {
                    let contenidoPorUnidad = max(p.contenidoNeto, 0.0001)
                    let total = p.cantidad * contenidoPorUnidad
                    let restante = total - ing.cantidadUsada
                    p.cantidad = max(0, restante / contenidoPorUnidad)
                }
            }
        } else {
            // Fallback: Servicio no encontrado en catálogo activo
            for nombre in ticket.productosConsumidos {
                guard let p = productos.first(where: { $0.nombre == nombre }) else {
                    if !silencioso {
                        alertaError = "Producto '\(nombre)' no encontrado."
                        mostrandoAlerta = true
                    }
                    return
                }
                if p.cantidad < 1 {
                    if !silencioso {
                        alertaError = "Stock insuficiente para '\(p.nombre)'."
                        mostrandoAlerta = true
                    }
                    return
                }
            }
            
            for nombre in ticket.productosConsumidos {
                if let p = productos.first(where: { $0.nombre == nombre }) {
                    p.cantidad = max(0, p.cantidad - 1)
                }
            }
        }
        
        mecanico.estado = .ocupado
        ticket.estado = .enProceso
        ticket.rfcMecanicoAsignado = mecanico.rfc
        ticket.nombreMecanicoAsignado = mecanico.nombre
        ticket.horaInicio = ahora
        // Usar la lógica de horario laboral para calcular el fin estimado real
        ticket.horaFinEstimada = mecanico.calcularFechaFin(inicio: ahora, duracionHoras: ticket.duracionHoras)
        
        HistorialLogger.logAutomatico(
            context: modelContext,
            titulo: "Auto-iniciado: \(ticket.nombreServicio)",
            detalle: "Ticket programado iniciado para [\(ticket.vehiculo?.placas ?? "N/A")] por \(mecanico.nombre).",
            categoria: .programacion,
            entidadAfectada: ticket.nombreServicio
        )
        
        // NUEVO: Incrementar contador Top 5
        if let serv = servicios.first(where: { $0.nombre == ticket.nombreServicio }) {
            serv.vecesRealizado += 1
        }
    }
    
    // MARK: - Acciones Programados (manual)
    
    private func iniciarTicketAhora(_ ticket: ServicioEnProceso) {
        let ahora = Date()
        let fin = ahora.addingTimeInterval(ticket.duracionHoras * 3600)
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: ahora)
        let startHour = cal.component(.hour, from: ahora)
        let endHour = cal.component(.hour, from: fin)
        
        let candidatosBase = personal.filter { _ in
            true // mantenemos lógica actual (sugerido si posible)
        }
        let candidatosElegibles = candidatosBase.filter { mec in
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
        
        if let servicioDef = servicios.first(where: { $0.nombre == ticket.nombreServicio }) {
             // 1. Validar Stock
             for ing in servicioDef.ingredientes {
                 guard let p = productos.first(where: { $0.nombre == ing.nombreProducto }) else {
                     alertaError = "Producto '\(ing.nombreProducto)' no encontrado en inventario."
                     mostrandoAlerta = true
                     return
                 }
                 
                 let contenidoPorUnidad = max(p.contenidoNeto, 0.0001)
                 let totalContenido = p.cantidad * contenidoPorUnidad
                 
                 if totalContenido < ing.cantidadUsada {
                     alertaError = "Stock insuficiente para '\(p.nombre)' (Req: \(ing.cantidadUsada), Disp: \(totalContenido))."
                     mostrandoAlerta = true
                     return
                 }
             }
             
             // 2. Consumir Stock
             for ing in servicioDef.ingredientes {
                 if let p = productos.first(where: { $0.nombre == ing.nombreProducto }) {
                     let contenidoPorUnidad = max(p.contenidoNeto, 0.0001)
                     let total = p.cantidad * contenidoPorUnidad
                     let restante = total - ing.cantidadUsada
                     p.cantidad = max(0, restante / contenidoPorUnidad)
                 }
             }
        } else {
             // Fallback
             for nombre in ticket.productosConsumidos {
                 guard let p = productos.first(where: { $0.nombre == nombre }) else {
                     alertaError = "Producto '\(nombre)' no encontrado en inventario."
                     mostrandoAlerta = true
                     return
                 }
                 if p.cantidad < 1 {
                     alertaError = "Stock insuficiente para '\(p.nombre)'."
                     mostrandoAlerta = true
                     return
                 }
             }
             
             for nombre in ticket.productosConsumidos {
                 if let p = productos.first(where: { $0.nombre == nombre }) {
                     p.cantidad = max(0, p.cantidad - 1)
                 }
             }
        }
        
        mecanico.estado = .ocupado
        
        ticket.estado = .enProceso
        ticket.rfcMecanicoAsignado = mecanico.rfc
        ticket.nombreMecanicoAsignado = mecanico.nombre
        ticket.horaInicio = ahora
        // Usar la lógica de horario laboral para calcular el fin estimado real
        ticket.horaFinEstimada = mecanico.calcularFechaFin(inicio: ahora, duracionHoras: ticket.duracionHoras)
        
        HistorialLogger.logAutomatico(
            context: modelContext,
            titulo: "Iniciado: \(ticket.nombreServicio)",
            detalle: "Ticket iniciado para [\(ticket.vehiculo?.placas ?? "N/A")] por \(mecanico.nombre).",
            categoria: .programacion,
            entidadAfectada: ticket.nombreServicio
        )
        
        // NUEVO: Incrementar contador Top 5
        if let serv = servicios.first(where: { $0.nombre == ticket.nombreServicio }) {
            serv.vecesRealizado += 1
        }
    }
    
    private func cancelarTicket(_ ticket: ServicioEnProceso) {
        ticket.estado = .cancelado
        HistorialLogger.logAutomatico(
            context: modelContext,
            titulo: "Cancelado: \(ticket.nombreServicio)",
            detalle: "Se canceló el ticket programado para [\(ticket.vehiculo?.placas ?? "N/A")].",
            categoria: .programacion,
            entidadAfectada: ticket.nombreServicio
        )
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
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(Color("MercedesPetrolGreen"))
            Text(texto)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Color("MercedesCard")
                LinearGradient(colors: [Color.white.opacity(0.012), Color("MercedesBackground").opacity(0.06)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        )
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
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
    // NUEVO: callback para solicitar cancelación (con confirmación en el padre)
    var onSolicitarCancelar: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ticket.nombreServicio)
                        .font(.headline).fontWeight(.semibold)
                    if let v = ticket.vehiculo {
                        HStack(spacing: 6) {
                            badge(text: "[\(v.placas)]", icon: "number.square.fill")
                            badge(text: "\(v.marca) \(v.modelo)", icon: "car.fill")
                        }
                        .padding(.top, 2)
                        if let cliente = v.cliente?.nombre, !cliente.isEmpty {
                            Label("Cliente: \(cliente)", systemImage: "person.text.rectangle")
                                .font(.caption2).foregroundColor(.gray)
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
                        .font(.caption2).foregroundColor(.gray)
                    Text("Duración: \(ticket.duracionHoras, specifier: "%.1f") h")
                        .font(.caption2).foregroundColor(.gray)
                }
            }
            Divider().opacity(0.5)
            HStack(spacing: 8) {
                /* Button {
                    onIniciarAhora()
                } label: {
                    Label("Iniciar ahora", systemImage: "play.circle.fill")
                        .font(.subheadline)
                        .padding(.vertical, 8).padding(.horizontal, 10)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain) */
                
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
                    onSolicitarCancelar()
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
    }
    
    private func badge(text: String, icon: String) -> some View {
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
    @State private var horaTexto: String = ""

    var isHoraValida: Bool {
        let cal = Calendar.current
        let hora = cal.component(.hour, from: fechaInicio)
        let minuto = cal.component(.minute, from: fechaInicio)
        if hora < 6 { return false }
        if hora > 20 { return false }
        if hora == 20 && minuto > 0 { return false }
        return true
    }
    
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
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        _horaTexto = State(initialValue: formatter.string(from: (ticket.fechaProgramadaInicio ?? Date().addingTimeInterval(2 * 3600))))
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
                DatePicker("", selection: $fechaInicio, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .onChange(of: fechaInicio) { _, newValue in
                         recalcularCandidato()
                         let formatter = DateFormatter()
                         formatter.dateFormat = "HH:mm"
                         let str = formatter.string(from: newValue)
                         if horaTexto != str { horaTexto = str }
                    }
                
                // Input manual de hora y validación
                HStack {
                    Image(systemName: "clock").foregroundColor(.gray)
                    TextField("HH:mm (24h)", text: $horaTexto)
                        .textFieldStyle(.plain)
                        .onChange(of: horaTexto) { _, newValue in
                            let formatter = DateFormatter()
                            formatter.dateFormat = "HH:mm"
                            if let dateTime = formatter.date(from: newValue) {
                                let cal = Calendar.current
                                let compTime = cal.dateComponents([.hour, .minute], from: dateTime)
                                let compDate = cal.dateComponents([.year, .month, .day], from: fechaInicio)
                                var newComps = DateComponents()
                                newComps.year = compDate.year
                                newComps.month = compDate.month
                                newComps.day = compDate.day
                                newComps.hour = compTime.hour
                                newComps.minute = compTime.minute
                                if let newDate = cal.date(from: newComps), newDate != fechaInicio {
                                    fechaInicio = newDate
                                }
                            }
                        }
                }
                .padding(8)
                .background(Color("MercedesBackground"))
                .cornerRadius(8)
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

                if fechaInicio < Date() {
                    Label("La fecha de inicio no puede ser en el pasado.", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                if !isHoraValida {
                    Label("El horario de programación debe ser entre 06:00 AM y 08:00 PM.", systemImage: "clock.badge.exclamationmark.fill")
                        .font(.caption)
                        .foregroundColor(.red)
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
                .disabled(candidato == nil || fechaInicio < Date() || !isHoraValida)
                .opacity((candidato == nil || fechaInicio < Date() || !isHoraValida) ? 0.6 : 1.0)
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
        
        let candidatosBase = personal.filter { mec in
            mec.diasLaborales.contains(weekday) &&
            (mec.horaEntrada <= startHour) && (mec.horaSalida >= endHour)
        }
        
        let candidatosSinSolape = candidatosBase.filter {
            !ServicioEnProceso.existeSolape(paraRFC: $0.rfc, inicio: fechaInicio, fin: endDate, tickets: todosLosTickets, ignoringID: ticket.id)
        }
        
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
        
        HistorialLogger.logAutomatico(
            context: modelContext,
            titulo: "Reprogramado: \(ticket.nombreServicio)",
            detalle: "Sugerido para \(candidato.nombre) el \(fechaInicio.formatted(date: .abbreviated, time: .shortened)) para vehículo [\(ticket.vehiculo?.placas ?? "N/A")].",
            categoria: .programacion,
            entidadAfectada: ticket.nombreServicio
        )
        dismiss()
    }
}

// --- TARJETA DE "TICKET" EN PROCESO (existente, se mantiene) ---
struct ServicioEnProcesoCard: View {
    let servicio: ServicioEnProceso
    var onTerminar: () -> Void
    
    @Query private var personal: [Personal]
    
    @State private var segundosRestantes: Double
    @State private var confirmando = false
    @State private var estaPausado = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(servicio: ServicioEnProceso, onTerminar: @escaping () -> Void) {
        self.servicio = servicio
        self.onTerminar = onTerminar
        // Inicialización temporal, se ajusta en onAppear
        _segundosRestantes = State(initialValue: servicio.tiempoRestanteSegundos)
    }
    
    private var mecanicoAsignado: Personal? {
        personal.first(where: { $0.rfc == servicio.rfcMecanicoAsignado })
    }
    
    private var progreso: Double {
        // El progreso visual es relativo al tiempo total estimado vs el restante laboral
        // Si está pausado, no avanza.
        // Calculamos un total teórico basado en duración horas (que son horas laborales)
        let totalSegundosLaborales = servicio.duracionHoras * 3600
        let restante = segundosRestantes
        return max(0, min(1, restante / totalSegundosLaborales))
    }
    
    private var colorUrgencia: Color {
        if estaPausado { return .gray }
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
                        .font(.headline).fontWeight(.semibold)
                    if let vehiculo = servicio.vehiculo {
                        HStack(spacing: 6) {
                            badge(text: "[\(vehiculo.placas)]", icon: "number.square.fill")
                            badge(text: "\(vehiculo.marca) \(vehiculo.modelo)", icon: "car.fill")
                        }
                        .padding(.top, 2)
                        if let cliente = vehiculo.cliente?.nombre, !cliente.isEmpty {
                            Label("Cliente: \(cliente)", systemImage: "person.text.rectangle")
                                .font(.caption2).foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Label(servicio.nombreMecanicoAsignado, systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    Label("Fin: \(servicio.horaFinEstimada.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                        .font(.caption2).foregroundColor(.gray)
                }
            }
            
            // Contador
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Tiempo restante (Laboral)")
                        .font(.caption).foregroundColor(.gray)
                    Spacer()
                    
                    if estaPausado {
                        Text("PAUSADO (Fuera de horario)")
                            .font(.caption2)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(6)
                    }
                    
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
                        .foregroundColor(estaPausado ? .gray : .white)
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
        .onAppear {
            actualizarTiempo()
        }
        .onReceive(timer) { _ in
            actualizarTiempo()
        }
    }
    
    private func actualizarTiempo() {
        guard let mec = mecanicoAsignado else {
            // Fallback si no hay mecánico (raro)
            segundosRestantes = max(0, servicio.horaFinEstimada.timeIntervalSinceNow)
            estaPausado = false
            return
        }
        
        // 1. Verificar si estamos en horario laboral AHORA
        let ahora = Date()
        estaPausado = !mec.estaEnHorarioLaboral(ahora)
        
        // 2. Calcular tiempo restante laboral REAL
        // Esto recalcula siempre basado en la fecha fin estimada, que ya tiene en cuenta los huecos.
        // Si estamos en pausa, el tiempo restante laboral no debería cambiar (porque 'ahora' avanza pero no consume laboral)
        // PERO, calcularTiempoRestanteLaboral(hasta: fin) desde 'ahora' ya maneja eso:
        // si 'ahora' está en hueco, no suma tiempo hasta que empieza el turno.
        // El problema es que si 'ahora' avanza en hueco, la distancia a 'fin' se mantiene igual en términos laborales.
        // Así que simplemente llamamos a la función.
        
        segundosRestantes = mec.calcularTiempoRestanteLaboral(hasta: servicio.horaFinEstimada)
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
        .font(.caption2)
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
    let servicios: [Servicio]
    
    @State private var observaciones = ""
    @State private var mostrandoConfirmacion = false
    
    // NUEVO: Ganancias acumuladas
    @AppStorage("gananciaServiciosAcumulada") private var gananciaServiciosAcumulada: Double = 0.0
    
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
            
            let servicioCatalogo: Servicio? = {
                if let exact = servicios.first(where: { $0.nombre == servicio.nombreServicio }) {
                    return exact
                }
                let lower = servicio.nombreServicio.lowercased()
                return servicios.first(where: { $0.nombre.lowercased() == lower })
            }()
            
            if let servicioCatalogo {
                let montoMO = max(0, servicioCatalogo.costoManoDeObra)
                mecanico.comisiones += montoMO
                mecanico.recalcularYActualizarSnapshots()
                
                HistorialLogger.logAutomatico(
                    context: modelContext,
                    titulo: "Comisión sumada: \(servicioCatalogo.nombre)",
                    detalle: "Se sumaron $\(String(format: "%.2f", montoMO)) de mano de obra al empleado \(mecanico.nombre) (RFC \(mecanico.rfc)).",
                    categoria: .personal,
                    entidadAfectada: mecanico.nombre
                )
                
                // NUEVO: Incrementar servicios realizados para el Top 5
                mecanico.serviciosRealizados += 1
                
                // NUEVO: Incrementar Ganancia Global (Revenue/Venta)
                gananciaServiciosAcumulada += servicioCatalogo.precioFinalAlCliente
            } else {
                let registroAviso = DecisionRecord(
                    fecha: Date(),
                    titulo: "Aviso: Servicio no encontrado para comisión",
                    razon: "No se encontró en el catálogo el servicio '\(servicio.nombreServicio)'; no se pudo sumar comisión automáticamente.",
                    queryUsuario: "Cierre de Servicio"
                )
                modelContext.insert(registroAviso)
            }
        }
        
        HistorialLogger.logAutomatico(
            context: modelContext,
            titulo: "Completado: \(servicio.nombreServicio)",
            detalle: """
            Vehículo: [\(servicio.vehiculo?.placas ?? "N/A")] - \(servicio.vehiculo?.cliente?.nombre ?? "N/A")
            Asignado a: \(servicio.nombreMecanicoAsignado)
            Observaciones: \(observaciones.isEmpty ? "Sin observaciones." : observaciones)
            """,
            categoria: .servicio,
            entidadAfectada: servicio.nombreServicio
        )
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

