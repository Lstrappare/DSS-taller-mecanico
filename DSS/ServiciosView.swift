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
    // Forzamos el tipo de la key path en el sort para evitar "Cannot infer key path type..."
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
            header
            filtrosView
            ScrollView {
                LazyVStack(spacing: 12) {
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
                ServicioFormView(mode: .add)
                    .environment(\.modelContext, modelContext)
            case .edit(let servicio):
                ServicioFormView(mode: .edit(servicio))
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
    var onSchedule: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query private var personal: [Personal]
    @Query private var productos: [Producto]
    
    private var previewAsignable: (asignable: Bool, motivo: String) {
        let candidatos = personal.filter { mec in
            mec.isAsignable &&
            mec.especialidades.contains(servicio.especialidadRequerida) &&
            mec.rol == servicio.rolRequerido
        }
        guard candidatos.first != nil else {
            return (false, "Sin candidato disponible")
        }
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
                    Button { onEdit() } label: {
                        Label("Editar", systemImage: "pencil")
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(Color("MercedesBackground"))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    
                    Button { onSchedule() } label: {
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
            
            HStack(spacing: 6) {
                chip(text: servicio.rolRequerido.rawValue, systemImage: "person.badge.shield.checkmark.fill")
                chip(text: servicio.especialidadRequerida, systemImage: "wrench.and.screwdriver.fill")
                chip(text: String(format: "%.1f h", servicio.duracionHoras), systemImage: "clock")
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("\(productosCount) producto\(productosCount == 1 ? "" : "s")", systemImage: "shippingbox.fill")
                    Spacer()
                    Label("Costo insumos: $\(costoEstimado, specifier: "%.2f")", systemImage: "creditcard")
                }
                .font(.caption2)
                .foregroundColor(.gray)
                
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
            
            HStack {
                let estado = previewAsignable
                Label(estado.motivo, systemImage: estado.asignable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background((estado.asignable ? Color.green : Color.red).opacity(0.15))
                    .foregroundColor(estado.asignable ? .green : .red)
                    .cornerRadius(6)
                Spacer()
                Button { onAssign() } label: {
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

// --- MODAL DE ASIGNACIÓN ---
fileprivate struct AsignarServicioModal: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var personal: [Personal]
    @Query private var productos: [Producto]
    @Query private var vehiculos: [Vehiculo]
    
    var servicio: Servicio
    @ObservedObject var appState: AppNavigationState
    
    @State private var vehiculoSeleccionadoID: Vehiculo.ID?
    @State private var searchVehiculo = ""
    @State private var alertaError: String?
    @State private var mostrandoAlerta = false
    
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
                .font(.title2).fontWeight(.bold)
            
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
            
            HStack(alignment: .top, spacing: 16) {
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
    
    private func recalcularPreview() {
        let candidatos = personal.filter { mec in
            mec.isAsignable &&
            mec.especialidades.contains(servicio.especialidadRequerida) &&
            mec.rol == servicio.rolRequerido
        }
        candidato = candidatos.sorted(by: { $0.rol.rawValue < $1.rol.rawValue }).first
        
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
        // NUEVO: guarda cantidades exactas
        nuevoServicio.productosConCantidad = servicio.ingredientes
        nuevoServicio.estado = .enProceso
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
    
    @State private var vehiculoSeleccionadoID: Vehiculo.ID?
    @State private var searchVehiculo = ""
    @State private var fechaInicio: Date = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    
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
                    DatePicker("Inicio", selection: $fechaInicio, displayedComponents: [.date, .hourAndMinute])
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
                .disabled(vehiculoSeleccionadoID == nil || candidato == nil)
                .opacity((vehiculoSeleccionadoID == nil || candidato == nil) ? 0.6 : 1.0)
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
    
    private func recalcularCandidato() {
        conflictoMensaje = nil
        stockAdvertencia = nil
        
        let cal = Calendar.current
        let endDate = fechaInicio.addingTimeInterval(servicio.duracionHoras * 3600)
        let weekday = cal.component(.weekday, from: fechaInicio)
        let startHour = cal.component(.hour, from: fechaInicio)
        let endHour = cal.component(.hour, from: endDate)
        
        let candidatosBase = personal.filter { mec in
            mec.rol == servicio.rolRequerido &&
            mec.especialidades.contains(servicio.especialidadRequerida) &&
            mec.diasLaborales.contains(weekday) &&
            (mec.horaEntrada <= startHour) && (mec.horaSalida >= endHour)
        }
        
        let candidatosSinSolape = candidatosBase.filter {
            !ServicioEnProceso.existeSolape(paraRFC: $0.rfc, inicio: fechaInicio, fin: endDate, tickets: tickets)
        }
        
        candidato = candidatosSinSolape.sorted { $0.nombre < $1.nombre }.first
        
        if candidato == nil && !candidatosBase.isEmpty {
            conflictoMensaje = "Todos los candidatos tienen solapes en ese horario."
        } else if candidatosBase.isEmpty {
            conflictoMensaje = "No hay candidatos con el rol/especialidad y turno adecuado."
        }
        
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
        
        let ticket = ServicioEnProceso(
            nombreServicio: servicio.nombre,
            rfcMecanicoAsignado: candidato.rfc,
            nombreMecanicoAsignado: candidato.nombre,
            horaInicio: fechaInicio,
            duracionHoras: servicio.duracionHoras,
            productosConsumidos: servicio.ingredientes.map { $0.nombreProducto },
            vehiculo: vehiculo
        )
        ticket.estado = .programado
        ticket.fechaProgramadaInicio = fechaInicio
        ticket.duracionHoras = servicio.duracionHoras
        ticket.rfcMecanicoSugerido = candidato.rfc
        ticket.nombreMecanicoSugerido = candidato.nombre
        // NUEVO: guarda cantidades exactas para validar al iniciar
        ticket.productosConCantidad = servicio.ingredientes
        
        modelContext.insert(ticket)
        
        let registro = DecisionRecord(
            fecha: Date(),
            titulo: "Programado: \(servicio.nombre)",
            razon: "Sugerido para \(candidato.nombre) el \(fechaInicio.formatted(date: .abbreviated, time: .shortened)) para vehículo [\(vehiculo.placas)].",
            queryUsuario: "Programación Automática de Servicio"
        )
        modelContext.insert(registro)
        
        dismiss()
        appState.seleccion = .serviciosEnProceso
    }
}

// --- HELPERS DE PRECIO Y DESGLOSE ---
fileprivate enum PricingHelpers {
    struct DesglosePrecio {
        let costosDirectos: Double
        let partesInternas: Double
        let subtotal: Double
        let iva: Double
        let precioFinal: Double
        let isrSobreGanancia: Double
        let gananciaNeta: Double
    }
    
    static func calcularDesglose(
        manoDeObra: Double,
        refacciones: Double,
        costoInventario: Double,
        gananciaDeseada: Double,
        gastosAdmin: Double,
        aplicarIVA: Bool,
        aplicarISR: Bool,
        porcentajeISR: Double
    ) -> DesglosePrecio {
        let costosDirectos = manoDeObra + refacciones + costoInventario
        let partesInternas = gananciaDeseada + gastosAdmin
        let subtotal = costosDirectos + partesInternas
        let iva = aplicarIVA ? (subtotal * 0.16) : 0.0
        let precioFinal = subtotal + iva
        let isr = aplicarISR ? (gananciaDeseada * (porcentajeISR / 100.0)) : 0.0
        let gananciaNeta = gananciaDeseada - isr
        
        return DesglosePrecio(
            costosDirectos: costosDirectos,
            partesInternas: partesInternas,
            subtotal: subtotal,
            iva: iva,
            precioFinal: precioFinal,
            isrSobreGanancia: isr,
            gananciaNeta: gananciaNeta
        )
    }
    
    static func costoIngredientes(servicio: Servicio, productos: [Producto]) -> Double {
        servicio.ingredientes.reduce(0) { acc, ing in
            if let p = productos.first(where: { $0.nombre == ing.nombreProducto }) {
                return acc + (p.precioVenta * ing.cantidadUsada)
            }
            return acc
        }
    }
    
    static func precioSugeridoParaServicio(servicio: Servicio, productos: [Producto]) -> Double {
        let costoInsumos = costoIngredientes(servicio: servicio, productos: productos)
        let desglose = calcularDesglose(
            manoDeObra: servicio.costoManoDeObra,
            refacciones: servicio.requiereRefacciones ? servicio.costoRefacciones : 0,
            costoInventario: costoInsumos,
            gananciaDeseada: servicio.gananciaDeseada,
            gastosAdmin: servicio.gastosAdministrativos,
            aplicarIVA: servicio.aplicarIVA,
            aplicarISR: servicio.aplicarISR,
            porcentajeISR: servicio.isrPorcentajeEstimado
        )
        return desglose.precioFinal
    }
}

// --- PLACEHOLDER TEMPORAL PARA SERVICIOFORMVIEW ---
// Sustituye esto por tu implementación real del formulario.
fileprivate struct ServicioFormView: View {
    enum Mode {
        case add
        case edit(Servicio)
    }
    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title2).bold()
            Text("Este es un placeholder temporal. Reemplázalo por tu ServicioFormView real.")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button("Cerrar") { dismiss() }
                .buttonStyle(.plain)
                .padding()
                .background(Color("MercedesPetrolGreen"))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 240)
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
    }
    
    private var title: String {
        switch mode {
        case .add: return "Añadir Servicio"
        case .edit(let s): return "Editar Servicio: \(s.nombre)"
        }
    }
}

// --- FORMULARIO DE SERVICIO (comentado en tu versión original) ---
// Copié arriba un placeholder para compilar. Sustitúyelo por tu ServicioFormView real cuando lo tengas.

