import SwiftUI
import SwiftData
import LocalAuthentication

// (El struct RecomendacionDSS no cambia)
struct RecomendacionDSS {
    var servicio: Servicio
    var mecanicoRecomendado: Personal?
    var costoTotalProductos: Double
    var rentabilidadEstimada: Double
    var advertencia: String?
}


// --- VISTA PRINCIPAL (Actualizada) ---
struct DecisionView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var seleccion: Vista?
    
    @Query private var servicios: [Servicio]
    @Query private var personal: [Personal]
    @Query private var productos: [Producto]

    @State private var servicioSeleccionadoID: Servicio.ID?
    @State private var estaCargando = false
    @State private var recomendacion: RecomendacionDSS?

    var body: some View {
        // Renombramos los títulos como pediste
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text("Asignar Servicio") // <-- Título Actualizado
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Text("Asigna al mejor personal para ejecutar los servicios.") // <-- Título Actualizado
                    .font(.title3).foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .font(.title2).foregroundColor(Color("MercedesPetrolGreen"))
                        Text("¿Qué servicio quieres asignar?")
                            .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    }
                    Text("Selecciona un servicio de tu catálogo para encontrar al mejor mecánico disponible y calcular costos.")
                        .font(.subheadline).foregroundColor(.gray)
                    
                    Picker("Selecciona un Servicio", selection: $servicioSeleccionadoID) {
                        Text("Selecciona un servicio...").tag(nil as Servicio.ID?)
                        ForEach(servicios) { servicio in
                            Text(servicio.nombre).tag(servicio.id as Servicio.ID?)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.top, 10)
                }
                .padding(20)
                .background(Color("MercedesCard"))
                .cornerRadius(15)
                
                HStack(spacing: 15) {
                    Button {
                        generarRecomendacion()
                    } label: {
                        Label("Generar Reporte", systemImage: "doc.text.fill")
                            .font(.headline).padding(.vertical, 10).frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(servicioSeleccionadoID == nil || estaCargando)
                }
                
                if estaCargando {
                    ProgressView()
                        .frame(maxWidth: .infinity).padding()
                } else if let rec = recomendacion {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Recomendación de Asignación").font(.title2).fontWeight(.bold)
                        if let advertencia = rec.advertencia {
                            Text("⚠️ ADVERTENCIA: \(advertencia)")
                                .font(.headline).foregroundColor(.yellow)
                        }
                        Text("Mecánico Recomendado:").font(.headline).foregroundColor(Color("MercedesPetrolGreen"))
                        Text(rec.mecanicoRecomendado?.nombre ?? "Ninguno Disponible")
                        Text("Costo de Piezas (Inventario):").font(.headline).foregroundColor(Color("MercedesPetrolGreen"))
                        Text("$\(rec.costoTotalProductos, specifier: "%.2f")")
                        Text("Rentabilidad Estimada (Mano de obra):").font(.headline).foregroundColor(Color("MercedesPetrolGreen"))
                        Text("$\(rec.rentabilidadEstimada, specifier: "%.2f")")
                        Button {
                            aceptarDecision(rec)
                        } label: {
                            Label("Aceptar y Empezar Trabajo", systemImage: "checkmark.circle.fill")
                                .font(.headline).padding(.vertical, 10).frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.4)).foregroundColor(.white).cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .padding(.top)
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
    }
    
    
    // --- LÓGICA DEL "CEREBRO" (¡ACTUALIZADA!) ---
    
    func generarRecomendacion() {
        guard let servicioID = servicioSeleccionadoID else { return }
        guard let servicio = servicios.first(where: { $0.id == servicioID }) else {
            print("Error: No se encontró el servicio")
            return
        }
        
        estaCargando = true
        recomendacion = nil
        var advertencia: String? = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            
            // 2. Encuentra Candidatos (Personal)
            let candidatos = personal.filter { mec in
                mec.estaDisponible &&
                mec.estaEnHorario &&
                mec.especialidades.contains(servicio.especialidadRequerida) &&
                mec.nivelHabilidad.rawValue >= servicio.nivelMinimoRequerido.rawValue
            }
            let mecanicoElegido = candidatos.first
            if mecanicoElegido == nil {
                advertencia = "No se encontraron mecánicos disponibles que cumplan los requisitos."
            }
            
            // --- 4. Calcula Costos (¡LÓGICA ACTUALIZADA!) ---
            var costoTotalProductos: Double = 0.0
            
            // Itera sobre los ingredientes de la receta
            for ingrediente in servicio.ingredientes {
                if let producto = productos.first(where: { $0.nombre == ingrediente.nombreProducto }) {
                    
                    // Revisa si hay suficiente stock
                    if producto.cantidad < ingrediente.cantidadUsada {
                        advertencia = (advertencia ?? "") + "\nStock insuficiente de: \(producto.nombre)."
                    }
                    // Suma el costo
                    costoTotalProductos += (producto.costo * ingrediente.cantidadUsada)
                    
                } else {
                    advertencia = (advertencia ?? "") + "\nNo se encontró \(ingrediente.nombreProducto) en el inventario."
                }
            }
            
            // 5. Calcula Rentabilidad
            let rentabilidad = servicio.precioAlCliente
            
            // 6. Prepara la recomendación
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
    
    
    // --- LÓGICA DEL "GATILLO" (¡ACTUALIZADA!) ---
    
    func aceptarDecision(_ rec: RecomendacionDSS) {
        guard let mecanico = rec.mecanicoRecomendado else { return }
        
        // 1. Crear el "Ticket"
        let nuevoServicio = ServicioEnProceso(
            nombreServicio: rec.servicio.nombre,
            dniMecanicoAsignado: mecanico.dni,
            nombreMecanicoAsignado: mecanico.nombre,
            horaInicio: Date(),
            duracionHoras: rec.servicio.duracionHoras,
            // Pasa los nombres de los productos consumidos
            productosConsumidos: rec.servicio.ingredientes.map { $0.nombreProducto }
        )
        modelContext.insert(nuevoServicio)
        
        // 2. Ocupar al Mecánico
        mecanico.estaDisponible = false
        
        // --- 3. Restar del Inventario (¡LÓGICA ACTUALIZADA!) ---
        for ingrediente in rec.servicio.ingredientes {
            if let producto = productos.first(where: { $0.nombre == ingrediente.nombreProducto }) {
                // Resta la cantidad fraccional
                producto.cantidad -= ingrediente.cantidadUsada
            }
        }
        
        // 4. Guardar en el Historial de Decisiones
        let registro = DecisionRecord(
            fecha: Date(),
            titulo: "Iniciando: \(rec.servicio.nombre)",
            razon: "Asignado a \(mecanico.nombre). Costo piezas: $\(rec.costoTotalProductos, default: "%.2f")",
            queryUsuario: "Asignación de Servicio"
        )
        modelContext.insert(registro)
        
        // 5. Limpiar la UI y Navegar
        recomendacion = nil
        servicioSeleccionadoID = nil
        seleccion = .serviciosEnProceso
    }
}
