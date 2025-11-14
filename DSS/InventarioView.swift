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
                producto.informacion.lowercased().contains(query)
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
                TextField("Buscar por Nombre, Unidad o Información...", text: $searchQuery)
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
                    Text(producto.nombre)
                        .font(.title2).fontWeight(.semibold)
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
                    }
                    Text("Cantidad: \(producto.cantidad, specifier: "%.2f") \(producto.unidadDeMedida)(s)")
                        .font(.body).foregroundColor(.gray)
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
    @State private var costoString = ""
    @State private var precioVentaString = ""
    @State private var cantidadString = ""
    @State private var informacion = ""
    @State private var unidadDeMedida = "Pieza"
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
    private var precioInvalido: Bool {
        Double(precioVentaString.replacingOccurrences(of: ",", with: ".")) == nil
    }
    private var cantidadInvalida: Bool {
        Double(cantidadString.replacingOccurrences(of: ",", with: ".")) == nil
    }
    
    // Margen en vivo
    private var margenPreview: Double {
        guard
            let c = Double(costoString.replacingOccurrences(of: ",", with: ".")),
            let p = Double(precioVentaString.replacingOccurrences(of: ",", with: ".")),
            p > 0
        else { return 0 }
        return (1 - (c / p)) * 100
    }
    private var margenColor: Color {
        margenPreview > 50 ? .green : (margenPreview > 20 ? .yellow : .red)
    }
    
    // Inicializador
    init(mode: ProductModalMode) {
        self.mode = mode
        
        if case .edit(let producto) = mode {
            self.productoAEditar = producto
            _nombre = State(initialValue: producto.nombre)
            _costoString = State(initialValue: String(format: "%.2f", producto.costo))
            _precioVentaString = State(initialValue: String(format: "%.2f", producto.precioVenta))
            _cantidadString = State(initialValue: String(format: "%.2f", producto.cantidad))
            _informacion = State(initialValue: producto.informacion)
            _unidadDeMedida = State(initialValue: producto.unidadDeMedida)
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
                    SectionHeader(title: "Detalles del Producto", subtitle: nil)
                    
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
                    
                    // Costo y Precio
                    HStack(spacing: 16) {
                        FormField(title: "• Costo", placeholder: "$ 0.00", text: $costoString)
                            .validationHint(isInvalid: costoInvalido, message: "Debe ser un número.")
                        FormField(title: "• Precio de Venta", placeholder: "$ 0.00", text: $precioVentaString)
                            .validationHint(isInvalid: precioInvalido, message: "Debe ser un número.")
                    }
                    
                    // Margen en vivo
                    HStack(spacing: 8) {
                        Text("Margen estimado:")
                            .font(.caption).foregroundColor(.gray)
                        Text(String(format: "%.0f%%", margenPreview))
                            .font(.headline).foregroundColor(margenColor)
                        Circle().fill(margenColor).frame(width: 8, height: 8)
                    }
                }
                
                // Inventario e Info
                Section {
                    SectionHeader(title: "Inventario e Información", subtitle: nil)
                    HStack(spacing: 16) {
                        FormField(title: "• Cantidad", placeholder: "ej. 10.5", text: $cantidadString)
                            .validationHint(isInvalid: cantidadInvalida, message: "Debe ser un número.")
                        
                        Picker("Unidad de Medida", selection: $unidadDeMedida) {
                            ForEach(opcionesUnidad, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                    FormField(title: "Información (Opcional)", placeholder: "ej. Para motores V6 2.5L", text: $informacion)
                }
            }
            .textFieldStyle(PlainTextFieldStyle())
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            
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
                .disabled(nombreInvalido || costoInvalido || precioInvalido || cantidadInvalida)
                .opacity((nombreInvalido || costoInvalido || precioInvalido || cantidadInvalida) ? 0.6 : 1.0)
            }
            .padding(.horizontal).padding(.bottom, 8)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 700, minHeight: 520, maxHeight: 650)
        .cornerRadius(15)
        .sheet(isPresented: $showingAuthModal) {
            authModalView()
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
        guard let precioVenta = Double(precioVentaString.replacingOccurrences(of: ",", with: ".")), precioVenta >= 0 else {
            errorMsg = "El Precio de Venta debe ser un número válido."
            return
        }
        guard let cantidad = Double(cantidadString.replacingOccurrences(of: ",", with: ".")), cantidad >= 0 else {
            errorMsg = "La Cantidad debe ser un número válido."
            return
        }
        
        if let producto = productoAEditar {
            producto.nombre = trimmedNombre
            producto.costo = costo
            producto.precioVenta = precioVenta
            producto.cantidad = cantidad
            producto.informacion = informacion
            producto.unidadDeMedida = unidadDeMedida
        } else {
            let nuevoProducto = Producto(
                nombre: trimmedNombre,
                costo: costo,
                precioVenta: precioVenta,
                cantidad: cantidad,
                unidadDeMedida: unidadDeMedida,
                informacion: informacion
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
