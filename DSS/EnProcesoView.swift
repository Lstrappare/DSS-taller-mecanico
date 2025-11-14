import SwiftUI
import SwiftData
internal import Combine

// --- VISTA PRINCIPAL DE "EN PROCESO" (Mejorada UI) ---
struct EnProcesoView: View {
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppNavigationState
    
    // --- CONSULTAS ---
    @Query private var personal: [Personal]
    @Query(sort: \ServicioEnProceso.horaFinEstimada) private var serviciosActivos: [ServicioEnProceso]
    
    @State private var searchQuery = ""
    @State private var filtroUrgencia: UrgenciaFiltro = .todos
    
    // --- NUEVO STATE PARA EL MODAL ---
    @State private var servicioACerrar: ServicioEnProceso?
    
    enum UrgenciaFiltro: String, CaseIterable, Identifiable {
        case todos = "Todos"
        case menosDe30 = "< 30 min"
        case vencidos = "Vencidos"
        case hoy = "Hoy"
        var id: String { rawValue }
    }
    
    var filteredServicios: [ServicioEnProceso] {
        let base: [ServicioEnProceso]
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            base = serviciosActivos
        } else {
            let q = searchQuery.lowercased()
            base = serviciosActivos.filter { s in
                let nombreServicioMatch = s.nombreServicio.lowercased().contains(q)
                let placasMatch = s.vehiculo?.placas.lowercased().contains(q) ?? false
                let clienteMatch = s.vehiculo?.cliente?.nombre.lowercased().contains(q) ?? false
                let mecanicoMatch = s.nombreMecanicoAsignado.lowercased().contains(q)
                return nombreServicioMatch || placasMatch || clienteMatch || mecanicoMatch
            }
        }
        switch filtroUrgencia {
        case .todos:
            return base
        case .menosDe30:
            return base.filter { $0.tiempoRestanteSegundos > 0 && $0.tiempoRestanteSegundos <= 1800 }
        case .vencidos:
            return base.filter { $0.tiempoRestanteSegundos == 0 }
        case .hoy:
            let cal = Calendar.current
            return base.filter { cal.isDateInToday($0.horaFinEstimada) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // --- Cabecera ---
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Servicios en Proceso")
                        .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                    HStack(spacing: 10) {
                        Label("\(serviciosActivos.count) activos", systemImage: "hammer.circle.fill")
                            .font(.subheadline).foregroundColor(.gray)
                        if let masCercano = serviciosActivos.map(\.horaFinEstimada).min() {
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
            
            // --- Cuadrícula de Tickets ---
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 18)], spacing: 18) {
                    
                    if filteredServicios.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        ForEach(filteredServicios) { servicio in
                            ServicioEnProcesoCard(servicio: servicio) {
                                servicioACerrar = servicio
                            }
                        }
                    }
                }
                .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .sheet(item: $servicioACerrar) { servicio in
            CierreServicioModalView(
                servicio: servicio,
                personal: personal,
                modelContext: modelContext
            )
        }
    }
    
    // Empty state agradable
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wrench.adjustable")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(Color("MercedesPetrolGreen"))
            Text(searchQuery.isEmpty ? "No hay servicios activos en este momento." :
                 "No se encontraron servicios para “\(searchQuery)”.")
                .font(.headline)
                .foregroundColor(.gray)
            if searchQuery.isEmpty {
                Button {
                    appState.seleccion = .operaciones_servicios
                } label: {
                    Label("Asignar un servicio", systemImage: "plus.circle.fill")
                        .font(.subheadline).padding(.vertical, 8).padding(.horizontal, 12)
                        .background(Color("MercedesCard"))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .foregroundColor(Color("MercedesPetrolGreen"))
            }
        }
    }
    
    // Helpers
    private func formatearTiempoCorto(segundos: Double) -> String {
        let m = Int(segundos) / 60
        let h = m / 60
        let rm = m % 60
        if h > 0 { return "\(h)h \(rm)m" }
        return "\(m)m"
    }
}


// --- TARJETA DE "TICKET" INDIVIDUAL (Mejorada UI) ---
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
                // Cuando llega a 0, sugerimos cerrar; no forzamos
                // para no abrir modal en bucle si el usuario lo ignora
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


// --- MODAL DE CIERRE (Mejorado UI) ---
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
        if let mecanico = personal.first(where: { $0.dni == servicio.dniMecanicoAsignado }) {
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
