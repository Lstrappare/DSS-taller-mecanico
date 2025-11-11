import SwiftUI
import SwiftData
internal import Combine

// --- VISTA PRINCIPAL DE "EN PROCESO" (¡ACTUALIZADA!) ---
struct EnProcesoView: View {
    
    @Environment(\.modelContext) private var modelContext
    
    // --- CONSULTAS ---
    // (Movemos 'personal' aquí para que el modal pueda usarlo)
    @Query private var personal: [Personal]
    @Query(sort: \ServicioEnProceso.horaFinEstimada) private var serviciosActivos: [ServicioEnProceso]
    
    @State private var searchQuery = ""
    
    // --- NUEVO STATE PARA EL MODAL ---
    // Esto controla qué servicio estamos a punto de cerrar
    @State private var servicioACerrar: ServicioEnProceso?
    
    var filteredServicios: [ServicioEnProceso] {
        if searchQuery.isEmpty {
            return serviciosActivos
        } else {
            let query = searchQuery.lowercased()
            return serviciosActivos.filter { servicio in
                let nombreServicioMatch = servicio.nombreServicio.lowercased().contains(query)
                let placasMatch = servicio.vehiculo?.placas.lowercased().contains(query) ?? false
                let clienteMatch = servicio.vehiculo?.cliente?.nombre.lowercased().contains(query) ?? false
                return nombreServicioMatch || placasMatch || clienteMatch
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            // --- Cabecera ---
            Text("Servicios en Proceso")
                .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
            Text("Monitor de trabajos activos en el taller")
                .font(.title3).foregroundColor(.gray).padding(.bottom, 20)
            
            // --- Buscador ---
            TextField("Buscar por Placa, Cliente o Servicio...", text: $searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                .padding(.bottom, 20)
            
            // --- Cuadrícula de Tickets ---
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 350), spacing: 20)], spacing: 20) {
                    
                    if filteredServicios.isEmpty {
                        Text(searchQuery.isEmpty ? "No hay servicios activos en este momento." : "No se encontraron servicios para '\(searchQuery)'.")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.top, 50)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(filteredServicios) { servicio in
                            // Pasamos el 'servicio' al botón de la tarjeta
                            ServicioEnProcesoCard(servicio: servicio) {
                                // Esta es la acción del botón:
                                // establece el servicio que queremos cerrar.
                                servicioACerrar = servicio
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(30)
        // --- NUEVO .sheet() ---
        // Se activa cuando 'servicioACerrar' no es nulo
        .sheet(item: $servicioACerrar) { servicio in
            // Pasa el servicio, la lista de personal y el contexto al modal
            CierreServicioModalView(
                servicio: servicio,
                personal: personal,
                modelContext: modelContext
            )
        }
    }
}


// --- TARJETA DE "TICKET" INDIVIDUAL (ACTUALIZADA) ---
// (Ahora es más "tonta". Solo muestra datos y pasa la acción al padre)
struct ServicioEnProcesoCard: View {
    let servicio: ServicioEnProceso
    var onTerminar: () -> Void // Closure para la acción del botón
    
    @State private var segundosRestantes: Double
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(servicio: ServicioEnProceso, onTerminar: @escaping () -> Void) {
        self.servicio = servicio
        self.onTerminar = onTerminar
        _segundosRestantes = State(initialValue: servicio.tiempoRestanteSegundos)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            
            Text(servicio.nombreServicio)
                .font(.title2).fontWeight(.bold)
            
            if let vehiculo = servicio.vehiculo {
                Text("[\(vehiculo.placas)] - \(vehiculo.marca) \(vehiculo.modelo)")
                    .font(.subheadline).foregroundColor(.gray)
                Text("Cliente: \(vehiculo.cliente?.nombre ?? "N/A")")
                    .font(.subheadline).foregroundColor(.gray)
            }
            
            Label(servicio.nombreMecanicoAsignado, systemImage: "person.fill")
                .font(.headline)
                .foregroundColor(Color("MercedesPetrolGreen"))
            
            Divider()
            
            VStack {
                Text("Tiempo Restante:")
                    .font(.caption).foregroundColor(.gray)
                Text(formatearTiempo(segundos: segundosRestantes))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            
            // --- BOTÓN ACTUALIZADO ---
            // Ahora solo llama al closure 'onTerminar'
            Button(action: onTerminar) {
                Label("Terminar Trabajo Ahora", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.4))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
        }
        .padding()
        .background(Color("MercedesCard"))
        .cornerRadius(15)
        .onReceive(timer) { _ in
            if segundosRestantes > 0 {
                segundosRestantes -= 1
            } else {
                // Cuando llega a 0, también llama a la acción
                onTerminar()
                timer.upstream.connect().cancel() // Detiene el timer
            }
        }
    }
    
    func formatearTiempo(segundos: Double) -> String {
        let horas = Int(segundos) / 3600
        let minutos = (Int(segundos) % 3600) / 60
        let segs = Int(segundos) % 60
        return String(format: "%02i:%02i:%02i", horas, minutos, segs)
    }
}


// --- ¡NUEVA VISTA! EL MODAL DE CIERRE ---
fileprivate struct CierreServicioModalView: View {
    @Environment(\.dismiss) private var dismiss
    
    let servicio: ServicioEnProceso
    let personal: [Personal] // La lista completa de personal
    let modelContext: ModelContext // El contexto de la BD
    
    @State private var observaciones = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Cierre de Servicio")
                .font(.largeTitle).fontWeight(.bold)
            
            Text(servicio.nombreServicio)
                .font(.title2).foregroundColor(.gray)
            
            Divider()
            
            // --- CAMPO DE OBSERVACIONES ---
            VStack(alignment: .leading) {
                Text("Observaciones (Opcional)")
                    .font(.headline)
                Text("Añade cualquier nota sobre el servicio (ej. 'Cliente reportó ruido', 'Se cambiaron tornillos extra', etc.)")
                    .font(.subheadline).foregroundColor(.gray)
                
                TextEditor(text: $observaciones)
                    .frame(minHeight: 150)
                    .font(.body)
                    .background(Color("MercedesBackground"))
                    .cornerRadius(10)
            }
            
            Spacer()
            
            // --- Botones de Acción ---
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding().foregroundColor(.gray)
                
                Spacer()
                
                Button {
                    completarServicio()
                } label: {
                    Label("Confirmar y Cerrar Servicio", systemImage: "archivebox.fill")
                        .font(.headline).padding()
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 450)
        .background(Color("MercedesCard"))
        .cornerRadius(15)
        .preferredColorScheme(.dark)
        .textFieldStyle(PlainTextFieldStyle())
    }
    
    // --- LÓGICA DE CIERRE FINAL ---
    func completarServicio() {
        // 1. Buscar al mecánico
        if let mecanico = personal.first(where: { $0.dni == servicio.dniMecanicoAsignado }) {
            mecanico.estado = .disponible
        }
        
        // 2. Crear el nuevo registro en el HISTORIAL
        let registro = DecisionRecord(
            fecha: Date(), // ¡Esta es la hora FIN real!
            titulo: "Completado: \(servicio.nombreServicio)",
            razon: """
            Vehículo: [\(servicio.vehiculo?.placas ?? "N/A")] - \(servicio.vehiculo?.cliente?.nombre ?? "N/A")
            Asignado a: \(servicio.nombreMecanicoAsignado)
            Observaciones: \(observaciones.isEmpty ? "Sin observaciones." : observaciones)
            """,
            queryUsuario: "Cierre de Servicio"
        )
        modelContext.insert(registro)
        
        // 3. Borrar el "ticket" de la base de datos
        modelContext.delete(servicio)
        
        dismiss()
    }
}
