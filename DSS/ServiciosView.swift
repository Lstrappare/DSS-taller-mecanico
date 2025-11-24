import SwiftUI
import SwiftData
import LocalAuthentication

// --- MODO DEL MODAL (Actualizado con assign) ---
fileprivate enum ServiceModalMode: Identifiable {
    case add
    case edit(Servicio)
    case assign(Servicio)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let servicio): return servicio.nombre
        case .assign(let servicio): return "assign-\(servicio.nombre)"
        }
    }
}

// --- VISTA PRINCIPAL (comportamiento de la versión anterior) ---
struct ServiciosView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppNavigationState
    @Query(sort: \Servicio.nombre) private var servicios: [Servicio]
    
    @State private var modalMode: ServiceModalMode?
    @State private var searchQuery = ""
    
    var filteredServicios: [Servicio] {
        if searchQuery.isEmpty {
            return servicios
        } else {
            let query = searchQuery.lowercased()
            return servicios.filter {
                $0.nombre.lowercased().contains(query) ||
                $0.rolRequerido.rawValue.lowercased().contains(query) ||
                $0.especialidadRequerida.lowercased().contains(query)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header compacto con métrica y CTA
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Gestión de Servicios")
                        .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                    HStack(spacing: 10) {
                        Label("\(servicios.count) en catálogo", systemImage: "wrench.and.screwdriver.fill")
                            .font(.subheadline).foregroundColor(.gray)
                    }
                }
                Spacer()
                Button {
                    modalMode = .add
                } label: {
                    Label("Añadir Servicio", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding(.vertical, 10).padding(.horizontal, 14)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            
            // Buscador
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color("MercedesPetrolGreen"))
                TextField("Buscar por Nombre, Rol o Especialidad...", text: $searchQuery)
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
            
            // Lista de servicios
            ScrollView {
                LazyVStack(spacing: 14) {
                    if filteredServicios.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        ForEach(filteredServicios) { servicio in
                            ServicioCard(
                                servicio: servicio,
                                costoEstimado: costoEstimadoProductos(servicio),
                                productosCount: servicio.ingredientes.count,
                                onEdit: { modalMode = .edit(servicio) },
                                onAssign: { modalMode = .assign(servicio) }
                            )
                        }
                    }
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(30)
        .sheet(item: $modalMode) { mode in
            switch mode {
            case .add:
                ServicioFormView(mode: .add)
                    .environment(\.modelContext, modelContext)
            case .edit(let servicio):
                ServicioFormView(mode: .edit(servicio))
                    .environment(\.modelContext, modelContext)
            case .assign(let servicio):
                AsignarServicioModal(servicio: servicio, appState: appState)
                    .environment(\.modelContext, modelContext)
            }
        }
    }
    
    // Empty state agradable
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wrench.adjustable")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(Color("MercedesPetrolGreen"))
            Text(searchQuery.isEmpty ? "No hay servicios registrados aún." :
                 "No se encontraron servicios para “\(searchQuery)”.")
                .font(.headline)
                .foregroundColor(.gray)
            if searchQuery.isEmpty {
                Text("Añade tu primer servicio para empezar a asignar trabajos.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // Calcula costo estimado de insumos para mostrar en la tarjeta
    private func costoEstimadoProductos(_ servicio: Servicio) -> Double {
        let descriptor = FetchDescriptor<Producto>()
        let productos = (try? modelContext.fetch(descriptor)) ?? []
        var costo: Double = 0
        for ing in servicio.ingredientes {
            if let p = productos.first(where: { $0.nombre == ing.nombreProducto }) {
                costo += p.costo * ing.cantidadUsada
            }
        }
        return costo
    }
    
    func formatearIngredientes(_ ingredientes: [Ingrediente]) -> String {
        ingredientes.map { "\($0.nombreProducto) (\(String(format: "%.2f", $0.cantidadUsada)))" }
            .joined(separator: ", ")
    }
}

// Tarjeta individual de servicio
fileprivate struct ServicioCard: View {
    let servicio: Servicio
    let costoEstimado: Double
    let productosCount: Int
    var onEdit: () -> Void
    var onAssign: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query private var personal: [Personal]
    @Query private var productos: [Producto]
    
    // Preview rápida: hay candidato y stock?
    private var previewAsignable: (asignable: Bool, motivo: String) {
        // Candidato
        let candidatos = personal.filter { mec in
            mec.isAsignable &&
            mec.especialidades.contains(servicio.especialidadRequerida) &&
            mec.rol == servicio.rolRequerido
        }
        guard candidatos.first != nil else {
            return (false, "Sin candidato disponible")
        }
        // Stock
        for ing in servicio.ingredientes {
            guard let p = productos.first(where: { $0.nombre == ing.nombreProducto }) else { continue }
            if p.cantidad < ing.cantidadUsada {
                return (false, "Stock insuficiente")
            }
        }
        return (true, "Listo para asignar")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(servicio.nombre)
                        .font(.title2).fontWeight(.semibold)
                    Text(servicio.descripcion.isEmpty ? "Sin descripción" : servicio.descripcion)
                        .font(.subheadline).foregroundColor(.gray)
                }
                Spacer()
                Button {
                    onEdit()
                } label: {
                    Label("Editar", systemImage: "pencil")
                        .font(.subheadline)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color("MercedesBackground"))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
            }
            
            // Chips de requerimientos
            HStack(spacing: 8) {
                chip(text: servicio.rolRequerido.rawValue, systemImage: "person.badge.shield.checkmark.fill")
                chip(text: servicio.especialidadRequerida, systemImage: "wrench.and.screwdriver.fill")
                chip(text: String(format: "%.1f h", servicio.duracionHoras), systemImage: "clock")
            }
            
            // Productos y costo + precio final
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("\(productosCount) producto\(productosCount == 1 ? "" : "s")", systemImage: "shippingbox.fill")
                    Spacer()
                    Label("Costo insumos: $\(costoEstimado, specifier: "%.2f")", systemImage: "creditcard")
                }
                .font(.caption)
                .foregroundColor(.gray)
                
                // Precio final y sugerido (si fue modificado)
                let sugerido = PricingHelpers.precioSugeridoParaServicio(servicio: servicio, productos: productos)
                HStack(spacing: 10) {
                    Text("Precio final: $\(servicio.precioFinalAlCliente, specifier: "%.2f")")
                        .font(.headline)
                        .foregroundColor(.white)
                    if servicio.precioModificadoManualmente {
                        Text("Sugerido: $\(sugerido, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color("MercedesBackground"))
                            .cornerRadius(6)
                    }
                }
            }
            
            Divider().opacity(0.5)
            
            // Footer con estado de asignación y CTA
            HStack {
                let estado = previewAsignable
                Label(estado.motivo, systemImage: estado.asignable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background((estado.asignable ? Color.green : Color.red).opacity(0.15))
                    .foregroundColor(estado.asignable ? .green : .red)
                    .cornerRadius(6)
                Spacer()
                Button {
                    onAssign()
                } label: {
                    Label("Asignar", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .padding(.vertical, 8).padding(.horizontal, 12)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("MercedesCard"))
        .cornerRadius(12)
    }
    
    private func chip(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color("MercedesBackground"))
        .cornerRadius(8)
        .foregroundColor(.white)
    }
}

// --- MODAL DE ASIGNACIÓN (UI mejorada, misma lógica) ---
fileprivate struct AsignarServicioModal: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var personal: [Personal]
    @Query private var productos: [Producto]
    @Query private var vehiculos: [Vehiculo]
    
    var servicio: Servicio
    @ObservedObject var appState: AppNavigationState
    
    // UI State
    @State private var vehiculoSeleccionadoID: Vehiculo.ID?
    @State private var searchVehiculo = ""
    @State private var alertaError: String?
    @State private var mostrandoAlerta = false
    
    // Preview calculada
    @State private var candidato: Personal?
    @State private var costoEstimado: Double = 0
    @State private var hayStockInsuficiente: Bool = false
    
    var vehiculosFiltrados: [Vehiculo] {
        if searchVehiculo.trimmingCharacters(in: .whitespaces).isEmpty { return vehiculos }
        let q = searchVehiculo.lowercased()
        return vehiculos.filter { v in
            v.placas.lowercased().contains(q) ||
            v.marca.lowercased().contains(q) ||
            v.modelo.lowercased().contains(q) ||
            (v.cliente?.nombre.lowercased().contains(q) ?? false)
        }
    }
    
    var candidatoColor: Color {
        guard let c = candidato else { return .red }
        switch c.estado {
        case .disponible: return .green
        case .ocupado: return .red
        case .descanso: return .yellow
        case .ausente: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Asignar Servicio")
                .font(.largeTitle).fontWeight(.bold)
            
            // Header con resumen del servicio
            VStack(alignment: .leading, spacing: 8) {
                Text(servicio.nombre)
                    .font(.title2).fontWeight(.semibold)
                HStack(spacing: 8) {
                    chip(text: servicio.rolRequerido.rawValue, systemImage: "person.badge.shield.checkmark.fill")
                    chip(text: servicio.especialidadRequerida, systemImage: "wrench.and.screwdriver.fill")
                    chip(text: String(format: "%.1f h", servicio.duracionHoras), systemImage: "clock")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color("MercedesCard"))
            .cornerRadius(10)
            
            // Selector de vehículo con búsqueda
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Selecciona el Vehículo")
                        .font(.headline)
                    Spacer()
                    Button {
                        appState.seleccion = .gestionClientes
                        dismiss()
                    } label: {
                        Text("Gestionar Clientes y Vehículos")
                            .underline()
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                }
                
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    TextField("Buscar por placas, cliente, marca o modelo...", text: $searchVehiculo)
                        .textFieldStyle(PlainTextFieldStyle())
                    if !searchVehiculo.isEmpty {
                        Button {
                            searchVehiculo = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color("MercedesBackground"))
                .cornerRadius(8)
                
                // Lista de opciones
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vehiculosFiltrados) { vehiculo in
                            let isSelected = vehiculoSeleccionadoID == vehiculo.id
                            Button {
                                vehiculoSeleccionadoID = vehiculo.id
                                recalcularPreview()
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Text("[\(vehiculo.placas)]")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(Color("MercedesPetrolGreen"))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(vehiculo.marca) \(vehiculo.modelo) (\(vehiculo.anio))")
                                            .font(.headline)
                                        Text("Cliente: \(vehiculo.cliente?.nombre ?? "N/A")")
                                            .font(.caption).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color("MercedesPetrolGreen"))
                                    }
                                }
                                .padding(10)
                                .background(Color("MercedesCard").opacity(isSelected ? 1.0 : 0.6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        if vehiculosFiltrados.isEmpty {
                            Text("No se encontraron vehículos para “\(searchVehiculo)”.")
                                .font(.caption).foregroundColor(.gray).padding(.top, 6)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
            .padding()
            .background(Color("MercedesCard"))
            .cornerRadius(10)
            
            // Candidato y productos
            HStack(alignment: .top, spacing: 16) {
                // Candidato
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Candidato Asignado").font(.headline)
                        Spacer()
                        Button {
                            appState.seleccion = .operaciones_personal
                            dismiss()
                        } label: {
                            Text("Gestionar Personal")
                                .underline()
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    }
                    
                    if let c = candidato {
                        HStack {
                            Image(systemName: "person.fill")
                            Text(c.nombre).fontWeight(.semibold)
                            Spacer()
                            Text(c.estado.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(candidatoColor.opacity(0.2))
                                .foregroundColor(candidatoColor)
                                .cornerRadius(6)
                        }
                        .font(.body)
                        Text("Rol: \(c.rol.rawValue)")
                            .font(.caption).foregroundColor(.gray)
                        if !c.especialidades.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(c.especialidades, id: \.self) { esp in
                                        chipSmall(text: esp)
                                    }
                                }
                            }
                        }
                    } else {
                        Text("No hay candidatos disponibles que cumplan rol y especialidad.")
                            .font(.caption).foregroundColor(.red)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("MercedesCard"))
                .cornerRadius(10)
                
                // Productos
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Productos a Consumir").font(.headline)
                        Spacer()
                        Button {
                            appState.seleccion = .operaciones_inventario
                            dismiss()
                        } label: {
                            Text("Gestionar Inventario")
                                .underline()
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    }
                    
                    if servicio.ingredientes.isEmpty {
                        Text("Este servicio no requiere productos.")
                            .font(.caption).foregroundColor(.gray)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(servicio.ingredientes, id: \.self) { ing in
                                    let prod = productos.first(where: { $0.nombre == ing.nombreProducto })
                                    let stock = prod?.cantidad ?? 0
                                    let unidad = prod?.unidadDeMedida ?? ""
                                    let ok = stock >= ing.cantidadUsada
                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading) {
                                            Text(ing.nombreProducto).fontWeight(.semibold)
                                            Text("\(ing.cantidadUsada, specifier: "%.2f") \(unidad) requeridos")
                                                .font(.caption).foregroundColor(.gray)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 6) {
                                            Text("Stock: \(stock, specifier: "%.2f")")
                                                .font(.caption)
                                                .foregroundColor(ok ? .green : .red)
                                            stockBar(progress: min(1, max(0, stock == 0 ? 0 : (stock / max(ing.cantidadUsada, 0.0001)))), color: ok ? .green : .red)
                                                .frame(width: 120, height: 6)
                                        }
                                        Image(systemName: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                            .foregroundColor(ok ? .green : .red)
                                    }
                                    .padding(8)
                                    .background(Color("MercedesBackground"))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color("MercedesCard"))
                .cornerRadius(10)
            }
            
            // Barra inferior
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resumen")
                        .font(.headline)
                    HStack(spacing: 12) {
                        Label("Costo piezas: $\(costoEstimado, specifier: "%.2f")", systemImage: "creditcard")
                        Label("Duración: \(servicio.duracionHoras, specifier: "%.1f") h", systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundColor(.gray)
                }
                Spacer()
                Button {
                    ejecutarAsignacion()
                } label: {
                    Label("Confirmar y Empezar Trabajo", systemImage: "checkmark.circle.fill")
                        .font(.headline).padding()
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(vehiculoSeleccionadoID == nil || candidato == nil || hayStockInsuficiente)
                .opacity((vehiculoSeleccionadoID == nil || candidato == nil || hayStockInsuficiente) ? 0.6 : 1.0)
                .help(botonHelpMessage)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(minWidth: 700, minHeight: 600)
        .background(Color("MercedesBackground"))
        .cornerRadius(15)
        .preferredColorScheme(.dark)
        .onAppear { recalcularPreview() }
        .onChange(of: vehiculoSeleccionadoID) { _, _ in recalcularPreview() }
        .alert("Error de Asignación", isPresented: $mostrandoAlerta, presenting: alertaError) { _ in
            Button("OK") { }
        } message: { error in
            Text(error)
        }
    }
    
    private var botonHelpMessage: String {
        if vehiculoSeleccionadoID == nil { return "Selecciona un vehículo para continuar." }
        if candidato == nil { return "No hay candidatos disponibles que cumplan rol y especialidad." }
        if hayStockInsuficiente { return "Hay productos con stock insuficiente para este servicio." }
        return "Listo para confirmar."
    }
    
    // Recalcula candidato, costo y stock para pintar la UI
    private func recalcularPreview() {
        // Candidato
        let candidatos = personal.filter { mec in
            mec.isAsignable &&
            mec.especialidades.contains(servicio.especialidadRequerida) &&
            mec.rol == servicio.rolRequerido
        }
        candidato = candidatos.sorted(by: { $0.rol.rawValue < $1.rol.rawValue }).first
        
        // Costo y stock
        var costo: Double = 0
        var stockOK = true
        for ing in servicio.ingredientes {
            guard let p = productos.first(where: { $0.nombre == ing.nombreProducto }) else { continue }
            costo += (p.costo * ing.cantidadUsada)
            if p.cantidad < ing.cantidadUsada { stockOK = false }
        }
        costoEstimado = costo
        hayStockInsuficiente = !stockOK
    }
    
    // Chips helpers
    private func chip(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color("MercedesBackground"))
        .cornerRadius(8)
    }
    private func chipSmall(text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color("MercedesBackground"))
            .cornerRadius(6)
    }
    private func stockBar(progress: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.25))
                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: geo.size.width * progress)
            }
        }
    }
    
    // Lógica de asignación (igual que antes)
    func ejecutarAsignacion() {
        guard let vehiculoID = vehiculoSeleccionadoID,
              let vehiculo = vehiculos.first(where: { $0.id == vehiculoID }) else {
            alertaError = "No se seleccionó un vehículo."
            mostrandoAlerta = true
            return
        }
        
        let candidatos = personal.filter { mec in
            mec.isAsignable &&
            mec.especialidades.contains(servicio.especialidadRequerida) &&
            mec.rol == servicio.rolRequerido
        }
        
        guard let mecanico = candidatos.sorted(by: { $0.rol.rawValue < $1.rol.rawValue }).first else {
            alertaError = "No se encontraron mecánicos disponibles que cumplan los requisitos de ROL y ESPECIALIDAD."
            mostrandoAlerta = true
            return
        }
        
        var costoTotalProductos: Double = 0.0
        for ingrediente in servicio.ingredientes {
            guard let producto = productos.first(where: { $0.nombre == ingrediente.nombreProducto }) else {
                alertaError = "Error de Sistema: El producto '\(ingrediente.nombreProducto)' no fue encontrado en el inventario."
                mostrandoAlerta = true
                return
            }
            guard producto.cantidad >= ingrediente.cantidadUsada else {
                alertaError = "Stock insuficiente de: \(producto.nombre). Se necesitan \(ingrediente.cantidadUsada) \(producto.unidadDeMedida)(s) pero solo hay \(producto.cantidad)."
                mostrandoAlerta = true
                return
            }
            costoTotalProductos += (producto.costo * ingrediente.cantidadUsada)
        }
        
        let nuevoServicio = ServicioEnProceso(
            nombreServicio: servicio.nombre,
            rfcMecanicoAsignado: mecanico.rfc,
            nombreMecanicoAsignado: mecanico.nombre,
            horaInicio: Date(),
            duracionHoras: servicio.duracionHoras,
            productosConsumidos: servicio.ingredientes.map { $0.nombreProducto },
            vehiculo: vehiculo
        )
        modelContext.insert(nuevoServicio)
        
        mecanico.estado = .ocupado
        
        for ingrediente in servicio.ingredientes {
            if let producto = productos.first(where: { $0.nombre == ingrediente.nombreProducto }) {
                producto.cantidad -= ingrediente.cantidadUsada
            }
        }
        
        let costoFormateado = String(format: "%.2f", costoTotalProductos)
        let registro = DecisionRecord(
            fecha: Date(),
            titulo: "Iniciando: \(servicio.nombre)",
            razon: "Asignado a \(mecanico.nombre) para el vehículo [\(vehiculo.placas)]. Costo piezas: $\(costoFormateado)",
            queryUsuario: "Asignación Automática de Servicio"
        )
        modelContext.insert(registro)
        
        dismiss()
        appState.seleccion = .serviciosEnProceso
    }
}

// --- HELPERS DE PRECIO Y PORCENTAJES ---
fileprivate enum PricingHelpers {
    static func calcularPorcentaje(base: Double, porcentaje: Double) -> Double {
        base * (porcentaje / 100.0)
    }
    static func calcularMontos(baseCosto: Double, pMO: Double, pAdmin: Double, pMargen: Double) -> (mo: Double, admin: Double, margen: Double, subtotal: Double) {
        let mo = calcularPorcentaje(base: baseCosto, porcentaje: pMO)
        let admin = calcularPorcentaje(base: baseCosto, porcentaje: pAdmin)
        let margen = calcularPorcentaje(base: baseCosto, porcentaje: pMargen)
        let subtotal = mo + admin + margen
        return (mo, admin, margen, subtotal)
    }
    static func calcularIVA(subtotal: Double, tasa: Double = 0.16, aplicar: Bool) -> Double {
        aplicar ? subtotal * tasa : 0.0
    }
    static func calcularISR(subtotal: Double, porcentajeISR: Double, aplicar: Bool) -> Double {
        aplicar ? calcularPorcentaje(base: subtotal, porcentaje: porcentajeISR) : 0.0
    }
    static func calcularPrecioSugerido(subtotal: Double, iva: Double, isr: Double) -> Double {
        subtotal + iva + isr
    }
    static func costoIngredientes(servicio: Servicio, productos: [Producto]) -> Double {
        servicio.ingredientes.reduce(0) { acc, ing in
            if let p = productos.first(where: { $0.nombre == ing.nombreProducto }) {
                return acc + (p.costo * ing.cantidadUsada)
            }
            return acc
        }
    }
    static func precioSugeridoParaServicio(servicio: Servicio, productos: [Producto]) -> Double {
        let costoInsumos = costoIngredientes(servicio: servicio, productos: productos)
        let baseCosto = servicio.costoBase + (servicio.requiereRefacciones ? servicio.costoRefacciones : 0) + costoInsumos
        let montos = calcularMontos(baseCosto: baseCosto,
                                    pMO: servicio.porcentajeManoDeObra,
                                    pAdmin: servicio.porcentajeGastosAdministrativos,
                                    pMargen: servicio.porcentajeMargen)
        let iva = calcularIVA(subtotal: montos.subtotal, aplicar: servicio.aplicarIVA)
        let isr = calcularISR(subtotal: montos.subtotal, porcentajeISR: servicio.isrPorcentajeEstimado, aplicar: servicio.aplicarISR)
        return calcularPrecioSugerido(subtotal: montos.subtotal, iva: iva, isr: isr)
    }
}

// --- VISTA DEL FORMULARIO (Actualizada a porcentajes e impuestos) ---
fileprivate struct ServicioFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true
    
    @Query private var productos: [Producto]
    @Query private var personal: [Personal]

    let mode: ServiceModalMode
    
    // Datos base
    @State private var nombre = ""
    @State private var descripcion = ""
    @State private var especialidadRequerida = ""
    @State private var rolRequerido: Rol = .ayudante
    @State private var duracionString = "1.0"
    
    // Ingredientes
    @State private var cantidadesProductos: [String: Double] = [:]
    @State private var especialidadesDisponibles: [String] = []

    // Costos y configuración porcentual
    @State private var costoBaseString = "0.0"
    @State private var requiereRefacciones = false
    @State private var costoRefaccionesString = "0.0"
    @State private var porcentajeMOString = "40.0"
    @State private var porcentajeAdminString = "20.0"
    @State private var porcentajeMargenString = "30.0"
    @State private var aplicarIVA = false
    @State private var aplicarISR = false
    @State private var porcentajeISRString = "10.0" // configurable

    // Precio final editable
    @State private var precioFinalString = "0.0"
    @State private var precioModificadoManualmente = false
    
    // Seguridad para editar nombre en modo edición
    @State private var isNombreUnlocked = false
    @State private var showingAuthModal = false
    @State private var authError = ""
    @State private var passwordAttempt = ""
    @State private var errorMsg: String?
    
    private enum AuthReason {
        case unlockNombre, deleteServicio
    }
    @State private var authReason: AuthReason = .unlockNombre
    
    private var servicioAEditar: Servicio?
    var formTitle: String {
        switch mode {
        case .add: return "Añadir Nuevo Servicio"
        case .edit: return "Editar Servicio"
        case .assign: return "Editar Servicio"
        }
    }
    
    // Validaciones
    private var nombreInvalido: Bool { nombre.trimmingCharacters(in: .whitespaces).count < 3 }
    private var duracionInvalida: Bool { Double(duracionString) == nil || (Double(duracionString) ?? 0) <= 0 }
    private var costoBaseInvalido: Bool { Double(costoBaseString) == nil || (Double(costoBaseString) ?? -1) < 0 }
    private var costoRefInvalido: Bool { Double(costoRefaccionesString) == nil || (Double(costoRefaccionesString) ?? -1) < 0 }
    private var pMOInvalido: Bool { porcentajeInvalido(porcentajeMOString) }
    private var pAdminInvalido: Bool { porcentajeInvalido(porcentajeAdminString) }
    private var pMargenInvalido: Bool { porcentajeInvalido(porcentajeMargenString) }
    private var pISRInvalido: Bool { porcentajeInvalido(porcentajeISRString) }
    private func porcentajeInvalido(_ s: String) -> Bool {
        guard let v = Double(s.replacingOccurrences(of: ",", with: ".")) else { return true }
        return v < 0 || v > 100
    }
    
    // Cálculos automáticos (solo lectura)
    private var costoIngredientes: Double {
        PricingHelpers.costoIngredientes(servicio: servicioPreview, productos: productos)
    }
    private var baseCostoTotal: Double {
        (Double(costoBaseString) ?? 0) + (requiereRefacciones ? (Double(costoRefaccionesString) ?? 0) : 0) + costoIngredientes
    }
    private var moMonto: Double {
        PricingHelpers.calcularPorcentaje(base: baseCostoTotal, porcentaje: Double(porcentajeMOString) ?? 0)
    }
    private var adminMonto: Double {
        PricingHelpers.calcularPorcentaje(base: baseCostoTotal, porcentaje: Double(porcentajeAdminString) ?? 0)
    }
    private var margenMonto: Double {
        PricingHelpers.calcularPorcentaje(base: baseCostoTotal, porcentaje: Double(porcentajeMargenString) ?? 0)
    }
    private var subtotal: Double { moMonto + adminMonto + margenMonto }
    private var ivaMonto: Double { PricingHelpers.calcularIVA(subtotal: subtotal, aplicar: aplicarIVA) }
    private var isrMonto: Double { PricingHelpers.calcularISR(subtotal: subtotal, porcentajeISR: Double(porcentajeISRString) ?? 0, aplicar: aplicarISR) }
    private var precioSugerido: Double { PricingHelpers.calcularPrecioSugerido(subtotal: subtotal, iva: ivaMonto, isr: isrMonto) }
    
    // Servicio “preview” para cálculo de ingredientes
    private var servicioPreview: Servicio {
        let ingredientesArray: [Ingrediente] = cantidadesProductos.compactMap { (nombre, cantidad) in
            guard cantidad > 0 else { return nil }
            return Ingrediente(nombreProducto: nombre, cantidadUsada: cantidad)
        }
        // Construimos un objeto efímero solo para helpers (no se inserta)
        let dummy = Servicio(
            nombre: nombre.isEmpty ? "tmp" : nombre,
            descripcion: descripcion,
            especialidadRequerida: especialidadRequerida,
            rolRequerido: rolRequerido,
            ingredientes: ingredientesArray,
            precioAlCliente: Double(precioFinalString) ?? 0,
            duracionHoras: Double(duracionString) ?? 1.0,
            costoBase: Double(costoBaseString) ?? 0,
            requiereRefacciones: requiereRefacciones,
            costoRefacciones: Double(costoRefaccionesString) ?? 0,
            porcentajeManoDeObra: Double(porcentajeMOString) ?? 0,
            porcentajeGastosAdministrativos: Double(porcentajeAdminString) ?? 0,
            porcentajeMargen: Double(porcentajeMargenString) ?? 0,
            aplicarIVA: aplicarIVA,
            aplicarISR: aplicarISR,
            isrPorcentajeEstimado: Double(porcentajeISRString) ?? 0,
            precioFinalAlCliente: Double(precioFinalString) ?? 0,
            precioModificadoManualmente: precioModificadoManualmente
        )
        return dummy
    }
    
    init(mode: ServiceModalMode) {
        self.mode = mode
        
        if case .edit(let servicio) = mode {
            self.servicioAEditar = servicio
            _nombre = State(initialValue: servicio.nombre)
            _descripcion = State(initialValue: servicio.descripcion)
            _especialidadRequerida = State(initialValue: servicio.especialidadRequerida)
            _rolRequerido = State(initialValue: servicio.rolRequerido)
            _duracionString = State(initialValue: String(format: "%.2f", servicio.duracionHoras))
            let cantidades = Dictionary(uniqueKeysWithValues: servicio.ingredientes.map { ($0.nombreProducto, $0.cantidadUsada) })
            _cantidadesProductos = State(initialValue: cantidades)
            
            // Nuevos campos
            _costoBaseString = State(initialValue: String(format: "%.2f", servicio.costoBase))
            _requiereRefacciones = State(initialValue: servicio.requiereRefacciones)
            _costoRefaccionesString = State(initialValue: String(format: "%.2f", servicio.costoRefacciones))
            _porcentajeMOString = State(initialValue: String(format: "%.2f", servicio.porcentajeManoDeObra))
            _porcentajeAdminString = State(initialValue: String(format: "%.2f", servicio.porcentajeGastosAdministrativos))
            _porcentajeMargenString = State(initialValue: String(format: "%.2f", servicio.porcentajeMargen))
            _aplicarIVA = State(initialValue: servicio.aplicarIVA)
            _aplicarISR = State(initialValue: servicio.aplicarISR)
            _porcentajeISRString = State(initialValue: String(format: "%.2f", servicio.isrPorcentajeEstimado))
            _precioFinalString = State(initialValue: String(format: "%.2f", servicio.precioFinalAlCliente))
            _precioModificadoManualmente = State(initialValue: servicio.precioModificadoManualmente)
        } else {
            // defaults para alta
            _porcentajeMOString = State(initialValue: "40.0")
            _porcentajeAdminString = State(initialValue: "20.0")
            _porcentajeMargenString = State(initialValue: "30.0")
            _porcentajeISRString = State(initialValue: "10.0")
            _precioFinalString = State(initialValue: "0.0")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(formTitle).font(.title).fontWeight(.bold)
                Text("Completa los datos. Los campos marcados con • son obligatorios.")
                    .font(.footnote).foregroundColor(.gray)
            }
            .padding(.top, 14).padding(.bottom, 8)

            Form {
                Section {
                    SectionHeader(title: "Detalles del Servicio", subtitle: nil)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("• Nombre del Servicio").font(.caption).foregroundColor(.gray)
                            if servicioAEditar != nil {
                                Image(systemName: isNombreUnlocked ? "lock.open.fill" : "lock.fill")
                                    .foregroundColor(isNombreUnlocked ? .green : .red)
                                    .font(.caption)
                            }
                        }
                        HStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                TextField("", text: $nombre)
                                    .disabled(servicioAEditar != nil && !isNombreUnlocked)
                                    .padding(8).background(Color("MercedesBackground").opacity(0.9)).cornerRadius(8)
                                if nombre.isEmpty {
                                    Text("ej. Cambio de Frenos Delanteros")
                                        .foregroundColor(Color.white.opacity(0.35))
                                        .padding(.horizontal, 12).allowsHitTesting(false)
                                }
                            }
                            if servicioAEditar != nil {
                                Button {
                                    if isNombreUnlocked { isNombreUnlocked = false }
                                    else {
                                        authReason = .unlockNombre
                                        showingAuthModal = true
                                    }
                                } label: {
                                    Text(isNombreUnlocked ? "Bloquear" : "Desbloquear")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(isNombreUnlocked ? .green : .red)
                            }
                        }
                        .validationHint(isInvalid: nombreInvalido, message: "El nombre debe tener al menos 3 caracteres.")
                    }
                    
                    FormField(title: "Descripción", placeholder: "ej. Reemplazo de balatas y rectificación de discos", text: $descripcion)
                    
                    HStack(spacing: 16) {
                        FormField(title: "• Duración Estimada (Horas)", placeholder: "ej. 2.5", text: $duracionString)
                            .validationHint(isInvalid: duracionInvalida, message: "Debe ser un número > 0.")
                        Picker("• Especialidad Requerida", selection: $especialidadRequerida) {
                            Text("Seleccionar...").tag("")
                            ForEach(especialidadesDisponibles, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                        Picker("• Rol Requerido", selection: $rolRequerido) {
                            ForEach(Rol.allCases, id: \.self) { rol in
                                Text(rol.rawValue).tag(rol)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // Configuración de Costos Base
                Section {
                    SectionHeader(title: "Costos Base", subtitle: "Costo del servicio y refacciones")
                    HStack(spacing: 16) {
                        FormField(title: "• Costo base del servicio ($)", placeholder: "ej. 800.00", text: $costoBaseString)
                            .validationHint(isInvalid: costoBaseInvalido, message: "Debe ser un número ≥ 0.")
                        Toggle("¿Requiere refacciones?", isOn: $requiereRefacciones)
                            .toggleStyle(.switch)
                            .font(.caption)
                            .foregroundColor(.gray)
                        FormField(title: "Costo de refacciones ($)", placeholder: "ej. 500.00", text: $costoRefaccionesString)
                            .validationHint(isInvalid: costoRefInvalido, message: "Debe ser un número ≥ 0.")
                            .disabled(!requiereRefacciones)
                            .opacity(requiereRefacciones ? 1 : 0.5)
                    }
                    HStack {
                        Text("Costo de ingredientes (automático): $\(costoIngredientes, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
                
                // Configuración Porcentual
                Section {
                    SectionHeader(title: "Configuración Porcentual", subtitle: "Todo en % (0 a 100)")
                    HStack(spacing: 16) {
                        FormField(title: "• % Mano de Obra", placeholder: "ej. 40", text: $porcentajeMOString)
                            .validationHint(isInvalid: pMOInvalido, message: "0 a 100.")
                        FormField(title: "• % Gastos Administrativos", placeholder: "ej. 20", text: $porcentajeAdminString)
                            .validationHint(isInvalid: pAdminInvalido, message: "0 a 100.")
                        FormField(title: "• % Margen de Ganancia", placeholder: "ej. 30", text: $porcentajeMargenString)
                            .validationHint(isInvalid: pMargenInvalido, message: "0 a 100.")
                    }
                    HStack(spacing: 16) {
                        Toggle("Aplicar IVA (16%)", isOn: $aplicarIVA)
                        Toggle("Aplicar ISR (aprox.)", isOn: $aplicarISR)
                        FormField(title: "% ISR (aprox.)", placeholder: "ej. 10", text: $porcentajeISRString)
                            .validationHint(isInvalid: pISRInvalido, message: "0 a 100.")
                            .disabled(!aplicarISR)
                            .opacity(aplicarISR ? 1 : 0.5)
                    }
                    Text("Los cálculos de ISR son aproximados. Verifique las tablas oficiales del SAT.")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
                
                // Ingredientes
                Section {
                    SectionHeader(title: "Productos Requeridos", subtitle: "Ingresa la cantidad a usar por servicio (ej. 0.5)")
                    
                    List(productos) { producto in
                        HStack {
                            Text("\(producto.nombre) (\(producto.unidadDeMedida))")
                            Spacer()
                            HStack(spacing: 6) {
                                TextField("0.0", text: Binding(
                                    get: {
                                        cantidadesProductos[producto.nombre].map { String(format: "%.2f", $0) } ?? ""
                                    },
                                    set: {
                                        cantidadesProductos[producto.nombre] = Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0
                                    }
                                ))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                if (cantidadesProductos[producto.nombre] ?? 0) > 0 {
                                    Button {
                                        cantidadesProductos[producto.nombre] = 0
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .listRowBackground(Color("MercedesCard"))
                    }
                    .frame(minHeight: 150, maxHeight: 250)
                }
                
                // Cálculos automáticos y Precio
                Section {
                    SectionHeader(title: "Cálculos Automáticos", subtitle: "Solo lectura")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 8) {
                        roField("Monto Mano de Obra", moMonto)
                        roField("Monto Gastos Administrativos", adminMonto)
                        roField("Monto Margen", margenMonto)
                        roField("Subtotal", subtotal)
                        roField("IVA (16%)", ivaMonto)
                        roField("ISR (aprox.)", isrMonto)
                    }
                    // Precio sugerido y final
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Precio Sugerido: $\(precioSugerido, specifier: "%.2f")")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        HStack(spacing: 12) {
                            FormField(title: "Precio final al cliente (editable)", placeholder: "ej. 2500.00", text: $precioFinalString)
                                .onChange(of: precioFinalString) { _, new in
                                    // Marca como modificado si difiere del sugerido por más de 1 centavo
                                    let final = Double(new.replacingOccurrences(of: ",", with: ".")) ?? 0
                                    precioModificadoManualmente = abs(final - precioSugerido) > 0.009
                                }
                            if precioModificadoManualmente {
                                Text("Modificado manualmente")
                                    .font(.caption)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.yellow.opacity(0.2))
                                    .foregroundColor(.yellow)
                                    .cornerRadius(6)
                            }
                        }
                        Text("El precio sugerido se mantiene como referencia si editas el precio final.")
                            .font(.caption).foregroundColor(.gray)
                    }
                }
            }
            .textFieldStyle(PlainTextFieldStyle())
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .onAppear {
                let todasLasHabilidades = personal.flatMap { $0.especialidades }
                especialidadesDisponibles = Array(Set(todasLasHabilidades)).sorted()
                
                if servicioAEditar == nil {
                    rolRequerido = .ayudante
                    if let primera = especialidadesDisponibles.first {
                        especialidadRequerida = primera
                    }
                    // Inicializar precio final con el sugerido al abrir "add"
                    precioFinalString = String(format: "%.2f", precioSugerido)
                }
            }
            .onChange(of: costoBaseString) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: requiereRefacciones) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: costoRefaccionesString) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: porcentajeMOString) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: porcentajeAdminString) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: porcentajeMargenString) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: aplicarIVA) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: aplicarISR) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: porcentajeISRString) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: cantidadesProductos) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: duracionString) { _, _ in /* no afecta precio, solo info */ }
            
            if let errorMsg {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.vertical, 6)
            }
            
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding(.vertical, 6).padding(.horizontal, 8).foregroundColor(.gray)
                
                if case .edit = mode {
                    Button("Eliminar", role: .destructive) {
                        authReason = .deleteServicio
                        showingAuthModal = true
                    }
                    .buttonStyle(.plain).padding(.vertical, 6).padding(.horizontal, 8).foregroundColor(.red)
                }
                Spacer()
                Button(servicioAEditar == nil ? "Añadir Servicio" : "Guardar Cambios") {
                    guardarCambios()
                }
                .buttonStyle(.plain).padding(.vertical, 8).padding(.horizontal, 12)
                .foregroundColor(Color("MercedesPetrolGreen")).cornerRadius(8)
                .disabled(nombreInvalido || duracionInvalida || costoBaseInvalido || costoRefInvalido || pMOInvalido || pAdminInvalido || pMargenInvalido || pISRInvalido || especialidadRequerida.isEmpty)
                .opacity((nombreInvalido || duracionInvalida || costoBaseInvalido || costoRefInvalido || pMOInvalido || pAdminInvalido || pMargenInvalido || pISRInvalido || especialidadRequerida.isEmpty) ? 0.6 : 1.0)
            }
            .padding(.horizontal).padding(.bottom, 8)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 760, minHeight: 600, maxHeight: 600)
        .cornerRadius(15)
        .sheet(isPresented: $showingAuthModal) {
            authModalView()
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
    
    private func syncPrecioFinalConSugeridoSiNoManual() {
        if !precioModificadoManualmente {
            precioFinalString = String(format: "%.2f", precioSugerido)
        }
    }
    
    @ViewBuilder
    func authModalView() -> some View {
        let prompt = (authReason == .unlockNombre) ?
            "Autoriza para editar el Nombre del Servicio." :
            "Autoriza para ELIMINAR este servicio."
        
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Autorización Requerida").font(.title).fontWeight(.bold)
                Text(prompt)
                    .font(.callout)
                    .foregroundColor(authReason == .deleteServicio ? .red : .gray)
                
                if isTouchIDEnabled {
                    Button { Task { await authenticateWithTouchID() } } label: {
                        Label("Usar Huella (Touch ID)", systemImage: "touchid")
                            .font(.headline).padding().frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    Text("o").foregroundColor(.gray)
                }
                
                Text("Usa tu contraseña de administrador:").font(.subheadline)
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
    
    func guardarCambios() {
        errorMsg = nil
        let trimmedNombre = nombre.trimmingCharacters(in: .whitespaces)
        
        guard trimmedNombre.count >= 3 else {
            errorMsg = "El nombre del servicio debe tener al menos 3 caracteres."
            return
        }
        guard let duracion = Double(duracionString), duracion > 0 else {
            errorMsg = "La Duración debe ser un número mayor a 0."
            return
        }
        guard let costoBase = Double(costoBaseString.replacingOccurrences(of: ",", with: ".")), costoBase >= 0 else {
            errorMsg = "El Costo base debe ser un número válido."
            return
        }
        guard let costoRef = Double(costoRefaccionesString.replacingOccurrences(of: ",", with: ".")), (!requiereRefacciones || costoRef >= 0) else {
            errorMsg = "El Costo de refacciones debe ser un número válido."
            return
        }
        guard let pMO = Double(porcentajeMOString.replacingOccurrences(of: ",", with: ".")), (0...100).contains(pMO) else {
            errorMsg = "% Mano de Obra inválido."
            return
        }
        guard let pAdmin = Double(porcentajeAdminString.replacingOccurrences(of: ",", with: ".")), (0...100).contains(pAdmin) else {
            errorMsg = "% Gastos Administrativos inválido."
            return
        }
        guard let pMargen = Double(porcentajeMargenString.replacingOccurrences(of: ",", with: ".")), (0...100).contains(pMargen) else {
            errorMsg = "% Margen inválido."
            return
        }
        guard let pISR = Double(porcentajeISRString.replacingOccurrences(of: ",", with: ".")), (0...100).contains(pISR) else {
            errorMsg = "% ISR inválido."
            return
        }
        
        let ingredientesArray: [Ingrediente] = cantidadesProductos.compactMap { (nombre, cantidad) in
            guard cantidad > 0 else { return nil }
            return Ingrediente(nombreProducto: nombre, cantidadUsada: cantidad)
        }
        
        let final = Double(precioFinalString.replacingOccurrences(of: ",", with: ".")) ?? precioSugerido
        
        if let servicio = servicioAEditar {
            // Actualiza todos los campos
            servicio.nombre = trimmedNombre
            servicio.descripcion = descripcion
            servicio.especialidadRequerida = especialidadRequerida
            servicio.rolRequerido = rolRequerido
            servicio.duracionHoras = duracion
            servicio.ingredientes = ingredientesArray
            
            servicio.costoBase = costoBase
            servicio.requiereRefacciones = requiereRefacciones
            servicio.costoRefacciones = costoRef
            servicio.porcentajeManoDeObra = pMO
            servicio.porcentajeGastosAdministrativos = pAdmin
            servicio.porcentajeMargen = pMargen
            servicio.aplicarIVA = aplicarIVA
            servicio.aplicarISR = aplicarISR
            servicio.isrPorcentajeEstimado = pISR
            
            servicio.precioFinalAlCliente = final
            servicio.precioModificadoManualmente = precioModificadoManualmente
            
            // Compatibilidad: actualiza precioAlCliente a lo final (para vistas antiguas/IA)
            servicio.precioAlCliente = final
        } else {
            let nuevoServicio = Servicio(
                nombre: trimmedNombre,
                descripcion: descripcion,
                especialidadRequerida: especialidadRequerida,
                rolRequerido: rolRequerido,
                ingredientes: ingredientesArray,
                precioAlCliente: final, // compat
                duracionHoras: duracion,
                costoBase: costoBase,
                requiereRefacciones: requiereRefacciones,
                costoRefacciones: costoRef,
                porcentajeManoDeObra: pMO,
                porcentajeGastosAdministrativos: pAdmin,
                porcentajeMargen: pMargen,
                aplicarIVA: aplicarIVA,
                aplicarISR: aplicarISR,
                isrPorcentajeEstimado: pISR,
                precioFinalAlCliente: final,
                precioModificadoManualmente: precioModificadoManualmente
            )
            modelContext.insert(nuevoServicio)
        }
        dismiss()
    }
    
    func eliminarServicio(_ servicio: Servicio) {
        modelContext.delete(servicio)
        dismiss()
    }
    
    func authenticateWithTouchID() async {
        let context = LAContext()
        let reason = (authReason == .unlockNombre) ? "Autoriza la edición del Nombre." : "Autoriza la ELIMINACIÓN del servicio."
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
        case .unlockNombre:
            isNombreUnlocked = true
        case .deleteServicio:
            if case .edit(let servicio) = mode {
                eliminarServicio(servicio)
            }
        }
        showingAuthModal = false
        authError = ""
        passwordAttempt = ""
    }
}

// --- Helpers de UI reutilizados ---
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

// --- FormModal usado por AsignarServicioModal ---
fileprivate struct FormModal<Content: View>: View {
    var title: String
    var minHeight: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.largeTitle).fontWeight(.bold)
            
            Form {
                content()
            }
            .textFieldStyle(PlainTextFieldStyle())
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .padding(30)
        .frame(minWidth: 500, minHeight: minHeight)
        .background(Color("MercedesCard"))
        .cornerRadius(15)
        .preferredColorScheme(.dark)
    }
}

