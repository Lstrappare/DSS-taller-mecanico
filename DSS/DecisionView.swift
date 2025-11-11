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


// --- VISTA PRINCIPAL (¡ACTUALIZADA!) ---
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
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                
                // --- 1. Cabecera ---
                Text("Asignar Servicio")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Text("Asigna al mejor personal para ejecutar los servicios.")
                    .font(.title3).foregroundColor(.gray)
                
                // --- 2. Tarjeta de Consulta ---
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
                            // Mostramos el servicio y el ROL que requiere
                            Text("\(servicio.nombre) (Req: \(servicio.rolRequerido.rawValue))")
                                .tag(servicio.id as Servicio.ID?)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.top, 10)
                }
                .padding(20)
                .background(Color("MercedesCard"))
                .cornerRadius(15)

                
                // --- 3. Botones ---
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

                
                // --- 4. Área de Resultados ---
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
                        // Mostramos el nombre Y EL ROL del mecánico
                        Text(rec.mecanicoRecomendado?.nombre ?? "Ninguno Disponible")
                            .font(.title3)
                        Text(rec.mecanicoRecomendado?.rol.rawValue ?? "")
                            .font(.subheadline).foregroundColor(.gray)
                        
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
        guard let servicio = servicios.first(where: { $0.id == servicioID }) else { return }
        
        estaCargando = true
        recomendacion = nil
        var advertencia: String? = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            
            // --- 2. Encuentra Candidatos (Personal) ---
            // ¡ESTA ES LA LÓGICA 100% ACTUALIZADA!
            let candidatos = personal.filter { mec in
                mec.isAsignable && // ¿Está "Disponible" Y "En Horario"?
                mec.especialidades.contains(servicio.especialidadRequerida) && // ¿Sabe hacerlo?
                mec.rol == servicio.rolRequerido // ¿Tiene el ROL correcto?
            }
            
            // (Esta es la lógica V2 que discutimos, el "Cerebro Eficiente")
            // Ordena los candidatos.
            // Esto es 'inteligente': si el rol es "Ayudante", no importa.
            // Pero si es un rol de "Mecánico", prioriza al de menor rango (Ayudante -> Técnico -> Maestro)
            // para no desperdiciar a los expertos en trabajos fáciles.
            let mecanicoElegido = candidatos.sorted(by: { $0.rol.rawValue < $1.rol.rawValue }).first
            
            if mecanicoElegido == nil {
                advertencia = "No se encontraron mecánicos disponibles que cumplan los requisitos de ROL y ESPECIALIDAD."
            }
            
            // --- 4. Calcula Costos (Lógica fraccional) ---
            var costoTotalProductos: Double = 0.0
            for ingrediente in servicio.ingredientes {
                if let producto = productos.first(where: { $0.nombre == ingrediente.nombreProducto }) {
                    if producto.cantidad < ingrediente.cantidadUsada {
                        advertencia = (advertencia ?? "") + "\nStock insuficiente de: \(producto.nombre)."
                    }
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
            productosConsumidos: rec.servicio.ingredientes.map { $0.nombreProducto },
            vehiculo: nil // No hay selección de vehículo en esta vista aún
        )
        modelContext.insert(nuevoServicio)
        
        // 2. Ocupar al Mecánico
        // ¡CAMBIO CLAVE! Pone el estado en "Ocupado"
        mecanico.estado = .ocupado
        
        // 3. Restar del Inventario (Lógica fraccional)
        for ingrediente in rec.servicio.ingredientes {
            if let producto = productos.first(where: { $0.nombre == ingrediente.nombreProducto }) {
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
