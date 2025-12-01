import SwiftUI
import SwiftData
import LocalAuthentication

// --- MODO DEL MODAL (Actualizado con assign y schedule) ---
fileprivate enum ServiceModalMode: Identifiable {
    case add
    case edit(Servicio)
    case assign(Servicio)
    case schedule(Servicio)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let servicio): return servicio.nombre
        case .assign(let servicio): return "assign-\(servicio.nombre)"
        case .schedule(let servicio): return "schedule-\(servicio.nombre)"
        }
    }
}

// --- VISTA PRINCIPAL (alineada a InventarioView) ---
struct ServiciosView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppNavigationState
    @Query(sort: \Servicio.nombre) private var servicios: [Servicio]
    
    @State private var modalMode: ServiceModalMode?
    @State private var searchQuery = ""
    
    // Ordenamiento (patrón InventarioView)
    enum SortOption: String, CaseIterable, Identifiable {
        case nombre = "Nombre"
        case precio = "Precio final"
        case duracion = "Duración"
        var id: String { rawValue }
    }
    @State private var sortOption: SortOption = .nombre
    @State private var sortAscending: Bool = true
    
    var filteredServicios: [Servicio] {
        var base = servicios
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchQuery.lowercased()
            base = base.filter {
                $0.nombre.lowercased().contains(query) ||
                $0.rolRequerido.rawValue.lowercased().contains(query) ||
                $0.especialidadRequerida.lowercased().contains(query)
            }
        }
        // Ordenamiento
        base.sort { a, b in
            switch sortOption {
            case .nombre:
                let cmp = a.nombre.localizedCaseInsensitiveCompare(b.nombre)
                return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
            case .precio:
                return sortAscending ? (a.precioFinalAlCliente < b.precioFinalAlCliente) : (a.precioFinalAlCliente > b.precioFinalAlCliente)
            case .duracion:
                return sortAscending ? (a.duracionHoras < b.duracionHoras) : (a.duracionHoras > b.duracionHoras)
            }
        }
        return base
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header compacto con métrica y CTA (patrón InventarioView)
            header
            
            // Filtros y búsqueda mejorados
            filtrosView
            
            // Lista de servicios
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Contador de resultados
                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .foregroundColor(Color("MercedesPetrolGreen"))
                        Text("\(filteredServicios.count) resultado\(filteredServicios.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    if filteredServicios.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    } else {
                        ForEach(filteredServicios) { servicio in
                            ServicioCard(
                                servicio: servicio,
                                costoEstimado: costoEstimadoProductos(servicio),
                                productosCount: servicio.ingredientes.count,
                                onEdit: { modalMode = .edit(servicio) },
                                onAssign: { modalMode = .assign(servicio) },
                                onSchedule: { modalMode = .schedule(servicio) }
                            )
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
        .sheet(item: $modalMode) { mode in
            switch mode {
            case .add:
                ServicioFormView(mode: .add, modalMode: $modalMode)
                    .environment(\.modelContext, modelContext)
            case .edit(let servicio):
                ServicioFormView(mode: .edit(servicio), modalMode: $modalMode)
                    .environment(\.modelContext, modelContext)
            case .assign(let servicio):
                AsignarServicioModal(servicio: servicio, appState: appState)
                    .environment(\.modelContext, modelContext)
            case .schedule(let servicio):
                ProgramarServicioModal(servicio: servicio, appState: appState)
                    .environment(\.modelContext, modelContext)
            }
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
                    Text("Gestión de Servicios")
                        .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    HStack(spacing: 10) {
                        Label("\(servicios.count) en catálogo", systemImage: "wrench.and.screwdriver.fill")
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
                .help("Crear un nuevo servicio")
            }
            .padding(.horizontal, 12)
        }
    }
    
    private var filtrosView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Buscar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    TextField("Buscar por Nombre, Rol o Especialidad...", text: $searchQuery)
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
                
                // Orden
                HStack(spacing: 6) {
                    Picker("Ordenar", selection: $sortOption) {
                        ForEach(SortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 160)
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
                
                // Filtros activos + limpiar (si aplica)
                if !searchQuery.isEmpty || sortOption != .nombre || sortAscending == false {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("Filtros activos")
                        if !searchQuery.isEmpty {
                            Text("“\(searchQuery)”")
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color("MercedesBackground")).cornerRadius(6)
                        }
                        if sortOption != .nombre {
                            Text("Orden: \(sortOption.rawValue)")
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color("MercedesBackground")).cornerRadius(6)
                        }
                        if sortAscending == false {
                            Text("Descendente")
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color("MercedesBackground")).cornerRadius(6)
                        }
                        Button {
                            withAnimation {
                                searchQuery = ""
                                sortOption = .nombre
                                sortAscending = true
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
    
    // Empty state compacto
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "wrench.adjustable")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(Color("MercedesPetrolGreen"))
            Text(searchQuery.isEmpty ? "No hay servicios registrados aún." :
                 "No se encontraron servicios para “\(searchQuery)”.")
                .font(.subheadline)
                .foregroundColor(.gray)
            if searchQuery.isEmpty {
                Text("Añade tu primer servicio para empezar a asignar trabajos.")
                    .font(.caption2)
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

// Tarjeta individual de servicio (alineada a ProductoCard/PersonalCard)
fileprivate struct ServicioCard: View {
    let servicio: Servicio
    let costoEstimado: Double
    let productosCount: Int
    var onEdit: () -> Void
    var onAssign: () -> Void
    var onSchedule: () -> Void
    
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
                        .font(.headline).fontWeight(.semibold)
                    Text(servicio.descripcion.isEmpty ? "Sin descripción" : servicio.descripcion)
                        .font(.caption2).foregroundColor(.gray)
                        .lineLimit(2)
                }
                Spacer()
                HStack(spacing: 6) {
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
                    
                    Button {
                        onSchedule()
                    } label: {
                        Label("Programar", systemImage: "calendar.badge.plus")
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(Color.blue.opacity(0.25))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                }
            }
            
            // Chips de requerimientos
            HStack(spacing: 6) {
                chip(text: servicio.rolRequerido.rawValue, systemImage: "person.badge.shield.checkmark.fill")
                chip(text: servicio.especialidadRequerida, systemImage: "wrench.and.screwdriver.fill")
                chip(text: String(format: "%.1f h", servicio.duracionHoras), systemImage: "clock")
                Spacer()
            }
            
            // Productos y costo + precio final
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("\(productosCount) producto\(productosCount == 1 ? "" : "s")", systemImage: "shippingbox.fill")
                    Spacer()
                    Label("Costo insumos: $\(costoEstimado, specifier: "%.2f")", systemImage: "creditcard")
                }
                .font(.caption2)
                .foregroundColor(.gray)
                
                // Precio final y sugerido (si fue modificado)
                let sugerido = PricingHelpers.precioSugeridoParaServicio(servicio: servicio, productos: productos)
                HStack(spacing: 10) {
                    Text("$\(servicio.precioFinalAlCliente, specifier: "%.2f")")
                        .font(.headline)
                        .foregroundColor(.white)
                    if servicio.precioModificadoManualmente {
                        Text("Sugerido: $\(sugerido, specifier: "%.2f")")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 6).padding(.vertical, 3)
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
                    .font(.caption2)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background((estado.asignable ? Color.green : Color.red).opacity(0.15))
                    .foregroundColor(estado.asignable ? .green : .red)
                    .cornerRadius(6)
                Spacer()
                Button {
                    onAssign()
                } label: {
                    Label("Asignar", systemImage: "arrow.right.circle.fill")
                        .font(.subheadline)
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
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
    }
    
    private func chip(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption2)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color("MercedesBackground"))
        .cornerRadius(6)
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
    // Nuevo: tickets para balanceo justo
    @Query private var tickets: [ServicioEnProceso]
    
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
    @State private var fechaFinEstimada: Date?
    
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
                .font(.title2).fontWeight(.bold)
            
            // Header con resumen del servicio
            VStack(alignment: .leading, spacing: 8) {
                Text(servicio.nombre)
                    .font(.headline).fontWeight(.semibold)
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
                                            .font(.subheadline).fontWeight(.semibold)
                                        Text("Cliente: \(vehiculo.cliente?.nombre ?? "N/A")")
                                            .font(.caption2).foregroundColor(.gray)
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
                                .font(.caption2).foregroundColor(.gray).padding(.top, 6)
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
                                .font(.caption2)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(candidatoColor.opacity(0.2))
                                .foregroundColor(candidatoColor)
                                .cornerRadius(6)
                        }
                        .font(.subheadline)
                        Text("Rol: \(c.rol.rawValue)")
                            .font(.caption2).foregroundColor(.gray)
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
                            .font(.caption2).foregroundColor(.red)
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
                            .font(.caption2).foregroundColor(.gray)
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
                                                .font(.caption2).foregroundColor(.gray)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 6) {
                                            Text("Stock: \(stock, specifier: "%.2f")")
                                                .font(.caption2)
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
                    
                    if let fin = fechaFinEstimada, !Calendar.current.isDate(fin, inSameDayAs: Date()) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.calendar")
                            Text("Finaliza el \(fin.formatted(date: .abbreviated, time: .shortened))")
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                    }
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
        // Candidato justo por balance
        let ahora = Date()
        let candidatos = personal.filter { mec in
            mec.isAsignable &&
            mec.especialidades.contains(servicio.especialidadRequerida) &&
            mec.rol == servicio.rolRequerido
        }
        let ordenados = ordenarCandidatosJusto(candidatos: candidatos, inicio: ahora, duracionHoras: servicio.duracionHoras)
        candidato = ordenados.first
        
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
        
        if let c = candidato {
            fechaFinEstimada = c.calcularFechaFin(inicio: ahora, duracionHoras: servicio.duracionHoras)
        } else {
            fechaFinEstimada = nil
        }
    }
    
    // Chips helpers
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
    
    // Lógica de asignación con balance justo
    func ejecutarAsignacion() {
        guard let vehiculoID = vehiculoSeleccionadoID,
              let vehiculo = vehiculos.first(where: { $0.id == vehiculoID }) else {
            alertaError = "No se seleccionó un vehículo."
            mostrandoAlerta = true
            return
        }
        
        // Selección justa en el momento de confirmar
        let ahora = Date()
        
        let candidatosElegibles = personal.filter { mec in
            mec.isAsignable &&
            mec.especialidades.contains(servicio.especialidadRequerida) &&
            mec.rol == servicio.rolRequerido
        }
        let ordenados = ordenarCandidatosJusto(candidatos: candidatosElegibles, inicio: ahora, duracionHoras: servicio.duracionHoras)
        guard let mecanico = ordenados.first else {
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
            horaInicio: ahora,
            duracionHoras: servicio.duracionHoras,
            productosConsumidos: servicio.ingredientes.map { $0.nombreProducto },
            vehiculo: vehiculo
        )
        nuevoServicio.estado = .enProceso
        // Ajustar fecha fin estimada respetando horario
        nuevoServicio.horaFinEstimada = mecanico.calcularFechaFin(inicio: ahora, duracionHoras: servicio.duracionHoras)
        
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
            razon: "Asignado (balanceado) a \(mecanico.nombre) para el vehículo [\(vehiculo.placas)]. Costo piezas: $\(costoFormateado)",
            queryUsuario: "Asignación Automática de Servicio (balance justo)"
        )
        modelContext.insert(registro)
        
        dismiss()
        appState.seleccion = .serviciosEnProceso
    }
    
    // MARK: - Helpers de balance justo (Asignar)
    private func calcularCargaHoras(rfc: String, en inicio: Date, fin: Date) -> Double {
        var suma: Double = 0
        for t in tickets {
            guard (t.estado == .programado || t.estado == .enProceso) else { continue }
            guard t.rfcMecanicoAsignado == rfc || t.rfcMecanicoSugerido == rfc else { continue }
            let ti = t.fechaProgramadaInicio ?? t.horaInicio
            let tf: Date = (t.estado == .programado) ? (ti.addingTimeInterval(t.duracionHoras * 3600)) : t.horaFinEstimada
            // Si hay solape, sumar la intersección en horas
            if inicio < tf && fin > ti {
                let interIni = max(inicio, ti)
                let interFin = min(fin, tf)
                let horas = interFin.timeIntervalSince(interIni) / 3600.0
                suma += max(0, horas)
            }
        }
        return suma
    }
    
    private func ultimaAsignacion(rfc: String) -> Date {
        var ultimo: Date = .distantPast
        for t in tickets {
            guard t.rfcMecanicoAsignado == rfc || t.rfcMecanicoSugerido == rfc else { continue }
            let fecha = (t.estado == .programado) ? (t.fechaProgramadaInicio ?? t.horaInicio) : t.horaInicio
            if fecha > ultimo { ultimo = fecha }
        }
        return ultimo
    }
    
    private func ordenarCandidatosJusto(candidatos: [Personal], inicio: Date, duracionHoras: Double) -> [Personal] {
        return candidatos.sorted { a, b in
            let finA = a.calcularFechaFin(inicio: inicio, duracionHoras: duracionHoras)
            let finB = b.calcularFechaFin(inicio: inicio, duracionHoras: duracionHoras)
            
            let cargaA = calcularCargaHoras(rfc: a.rfc, en: inicio, fin: finA)
            let cargaB = calcularCargaHoras(rfc: b.rfc, en: inicio, fin: finB)
            
            if abs(cargaA - cargaB) > 0.0001 {
                return cargaA < cargaB
            }
            let lastA = ultimaAsignacion(rfc: a.rfc)
            let lastB = ultimaAsignacion(rfc: b.rfc)
            if lastA != lastB {
                return lastA < lastB // el que lleva más tiempo sin asignación primero
            }
            return a.nombre < b.nombre
        }
    }
}

// --- MODAL DE PROGRAMACIÓN (nuevo) ---
fileprivate struct ProgramarServicioModal: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var personal: [Personal]
    @Query private var productos: [Producto]
    @Query private var vehiculos: [Vehiculo]
    @Query private var tickets: [ServicioEnProceso]
    
    var servicio: Servicio
    @ObservedObject var appState: AppNavigationState
    
    // UI State
    @State private var vehiculoSeleccionadoID: Vehiculo.ID?
    @State private var searchVehiculo = ""
    @State private var fechaInicio: Date = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    
    // Preview calculada
    @State private var candidato: Personal?
    @State private var conflictoMensaje: String?
    @State private var stockAdvertencia: String?
    
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
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Programar Servicio")
                .font(.title2).fontWeight(.bold)
            
            // Resumen Servicio
            VStack(alignment: .leading, spacing: 8) {
                Text(servicio.nombre)
                    .font(.headline).fontWeight(.semibold)
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
            
            // Selección de vehículo y fecha
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selecciona el Vehículo").font(.headline)
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color("MercedesPetrolGreen"))
                        TextField("Buscar por placas, cliente, marca o modelo...", text: $searchVehiculo)
                            .textFieldStyle(PlainTextFieldStyle())
                        if !searchVehiculo.isEmpty {
                            Button {
                                searchVehiculo = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(Color("MercedesBackground"))
                    .cornerRadius(8)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(vehiculosFiltrados) { vehiculo in
                                let isSelected = vehiculoSeleccionadoID == vehiculo.id
                                Button {
                                    vehiculoSeleccionadoID = vehiculo.id
                                    recalcularCandidato()
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("[\(vehiculo.placas)]")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(Color("MercedesPetrolGreen"))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(vehiculo.marca) \(vehiculo.modelo) (\(vehiculo.anio))")
                                                .font(.subheadline).fontWeight(.semibold)
                                            Text("Cliente: \(vehiculo.cliente?.nombre ?? "N/A")")
                                                .font(.caption2).foregroundColor(.gray)
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
                        }
                    }
                    .frame(maxHeight: 160)
                }
                .frame(maxWidth: .infinity)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fecha y hora de inicio").font(.headline)
                    DatePicker("Inicio", selection: $fechaInicio, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .onChange(of: fechaInicio) { _, _ in recalcularCandidato() }
                    Text("Fin estimado: \(fechaInicio.addingTimeInterval(servicio.duracionHoras * 3600).formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundColor(.gray)
                }
                .frame(maxWidth: 320)
            }
            .padding()
            .background(Color("MercedesCard"))
            .cornerRadius(10)
            
            // Candidato sugerido y advertencias
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
                    guardarProgramacion()
                } label: {
                    Label("Guardar Programación", systemImage: "calendar.badge.checkmark")
                        .font(.headline)
                        .padding()
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(vehiculoSeleccionadoID == nil || candidato == nil || fechaInicio < Date())
                .opacity((vehiculoSeleccionadoID == nil || candidato == nil || fechaInicio < Date()) ? 0.6 : 1.0)
            }
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 600)
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
    
    // Selección automática del mejor candidato sin solapes con balance justo
    private func recalcularCandidato() {
        conflictoMensaje = nil
        stockAdvertencia = nil
        
        // 1) Posibles candidatos por rol/especialidad y disponibilidad laboral (día/horas)
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: fechaInicio)
        let startHour = cal.component(.hour, from: fechaInicio)
        
        // Filtramos solo por inicio dentro del horario (o cerca), pero NO exigimos que termine hoy.
        let candidatosBase = personal.filter { mec in
            mec.rol == servicio.rolRequerido &&
            mec.especialidades.contains(servicio.especialidadRequerida) &&
            mec.diasLaborales.contains(weekday) &&
            (mec.horaEntrada <= startHour) // Debe haber empezado su turno (o estar en él)
        }
        
        // 2) Evitar solapes
        // Para verificar solapes, necesitamos calcular el fin REAL para cada candidato
        let candidatosSinSolape = candidatosBase.filter { mec in
            let finEstimado = mec.calcularFechaFin(inicio: fechaInicio, duracionHoras: servicio.duracionHoras)
            return !ServicioEnProceso.existeSolape(paraRFC: mec.rfc, inicio: fechaInicio, fin: finEstimado, tickets: tickets)
        }
        
        // 3) Balance justo: carga + última asignación + nombre
        let ordenados = ordenarCandidatosJusto(candidatos: candidatosSinSolape, inicio: fechaInicio, duracionHoras: servicio.duracionHoras)
        candidato = ordenados.first
        
        if candidato == nil && !candidatosBase.isEmpty {
            conflictoMensaje = "Todos los candidatos tienen solapes en ese horario."
        } else if candidatosBase.isEmpty {
            conflictoMensaje = "No hay candidatos con el rol/especialidad y turno adecuado."
        }
        
        // 4) Advertencia de stock (no reservamos)
        var faltantes: [String] = []
        for ing in servicio.ingredientes {
            if let p = productos.first(where: { $0.nombre == ing.nombreProducto }), p.cantidad < ing.cantidadUsada {
                faltantes.append(ing.nombreProducto)
            }
        }
        if !faltantes.isEmpty {
            stockAdvertencia = "Stock insuficiente hoy para: \(faltantes.joined(separator: ", ")). No se reserva; se validará al iniciar."
        }
    }
    
    private func guardarProgramacion() {
        guard let vehiculoID = vehiculoSeleccionadoID,
              let vehiculo = vehiculos.first(where: { $0.id == vehiculoID }),
              let candidato else { return }
        
        // Creamos un ticket programado
        let placeholderInicio = Date()
        let ticket = ServicioEnProceso(
            nombreServicio: servicio.nombre,
            rfcMecanicoAsignado: candidato.rfc,
            nombreMecanicoAsignado: candidato.nombre,
            horaInicio: placeholderInicio,
            duracionHoras: servicio.duracionHoras,
            productosConsumidos: servicio.ingredientes.map { $0.nombreProducto },
            vehiculo: vehiculo
        )
        ticket.estado = .programado
        ticket.fechaProgramadaInicio = fechaInicio
        ticket.duracionHoras = servicio.duracionHoras
        ticket.rfcMecanicoSugerido = candidato.rfc
        ticket.nombreMecanicoSugerido = candidato.nombre
        
        // Ajustar fin estimado real
        ticket.horaFinEstimada = candidato.calcularFechaFin(inicio: fechaInicio, duracionHoras: servicio.duracionHoras)
        
        modelContext.insert(ticket)
        
        let registro = DecisionRecord(
            fecha: Date(),
            titulo: "Programado: \(servicio.nombre)",
            razon: "Sugerido (balanceado) para \(candidato.nombre) el \(fechaInicio.formatted(date: .abbreviated, time: .shortened)) para vehículo [\(vehiculo.placas)].",
            queryUsuario: "Programación Automática de Servicio (balance justo)"
        )
        modelContext.insert(registro)
        
        dismiss()
        appState.seleccion = .serviciosEnProceso
    }
    
    // MARK: - Helpers de balance justo (Programar)
    private func calcularCargaHoras(rfc: String, en inicio: Date, fin: Date) -> Double {
        var suma: Double = 0
        for t in tickets {
            guard (t.estado == .programado || t.estado == .enProceso) else { continue }
            guard t.rfcMecanicoAsignado == rfc || t.rfcMecanicoSugerido == rfc else { continue }
            let ti = t.fechaProgramadaInicio ?? t.horaInicio
            let tf: Date = (t.estado == .programado) ? (ti.addingTimeInterval(t.duracionHoras * 3600)) : t.horaFinEstimada
            if inicio < tf && fin > ti {
                let interIni = max(inicio, ti)
                let interFin = min(fin, tf)
                let horas = interFin.timeIntervalSince(interIni) / 3600.0
                suma += max(0, horas)
            }
        }
        return suma
    }
    
    private func ultimaAsignacion(rfc: String) -> Date {
        var ultimo: Date = .distantPast
        for t in tickets {
            guard t.rfcMecanicoAsignado == rfc || t.rfcMecanicoSugerido == rfc else { continue }
            let fecha = (t.estado == .programado) ? (t.fechaProgramadaInicio ?? t.horaInicio) : t.horaInicio
            if fecha > ultimo { ultimo = fecha }
        }
        return ultimo
    }
    
    private func ordenarCandidatosJusto(candidatos: [Personal], inicio: Date, duracionHoras: Double) -> [Personal] {
        return candidatos.sorted { a, b in
            let finA = a.calcularFechaFin(inicio: inicio, duracionHoras: duracionHoras)
            let finB = b.calcularFechaFin(inicio: inicio, duracionHoras: duracionHoras)
            
            let cargaA = calcularCargaHoras(rfc: a.rfc, en: inicio, fin: finA)
            let cargaB = calcularCargaHoras(rfc: b.rfc, en: inicio, fin: finB)
            
            if abs(cargaA - cargaB) > 0.0001 {
                return cargaA < cargaB
            }
            let lastA = ultimaAsignacion(rfc: a.rfc)
            let lastB = ultimaAsignacion(rfc: b.rfc)
            if lastA != lastB {
                return lastA < lastB
            }
            return a.nombre < b.nombre
        }
    }
}

// --- HELPERS DE PRECIO Y PORCENTAJES ---
// --- HELPERS DE PRECIO Y DESGLOSE (Nueva Lógica) ---


// --- VISTA DEL FORMULARIO (Actualizada a porcentajes e impuestos) ---
// --- VISTA DEL FORMULARIO (Actualizada a Montos Fijos) ---
fileprivate struct ServicioFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true
    
    @Query private var productos: [Producto]
    @Query private var personal: [Personal]
    @Query private var servicios: [Servicio] // Para validar duplicados

    let mode: ServiceModalMode
    @Binding var modalMode: ServiceModalMode? // Para cambiar a modo edición si hay duplicado
    
    // Datos base
    @State private var nombre = ""
    @State private var descripcion = ""
    @State private var especialidadRequerida = ""
    @State private var rolRequerido: Rol? = nil
    @State private var duracionString = ""
    
    // Ingredientes
    @State private var cantidadesProductos: [String: Double] = [:]
    @State private var especialidadesDisponibles: [String] = []

    // Costos y configuración (Montos Fijos)
    @State private var costoManoDeObraString = ""
    @State private var gananciaDeseadaString = ""
    @State private var gastosAdminString = ""
    
    @State private var requiereRefacciones = false
    @State private var costoRefaccionesString = ""
    
    @State private var aplicarIVA = false
    @State private var aplicarISR = false
    @State private var porcentajeISRString = "" // configurable

    // Precio final editable
    @State private var precioFinalString = ""
    @State private var precioModificadoManualmente = false
    
    // Seguridad para editar nombre en modo edición
    @State private var isNombreUnlocked = false
    @State private var showingAuthModal = false
    @State private var authError = ""
    @State private var passwordAttempt = ""
    @State private var errorMsg: String?
    @State private var searchTextProductos: String = ""
    
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
        case .schedule: return "Editar Servicio"
        }
    }
    

    

    
    private var productosFiltrados: [Producto] {
        if searchTextProductos.isEmpty {
            return productos
        }
        return productos.filter { p in
            p.nombre.localizedCaseInsensitiveContains(searchTextProductos) ||
            p.categoria.localizedCaseInsensitiveContains(searchTextProductos) ||
            p.proveedor.localizedCaseInsensitiveContains(searchTextProductos) ||
            p.lote.localizedCaseInsensitiveContains(searchTextProductos)
        }
    }
    
    // Validaciones
    private var productoExistenteConMismoNombre: Servicio? {
        let trimmed = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return nil }
        return servicios.first { s in
            s.nombre.localizedCaseInsensitiveCompare(trimmed) == .orderedSame &&
            s.id != servicioAEditar?.id
        }
    }
    
    private var nombreDuplicado: Bool { productoExistenteConMismoNombre != nil }
    
    private var nombreInvalido: Bool { 
        nombre.trimmingCharacters(in: .whitespaces).count < 3 || nombreDuplicado
    }
    private var duracionInvalida: Bool { 
        guard let d = Double(duracionString) else { return true }
        return d <= 0
    }
    private var costoMOInvalido: Bool { Double(costoManoDeObraString) == nil || (Double(costoManoDeObraString) ?? -1) < 0 }
    private var gananciaInvalida: Bool { Double(gananciaDeseadaString) == nil || (Double(gananciaDeseadaString) ?? -1) < 0 }
    private var gastosAdminInvalido: Bool { Double(gastosAdminString) == nil || (Double(gastosAdminString) ?? -1) < 0 }
    private var costoRefInvalido: Bool { Double(costoRefaccionesString) == nil || (Double(costoRefaccionesString) ?? -1) < 0 }
    private var pISRInvalido: Bool { porcentajeInvalido(porcentajeISRString) }
    
    private func porcentajeInvalido(_ s: String) -> Bool {
        guard let v = Double(s.replacingOccurrences(of: ",", with: ".")) else { return true }
        return v < 0 || v > 100
    }
    
    // Cálculos automáticos (Desglose)
    private var costoIngredientes: Double {
        PricingHelpers.costoIngredientes(servicio: servicioPreview, productos: productos)
    }
    
    private var desglose: PricingHelpers.DesglosePrecio {
        PricingHelpers.calcularDesglose(
            manoDeObra: Double(costoManoDeObraString) ?? 0,
            refacciones: requiereRefacciones ? (Double(costoRefaccionesString) ?? 0) : 0,
            costoInventario: costoIngredientes,
            gananciaDeseada: Double(gananciaDeseadaString) ?? 0,
            gastosAdmin: Double(gastosAdminString) ?? 0,
            aplicarIVA: aplicarIVA,
            aplicarISR: aplicarISR,
            porcentajeISR: Double(porcentajeISRString) ?? 0
        )
    }
    
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
            rolRequerido: rolRequerido ?? .ayudante,
            ingredientes: ingredientesArray,
            precioAlCliente: Double(precioFinalString) ?? 0,
            duracionHoras: Double(duracionString) ?? 1.0,
            
            costoBase: 0, // Deprecado
            requiereRefacciones: requiereRefacciones,
            costoRefacciones: Double(costoRefaccionesString) ?? 0,
            
            // Nuevos campos
            costoManoDeObra: Double(costoManoDeObraString) ?? 0,
            gananciaDeseada: Double(gananciaDeseadaString) ?? 0,
            gastosAdministrativos: Double(gastosAdminString) ?? 0,
            
            aplicarIVA: aplicarIVA,
            aplicarISR: aplicarISR,
            isrPorcentajeEstimado: Double(porcentajeISRString) ?? 0,
            precioFinalAlCliente: Double(precioFinalString) ?? 0,
            precioModificadoManualmente: precioModificadoManualmente
        )
        return dummy
    }
    
    init(mode: ServiceModalMode, modalMode: Binding<ServiceModalMode?>) {
        self.mode = mode
        self._modalMode = modalMode
        
        if case .edit(let servicio) = mode {
            self.servicioAEditar = servicio
            _nombre = State(initialValue: servicio.nombre)
            _descripcion = State(initialValue: servicio.descripcion)
            _especialidadRequerida = State(initialValue: servicio.especialidadRequerida)
            _rolRequerido = State(initialValue: servicio.rolRequerido)
            _duracionString = State(initialValue: String(format: "%.2f", servicio.duracionHoras))
            let cantidades = Dictionary(uniqueKeysWithValues: servicio.ingredientes.map { ($0.nombreProducto, $0.cantidadUsada) })
            _cantidadesProductos = State(initialValue: cantidades)
            
            // Nuevos campos (Montos)
            _costoManoDeObraString = State(initialValue: String(format: "%.2f", servicio.costoManoDeObra))
            _gananciaDeseadaString = State(initialValue: String(format: "%.2f", servicio.gananciaDeseada))
            _gastosAdminString = State(initialValue: String(format: "%.2f", servicio.gastosAdministrativos))
            
            _requiereRefacciones = State(initialValue: servicio.requiereRefacciones)
            _costoRefaccionesString = State(initialValue: String(format: "%.2f", servicio.costoRefacciones))
            
            _aplicarIVA = State(initialValue: servicio.aplicarIVA)
            _aplicarISR = State(initialValue: servicio.aplicarISR)
            _porcentajeISRString = State(initialValue: String(format: "%.2f", servicio.isrPorcentajeEstimado))
            _precioFinalString = State(initialValue: String(format: "%.2f", servicio.precioFinalAlCliente))
            _precioModificadoManualmente = State(initialValue: servicio.precioModificadoManualmente)
        } else {
            // defaults para alta
            _costoManoDeObraString = State(initialValue: "")
            _gananciaDeseadaString = State(initialValue: "")
            _gastosAdminString = State(initialValue: "")
            _porcentajeISRString = State(initialValue: "")
            _precioFinalString = State(initialValue: "")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Título y guía
            VStack(spacing: 4) {
                Text(formTitle).font(.title).fontWeight(.bold)
                Text("Completa los datos. Los campos marcados con • son obligatorios.")
                    .font(.footnote).foregroundColor(.gray)
            }
            .padding(16)

            ScrollView {
                VStack(spacing: 24) {
                    
                    // Sección 1: Datos del Servicio
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "1. Datos del Servicio", subtitle: "Información básica")
                        
                        // Nombre con candado en edición y validación de duplicados
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("• Nombre del Servicio").font(.caption2).foregroundColor(.gray)
                                if servicioAEditar != nil {
                                    Image(systemName: isNombreUnlocked ? "lock.open.fill" : "lock.fill")
                                        .foregroundColor(isNombreUnlocked ? .green : .red)
                                        .font(.caption2)
                                }
                            }
                            
                            HStack(spacing: 6) {
                                TextField("", text: $nombre)
                                    .disabled(servicioAEditar != nil && !isNombreUnlocked)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Color("MercedesBackground"))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .onChange(of: nombre) { _, newValue in
                                        if newValue.count > 21 {
                                            nombre = String(newValue.prefix(21))
                                        }
                                    }
                                    .help("Identificador único del producto (Máx 21 caracteres)")
                                
                                // Contador manual para Nombre
                                Text("\(nombre.count)/21")
                                    .font(.caption2)
                                    .foregroundColor(nombre.count >= 21 ? .red : .gray)
                                    .frame(width: 40, alignment: .trailing)
                                
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
                                    .help(isNombreUnlocked ? "Bloquear edición del nombre" : "Requiere autorización")
                                }
                            }
                            .validationHint(isInvalid: nombreInvalido, message: nombreDuplicado ? "Este nombre ya está en uso." : "El nombre debe tener al menos 3 caracteres.")
                            
                            // Botón para editar el existente si hay duplicado
                            if let existente = productoExistenteConMismoNombre {
                                Button {
                                    // Cambiar a modo edición del producto existente
                                    modalMode = .edit(existente)
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
                        }
                        
                        FormField(title: "Descripción", placeholder: "ej. Reemplazo de balatas y rectificación de discos", text: $descripcion, characterLimit: 231, isMultiline: true)
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                FormField(title: "• Duración Estimada (Horas)", placeholder: "ej. 2.5", text: $duracionString, isNumeric: true)
                                    .validationHint(isInvalid: duracionInvalida, message: "Debe ser > 0.")
                                
                                if let d = Double(duracionString), d > 8 {
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("Nota: El trabajo se dividirá entre los días laborales del trabajador. Si no trabaja, el servicio estará en pausa hasta que esté disponible.")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(8)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• Especialidad Requerida").font(.caption2).foregroundColor(.gray)
                                Picker("", selection: $especialidadRequerida) {
                                    Text("Seleccionar...").tag("")
                                    ForEach(especialidadesDisponibles, id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity)
                                .padding(6)
                                .background(Color("MercedesBackground"))
                                .cornerRadius(8)
                                .validationHint(isInvalid: especialidadRequerida.isEmpty, message: "Requerido")
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• Rol Requerido").font(.caption2).foregroundColor(.gray)
                                Picker("", selection: $rolRequerido) {
                                    Text("Seleccionar...").tag(nil as Rol?)
                                    ForEach(Rol.allCases, id: \.self) { rol in
                                        Text(rol.rawValue).tag(rol as Rol?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity)
                                .padding(6)
                                .background(Color("MercedesBackground"))
                                .cornerRadius(8)
                                .validationHint(isInvalid: rolRequerido == nil, message: "Requerido")
                            }
                        }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Sección 2: Costos Directos
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "2. Costos Directos", subtitle: "Mano de obra, refacciones e inventario")
                        HStack(spacing: 16) {
                            FormField(title: "• Costo Mano de Obra ($)", placeholder: "ej. 500.00", text: $costoManoDeObraString, isNumeric: true)
                                .validationHint(isInvalid: costoMOInvalido, message: "Número válido ≥ 0")
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle("¿Refacciones?", isOn: $requiereRefacciones)
                                    .toggleStyle(.switch)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                
                                if requiereRefacciones {
                                    FormField(title: "Costo Refacciones ($)", placeholder: "ej. 300.00", text: $costoRefaccionesString, isNumeric: true)
                                        .validationHint(isInvalid: costoRefInvalido, message: "Número válido ≥ 0")
                                }
                            }
                        }
                        
                        // Productos del Inventario (Movido aquí)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Productos del Inventario").font(.caption2).foregroundColor(.gray)
                            
                            // Buscador
                            HStack {
                                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                                TextField("Buscar por nombre, categoría, proveedor o lote...", text: $searchTextProductos)
                                    .textFieldStyle(.plain)
                            }
                            .padding(8)
                            .background(Color("MercedesBackground"))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(productosFiltrados) { producto in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(producto.nombre)
                                                    .font(.subheadline)
                                                    .foregroundColor(.white)
                                                Text("\(producto.categoria) • \(producto.proveedor) • Lote: \(producto.lote)")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                            Spacer()
                                            HStack(spacing: 6) {
                                                Text(producto.unidadDeMedida)
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                                
                                                TextField("0.0", text: Binding(
                                                    get: {
                                                        if let val = cantidadesProductos[producto.nombre], val > 0 {
                                                            return String(format: "%.2f", val)
                                                        }
                                                        return ""
                                                    },
                                                    set: {
                                                        let val = Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0
                                                        cantidadesProductos[producto.nombre] = val
                                                    }
                                                ))
                                                .multilineTextAlignment(.trailing)
                                                .frame(width: 80)
                                                .textFieldStyle(.plain)
                                                .padding(6)
                                                .background(Color("MercedesBackground"))
                                                .cornerRadius(6)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                                )
                                                
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
                                        .padding(8)
                                        .background(Color("MercedesBackground").opacity(0.3))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .frame(maxHeight: 250)
                            .background(Color("MercedesBackground").opacity(0.2))
                            .cornerRadius(8)
                        }

                        HStack {
                            roField("Costo de inventario (automático)", costoIngredientes)
                            Spacer()
                        }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Sección 3: Partes Internas
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "3. Partes Internas", subtitle: "Ganancia y gastos operativos")
                        HStack(spacing: 16) {
                            FormField(title: "• Ganancia Deseada ($)", placeholder: "ej. 400.00", text: $gananciaDeseadaString, isNumeric: true)
                                .validationHint(isInvalid: gananciaInvalida, message: "Número válido ≥ 0")
                            
                            FormField(title: "• Gastos Administrativos ($)", placeholder: "ej. 150.00", text: $gastosAdminString, isNumeric: true)
                                .validationHint(isInvalid: gastosAdminInvalido, message: "Número válido ≥ 0")
                        }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Sección 4: Impuestos
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "4. Impuestos", subtitle: "IVA e ISR")
                        HStack(spacing: 24) {
                            Toggle("Aplicar IVA (16%)", isOn: $aplicarIVA)
                                .toggleStyle(.switch)
                            
                            HStack(spacing: 8) {
                                Toggle("Aplicar ISR", isOn: $aplicarISR)
                                    .toggleStyle(.switch)
                                if aplicarISR {
                                    FormField(title: "% ISR", placeholder: "ej. 10", text: $porcentajeISRString, isNumeric: true)
                                        .frame(width: 80)
                                        .validationHint(isInvalid: pISRInvalido, message: "0-100")
                                }
                            }
                        }
                        Text("El ISR se calcula solo sobre la ganancia deseada y NO se suma al precio final (es gasto interno).")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    

                    
                    // Sección 6: Desglose Final
                    VStack(alignment: .leading, spacing: 16) {
                        // Contenedor con borde que incluye el Header y el Grid
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Desglose de Precio", subtitle: "Cálculo automático", color: "MercedesPetrolGreen")
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 8) {
                                roField("Costos Directos", desglose.costosDirectos)
                                roField("Ganancia Real", desglose.partesInternas - (Double(gastosAdminString) ?? 0))
                                roField("Gastos Administrativos", Double(gastosAdminString) ?? 0)
                                roField("Subtotal (Sin IVA)", desglose.subtotal)
                                roField("IVA (16%)", desglose.iva)
                                roField("Precio Final", desglose.precioFinal)
                                roField("ISR (Gasto Interno)", desglose.isrSobreGanancia)
                                roField("Ganancia Neta (Post ISR)", desglose.gananciaNeta)
                            }
                        }
                        .padding(16)
                        .background(Color("MercedesBackground").opacity(0.2))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color("MercedesPetrolGreen").opacity(0.5), lineWidth: 1)
                        )
                        
                        // Precio final editable
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Precio Final al Cliente", subtitle: "Ajustable")
                            HStack(spacing: 16) {
                                FormField(title: "Precio final al cliente", placeholder: "ej. 2500.00", text: $precioFinalString, isNumeric: true)
                                    .onChange(of: precioFinalString) { _, new in
                                        let final = Double(new.replacingOccurrences(of: ",", with: ".")) ?? 0
                                        precioModificadoManualmente = abs(final - desglose.precioFinal) > 0.009
                                    }
                                if precioModificadoManualmente {
                                    HStack {
                                        Text("Modificado manualmente")
                                            .font(.caption2)
                                            .padding(.horizontal, 8).padding(.vertical, 4)
                                            .background(Color.yellow.opacity(0.2))
                                            .foregroundColor(.yellow)
                                            .cornerRadius(6)
                                        
                                        Button {
                                            precioModificadoManualmente = false
                                            precioFinalString = String(format: "%.2f", desglose.precioFinal)
                                        } label: {
                                            Image(systemName: "arrow.counterclockwise")
                                            Text("Recalcular")
                                        }
                                        .font(.caption2)
                                        .buttonStyle(.bordered)
                                        .tint(.blue)
                                    }
                                }
                            }
                            Text("El precio calculado se mantiene como referencia si editas el precio final.")
                                .font(.caption2).foregroundColor(.gray)
                        }
                    }
                    
                    // Zona de Peligro
                    if case .edit = mode {
                        Divider().background(Color.red.opacity(0.3))
                        VStack(spacing: 12) {
                            Text("Esta acción no se puede deshacer y eliminará permanentemente el servicio.")
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                            
                            Button(role: .destructive) {
                                authReason = .deleteServicio
                                showingAuthModal = true
                            } label: {
                                Label("Eliminar servicio permanentemente", systemImage: "trash.fill")
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
                let todasLasHabilidades = personal.flatMap { $0.especialidades }
                especialidadesDisponibles = Array(Set(todasLasHabilidades)).sorted()
                
                if servicioAEditar == nil {
                    // Ya no forzamos valores por defecto aquí
                    precioFinalString = String(format: "%.2f", desglose.precioFinal)
                }
            }
            .onChange(of: costoManoDeObraString) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: gananciaDeseadaString) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: gastosAdminString) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: requiereRefacciones) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: costoRefaccionesString) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: aplicarIVA) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: aplicarISR) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: porcentajeISRString) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            .onChange(of: cantidadesProductos) { _, _ in syncPrecioFinalConSugeridoSiNoManual() }
            
            // Mensaje de Error
            if let errorMsg {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.vertical, 6)
            }
            
            // Barra de Botones
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
                
                Spacer()
                
                Button {
                    guardarCambios()
                } label: {
                    Text(servicioAEditar == nil ? "Guardar y añadir" : "Guardar cambios")
                        .fontWeight(.semibold)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .shadow(color: Color("MercedesPetrolGreen").opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(nombreInvalido || duracionInvalida || costoMOInvalido || gananciaInvalida || gastosAdminInvalido || costoRefInvalido || pISRInvalido || especialidadRequerida.isEmpty)
                .opacity((nombreInvalido || duracionInvalida || costoMOInvalido || gananciaInvalida || gastosAdminInvalido || costoRefInvalido || pISRInvalido || especialidadRequerida.isEmpty) ? 0.6 : 1.0)
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
    
    private func syncPrecioFinalConSugeridoSiNoManual() {
        if !precioModificadoManualmente {
            precioFinalString = String(format: "%.2f", desglose.precioFinal)
        }
    }
    
    @ViewBuilder
    func authModalView() -> some View {
        let prompt = (authReason == .unlockNombre) ?
            "Autoriza para editar el Nombre del Servicio." :
            "Autoriza para ELIMINAR este servicio."
        
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Autorización Requerida").font(.title2).fontWeight(.bold)
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
                    .padding(8).background(Color("MercedesCard")).cornerRadius(8)
                
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
            .padding(22)
        }
        .frame(minWidth: 520, minHeight: 360)
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
        guard let costoMO = Double(costoManoDeObraString.replacingOccurrences(of: ",", with: ".")), costoMO >= 0 else {
            errorMsg = "Costo Mano de Obra inválido."
            return
        }
        guard let ganancia = Double(gananciaDeseadaString.replacingOccurrences(of: ",", with: ".")), ganancia >= 0 else {
            errorMsg = "Ganancia deseada inválida."
            return
        }
        guard let gastosAdmin = Double(gastosAdminString.replacingOccurrences(of: ",", with: ".")), gastosAdmin >= 0 else {
            errorMsg = "Gastos administrativos inválidos."
            return
        }
        guard let costoRef = Double(costoRefaccionesString.replacingOccurrences(of: ",", with: ".")), (!requiereRefacciones || costoRef >= 0) else {
            errorMsg = "Costo de refacciones inválido."
            return
        }
        guard let pISR = Double(porcentajeISRString.replacingOccurrences(of: ",", with: ".")), (0...100).contains(pISR) else {
            errorMsg = "% ISR inválido."
            return
        }
        // NEW: ensure rolRequerido is selected for both edit/add
        guard let rol = rolRequerido else {
            errorMsg = "Selecciona un rol requerido."
            return
        }
        
        let ingredientesArray: [Ingrediente] = cantidadesProductos.compactMap { (nombre, cantidad) in
            guard cantidad > 0 else { return nil }
            return Ingrediente(nombreProducto: nombre, cantidadUsada: cantidad)
        }
        
        let final = Double(precioFinalString.replacingOccurrences(of: ",", with: ".")) ?? desglose.precioFinal
        
        if let servicio = servicioAEditar {
            // Actualiza todos los campos
            servicio.nombre = trimmedNombre
            servicio.descripcion = descripcion
            servicio.especialidadRequerida = especialidadRequerida
            servicio.rolRequerido = rol
            servicio.duracionHoras = duracion
            servicio.ingredientes = ingredientesArray
            
            // Nuevos campos
            servicio.costoManoDeObra = costoMO
            servicio.gananciaDeseada = ganancia
            servicio.gastosAdministrativos = gastosAdmin
            
            servicio.requiereRefacciones = requiereRefacciones
            servicio.costoRefacciones = costoRef
            
            servicio.aplicarIVA = aplicarIVA
            servicio.aplicarISR = aplicarISR
            servicio.isrPorcentajeEstimado = pISR
            
            servicio.precioFinalAlCliente = final
           if nombreInvalido || duracionInvalida || costoMOInvalido || gananciaInvalida || gastosAdminInvalido || costoRefInvalido || pISRInvalido || especialidadRequerida.isEmpty || rolRequerido == nil {
            errorMsg = "Por favor corrige los campos marcados en rojo."
            return
        }
            servicio.precioModificadoManualmente = precioModificadoManualmente
            
            // Compatibilidad
            servicio.precioAlCliente = final
        } else {
            let nuevoServicio = Servicio(
                nombre: trimmedNombre,
                descripcion: descripcion,
                especialidadRequerida: especialidadRequerida,
                rolRequerido: rol,
                ingredientes: ingredientesArray,
                precioAlCliente: final, // compat
                duracionHoras: duracion,
                
                costoBase: 0.0,
                requiereRefacciones: requiereRefacciones,
                costoRefacciones: costoRef,
                
                costoManoDeObra: costoMO,
                gananciaDeseada: ganancia,
                gastosAdministrativos: gastosAdmin,
                
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
    var color: String? = nil
    var body: some View {
        HStack {
            Text(title).font(.headline).foregroundColor(color != nil ? Color(color!) : .white)
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
    var isMultiline: Bool = false
    var isNumeric: Bool = false
    var suggestions: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                if let limit = characterLimit {
                    Text("\(text.count)/\(limit)")
                        .font(.caption2)
                        .foregroundColor(text.count >= limit ? .red : .gray)
                }
            }
            TextField("", text: $text, axis: isMultiline ? .vertical : .horizontal)
                .textFieldStyle(.plain)
                .lineLimit(isMultiline ? 3...6 : 1...1)
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color("MercedesBackground"))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .overlay(
                    HStack {
                        Spacer()
                        if !suggestions.isEmpty {
                            Menu {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button(suggestion) {
                                        text = suggestion
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.down.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                )
                .onChange(of: text) { _, newValue in
                    if let limit = characterLimit, newValue.count > limit {
                        text = String(newValue.prefix(limit))
                    }
                    if isNumeric {
                        let filtered = newValue.filter { "0123456789.".contains($0) }
                        if filtered != newValue {
                            text = filtered
                        }
                        // Evitar múltiples puntos
                        if text.filter({ $0 == "." }).count > 1 {
                             text = String(text.dropLast())
                        }
                    }
                }
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

