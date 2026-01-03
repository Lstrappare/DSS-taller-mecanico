import SwiftUI
import SwiftData
import LocalAuthentication

// --- MODO DEL MODAL ---
enum ProductModalMode: Identifiable {
    case add
    case edit(Producto)
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let producto): return producto.nombre
        }
    }
}

// --- Helpers de precio para productos (flujo confirmado) ---
fileprivate enum ProductPricingHelpers {
    // Diferencia final vs sugerido
    static func variacionPrecio(final: Double, sugerido: Double) -> Double {
        final - sugerido
    }
    // NUEVO: Flujo según reglas confirmadas por el usuario
    // 1) Partimos del costo
    // 2) Ganancia y gastos admin calculados sobre el costo
    // 3) IVA del 16% sobre el subtotal (costo + ganancia + admin)
    // 4) ISR SOLO sobre la ganancia (margen), NO sobre los gastos administrativos
    struct ReglaCalculoResultado {
        let ganancia: Double
        let gastosAdmin: Double
        let subtotalAntesIVA: Double
        let iva: Double
        let precioSugeridoConIVA: Double
        let utilidadTotal: Double
        let isr: Double
        let precioNetoDespuesISR: Double
        // NUEVO: Reparto directo después del ISR (sin proporciones)
        let utilidadRealDespuesISR: Double
        let proporcionGanancia: Double
        let proporcionAdmin: Double
        let gananciaRealDespuesISR: Double
        let gastosAdminRealesDespuesISR: Double
        // NUEVO: IVA Acreditable y IVA a Pagar
        let ivaAcreditable: Double
        let ivaPorPagar: Double
    }
    
    static func calcularPrecioVentaSegunReglas(costo: Double,
                                               porcentajeGanancia: Double,
                                               porcentajeGastosAdmin: Double,
                                               isrPorcentaje: Double,
                                               ivaTasaFija: Double = 0.16) -> ReglaCalculoResultado {
        let ganancia = costo * (porcentajeGanancia / 100.0)
        let gastosAdmin = costo * (porcentajeGastosAdmin / 100.0)
        let subtotal = costo + ganancia + gastosAdmin
        let iva = subtotal * ivaTasaFija
        let precioConIVA = subtotal + iva
        
        // Utilidad total antes de ISR
        let utilidadTotal = ganancia + gastosAdmin
        
        // ISR SOLO sobre la ganancia (margen)
        let isr = ganancia * (isrPorcentaje / 100.0)
        
        // El precio al cliente no cambia por ISR (gasto interno)
        let precioNetoDespuesISR = precioConIVA - isr
        
        // Utilidad real después de ISR: ganancia neta + gastos admin (sin tocar)
        let gananciaRealDespuesISR = max(0, ganancia - isr)
        let gastosAdminRealesDespuesISR = gastosAdmin
        let utilidadRealDespuesISR = max(0, gananciaRealDespuesISR + gastosAdminRealesDespuesISR)
        
        // Mantener proporciones solo para referencia visual (opcionales)
        let denominador = max(utilidadTotal, 0.0000001)
        let proporcionGanancia = ganancia / denominador
        let proporcionAdmin = gastosAdmin / denominador
        
        return ReglaCalculoResultado(
            ganancia: ganancia,
            gastosAdmin: gastosAdmin,
            subtotalAntesIVA: subtotal,
            iva: iva,
            precioSugeridoConIVA: precioConIVA,
            utilidadTotal: utilidadTotal,
            isr: isr,
            precioNetoDespuesISR: precioConIVA - isr,
            utilidadRealDespuesISR: utilidadRealDespuesISR,
            proporcionGanancia: proporcionGanancia,
            proporcionAdmin: proporcionAdmin,
            gananciaRealDespuesISR: gananciaRealDespuesISR,
            gastosAdminRealesDespuesISR: gastosAdminRealesDespuesISR,
            ivaAcreditable: costo * ivaTasaFija,
            ivaPorPagar: iva - (costo * ivaTasaFija)
        )
    }
}

// --- VISTA PRINCIPAL (UI simplificada y clara) ---
struct InventarioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Producto.nombre) private var productos: [Producto]
    // Queries para validación de dependencias
    @Query private var servicios: [Servicio]
    @Query private var serviciosEnProceso: [ServicioEnProceso]
    
    @State private var modalMode: ProductModalMode?
    @State private var searchQuery = ""
    @State private var filtroCategoria: String = "Todas"
    @State private var productoAEliminar: Producto?
    @State private var mostrandoConfirmacionBorrado = false
    @State private var showingDependencyAlert = false
    @State private var dependencyAlertMessage = ""
    
    // NUEVO: Filtro de activos
    @State private var incluirInactivos = false

    // NUEVO: Ganancias acumuladas (persistencia simple)
    @AppStorage("gananciaAcumulada") private var gananciaAcumulada: Double = 0.0
    
    // NUEVO: Ordenamiento
    enum SortOption: String, CaseIterable, Identifiable {
        case nombre = "Nombre"
        case precio = "Precio"
        case stock = "Stock"
        var id: String { rawValue }
    }
    @State private var sortOption: SortOption = .nombre
    @State private var sortAscending: Bool = true
    
    // Configuración de UI
    private let lowStockThreshold: Double = 2.0
    
    private var categorias: [String] {
        let set = Set(productos.map { $0.categoria }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        return ["Todas"] + set.sorted()
    }
    
    var filteredProductos: [Producto] {
        var base = productos
        if filtroCategoria != "Todas" {
            base = base.filter { $0.categoria == filtroCategoria }
        }
        // Filtro de activos/inactivos
        if incluirInactivos {
            // Modo "Ver de baja": Solo inactivos
            base = base.filter { !$0.activo }
        } else {
            // Modo normal: Solo activos
            base = base.filter { $0.activo }
        }
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchQuery.lowercased()
            base = base.filter { producto in
                producto.nombre.lowercased().contains(query) ||
                producto.unidadDeMedida.lowercased().contains(query) ||
                producto.informacion.lowercased().contains(query) ||
                producto.categoria.lowercased().contains(query) ||
                producto.proveedor.lowercased().contains(query) ||
                producto.lote.lowercased().contains(query)
            }
        }
        // Ordenamiento
        base.sort { a, b in
            switch sortOption {
            case .nombre:
                return sortAscending ? (a.nombre.localizedCaseInsensitiveCompare(b.nombre) == .orderedAscending)
                                    : (a.nombre.localizedCaseInsensitiveCompare(b.nombre) == .orderedDescending)
            case .precio:
                return sortAscending ? (a.precioVenta < b.precioVenta) : (a.precioVenta > b.precioVenta)
            case .stock:
                return sortAscending ? (a.cantidad < b.cantidad) : (a.cantidad > b.cantidad)
            }
        }
        return base
    }
    
    // Métricas
    private var totalProductos: Int { productos.count }
    private var costoTotal: Double {
        productos.reduce(0) { $0 + ($1.costo * $1.cantidad) }
    }
    private var valorInventario: Double {
        productos.reduce(0) { $0 + ($1.precioVenta * $1.cantidad) }
    }
    private var utilidadEstimada: Double {
        max(0, valorInventario - costoTotal)
    }

    // MARK: - Helpers de Dependencias
    private func validarDependencias(_ producto: Producto) -> String? {
        // 1. Revisar Servcios (Catálogo)
        let serviciosDependientes = servicios.filter { servicio in
            servicio.ingredientes.contains { ing in
                ing.nombreProducto == producto.nombre
            }
        }
        
        if !serviciosDependientes.isEmpty {
            let nombres = serviciosDependientes.prefix(3).map(\.nombre).joined(separator: ", ")
            let mas = serviciosDependientes.count > 3 ? " y \(serviciosDependientes.count - 3) más" : ""
            return "Este producto es usado en los siguientes servicios: \(nombres)\(mas).\n\nPara eliminarlo, primero debes quitar el servicio o editarlo para eliminar este producto de sus ingredientes."
        }
        
        // 2. Revisar Servicios En Proceso
        let procesosDependientes = serviciosEnProceso.filter { proceso in
            proceso.productosConsumidos.contains(producto.nombre)
        }
        
        if !procesosDependientes.isEmpty {
             return "Este producto está siendo usado en un servicio en curso (\(procesosDependientes.first?.nombreServicio ?? "")).\n\nFinaliza el servicio antes de modificar el producto."
        }
        
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header compacto
            header

            // Fila de Título Top 5 y Ganancias
            HStack(alignment: .center) {
                if !productos.isEmpty && productos.contains(where: { $0.vecesVendido > 0 }) {
                     Label("Top 5 Más Vendidos", systemImage: "trophy.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Spacer()
                // Ganancias (Badge)
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    Text("Ganancias Aproximadas: $\(gananciaAcumulada, specifier: "%.2f")")
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(Color("MercedesPetrolGreen"))
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.white.opacity(0.9))
                .cornerRadius(6)
            }
            .padding(.horizontal, 4)

            // Top 5 Productos más vendidos (Lista horizontal)
            topProductosView
            
            // Filtros y búsqueda mejorados
            filtrosView
            
            // Lista
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Contador de resultados
                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .foregroundColor(Color("MercedesPetrolGreen"))
                        Text("\(filteredProductos.count) resultado\(filteredProductos.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    if filteredProductos.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    } else {
                        ForEach(filteredProductos) { producto in
                            ProductoCard(
                                producto: producto,
                                lowStockThreshold: lowStockThreshold,
                                onEdit: { modalMode = .edit(producto) },
                                onDelete: {
                                    if let mensaje = validarDependencias(producto) {
                                        dependencyAlertMessage = mensaje
                                        showingDependencyAlert = true
                                    } else {
                                        productoAEliminar = producto
                                        mostrandoConfirmacionBorrado = true
                                    }
                                }
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
            ProductFormView(mode: $modalMode, initialMode: mode)
                .environment(\.modelContext, modelContext)
                .id(mode.id) // Force recreation when mode changes
        }
        .confirmationDialog(
            "Eliminar producto",
            isPresented: $mostrandoConfirmacionBorrado,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                if let p = productoAEliminar {
                    HistorialLogger.logAutomatico(
                        context: modelContext,
                        titulo: "Producto Eliminado",
                        detalle: "Se eliminó manualmente el producto \(p.nombre).",
                        categoria: .inventario,
                        entidadAfectada: p.nombre
                    )
                    modelContext.delete(p)
                }
            }
            Button("Cancelar", role: .cancel) { productoAEliminar = nil }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
        .alert("No se puede eliminar", isPresented: $showingDependencyAlert) {
            Button("Entendido", role: .cancel) { }
        } message: {
            Text(dependencyAlertMessage)
        }
    }
    
    private var header: some View {
        ZStack {
            // Fondo más sutil y compacto
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color("MercedesCard"), Color("MercedesBackground").opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                .frame(height: 110) // altura compacta
            
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Inventario")
                        .font(.title2).fontWeight(.bold).foregroundColor(.white) // antes largeTitle
                    Text("Controla tus productos, precios y stock.")
                        .font(.footnote).foregroundColor(.gray) // antes subheadline
                }
                Spacer()
                Button { modalMode = .add } label: {
                    Label("Añadir", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("Crear un nuevo producto")
            }
            .padding(.horizontal, 12)
            
        }
    }
    
    private func kpi(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)).frame(width: 32, height: 32) // antes 38
                Image(systemName: icon).foregroundColor(color).font(.system(size: 14, weight: .semibold)) // antes 16
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption2).foregroundColor(.gray) // antes caption
                Text(value).font(.subheadline).foregroundColor(.white) // antes headline
            }
            Spacer(minLength: 6)
        }
        .padding(8) // antes 10
        .background(
            ZStack {
                Color("MercedesCard")
                LinearGradient(colors: [Color.white.opacity(0.015), color.opacity(0.05)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        )
        .cornerRadius(8) // antes 10
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
    }
    
    private var filtrosView: some View {
        VStack(spacing: 8) {
            // Única barra: búsqueda + orden + categoría + limpiar
            HStack(spacing: 8) {
                // Buscar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    TextField("Buscar por Nombre, Unidad, Categoría, Proveedor o Información...", text: $searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.subheadline)
                        .animation(.easeInOut(duration: 0.15), value: searchQuery)
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
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
                
                // Orden (Consolidado)
                HStack(spacing: 6) {
                    Menu {
                        // Sección 1: Ordenamiento General (Activos)
                        Button {
                            // Resetear filtros
                            filtroCategoria = "Todas"
                            incluirInactivos = false
                            sortOption = .nombre
                        } label: {
                            if !incluirInactivos && filtroCategoria == "Todas" && sortOption == .nombre {
                                Label("Ordenar por Nombre", systemImage: "checkmark")
                            } else {
                                Text("Ordenar por Nombre")
                            }
                        }
                        
                        Button {
                            filtroCategoria = "Todas"
                            incluirInactivos = false
                            sortOption = .precio
                        } label: {
                            if !incluirInactivos && filtroCategoria == "Todas" && sortOption == .precio {
                                Label("Ordenar por Precio", systemImage: "checkmark")
                            } else {
                                Text("Ordenar por Precio")
                            }
                        }
                        
                        Button {
                            filtroCategoria = "Todas"
                            incluirInactivos = false
                            sortOption = .stock
                        } label: {
                            if !incluirInactivos && filtroCategoria == "Todas" && sortOption == .stock {
                                Label("Ordenar por Stock", systemImage: "checkmark")
                            } else {
                                Text("Ordenar por Stock")
                            }
                        }
                        
                        Divider()
                        
                        // Sección 2: Categorías
                        Menu("Ordenar por Categoría...") {
                            ForEach(categorias, id: \.self) { cat in
                                if cat != "Todas" { // "Todas" ya está implícito en los de arriba
                                    Button {
                                        incluirInactivos = false
                                        filtroCategoria = cat
                                    } label: {
                                        if !incluirInactivos && filtroCategoria == cat {
                                            Label(cat, systemImage: "checkmark")
                                        } else {
                                            Text(cat)
                                        }
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Sección 3: Inactivos
                        Button {
                            filtroCategoria = "Todas" // Resetear categoría para ver todos los inactivos
                            incluirInactivos = true
                        } label: {
                            if incluirInactivos {
                                Label("Ver Productos dados de Baja", systemImage: "checkmark")
                            } else {
                                Text("Ver Productos dados de Baja")
                            }
                        }
                        
                    } label: {
                         HStack(spacing: 6) {
                            // Texto dinámico: Prioridad Inactivos > Categoría > Orden
                            let labelText: String = {
                                if incluirInactivos { return "Ver Productos dados de Baja" }
                                if filtroCategoria != "Todas" { return "Categoría: \(filtroCategoria)" }
                                return "Ordenar por \(sortOption.rawValue)"
                            }()
                            
                            Text(labelText)
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                        .font(.subheadline)
                        .padding(8)
                        .background(Color("MercedesCard"))
                        .cornerRadius(8)
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 200)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            sortAscending.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                            Text(sortAscending ? "Ascendente" : "Descendente")
                        }
                        .font(.subheadline)
                        .padding(8)
                        .background(Color("MercedesCard"))
                        .cornerRadius(8)
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    }
                    .buttonStyle(.plain)
                    .help("Cambiar orden \(sortAscending ? "ascendente" : "descendente")")
                }
                
                Spacer()
            }
        }
    }
    
    // Empty state agradable
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(Color("MercedesPetrolGreen"))
            
            if !searchQuery.isEmpty {
                Text("No se encontraron productos para “\(searchQuery)”.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else if incluirInactivos {
                Text("No hay productos dados de baja.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                Text("No hay productos registrados aún.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("Añade tu primer producto para empezar a gestionar el inventario.")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // Top 5 View (Solo el ScrollView content)
    private var topProductosView: some View {
        let top5 = productos.sorted { $0.vecesVendido > $1.vecesVendido }.prefix(5)
        
        return Group {
            if !top5.isEmpty && top5.first!.vecesVendido > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(top5.enumerated()), id: \.element.nombre) { index, prod in
                            if prod.vecesVendido > 0 {
                                HStack(spacing: 8) {
                                    // Badge Rank
                                    ZStack {
                                        Circle()
                                            .fill(index == 0 ? Color.yellow : Color.gray.opacity(0.5))
                                            .frame(width: 24, height: 24)
                                        Text("#\(index + 1)")
                                            .font(.caption2).fontWeight(.bold)
                                            .foregroundColor(index == 0 ? .black : .white)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(prod.nombre)
                                            .font(.caption).fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text("\(prod.vecesVendido) ventas")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color("MercedesCard"))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }
}

// Tarjeta individual de producto (UI más clara)
struct ProductoCard: View {
    let producto: Producto
    let lowStockThreshold: Double
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    // Acceso a Ganancias Globales
    @AppStorage("gananciaAcumulada") private var gananciaAcumulada: Double = 0.0

    
    private var isLowStock: Bool {
        producto.cantidad <= lowStockThreshold
    }
    // Expiración (compara contra inicio de día para evitar falsos positivos por hora)
    private var isExpired: Bool {
        guard let cad = producto.fechaCaducidad else { return false }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return cad < startOfToday
    }
    // NUEVO: ¿Caduca este mes?
    private var isExpiringThisMonth: (flag: Bool, daysLeft: Int)? {
        guard let cad = producto.fechaCaducidad else { return nil }
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        guard cad >= startOfToday else { return (false, 0) } // si ya caducó, no aplica aquí
        let nowComp = cal.dateComponents([.year, .month], from: now)
        let cadComp = cal.dateComponents([.year, .month], from: cad)
        guard nowComp.year == cadComp.year, nowComp.month == cadComp.month else { return (false, 0) }
        let days = cal.dateComponents([.day], from: startOfToday, to: cal.startOfDay(for: cad)).day ?? 0
        return (true, max(0, days))
    }
    // Desglose real: Ganancia y Gastos Admin sobre el costo del producto
    private var desglose: ProductPricingHelpers.ReglaCalculoResultado {
        ProductPricingHelpers.calcularPrecioVentaSegunReglas(
            costo: producto.costo,
            porcentajeGanancia: producto.porcentajeMargenSugerido,
            porcentajeGastosAdmin: producto.porcentajeGastosAdministrativos,
            isrPorcentaje: producto.isrPorcentajeEstimado,
            ivaTasaFija: 0.16
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(producto.nombre)
                        .font(.headline).fontWeight(.semibold)
                    if !producto.informacion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(producto.informacion)
                            .font(.caption2).foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Spacer()
                
                // Botón Editar (Movido aquí)
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
                .help("Editar este producto")
            }
            
            // Banner de Inactivo
            if !producto.activo {
                banner(text: "Producto inactivo (Baja temporal)", color: .gray, systemImage: "eye.slash.fill")
            }
            
            // Avisos de caducidad
            if isExpired {
                banner(text: "Producto caducado", color: .red, systemImage: "exclamationmark.triangle.fill")
            } else if let exp = isExpiringThisMonth, exp.flag {
                banner(text: "Caduca este mes (\(exp.daysLeft) día\(exp.daysLeft == 1 ? "" : "s") restantes)", color: .orange, systemImage: "calendar.badge.exclamationmark")
            }
            
            // Desglose de utilidad real
            HStack(spacing: 6) {
                chip(text: "Margen de Ganancia: $" + String(format: "%.2f", desglose.ganancia), icon: "chart.line.uptrend.xyaxis")
                chip(text: "Gastos de Administración: $" + String(format: "%.2f", desglose.gastosAdmin), icon: "gearshape.2.fill")
                Spacer()
            }
            
            // Reparto real después del ISR
            HStack(spacing: 6) {
                chip(text: "Ganancia real (después de ISR): $" + String(format: "%.2f", desglose.gananciaRealDespuesISR), icon: "dollarsign.arrow.circlepath")
                Spacer()
            }
            
            // Chips y datos
            HStack(spacing: 6) {
                if !producto.categoria.isEmpty { chip(text: producto.categoria, icon: "tag.fill") }
                chip(text: producto.unidadDeMedida, icon: "cube.box.fill")
                if !producto.proveedor.isEmpty { chip(text: producto.proveedor, icon: "building.2.fill") }
                if !producto.lote.isEmpty { chip(text: "Lote \(producto.lote)", icon: "number") }
                if isLowStock {
                    chip(text: "Reponer", icon: "exclamationmark.triangle.fill", color: .red)
                }
                Spacer()
            }
            
            // Footer acciones (Vender / Reponer / Editar)
            VStack(spacing: 8) {
                // Fila de botones de acción rápida
                HStack(spacing: 12) {
                    // Botón Vender (Compacto)
                    Button {
                        if producto.cantidad > 0 {
                            let nuevoStock = producto.cantidad - 1
                            if let ctx = producto.modelContext { // Safe access
                               HistorialLogger.logAutomatico(context: ctx, titulo: "Venta Rápida", detalle: "Venta de 1 unidad de \(producto.nombre). Stock: \(producto.cantidad) -> \(nuevoStock)", categoria: .inventario, entidadAfectada: producto.nombre)
                            }
                            producto.cantidad -= 1
                            producto.vecesVendido += 1
                            gananciaAcumulada += producto.precioVenta
                        }
                    } label: {
                        Label("Vender", systemImage: "cart.badge.minus")
                            .font(.caption) // Igual que Editar
                            .padding(.horizontal, 10).padding(.vertical, 5) // Similar a Editar (8,5) pero pelín más ancho por texto
                            .background(producto.cantidad > 0 ? Color("MercedesPetrolGreen") : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        if producto.cantidad > 0 {
                            // Log Venta Rápida (Pre-calculo para log correcto)
                             // Nota: El button action corre despues, pero simultaneous corre en paralelo.
                             // Mejor poner el log dentro del action regular.
                        }
                    })
                    // ... actually I will modify the action block directly in the logic below

                    .disabled(producto.cantidad <= 0)
                    .buttonStyle(.plain)
                    
                    // Botón Reponer (Compacto)
                    Button {
                        let nuevoStock = producto.cantidad + 1
                         if let ctx = producto.modelContext {
                            HistorialLogger.logAutomatico(context: ctx, titulo: "Reposición Rápida", detalle: "Reposición de +1 unidad de \(producto.nombre). Stock: \(producto.cantidad) -> \(nuevoStock)", categoria: .inventario, entidadAfectada: producto.nombre)
                        }
                        producto.cantidad += 1
                        // Restar costo, pero ganancia no baja de 0
                        gananciaAcumulada = max(0, gananciaAcumulada - producto.costo)
                    } label: {
                        Label("Reponer (+1)", systemImage: "shippingbox.fill")
                            .font(.caption)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color("MercedesCard"))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                
                // Leyenda de reponer
                Text("Usa Editar para reponer mayores cantidades.")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 4)
            
            // Footer acciones
            HStack(alignment: .bottom) {
                // Info Stock
                Text("Cantidad en Stock: \(producto.cantidad, specifier: "%.2f")")
                    .font(.caption2).foregroundColor(.gray)
                
                Spacer()
                
                // Precio (Arriba) y Fecha (Abajo) en esquina inferior derecha
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Precio de venta: $\(producto.precioVenta, specifier: "%.2f")")
                        .font(.headline).fontWeight(.bold)
                        .foregroundColor(.white)
                    // Mostrar costo discreto debajo del precio o al lado? El usuario prioriza precio.
                    // Lo pondré pequeño si cabe, o solo precio. "El precio lo puedes poner arriba de la fecha".
                    // Voy a omitir costo aquí para no saturar, o ponerlo muy pequeño.
                    // Mejor solo precio y fecha como pidió explicitamente.
                    
                    if let cad = producto.fechaCaducidad {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text("Caduca: \(cad.formatted(date: .abbreviated, time: .omitted))")
                        }
                        .font(.caption2)
                        .foregroundColor(.gray)
                    }
                }
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
    
    private func chip(text: String, icon: String, color: Color = Color("MercedesBackground")) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(color)
        .cornerRadius(6)
        .foregroundColor(.white)
    }
    
    private func banner(text: String, color: Color, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption2)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(color.opacity(0.18))
        .cornerRadius(6)
        .foregroundColor(color)
    }
}


// --- VISTA DEL FORMULARIO (UI guiada y sin ambigüedad) ---
struct ProductFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Query para validar duplicados
    @Query private var allProducts: [Producto]
    // Queries para validación de dependencias
    @Query private var servicios: [Servicio]
    @Query private var serviciosEnProceso: [ServicioEnProceso]
    
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true

    @Binding var mode: ProductModalMode?
    
    // States para los campos
    @State private var nombre = ""
    @State private var categoria = ""
    @State private var unidadDeMedida = ""
    @State private var contenidoNetoString = ""
    @State private var proveedor = ""
    @State private var lote = ""
    @State private var fechaCaducidad: Date? = nil
    @State private var activo = true
    
    @State private var costoString = ""
    @State private var cantidadString = ""
    @State private var informacion = ""
    
    // Configuraciones financieras (todas en %)
    @State private var porcentajeMargenSugeridoString = ""
    @State private var porcentajeAdminString = ""
    @State private var isrPorcentajeString = ""
    
    // Precio final editable
    @State private var precioFinalString = ""
    @State private var precioModificadoManualmente = false
    
    let opcionesUnidad = ["Pieza", "Litro", "Onza (Oz)", "Galón", "Botella", "Lata", "Juego", "Kit", "Kg", "g", "Caja", "Metro"]
    
    // States para Seguridad y Errores
    @State private var isNombreUnlocked = false
    @State private var showingAuthModal = false
    @State private var authError = ""
    @State private var passwordAttempt = ""
    @State private var errorMsg: String?
    
    // NUEVO: Alerta para activar/desactivar producto
    @State private var showingStatusAlert = false
    @State private var showingDependencyAlert = false
    @State private var dependencyAlertMessage = ""
    
    // Enum para la razón de la autenticación
    private enum AuthReason {
        case unlockNombre, deleteProduct
    }
    @State private var authReason: AuthReason = .unlockNombre
    
    private var productoAEditar: Producto?
    var formTitle: String {
        guard let mode = mode else { return "" }
        switch mode {
        case .add: return "Añadir Producto"
        case .edit: return "Editar Producto"
        }
    }

    // MARK: - Helpers de Dependencias
    private func validarDependencias(_ producto: Producto) -> String? {
        // 1. Revisar Servcios (Catálogo)
        let serviciosDependientes = servicios.filter { servicio in
            servicio.ingredientes.contains { ing in
                ing.nombreProducto == producto.nombre
            }
        }
        
        if !serviciosDependientes.isEmpty {
            let nombres = serviciosDependientes.prefix(3).map(\.nombre).joined(separator: ", ")
            let mas = serviciosDependientes.count > 3 ? " y \(serviciosDependientes.count - 3) más" : ""
            return "Este producto es usado en los siguientes servicios: \(nombres)\(mas).\n\nPara eliminarlo, primero debes quitar el servicio o editarlo para eliminar este producto de sus ingredientes."
        }
        
        // 2. Revisar Servicios En Proceso
        let procesosDependientes = serviciosEnProceso.filter { proceso in
            proceso.productosConsumidos.contains(producto.nombre)
        }
        
        if !procesosDependientes.isEmpty {
             return "Este producto está siendo usado en un servicio en curso (\(procesosDependientes.first?.nombreServicio ?? "")).\n\nFinaliza el servicio antes de modificar el producto."
        }
        
        return nil
    }
    
    // --- Bools de Validación ---
    
    // Validación de nombre duplicado
    private var productoExistenteConMismoNombre: Producto? {
        let trimmed = nombre.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        
        // Buscar si existe otro producto con el mismo nombre (case insensitive)
        return allProducts.first { p in
            p.nombre.localizedCaseInsensitiveCompare(trimmed) == .orderedSame &&
            p.nombre != productoAEditar?.nombre // Excluir el mismo si estamos editando
        }
    }
    
    private var nombreDuplicado: Bool {
        productoExistenteConMismoNombre != nil
    }

    private var nombreInvalido: Bool {
        nombre.trimmingCharacters(in: .whitespaces).count < 3 || nombreDuplicado
    }
    private var costoInvalido: Bool {
        guard let v = Double(costoString.replacingOccurrences(of: ",", with: ".")) else { return true }
        return v <= 0
    }
    private var cantidadInvalida: Bool {
        guard let v = Double(cantidadString.replacingOccurrences(of: ",", with: ".")) else { return true }
        return v <= 0
    }
    private var contenidoInvalido: Bool {
        guard let v = Double(contenidoNetoString.replacingOccurrences(of: ",", with: ".")) else { return true }
        return v <= 0
    }
    private var pMargenInvalido: Bool { porcentajeInvalido(porcentajeMargenSugeridoString) }
    private var pAdminInvalido: Bool { porcentajeInvalido(porcentajeAdminString) }
    private var pISRInvalido: Bool { porcentajeInvalido(isrPorcentajeString) }
    private func porcentajeInvalido(_ s: String) -> Bool {
        guard let v = Double(s.replacingOccurrences(of: ",", with: ".")) else { return true }
        return v < 0 || v > 100
    }
    
    // --- Cálculos automáticos (solo lectura) ---
    private var costo: Double { Double(costoString.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var cantidad: Double { Double(cantidadString.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var pMargen: Double { Double(porcentajeMargenSugeridoString.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var pAdmin: Double { Double(porcentajeAdminString.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var pISR: Double { Double(isrPorcentajeString.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    
    private var resultadoReglas: ProductPricingHelpers.ReglaCalculoResultado {
        ProductPricingHelpers.calcularPrecioVentaSegunReglas(
            costo: costo,
            porcentajeGanancia: pMargen,
            porcentajeGastosAdmin: pAdmin,
            isrPorcentaje: pISR,
            ivaTasaFija: 0.16
        )
    }
    private var precioSugerido: Double {
        resultadoReglas.precioSugeridoConIVA
    }
    private var precioFinalEditable: Double {
        Double(precioFinalString.replacingOccurrences(of: ",", with: ".")) ?? precioSugerido
    }
    
    // Listas para autocompletado
    private var uniqueCategories: [String] {
        Array(Set(allProducts.map { $0.categoria })).filter { !$0.isEmpty }.sorted()
    }
    private var uniqueUnits: [String] {
        Array(Set(allProducts.map { $0.unidadDeMedida })).filter { !$0.isEmpty }.sorted()
    }
    private var uniqueProviders: [String] {
        Array(Set(allProducts.map { $0.proveedor })).filter { !$0.isEmpty }.sorted()
    }
    
    // Inicializador
    init(mode: Binding<ProductModalMode?>, initialMode: ProductModalMode) {
        self._mode = mode
        
        if case .edit(let producto) = initialMode {
            self.productoAEditar = producto
            _nombre = State(initialValue: producto.nombre)
            _costoString = State(initialValue: String(format: "%.2f", producto.costo))
            _cantidadString = State(initialValue: String(format: "%.2f", producto.cantidad))
            _informacion = State(initialValue: producto.informacion)
            _unidadDeMedida = State(initialValue: producto.unidadDeMedida)
            _contenidoNetoString = State(initialValue: String(format: "%.2f", producto.contenidoNeto))
            _categoria = State(initialValue: producto.categoria)
            _proveedor = State(initialValue: producto.proveedor)
            _lote = State(initialValue: producto.lote)
            _fechaCaducidad = State(initialValue: producto.fechaCaducidad)
            _porcentajeMargenSugeridoString = State(initialValue: String(format: "%.2f", producto.porcentajeMargenSugerido))
            _porcentajeAdminString = State(initialValue: String(format: "%.2f", producto.porcentajeGastosAdministrativos))
            _isrPorcentajeString = State(initialValue: String(format: "%.2f", producto.isrPorcentajeEstimado))
            _precioFinalString = State(initialValue: String(format: "%.2f", producto.precioVenta))
            _precioModificadoManualmente = State(initialValue: producto.precioModificadoManualmente)
            _activo = State(initialValue: producto.activo)
        }
    }
    
    // --- CUERPO DEL MODAL ---
    var body: some View {
        VStack(spacing: 0) {
            // Título y guía
            VStack(spacing: 4) {
                Text(formTitle).font(.title).fontWeight(.bold)
                Text("Completa los datos básicos. IVA 16% fijo.")
                    .font(.footnote).foregroundColor(.gray)
            }
            .padding(16)

            ScrollView {
                VStack(spacing: 24) {
                    
                    // Sección 1: Datos básicos del producto
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "1. Datos del Producto", subtitle: "Nombre, categoría, unidad y proveedor")
                        
                        // Nombre con candado en edición
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("• Nombre del Producto").font(.caption2).foregroundColor(.gray)
                                if productoAEditar != nil {
                                    Image(systemName: isNombreUnlocked ? "lock.open.fill" : "lock.fill")
                                        .foregroundColor(isNombreUnlocked ? .green : .red)
                                        .font(.caption2)
                                }
                            }
                            HStack(spacing: 6) {
                                TextField("", text: $nombre)
                                    .disabled(productoAEditar != nil && !isNombreUnlocked)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Color("MercedesBackground"))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .onChange(of: nombre) { _, newValue in
                                        if newValue.count > 60 {
                                            nombre = String(newValue.prefix(60))
                                        }
                                    }
                                    .help("Identificador único del producto (Máx 60 caracteres)")
                                
                                // Contador manual para Nombre
                                Text("\(nombre.count)/60")
                                    .font(.caption2)
                                    .foregroundColor(nombre.count >= 60 ? .red : .gray)
                                    .frame(width: 40, alignment: .trailing)
                                
                                if productoAEditar != nil {
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
                                    // Esto cerrará el sheet actual y abrirá uno nuevo debido al cambio de ID
                                    mode = .edit(existente)
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
                        
                        HStack(spacing: 16) {
                            FormField(title: "Categoría", placeholder: "ej. Aceites", text: $categoria, characterLimit: 21, suggestions: uniqueCategories)
                                .onChange(of: categoria) { _, newValue in
                                    if newValue.count > 21 {
                                        categoria = String(newValue.prefix(21))
                                    }
                                }
                                .help("Clasifica el producto para filtrar más fácil")
                            
                            HStack(spacing: 8) {
                                FormField(title: "• Contenido por producto", placeholder: "1.0", text: $contenidoNetoString)
                                    .frame(width: 80)
                                    .onChange(of: contenidoNetoString) { _, newValue in
                                        let filtered = newValue.filter { "0123456789.,".contains($0) }
                                        if filtered != newValue {
                                            contenidoNetoString = filtered
                                        }
                                    }
                                    .validationHint(isInvalid: contenidoInvalido, message: "Debe de ser mayor a 0")
                                    .help("Cantidad que conforma la unidad (ej. 3)")
                                FormField(title: "• Unidad de Medida", placeholder: "ej. Litro, Pieza, Kit", text: $unidadDeMedida, characterLimit: 11, suggestions: uniqueUnits)
                                    .onChange(of: unidadDeMedida) { _, newValue in
                                        // Permitir solo letras (incluyendo acentos) y espacios
                                        let filtered = newValue.filter { $0.isLetter || $0.isWhitespace }
                                        if filtered.count > 11 {
                                            unidadDeMedida = String(filtered.prefix(11))
                                        } else if filtered != newValue {
                                            unidadDeMedida = filtered
                                        }
                                    }
                                    .help("Unidad en la que controlas el stock")
                                    .validationHint(isInvalid: unidadDeMedida.trimmingCharacters(in: .whitespaces).isEmpty, message: "Requerido")
                            }
                        }
                        
                        HStack(spacing: 16) {
                            FormField(title: "Proveedor", placeholder: "ej. Mobil 1", text: $proveedor, characterLimit: 60, suggestions: uniqueProviders)
                                .onChange(of: proveedor) { _, newValue in
                                    if newValue.count > 60 {
                                        proveedor = String(newValue.prefix(60))
                                    }
                                }
                            FormField(title: "Lote", placeholder: "ej. L-12345", text: $lote, characterLimit: 21)
                                .onChange(of: lote) { _, newValue in
                                    if newValue.count > 21 {
                                        lote = String(newValue.prefix(21))
                                    }
                                }
                            
                            // Campo de Fecha de Caducidad (Estilizado)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Fecha de caducidad")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                
                                HStack {
                                    Toggle("", isOn: Binding(
                                        get: { fechaCaducidad != nil },
                                        set: { hasDate in fechaCaducidad = hasDate ? Date() : nil }
                                    ))
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                    
                                    Text(fechaCaducidad == nil ? "Sin caducidad" : "Vence el:")
                                        .font(.subheadline)
                                        .foregroundColor(fechaCaducidad == nil ? .gray.opacity(0.8) : .white)
                                    
                                    Spacer()
                                    
                                    if fechaCaducidad != nil {
                                        DatePicker("", selection: Binding(
                                            get: { fechaCaducidad ?? Date() },
                                            set: { fechaCaducidad = $0 }
                                        ), displayedComponents: .date)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                    }
                                }
                                .padding(8)
                                .background(Color("MercedesBackground"))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .help("Selecciona la fecha de caducidad si aplica")
                        }
                        
                        HStack(spacing: 16) {
                            FormField(title: "• Costo de compra por producto", placeholder: "$0.00", text: $costoString)
                                .onChange(of: costoString) { _, newValue in
                                    let filtered = newValue.filter { "0123456789.,".contains($0) }
                                    if filtered != newValue {
                                        costoString = filtered
                                    }
                                }
                                .validationHint(isInvalid: costoInvalido, message: "Debe ser mayor a 0.")
                                .help("Costo unitario de adquisición")
                            FormField(title: "• Cantidad en stock", placeholder: "0", text: $cantidadString)
                                .onChange(of: cantidadString) { _, newValue in
                                    let filtered = newValue.filter { "0123456789.,".contains($0) }
                                    if filtered != newValue {
                                        cantidadString = filtered
                                    }
                                }
                                .validationHint(isInvalid: cantidadInvalida, message: "Debe ser mayor a 0.")
                                .help("Cantidad actual disponible")
                        }
                        
                        FormField(title: "Información (opcional)", placeholder: "Notas adicionales...", text: $informacion, characterLimit: 51)
                            .onChange(of: informacion) { _, newValue in
                                if newValue.count > 51 {
                                    informacion = String(newValue.prefix(51))
                                }
                            }
                            .help("Notas útiles para identificar/usar el producto")
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Sección 2: Porcentajes y reglas
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "2. Reglas de Precio", subtitle: "Porcentajes aplicados sobre el costo")
                        HStack(spacing: 16) {
                            FormField(title: "• % Margen de Ganancia", placeholder: "0-100", text: $porcentajeMargenSugeridoString)
                                .onChange(of: porcentajeMargenSugeridoString) { _, newValue in
                                    let filtered = newValue.filter { "0123456789.,".contains($0) }
                                    if filtered != newValue {
                                        porcentajeMargenSugeridoString = filtered
                                    }
                                }
                                .validationHint(isInvalid: pMargenInvalido, message: "0 a 100.")
                                .help("Porcentaje de ganancia sobre el costo")
                            FormField(title: "• % Gastos administrativos", placeholder: "0-100", text: $porcentajeAdminString)
                                .onChange(of: porcentajeAdminString) { _, newValue in
                                    let filtered = newValue.filter { "0123456789.,".contains($0) }
                                    if filtered != newValue {
                                        porcentajeAdminString = filtered
                                    }
                                }
                                .validationHint(isInvalid: pAdminInvalido, message: "0 a 100.")
                                .help("Porcentaje para cubrir administración sobre el costo")
                            FormField(title: "% ISR (aprox.)", placeholder: "0-100", text: $isrPorcentajeString)
                                .onChange(of: isrPorcentajeString) { _, newValue in
                                    let filtered = newValue.filter { "0123456789.,".contains($0) }
                                    if filtered != newValue {
                                        isrPorcentajeString = filtered
                                    }
                                }
                                .validationHint(isInvalid: pISRInvalido, message: "0 a 100.")
                                .help("Se calcula solo sobre la GANANCIA (margen)")
                        }
                        HStack(spacing: 6) {
                            Label("IVA: 16% (fijo)", systemImage: "info.circle")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Sección 3: Cálculo automático (compacto)
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Cálculo Automático", subtitle: "Lectura", color: "MercedesPetrolGreen")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 8) {
                            roField("Margen de Ganancia (monto)", resultadoReglas.ganancia)
                            roField("Gastos administrativos (monto)", resultadoReglas.gastosAdmin)
                            roField("Subtotal antes de IVA", resultadoReglas.subtotalAntesIVA)
                            roField("IVA Trasladado (16%)", resultadoReglas.iva)
                            roField("IVA Acreditable (16% costo)", resultadoReglas.ivaAcreditable)
                            roField("IVA a Pagar", resultadoReglas.ivaPorPagar)
                            roField("Precio (con IVA)", resultadoReglas.precioSugeridoConIVA)
                        }
                        HStack(spacing: 16) {
                            roField("ISR (solo sobre ganancia)", resultadoReglas.isr)
                            roField("Precio neto después de ISR", resultadoReglas.precioNetoDespuesISR)
                        }
                        
                        // NUEVO: Reparto real después del ISR
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reparto real después del ISR")
                                .font(.headline).foregroundColor(.white)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 8) {
                                roField("Margen de ganancia después del ISR", resultadoReglas.gananciaRealDespuesISR)
                                roField("Gastos administrativos (monto)", resultadoReglas.gastosAdmin)
                                roField("Utilidad real después de ISR", resultadoReglas.utilidadRealDespuesISR)
                                                            }
                            Text("El ISR solo afecta al margen de ganancia.")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(16)
                        .background(Color("MercedesBackground").opacity(0.3))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(16)
                    .background(Color("MercedesBackground").opacity(0.2))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color("MercedesPetrolGreen").opacity(0.5), lineWidth: 1)
                    )
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Sección 4: Precio final editable
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "3. Precio Final", subtitle: "Ajustable")
                        HStack(spacing: 16) {
                            FormField(title: "Precio final al cliente", placeholder: "0.00", text: $precioFinalString)
                                .onChange(of: precioFinalString) { _, new in
                                    let final = Double(new.replacingOccurrences(of: ",", with: ".")) ?? 0
                                    precioModificadoManualmente = abs(final - precioSugerido) > 0.009
                                }
                                .help("Si lo editas, se marcará como modificado manualmente")
                            if precioModificadoManualmente {
                                Text("Modificado manualmente")
                                    .font(.caption2)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.yellow.opacity(0.2))
                                    .foregroundColor(.yellow)
                                    .cornerRadius(6)
                            }
                        }
                    }
                    
                    // Zona de Peligro
                    if let currentMode = mode, case .edit = currentMode {
                        Divider().background(Color.red.opacity(0.3))
                        VStack(spacing: 12) {
                            Text("Esta acción no se puede deshacer y eliminará permanentemente el producto.")
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                            
                            Button(role: .destructive) {
                                if let p = productoAEditar, let msg = validarDependencias(p) {
                                    dependencyAlertMessage = msg
                                    showingDependencyAlert = true
                                } else {
                                    authReason = .deleteProduct
                                    showingAuthModal = true
                                }
                            } label: {
                                Label("Eliminar producto permanentemente", systemImage: "trash.fill")
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
                if productoAEditar == nil {
                    precioFinalString = String(format: "%.2f", precioSugerido)
                }
            }
            .onChange(of: costoString) { _, _ in syncFinalIfNotManual() }
            .onChange(of: porcentajeMargenSugeridoString) { _, _ in syncFinalIfNotManual() }
            .onChange(of: porcentajeAdminString) { _, _ in syncFinalIfNotManual() }
            .onChange(of: isrPorcentajeString) { _, _ in /* solo afecta ISR y precio neto */ }
            
            // Mensaje de Error
            if let errorMsg {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.vertical, 6)
            }
            
            // --- Barra de Botones ---
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
                
                // Botón de Activar/Desactivar
                if productoAEditar != nil {
                    Button {
                        // Mostrar alerta de confirmación en lugar de togglear directo
                        if let p = productoAEditar, activo, let msg = validarDependencias(p) {
                            // Si está activo y queremos desactivar (activo=true), validamos.
                            // Si ya está inactivo (activo=false) y queremos reactivar, no hay problema de dependencia (al contrario, es bueno).
                            dependencyAlertMessage = msg
                            showingDependencyAlert = true
                        } else {
                            showingStatusAlert = true
                        }
                    } label: {
                        Text(activo ? "Quitar temporalmente" : "Devolver al inventario")
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(activo ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                            .foregroundColor(activo ? .orange : .green)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(activo ? Color.orange.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(activo ? "Ocultar temporalmente (Baja)" : "Reactivar producto")
                }
                
                Spacer()
                
                Button {
                    guardarCambios()
                } label: {
                    Text(productoAEditar == nil ? "Guardar y añadir" : "Guardar cambios")
                        .fontWeight(.semibold)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .shadow(color: Color("MercedesPetrolGreen").opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(nombreInvalido || costoInvalido || cantidadInvalida || contenidoInvalido || pMargenInvalido || pAdminInvalido || pISRInvalido)
                .opacity((nombreInvalido || costoInvalido || cantidadInvalida || contenidoInvalido || pMargenInvalido || pAdminInvalido || pISRInvalido) ? 0.6 : 1.0)
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
        // ALERTA: Confirmar activar/desactivar
        .alert(activo ? "¿Quitar temporalmente?" : "¿Devolver al inventario?", isPresented: $showingStatusAlert) {
            Button(activo ? "Quitar temporalmente" : "Devolver al inventario", role: .destructive) {
                if let p = productoAEditar {
                    let nuevoEstado = !activo
                    HistorialLogger.logAutomatico(
                        context: modelContext,
                        titulo: nuevoEstado ? "Producto Reactivado" : "Baja Temporal de Producto",
                        detalle: "El producto \(p.nombre) cambió a estado \(nuevoEstado ? "Activo" : "Inactivo (Baja)").",
                        categoria: .inventario,
                        entidadAfectada: p.nombre
                    )
                }
                activo.toggle()
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text(
                activo
                ? "No se borrarán los datos del producto; solo quedará inactivo. Podrás devolverlo al inventario más adelante."
                : "El producto volverá al inventario"
            )
        }
        .alert("Acción no permitida", isPresented: $showingDependencyAlert) {
            Button("Entendido", role: .cancel) { }
        } message: {
            Text(dependencyAlertMessage)
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
    
    private func syncFinalIfNotManual() {
        if !precioModificadoManualmente {
            precioFinalString = String(format: "%.2f", precioSugerido)
        }
    }
    
    // --- VISTA: Modal de Autenticación ---
    @ViewBuilder
    func authModalView() -> some View {
        let prompt = (authReason == .unlockNombre) ?
            "Autoriza para editar el Nombre del Producto." :
            "Autoriza para ELIMINAR este producto."
        
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Autorización Requerida").font(.title2).fontWeight(.bold)
                Text(prompt)
                    .font(.callout)
                    .foregroundColor(authReason == .deleteProduct ? .red : .gray)
                
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
    
    // --- Lógica del Formulario (Validaciones) ---
    func guardarCambios() {
        errorMsg = nil
        let trimmedNombre = nombre.trimmingCharacters(in: .whitespaces)
        
        guard trimmedNombre.count >= 3 else {
            errorMsg = "El nombre del producto debe tener al menos 3 caracteres."
            return
        }
        guard !unidadDeMedida.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMsg = "La Unidad de Medida es requerida."
            return
        }
        guard let costo = Double(costoString.replacingOccurrences(of: ",", with: ".")), costo > 0 else {
            errorMsg = "El Costo debe ser mayor a 0."
            return
        }
        guard let cantidad = Double(cantidadString.replacingOccurrences(of: ",", with: ".")), cantidad > 0 else {
            errorMsg = "La Cantidad debe ser mayor a 0."
            return
        }
        guard let contenido = Double(contenidoNetoString.replacingOccurrences(of: ",", with: ".")), contenido > 0 else {
            errorMsg = "El Contenido debe ser mayor a 0."
            return
        }
        guard let pMargen = Double(porcentajeMargenSugeridoString.replacingOccurrences(of: ",", with: ".")), (0...100).contains(pMargen) else {
            errorMsg = "% Ganancia inválido."
            return
        }
        guard let pAdmin = Double(porcentajeAdminString.replacingOccurrences(of: ",", with: ".")), (0...100).contains(pAdmin) else {
            errorMsg = "% Gastos Administrativos inválido."
            return
        }
        guard let pISR = Double(isrPorcentajeString.replacingOccurrences(of: ",", with: ".")), (0...100).contains(pISR) else {
            errorMsg = "% ISR inválido."
            return
        }
        
        let finalEditable = Double(precioFinalString.replacingOccurrences(of: ",", with: ".")) ?? precioSugerido
        
        if let producto = productoAEditar {
            // Log Edición
            var diffs: [String] = []
            if let d = HistorialLogger.generarDiffCambioTexto(campo: "Nombre", ant: producto.nombre, nue: trimmedNombre) { diffs.append(d) }
            if let d = HistorialLogger.generarDiffCambioNumero(campo: "Costo", ant: producto.costo, nue: costo) { diffs.append(d) }
            if let d = HistorialLogger.generarDiffCambioNumero(campo: "Precio Venta", ant: producto.precioVenta, nue: finalEditable) { diffs.append(d) }
            if let d = HistorialLogger.generarDiffCambioNumero(campo: "Stock", ant: producto.cantidad, nue: cantidad) { diffs.append(d) }
            if let d = HistorialLogger.generarDiffCambioTexto(campo: "Categoría", ant: producto.categoria, nue: categoria) { diffs.append(d) }
            if let d = HistorialLogger.generarDiffCambioTexto(campo: "Proveedor", ant: producto.proveedor, nue: proveedor) { diffs.append(d) }
            
            if !diffs.isEmpty {
                 HistorialLogger.logAutomatico(
                    context: modelContext,
                    titulo: "Actualización de Producto: \(producto.nombre)",
                    detalle: "Cambios realizados:\n" + diffs.joined(separator: "\n"),
                    categoria: .inventario,
                    entidadAfectada: producto.nombre
                 )
            }
            
            producto.nombre = trimmedNombre
            producto.costo = costo
            producto.cantidad = cantidad
            producto.informacion = informacion
            producto.unidadDeMedida = unidadDeMedida
            producto.contenidoNeto = Double(contenidoNetoString.replacingOccurrences(of: ",", with: ".")) ?? 1.0
            producto.categoria = categoria
            producto.proveedor = proveedor
            producto.lote = lote
            producto.fechaCaducidad = fechaCaducidad
            // Mantener campos de configuración financiera
            producto.porcentajeMargenSugerido = pMargen
            producto.porcentajeGastosAdministrativos = pAdmin
            producto.isrPorcentajeEstimado = pISR
            // Precio final
            producto.precioVenta = finalEditable
            producto.precioModificadoManualmente = precioModificadoManualmente
            producto.activo = activo
        } else {
             HistorialLogger.logAutomatico(
                context: modelContext,
                titulo: "Nuevo Producto Añadido",
                detalle: "Se registró el producto \(trimmedNombre) (Costo: $\(costo), Precio: $\(finalEditable), Stock: \(cantidad)).",
                categoria: .inventario,
                entidadAfectada: trimmedNombre
             )
            
            let nuevoProducto = Producto(
                nombre: trimmedNombre,
                costo: costo,
                precioVenta: finalEditable,
                cantidad: cantidad,
                unidadDeMedida: unidadDeMedida,
                informacion: informacion,
                categoria: categoria,
                proveedor: proveedor,
                lote: lote,
                fechaCaducidad: fechaCaducidad,
                costoIncluyeIVA: true,
                porcentajeMargenSugerido: pMargen,
                porcentajeGastosAdministrativos: pAdmin,
                tipoFiscal: .iva16, // fijo en 16% para el cálculo
                isrPorcentajeEstimado: pISR,
                precioModificadoManualmente: precioModificadoManualmente,
                activo: activo,
                contenidoNeto: Double(contenidoNetoString.replacingOccurrences(of: ",", with: ".")) ?? 1.0
            )
            modelContext.insert(nuevoProducto)
        }
        dismiss()
    }
    
    func eliminarProducto(_ producto: Producto) {
        HistorialLogger.logAutomatico(
            context: modelContext,
            titulo: "Producto Eliminado",
            detalle: "Se eliminó definitivamente el producto \(producto.nombre).",
            categoria: .inventario,
            entidadAfectada: producto.nombre
        )
        modelContext.delete(producto)
        dismiss()
    }
    
    // --- Lógica de Autenticación ---
    func authenticateWithTouchID() async {
        let context = LAContext()
        let reason = (authReason == .unlockNombre) ? "Autoriza la edición del Nombre." : "Autoriza la ELIMINACIÓN del producto."
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
        case .deleteProduct:
            if let currentMode = mode, case .edit(let producto) = currentMode {
                eliminarProducto(producto)
            }
        }
        showingAuthModal = false
        authError = ""
        passwordAttempt = ""
    }
}


// --- Helpers de UI ---
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
            TextField("", text: $text)
                .textFieldStyle(.plain)
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
            if !placeholder.isEmpty {
                Text(placeholder)
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
                    .padding(.leading, 4)
            }
        }
    }
}

// Helper para mostrar la validación
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

