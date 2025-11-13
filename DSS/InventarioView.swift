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

// --- VISTA PRINCIPAL (Sin cambios) ---
struct InventarioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Producto.nombre) private var productos: [Producto]
    
    @State private var modalMode: ProductModalMode?
    @State private var searchQuery = ""
    
    var filteredProductos: [Producto] {
        if searchQuery.isEmpty {
            return productos
        } else {
            let query = searchQuery.lowercased()
            return productos.filter { producto in
                producto.nombre.lowercased().contains(query) ||
                producto.unidadDeMedida.lowercased().contains(query)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Gestión de Inventario")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Button { modalMode = .add }
                label: {
                    Label("Añadir Producto", systemImage: "plus")
                        .font(.headline).padding(.vertical, 10).padding(.horizontal)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)
            Text("Registra y modifica tus productos.")
                .font(.title3).foregroundColor(.gray).padding(.bottom, 20)
            
            TextField("Buscar por Nombre o Unidad de Medida...", text: $searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                .padding(.bottom, 20)
            
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(filteredProductos) { producto in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(producto.nombre)
                                .font(.title2).fontWeight(.semibold)
                            
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Costo: $\(producto.costo, specifier: "%.2f")")
                                    Text("Cantidad: \(producto.cantidad, specifier: "%.2f") \(producto.unidadDeMedida)(s)")
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Precio: $\(producto.precioVenta, specifier: "%.2f")")
                                    Text(String(format: "Margen de ganancia: %.0f%%", producto.margen))
                                        .font(.headline)
                                        .foregroundColor(producto.margen > 50 ? .green : (producto.margen > 20 ? .yellow : .red))
                                }
                            }
                            .font(.body)
                            .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("MercedesCard"))
                        .cornerRadius(10)
                        .onTapGesture { modalMode = .edit(producto) }
                    }
                }
            }
            Spacer()
        }
        .padding(30)
        .sheet(item: $modalMode) { mode in
            ProductFormView(mode: mode)
                .environment(\.modelContext, modelContext)
        }
    }
}


// --- VISTA DEL FORMULARIO (¡REDISEÑADA!) ---
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
        Double(costoString) == nil
    }
    private var precioInvalido: Bool {
        Double(precioVentaString) == nil
    }
    private var cantidadInvalida: Bool {
        Double(cantidadString) == nil
    }
    
    // Inicializador
    init(mode: ProductModalMode) {
        self.mode = mode
        
        if case .edit(let producto) = mode {
            self.productoAEditar = producto
            _nombre = State(initialValue: producto.nombre)
            _costoString = State(initialValue: "\(producto.costo)")
            _precioVentaString = State(initialValue: "\(producto.precioVenta)")
            _cantidadString = State(initialValue: "\(producto.cantidad)")
            _informacion = State(initialValue: producto.informacion)
            _unidadDeMedida = State(initialValue: producto.unidadDeMedida)
        }
    }
    
    // --- CUERPO DEL MODAL (¡ACTUALIZADO!) ---
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
                    }
                    
                    // Costo y Precio
                    HStack(spacing: 16) {
                        FormField(title: "• Costo", placeholder: "$ 0.00", text: $costoString)
                            .validationHint(isInvalid: costoInvalido, message: "Debe ser un número.")
                        FormField(title: "• Precio de Venta", placeholder: "$ 0.00", text: $precioVentaString)
                            .validationHint(isInvalid: precioInvalido, message: "Debe ser un número.")
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
        .frame(minWidth: 700, minHeight: 480, maxHeight: 600) // Más ancho y corto
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
        guard let costo = Double(costoString), costo >= 0 else {
            errorMsg = "El Costo debe ser un número válido."
            return
        }
        guard let precioVenta = Double(precioVentaString), precioVenta >= 0 else {
            errorMsg = "El Precio de Venta debe ser un número válido."
            return
        }
        guard let cantidad = Double(cantidadString), cantidad >= 0 else {
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


// --- Helpers de UI (¡ACTUALIZADOS!) ---
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
