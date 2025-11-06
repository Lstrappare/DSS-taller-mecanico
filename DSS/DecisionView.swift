import SwiftUI
import SwiftData
import LocalAuthentication

// --- Modelo para la Recomendación (Resultado del "Cerebro") ---
// Usamos esto para guardar el resultado de la IA antes de aceptarlo
struct RecomendacionDSS {
    var servicio: Servicio
    var mecanicoRecomendado: Personal?
    var costoTotalProductos: Double
    var rentabilidadEstimada: Double
    var advertencia: String? // Ej. "No hay mecánicos disponibles"
}


// --- VISTA PRINCIPAL (EL "CEREBRO") ---
struct DecisionView: View {
    @Environment(\.modelContext) private var modelContext
    
    // --- Conexión a la Navegación (¡Arregla el error!) ---
    @Binding var seleccion: Vista?
    
    // --- Consultas a la Base de Datos ---
    @Query private var servicios: [Servicio]
    @Query private var personal: [Personal]
    @Query private var productos: [Producto]

    // --- States de la UI ---
    @State private var servicioSeleccionadoID: Servicio.ID?
    @State private var estaCargando = false
    
    // Aquí guardamos el resultado de la IA
    @State private var recomendacion: RecomendacionDSS?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                
                // --- 1. Cabecera ---
                Text("Toma de Decisiones")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Text("Genera recomendaciones de asignación basadas en tus datos")
                    .font(.title3).foregroundColor(.gray)
                
                // --- 2. Tarjeta de Consulta (¡NUEVO PICKER!) ---
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .font(.title2).foregroundColor(Color("MercedesPetrolGreen"))
                        Text("¿Qué servicio quieres asignar?")
                            .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    }
                    
                    Text("Selecciona un servicio de tu catálogo para encontrar al mejor mecánico disponible y calcular costos.")
                        .font(.subheadline).foregroundColor(.gray)
                    
                    // --- El Picker de Servicios ---
                    Picker("Selecciona un Servicio", selection: $servicioSeleccionadoID) {
                        Text("Selecciona un servicio...").tag(nil as Servicio.ID?)
                        ForEach(servicios) { servicio in
                            Text(servicio.nombre).tag(servicio.id as Servicio.ID?)
                        }
                    }
                    .pickerStyle(.menu) // Estilo desplegable
                    .padding(.top, 10)
                }
                .padding(20)
                .background(Color("MercedesCard"))
                .cornerRadius(15)

                
                // --- 3. Botones ---
                HStack(spacing: 15) {
                    // Botón de Generar Reporte
                    Button {
                        generarRecomendacion()
                    } label: {
                        Label("Generar Reporte", systemImage: "doc.text.fill")
                            .font(.headline).padding(.vertical, 10).frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    // Deshabilitado si no hay servicio seleccionado
                    .disabled(servicioSeleccionadoID == nil || estaCargando)
                }

                
                // --- 4. Área de Resultados (¡AHORA ES REAL!) ---
                if estaCargando {
                    ProgressView()
                        .frame(maxWidth: .infinity).padding()
                } else if let rec = recomendacion {
                    // ¡Mostramos el resultado del "Cerebro"!
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Recomendación de Asignación")
                            .font(.title2).fontWeight(.bold)
                        
                        // Advertencia (si algo salió mal)
                        if let advertencia = rec.advertencia {
                            Text("⚠️ ADVERTENCIA: \(advertencia)")
                                .font(.headline).foregroundColor(.yellow)
                        }
                        
                        // Mecánico
                        Text("Mecánico Recomendado:").font(.headline).foregroundColor(Color("MercedesPetrolGreen"))
                        Text(rec.mecanicoRecomendado?.nombre ?? "Ninguno Disponible")
                        
                        // Costos
                        Text("Costo de Piezas (Inventario):").font(.headline).foregroundColor(Color("MercedesPetrolGreen"))
                        Text("$\(rec.costoTotalProductos, specifier: "%.2f")")
                        
                        // Rentabilidad
                        Text("Rentabilidad Estimada (Mano de obra):").font(.headline).foregroundColor(Color("MercedesPetrolGreen"))
                        Text("$\(rec.rentabilidadEstimada, specifier: "%.2f")")
                        
                        // El "Gatillo"
                        Button {
                            aceptarDecision(rec)
                        } label: {
                            Label("Aceptar y Empezar Trabajo", systemImage: "checkmark.circle.fill")
                                .font(.headline).padding(.vertical, 10).frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.4)).foregroundColor(.white).cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .padding(.top)
                        // Deshabilitar si no se pudo recomendar un mecánico
                        .disabled(rec.mecanicoRecomendado == nil)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("MercedesCard"))
                    .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding(30)
        }
        // Ya no necesitamos la lógica de "Escribir Decisión Personalizada" aquí
        // (La quitamos para simplificar este flujo)
    }
    
    
    // --- LÓGICA DEL "CEREBRO" ---
    
    func generarRecomendacion() {
        guard let servicioID = servicioSeleccionadoID else { return }
        
        // 1. Encuentra el Servicio (la "receta")
        guard let servicio = servicios.first(where: { $0.id == servicioID }) else {
            print("Error: No se encontró el servicio")
            return
        }
        
        estaCargando = true
        recomendacion = nil
        
        // Simulamos una pequeña carga
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            
            // --- LÓGICA DEL DSS ---
            
            // 2. Encuentra Candidatos (Personal)
            let candidatos = personal.filter { mec in
                            mec.estaDisponible &&      // ¿No está en otro servicio?
                            mec.estaEnHorario &&       // ¿Está EN TURNO ahora mismo? (¡TU IDEA!)
                            mec.especialidades.contains(servicio.especialidadRequerida) && // ¿Sabe hacerlo?
                            mec.nivelHabilidad.rawValue >= servicio.nivelMinimoRequerido.rawValue // ¿Tiene el nivel?
                        }
            
            // 3. Elige al mejor (por ahora, el primero que encuentre)
            // (En V2, aquí elegirías por costo por hora o nivel)
            let mecanicoElegido = candidatos.first
            
            // 4. Calcula Costos (Productos)
            var costoTotalProductos: Double = 0.0
            for nombreProducto in servicio.productosRequeridos {
                if let producto = productos.first(where: { $0.nombre == nombreProducto }) {
                    costoTotalProductos += producto.costo
                }
            }
            
            // 5. Calcula Rentabilidad
            let rentabilidad = servicio.precioAlCliente // (Por ahora, solo la mano de obra)
            
            // 6. Prepara la recomendación
            var advertencia: String? = nil
            if mecanicoElegido == nil {
                advertencia = "No se encontraron mecánicos disponibles que cumplan los requisitos."
            }
            if costoTotalProductos == 0 && !servicio.productosRequeridos.isEmpty {
                advertencia = (advertencia ?? "") + " No se encontraron algunos productos en el inventario."
            }
            
            recomendacion = RecomendacionDSS(
                servicio: servicio,
                mecanicoRecomendado: mecanicoElegido,
                costoTotalProductos: costoTotalProductos,
                rentabilidadEstimada: rentabilidad,
                advertencia: advertencia
            )
            
            estaCargando = false
        }
    }
    
    
    // --- LÓGICA DEL "GATILLO" ---
    
    func aceptarDecision(_ rec: RecomendacionDSS) {
        guard let mecanico = rec.mecanicoRecomendado else { return }
        
        // 1. Crear el "Ticket" (ServicioEnProceso)
        let nuevoServicio = ServicioEnProceso(
            nombreServicio: rec.servicio.nombre,
            dniMecanicoAsignado: mecanico.dni,
            nombreMecanicoAsignado: mecanico.nombre,
            horaInicio: Date(),
            duracionHoras: rec.servicio.duracionHoras,
            productosConsumidos: rec.servicio.productosRequeridos
        )
        modelContext.insert(nuevoServicio)
        
        // 2. Ocupar al Mecánico
        mecanico.estaDisponible = false
        
        // 3. Restar del Inventario
        for nombreProducto in rec.servicio.productosRequeridos {
            if let producto = productos.first(where: { $0.nombre == nombreProducto }) {
                if producto.cantidad > 0 {
                    producto.cantidad -= 1 // Resta 1 unidad
                } else {
                    print("Advertencia: Se usó \(producto.nombre) pero el stock ya era 0.")
                }
            }
        }
        
        // 4. Guardar en el Historial de Decisiones
        let registro = DecisionRecord(
            fecha: Date(),
            titulo: "Iniciando: \(rec.servicio.nombre)",
            razon: "Asignado a \(mecanico.nombre). Costo piezas: $\(rec.costoTotalProductos)",
            queryUsuario: "Asignación de Servicio"
        )
        modelContext.insert(registro)
        
        // 5. Limpiar la UI y Navegar
        recomendacion = nil
        servicioSeleccionadoID = nil
        
        // ¡Navega a la nueva página!
        seleccion = .serviciosEnProceso
    }
}
