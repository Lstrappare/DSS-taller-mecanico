import SwiftUI
import SwiftData
import LocalAuthentication

// --- MODO DEL MODAL ---
fileprivate enum ProductModalMode: Identifiable {
    case add
    case edit(Producto)
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let producto): return producto.nombre
        }
    }
}

// --- Helpers de precio para productos (flujo corregido) ---
fileprivate enum ProductPricingHelpers {
    // 1) Base sin IVA con margen: base = costo + margen(costo)
    static func baseConMargen(costo: Double, porcentajeMargen: Double) -> Double {
        costo + (costo * (porcentajeMargen / 100.0))
    }
    // 2) IVA sobre base
    static func ivaSobreBase(base: Double, ivaTasa: Double) -> Double {
        base * ivaTasa
    }
    // 3) Precio final sugerido: base + iva
    static func precioSugerido(base: Double, iva: Double) -> Double {
        base + iva
    }
    // 4) Gastos administrativos sobre base (sin IVA)
    static func gastoAdministrativo(base: Double, porcentajeAdmin: Double) -> Double {
        base * (porcentajeAdmin / 100.0)
    }
    // 5) Utilidad bruta antes de gastos
    static func utilidadAntesDeGastos(base: Double, costo: Double) -> Double {
        base - costo
    }
    // 6) Utilidad después de gastos
    static func utilidadDespuesDeGastos(utilidadAntes: Double, gastoAdmin: Double) -> Double {
        utilidadAntes - gastoAdmin
    }
    // 7) ISR aproximado sobre utilidad después de gastos
    static func isrAproximado(utilidadDespuesGastos: Double, tasaISR: Double) -> Double {
        max(0, utilidadDespuesGastos) * (tasaISR / 100.0)
    }
    // 8) Margen real respecto al precio final (editable)
    static func margenReal(utilidadDespuesGastos: Double, precioFinal: Double) -> Double {
        guard precioFinal > 0 else { return 0 }
        return utilidadDespuesGastos / precioFinal
    }
    // Utilidad práctica si el precio final fue editado (base desde precio final)
    static func utilidadDespuesDeGastosConPrecioFinal(precioFinalSinIVA: Double, costo: Double, porcentajeAdmin: Double) -> Double {
        // precioFinalSinIVA representa la base (sin IVA) cuando el usuario edita el precio final
        let utilidadAntes = utilidadAntesDeGastos(base: precioFinalSinIVA, costo: costo)
        let gastoAdmin = gastoAdministrativo(base: precioFinalSinIVA, porcentajeAdmin: porcentajeAdmin)
        return utilidadDespuesDeGastos(utilidadAntes: utilidadAntes, gastoAdmin: gastoAdmin)
    }
    // Diferencia final vs sugerido
    static func variacionPrecio(final: Double, sugerido: Double) -> Double {
        final - sugerido
    }
    // Si el costo incluye IVA y queremos recuperar el costo neto (no usado en el nuevo flujo, pero útil si se necesitara)
    static func costoSinIVA(desdeCostoConIVA costo: Double, ivaTasa: Double) -> Double {
        costo / max(1 + ivaTasa, 0.0001)
    }
}

// --- VISTA PRINCIPAL (Mejorada UI) ---
struct InventarioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Producto.nombre) private var productos: [Producto]
    
    @State private var modalMode: ProductModalMode?
    @State private var searchQuery = ""
    @State private var productoAEliminar: Producto?
    @State private var mostrandoConfirmacionBorrado = false
    
    // Configuración de UI
    private let lowStockThreshold: Double = 2.0
    
    var filteredProductos: [Producto] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return productos
        } else {
            let query = searchQuery.lowercased()
            return productos.filter { producto in
                producto.nombre.lowercased().contains(query) ||
                producto.unidadDeMedida.lowercased().contains(query) ||
                producto.informacion.lowercased().contains(query) ||
                producto.categoria.lowercased().contains(query) ||
                producto.proveedor.lowercased().contains(query) ||
                producto.lote.lowercased().contains(query)
            }
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Cabecera con métricas y CTA
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Gestión de Inventario")
                        .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                    HStack(spacing: 10) {
                        Label("\(totalProductos) producto\(totalProductos == 1 ? "" : "s")", systemImage: "shippingbox.fill")
                            .font(.subheadline).foregroundColor(.gray)
                        Label("Valor: $\(valorInventario, specifier: "%.2f")", systemImage: "banknote.fill")
                            .font(.subheadline).foregroundColor(.gray)
                        Label("Costo: $\(costoTotal, specifier: "%.2f")", systemImage: "creditcard.fill")
                            .font(.subheadline).foregroundColor(.gray)
                        Label("Utilidad: $\(utilidadEstimada, specifier: "%.2f")", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.subheadline).foregroundColor(.gray)
                    }
                }
                Spacer()
                Button { modalMode = .add } label: {
                    Label("Añadir Producto", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding(.vertical, 10).padding(.horizontal, 14)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            
            // Descripción
            Text("Registra y modifica tus productos.")
                .font(.title3).foregroundColor(.gray)
            
            // Buscador
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color("MercedesPetrolGreen"))
                TextField("Buscar por Nombre, Unidad, Categoría, Proveedor o Información...", text: $searchQuery)
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
            
            // Lista
            ScrollView {
                LazyVStack(spacing: 14) {
                    if filteredProductos.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        ForEach(filteredProductos) { producto in
                            ProductoCard(
                                producto: producto,
                                lowStockThreshold: lowStockThreshold,
                                onEdit: { modalMode = .edit(producto) },
                                onDelete: {
                                    productoAEliminar = producto
                                    mostrandoConfirmacionBorrado = true
                                }
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
            ProductFormView(mode: mode)
                .environment(\.modelContext, modelContext)
        }
        .confirmationDialog(
            "Eliminar producto",
            isPresented: $mostrandoConfirmacionBorrado,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                if let p = productoAEliminar {
                    modelContext.delete(p)
                }
            }
            Button("Cancelar", role: .cancel) { productoAEliminar = nil }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
    
    // Empty state agradable
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(Color("MercedesPetrolGreen"))
            Text(searchQuery.isEmpty ? "No hay productos registrados aún." :
                 "No se encontraron productos para “\(searchQuery)”.")
                .font(.headline)
                .foregroundColor(.gray)
            if searchQuery.isEmpty {
                Text("Añade tu primer producto para empezar a gestionar el inventario.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// Tarjeta individual de producto
fileprivate struct ProductoCard: View {
    let producto: Producto
    let lowStockThreshold: Double
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    private var margenColor: Color {
        producto.margen > 50 ? .green : (producto.margen > 20 ? .yellow : .red)
    }
    private var margenTexto: String {
        if producto.margen > 50 { return "Alto" }
        if producto.margen > 20 { return "Medio" }
        return "Crítico"
    }
    private var isLowStock: Bool {
        producto.cantidad <= lowStockThreshold
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(producto.nombre)
                            .font(.title2).fontWeight(.semibold)
                        if !producto.categoria.isEmpty {
                            Text(producto.categoria)
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color("MercedesBackground"))
                                .cornerRadius(6)
                        }
                    }
                    if !producto.informacion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(producto.informacion)
                            .font(.subheadline).foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }
                Spacer()
                HStack(spacing: 8) {
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
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                            .font(.subheadline)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.red.opacity(0.18))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
            }
            
            // Detalles
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        chip(text: producto.unidadDeMedida, icon: "cube.box.fill")
                        if isLowStock {
                            chip(text: "Stock bajo", icon: "exclamationmark.triangle.fill", color: .red)
                        }
                        if !producto.proveedor.isEmpty {
                            chip(text: producto.proveedor, icon: "building.2.fill")
                        }
                        if !producto.lote.isEmpty {
                            chip(text: "Lote \(producto.lote)", icon: "number")
                        }
                    }
                    Text("Cantidad: \(producto.cantidad, specifier: "%.2f") \(producto.unidadDeMedida)(s)")
                        .font(.body).foregroundColor(.gray)
                    if let cad = producto.fechaCaducidad {
                        Text("Caduca: \(cad.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundColor(.gray)
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Costo: $\(producto.costo, specifier: "%.2f")")
                    Text("Precio: $\(producto.precioVenta, specifier: "%.2f")")
                    HStack(spacing: 8) {
                        Text(String(format: "Margen: %.0f%%", producto.margen))
                            .font(.headline).foregroundColor(margenColor)
                        Text(margenTexto)
                            .font(.caption2)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(margenColor.opacity(0.18))
                            .foregroundColor(margenColor)
                            .cornerRadius(6)
                    }
                    Text(producto.tipoFiscal.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color("MercedesBackground"))
                        .cornerRadius(6)
                }
                .font(.body).foregroundColor(.gray)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("MercedesCard"))
        .cornerRadius(12)
    }
    
    private func chip(text: String, icon: String, color: Color = Color("MercedesBackground")) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color)
        .cornerRadius(8)
        .foregroundColor(.white)
    }
}


// --- VISTA DEL FORMULARIO (Mejorada) ---
fileprivate struct ProductFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true

    let mode: ProductModalMode
    
    // States para los campos
    @State private var nombre = ""
    @State private var categoria = ""
    @State private var unidadDeMedida = "Pieza"
    @State private var proveedor = ""
    @State private var lote = ""
    @State private var fechaCaducidad: Date? = nil
    
    @State private var costoString = ""
    @State private var cantidadString = ""
    @State private var informacion = ""
    @State private var tipoFiscal: TipoFiscalProducto = .iva16
    
    // Configuraciones financieras
    @State private var porcentajeMargenSugeridoString = "30.0"
    @State private var porcentajeAdminString = "10.0"
    @State private var isrPorcentajeString = "10.0"
    
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
    
    // Enum para la razón de la autenticación
    private enum AuthReason {
        case unlockNombre, deleteProduct
    }
    @State private var authReason: AuthReason = .unlockNombre
    
    private var productoAEditar: Producto?
    var formTitle: String {
        switch mode {
        case .add: return "Añadir Nuevo Producto"
        case .edit: return "Editar Producto"
        }
    }
    
    // --- Bools de Validación ---
    private var nombreInvalido: Bool {
        nombre.trimmingCharacters(in: .whitespaces).count < 3
    }
    private var costoInvalido: Bool {
        Double(costoString.replacingOccurrences(of: ",", with: ".")) == nil
    }
    private var cantidadInvalida: Bool {
        Double(cantidadString.replacingOccurrences(of: ",", with: ".")) == nil
    }
    private var pMargenInvalido: Bool { porcentajeInvalido(porcentajeMargenSugeridoString) }
    private var pAdminInvalido: Bool { porcentajeInvalido(porcentajeAdminString) }
    private var pISRInvalido: Bool { porcentajeInvalido(isrPorcentajeString) }
    private func porcentajeInvalido(_ s: String) -> Bool {
        guard let v = Double(s.replacingOccurrences(of: ",", with: ".")) else { return true }
        return v < 0 || v > 100
    }
    
    // --- Cálculos automáticos (solo lectura, basados en inputs) ---
    private var costo: Double { Double(costoString.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var cantidad: Double { Double(cantidadString.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var pMargen: Double { Double(porcentajeMargenSugeridoString.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var pAdmin: Double { Double(porcentajeAdminString.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var pISR: Double { Double(isrPorcentajeString.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var ivaTasa: Double { tipoFiscal.tasa }
    
    // Flujo exacto solicitado
    private var baseSinIVAConMargen: Double {
        ProductPricingHelpers.baseConMargen(costo: costo, porcentajeMargen: pMargen)
    }
    private var ivaMonto: Double {
        ProductPricingHelpers.ivaSobreBase(base: baseSinIVAConMargen, ivaTasa: ivaTasa)
    }
    private var precioSugerido: Double {
        ProductPricingHelpers.precioSugerido(base: baseSinIVAConMargen, iva: ivaMonto)
    }
    private var precioFinalEditable: Double {
        Double(precioFinalString.replacingOccurrences(of: ",", with: ".")) ?? precioSugerido
    }
    private var gastoAdminMonto: Double {
        ProductPricingHelpers.gastoAdministrativo(base: baseSinIVAConMargen, porcentajeAdmin: pAdmin)
    }
    private var utilidadAntesDeGastos: Double {
        ProductPricingHelpers.utilidadAntesDeGastos(base: baseSinIVAConMargen, costo: costo)
    }
    private var utilidadDespuesDeGastos: Double {
        ProductPricingHelpers.utilidadDespuesDeGastos(utilidadAntes: utilidadAntesDeGastos, gastoAdmin: gastoAdminMonto)
    }
    private var isrAproxMonto: Double {
        ProductPricingHelpers.isrAproximado(utilidadDespuesGastos: utilidadDespuesDeGastos, tasaISR: pISR)
    }
    private var margenRealPct: Double {
        // Para margen real usamos la utilidad después de gastos, sobre el precio final editable
        ProductPricingHelpers.margenReal(utilidadDespuesGastos: utilidadDespuesDeGastos, precioFinal: max(precioFinalEditable, 0.0001))
    }
    private var variacionVsSugerido: Double {
        ProductPricingHelpers.variacionPrecio(final: precioFinalEditable, sugerido: precioSugerido)
    }
    // NUEVO: Margen de ganancia neto (restando ISR)
    private var margenDeGananciaMonto: Double {
        utilidadDespuesDeGastos - isrAproxMonto
    }
    private var margenDeGananciaPct: Double {
        let denom = max(precioFinalEditable, 0.0001)
        return margenDeGananciaMonto / denom
    }
    
    // Inicializador
    init(mode: ProductModalMode) {
        self.mode = mode
        
        if case .edit(let producto) = mode {
            self.productoAEditar = producto
            _nombre = State(initialValue: producto.nombre)
            _costoString = State(initialValue: String(format: "%.2f", producto.costo))
            _cantidadString = State(initialValue: String(format: "%.2f", producto.cantidad))
            _informacion = State(initialValue: producto.informacion)
            _unidadDeMedida = State(initialValue: producto.unidadDeMedida)
            _categoria = State(initialValue: producto.categoria)
            _proveedor = State(initialValue: producto.proveedor)
            _lote = State(initialValue: producto.lote)
            _fechaCaducidad = State(initialValue: producto.fechaCaducidad)
            _tipoFiscal = State(initialValue: producto.tipoFiscal)
            _porcentajeMargenSugeridoString = State(initialValue: String(format: "%.2f", producto.porcentajeMargenSugerido))
            _porcentajeAdminString = State(initialValue: String(format: "%.2f", producto.porcentajeGastosAdministrativos))
            _isrPorcentajeString = State(initialValue: String(format: "%.2f", producto.isrPorcentajeEstimado))
            _precioFinalString = State(initialValue: String(format: "%.2f", producto.precioVenta))
            _precioModificadoManualmente = State(initialValue: producto.precioModificadoManualmente)
        }
    }
    
    // --- CUERPO DEL MODAL ---
    var body: some View {
        VStack(spacing: 0) {
            // Título
            VStack(spacing: 4) {
                Text(formTitle).font(.title).fontWeight(.bold)
                Text("Completa los datos. Los campos marcados con • son obligatorios.")
                    .font(.footnote).foregroundColor(.gray)
            }
            .padding(.top, 14).padding(.bottom, 8)

            Form {
                // Detalles del Producto
                Section {
                    SectionHeader(title: "Datos del Producto", subtitle: nil)
                    
                    // --- Nombre (ID Único) con Candado ---
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("• Nombre del Producto").font(.caption).foregroundColor(.gray)
                            if productoAEditar != nil {
                                Image(systemName: isNombreUnlocked ? "lock.open.fill" : "lock.fill")
                                    .foregroundColor(isNombreUnlocked ? .green : .red)
                                    .font(.caption)
                            }
                        }
                        HStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                TextField("", text: $nombre)
                                    .disabled(productoAEditar != nil && !isNombreUnlocked)
                                    .padding(8).background(Color("MercedesBackground").opacity(0.9)).cornerRadius(8)
                                if nombre.isEmpty {
                                    Text("ej. Filtro de Aceite X-123")
                                        .foregroundColor(Color.white.opacity(0.35))
                                        .padding(.horizontal, 12).allowsHitTesting(false)
                                }
                            }
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
                            }
                        }
                        .validationHint(isInvalid: nombreInvalido, message: "El nombre debe tener al menos 3 caracteres.")
                        if productoAEditar != nil && !isNombreUnlocked {
                            Text("Campo protegido. Desbloquéalo para editar.")
                                .font(.caption2).foregroundColor(.gray)
                        }
                    }
                    
                    // Categoría y Unidad
                    HStack(spacing: 16) {
                        FormField(title: "Categoría", placeholder: "ej. Aceites, Filtros...", text: $categoria)
                        Picker("• Unidad de Medida", selection: $unidadDeMedida) {
                            ForEach(opcionesUnidad, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Proveedor / Lote / Caducidad
                    HStack(spacing: 16) {
                        FormField(title: "Proveedor", placeholder: "Nombre comercial", text: $proveedor)
                        FormField(title: "Lote", placeholder: "ej. A123-45", text: $lote)
                        DatePicker("Caducidad (opcional)", selection: Binding(
                            get: { fechaCaducidad ?? Date() },
                            set: { fechaCaducidad = $0 }
                        ), displayedComponents: .date)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        Toggle("Sin fecha", isOn: Binding(
                            get: { fechaCaducidad == nil },
                            set: { noDate in fechaCaducidad = noDate ? nil : Date() }
                        ))
                        .toggleStyle(.switch)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    }
                    
                    // Costo y Cantidad
                    HStack(spacing: 16) {
                        FormField(title: "• Costo de compra", placeholder: "$ 0.00", text: $costoString)
                            .validationHint(isInvalid: costoInvalido, message: "Debe ser un número.")
                        FormField(title: "• Cantidad", placeholder: "ej. 10.5", text: $cantidadString)
                            .validationHint(isInvalid: cantidadInvalida, message: "Debe ser un número.")
                    }
                    
                    // Tipo fiscal
                    Picker("• Tipo fiscal del producto", selection: $tipoFiscal) {
                        ForEach(TipoFiscalProducto.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    FormField(title: "Información (opcional)", placeholder: "ej. Para motores V6 2.5L", text: $informacion)
                }
                
                // Configuraciones financieras
                Section {
                    SectionHeader(title: "Configuraciones financieras", subtitle: "Porcentajes entre 0 y 100")
                    HStack(spacing: 16) {
                        FormField(title: "• % Margen sugerido", placeholder: "ej. 30", text: $porcentajeMargenSugeridoString)
                            .validationHint(isInvalid: pMargenInvalido, message: "0 a 100.")
                        FormField(title: "• % Gastos administrativos", placeholder: "ej. 10", text: $porcentajeAdminString)
                            .validationHint(isInvalid: pAdminInvalido, message: "0 a 100.")
                        FormField(title: "% ISR (aprox.)", placeholder: "ej. 10", text: $isrPorcentajeString)
                            .validationHint(isInvalid: pISRInvalido, message: "0 a 100.")
                    }
                }
                
                // Cálculos automáticos y Precio
                Section {
                    SectionHeader(title: "Cálculos automáticos", subtitle: "Solo lectura y precio final editable")
                    
                    // Costo y precio
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Costo y precio").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 8) {
                            roField("Costo de compra", costo)
                            roField("Base sin IVA (con margen)", baseSinIVAConMargen)
                            roField("IVA (\(Int(ivaTasa * 100))%)", ivaMonto)
                            roField("Precio sugerido", precioSugerido)
                        }
                    }
                    
                    // Administración y fiscal
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Administración y fiscal").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 8) {
                            roField("% administrativo", pAdmin)
                            roField("Gasto administrativo (monto)", gastoAdminMonto)
                            roField("Utilidad antes de gastos", utilidadAntesDeGastos)
                            roField("Utilidad después de gastos", utilidadDespuesDeGastos)
                            roField("ISR aproximado", isrAproxMonto)
                            roField("Margen de ganancia (monto)", margenDeGananciaMonto)
                            roField("Margen de ganancia (%)", margenDeGananciaPct * 100)
                        }
                        HStack {
                            Text("El cálculo de ISR es aproximado. Verifique las tablas oficiales del SAT.")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Spacer()
                            Link("SAT (Portal oficial)", destination: URL(string: "https://www.sat.gob.mx/portal/public/home")!)
                                .font(.caption)
                                .foregroundColor(Color("MercedesPetrolGreen"))
                        }
                    }
                    
                    // Utilidad y precio final
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Precio final y variaciones").font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 8) {
                            roField("Variación vs sugerido", variacionVsSugerido)
                        }
                        HStack(spacing: 12) {
                            FormField(title: "Precio final al cliente (editable)", placeholder: "ej. 301.60", text: $precioFinalString)
                                .onChange(of: precioFinalString) { _, new in
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
                // En modo add, inicializa precio final con el sugerido
                if productoAEditar == nil {
                    precioFinalString = String(format: "%.2f", precioSugerido)
                }
            }
            .onChange(of: costoString) { _, _ in syncFinalIfNotManual() }
            .onChange(of: tipoFiscal) { _, _ in syncFinalIfNotManual() }
            .onChange(of: porcentajeMargenSugeridoString) { _, _ in syncFinalIfNotManual() }
            .onChange(of: porcentajeAdminString) { _, _ in /* no cambia el precio sugerido (afecta utilidad e ISR) */ }
            .onChange(of: isrPorcentajeString) { _, _ in /* solo ISR */ }
            
            // Mensaje de Error
            if let errorMsg {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.vertical, 6)
            }
            
            // --- Barra de Botones ---
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding(.vertical, 6).padding(.horizontal, 8).foregroundColor(.gray)
                
                if case .edit = mode {
                    Button("Eliminar", role: .destructive) {
                        authReason = .deleteProduct
                        showingAuthModal = true
                    }
                    .buttonStyle(.plain).padding(.vertical, 6).padding(.horizontal, 8).foregroundColor(.red)
                }
                Spacer()
                Button(productoAEditar == nil ? "Añadir Producto" : "Guardar Cambios") {
                    guardarCambios()
                }
                .buttonStyle(.plain).padding(.vertical, 8).padding(.horizontal, 12)
                .foregroundColor(Color("MercedesPetrolGreen")).cornerRadius(8)
                .disabled(nombreInvalido || costoInvalido || cantidadInvalida || pMargenInvalido || pAdminInvalido || pISRInvalido)
                .opacity((nombreInvalido || costoInvalido || cantidadInvalida || pMargenInvalido || pAdminInvalido || pISRInvalido) ? 0.6 : 1.0)
            }
            .padding(.horizontal).padding(.bottom, 8)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 760, minHeight: 580, maxHeight: 820)
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
            VStack(spacing: 16) {
                Text("Autorización Requerida").font(.title).fontWeight(.bold)
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
    
    // --- Lógica del Formulario (Validaciones) ---
    func guardarCambios() {
        errorMsg = nil
        let trimmedNombre = nombre.trimmingCharacters(in: .whitespaces)
        
        guard trimmedNombre.count >= 3 else {
            errorMsg = "El nombre del producto debe tener al menos 3 caracteres."
            return
        }
        guard let costo = Double(costoString.replacingOccurrences(of: ",", with: ".")), costo >= 0 else {
            errorMsg = "El Costo debe ser un número válido."
            return
        }
        guard let cantidad = Double(cantidadString.replacingOccurrences(of: ",", with: ".")), cantidad >= 0 else {
            errorMsg = "La Cantidad debe ser un número válido."
            return
        }
        guard let pMargen = Double(porcentajeMargenSugeridoString.replacingOccurrences(of: ",", with: ".")), (0...100).contains(pMargen) else {
            errorMsg = "% Margen inválido."
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
            producto.nombre = trimmedNombre
            producto.costo = costo
            producto.cantidad = cantidad
            producto.informacion = informacion
            producto.unidadDeMedida = unidadDeMedida
            producto.categoria = categoria
            producto.proveedor = proveedor
            producto.lote = lote
            producto.fechaCaducidad = fechaCaducidad
            producto.tipoFiscal = tipoFiscal
            producto.porcentajeMargenSugerido = pMargen
            producto.porcentajeGastosAdministrativos = pAdmin
            producto.isrPorcentajeEstimado = pISR
            producto.precioVenta = finalEditable
            producto.precioModificadoManualmente = precioModificadoManualmente
        } else {
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
                costoIncluyeIVA: true, // ya no lo usamos en el nuevo flujo, pero conservamos compatibilidad
                porcentajeMargenSugerido: pMargen,
                porcentajeGastosAdministrativos: pAdmin,
                tipoFiscal: tipoFiscal,
                isrPorcentajeEstimado: pISR,
                precioModificadoManualmente: precioModificadoManualmente
            )
            modelContext.insert(nuevoProducto)
        }
        dismiss()
    }
    
    func eliminarProducto(_ producto: Producto) {
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
            if case .edit(let producto) = mode {
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
