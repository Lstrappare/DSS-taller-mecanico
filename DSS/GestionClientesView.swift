import SwiftUI
import SwiftData
import LocalAuthentication // Necesario para seguridad

// --- Enums para controlar los Modales ---
fileprivate enum ModalMode: Identifiable {
    case addClienteConVehiculo
    case editCliente(Cliente)
    case addVehiculo(Cliente)
    case editVehiculo(Vehiculo)
    
    var id: String {
        switch self {
        case .addClienteConVehiculo: return "addClienteConVehiculo"
        case .editCliente(let cliente): return cliente.nombre
        case .addVehiculo(let cliente): return "addVehiculoA-\(cliente.nombre)"
        case .editVehiculo(let vehiculo): return vehiculo.placas
        }
    }
}

// Ordenamiento (alineado a InventarioView/PersonalView)
fileprivate enum SortOption: String, CaseIterable, Identifiable {
    case nombre = "Nombre"
    case vehiculos = "Vehículos"
    var id: String { rawValue }
}

// Helper de validación de nombre de cliente
fileprivate func isNombreClienteValido(_ raw: String) -> Bool {
    // Reglas:
    // - Al menos 3 palabras
    // - Cada palabra solo letras (incluye acentos y ñ), min 3 letras
    // - No se aceptan números
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let words = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    guard words.count >= 3 else { return false }
    // Regex: solo letras unicode (Letter) mínimo 3
    // Usamos \p{L} para cualquier letra en Unicode
    let pattern = #"^\p{L}{3,}$"#
    let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
    for w in words {
        if !predicate.evaluate(with: w) { return false }
    }
    // Además, que el nombre completo no contenga dígitos (redundante pero explícito)
    if raw.rangeOfCharacter(from: .decimalDigits) != nil { return false }
    return true
}

// --- VISTA PRINCIPAL (alineada a InventarioView) ---
struct GestionClientesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cliente.nombre) private var clientes: [Cliente]
    
    @State private var modalMode: ModalMode?
    @State private var searchQuery = ""
    @State private var sortOption: SortOption = .nombre
    @State private var sortAscending: Bool = true
    
    var filteredClientes: [Cliente] {
        var base = clientes
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchQuery.lowercased()
            base = base.filter { cliente in
                let nombreMatch = cliente.nombre.lowercased().contains(query)
                let telefonoMatch = cliente.telefono.lowercased().contains(query)
                let emailMatch = cliente.email.lowercased().contains(query)
                let vehiculosMatch = cliente.vehiculos.contains { v in
                    v.placas.lowercased().contains(query) ||
                    v.marca.lowercased().contains(query) ||
                    v.modelo.lowercased().contains(query) ||
                    String(v.anio).contains(query)
                }
                return nombreMatch || telefonoMatch || emailMatch || vehiculosMatch
            }
        }
        // Ordenamiento
        base.sort { a, b in
            switch sortOption {
            case .nombre:
                let cmp = a.nombre.localizedCaseInsensitiveCompare(b.nombre)
                return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
            case .vehiculos:
                return sortAscending ? (a.vehiculos.count < b.vehiculos.count) : (a.vehiculos.count > b.vehiculos.count)
            }
        }
        return base
    }
    
    private var totalVehiculos: Int {
        clientes.reduce(0) { $0 + $1.vehiculos.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header compacto
            header
            
            // Filtros y búsqueda (compactos)
            filtrosView
            
            // Lista
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Contador de resultados
                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .foregroundColor(Color("MercedesPetrolGreen"))
                        Text("\(filteredClientes.count) resultado\(filteredClientes.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    
                    if filteredClientes.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    } else {
                        ForEach(filteredClientes) { cliente in
                            ClienteCard(
                                cliente: cliente,
                                onEditCliente: { modalMode = .editCliente(cliente) },
                                onAddVehiculo: { modalMode = .addVehiculo(cliente) },
                                onEditVehiculo: { vehiculo in modalMode = .editVehiculo(vehiculo) }
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
            // Pasa el environment a TODOS los modales
            switch mode {
            case .addClienteConVehiculo:
                ClienteConVehiculoFormView(modalMode: $modalMode)
                    .environment(\.modelContext, modelContext)
            case .editCliente(let cliente):
                ClienteFormView(cliente: cliente, modalMode: $modalMode)
                    .environment(\.modelContext, modelContext)
            case .addVehiculo(let cliente):
                VehiculoFormView(cliente: cliente)
                    .environment(\.modelContext, modelContext)
            case .editVehiculo(let vehiculo):
                VehiculoFormView(vehiculo: vehiculo)
                    .environment(\.modelContext, modelContext)
            }
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
                .frame(height: 110)
            
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gestión de Clientes")
                        .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    HStack(spacing: 10) {
                        Label("\(clientes.count) cliente\(clientes.count == 1 ? "" : "s")", systemImage: "person.2.fill")
                            .font(.footnote).foregroundColor(.gray)
                        Label("\(totalVehiculos) vehículo\(totalVehiculos == 1 ? "" : "s")", systemImage: "car.2.fill")
                            .font(.footnote).foregroundColor(.gray)
                    }
                }
                Spacer()
                Button {
                    modalMode = .addClienteConVehiculo
                } label: {
                    Label("Añadir", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("Registrar nuevo cliente")
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
                    TextField("Buscar por Nombre, Teléfono, Email, Placas o Modelo...", text: $searchQuery)
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
                
                // Filtros activos + limpiar (solo si aplica)
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
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(Color("MercedesPetrolGreen"))
            Text(searchQuery.isEmpty ? "No hay clientes registrados aún." :
                 "No se encontraron clientes para “\(searchQuery)”.")
                .font(.subheadline)
                .foregroundColor(.gray)
            if searchQuery.isEmpty {
                Text("Añade tu primer cliente para empezar a registrar vehículos.")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
}

// --- Tarjeta de Cliente (alineada a ProductoCard/PersonalCard) ---
fileprivate struct ClienteCard: View {
    let cliente: Cliente
    var onEditCliente: () -> Void
    var onAddVehiculo: () -> Void
    var onEditVehiculo: (Vehiculo) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header con nombre y acción editar
            HStack(alignment: .top) {
                Text(cliente.nombre)
                    .font(.headline).fontWeight(.semibold)
                Spacer()
                Button {
                    onEditCliente()
                } label: {
                    Label("Editar", systemImage: "pencil")
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color("MercedesBackground"))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
            }
            
            // Contacto (Estilo PersonalView)
            HStack(spacing: 12) {
                if cliente.email.isEmpty {
                    Label("Email: N/A", systemImage: "envelope.fill")
                        .font(.caption2)
                        .foregroundColor(.gray)
                } else {
                    Link(destination: URL(string: "mailto:\(cliente.email)")!) {
                        Label(cliente.email, systemImage: "envelope.fill")
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                }
                
                if !cliente.telefono.isEmpty {
                    Link(destination: URL(string: "tel:\(cliente.telefono)")!) {
                        Label(cliente.telefono, systemImage: "phone.fill")
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                } else {
                    Label("Tel: N/A", systemImage: "phone.fill")
                        .font(.caption2).foregroundColor(.gray)
                }
            }
            
            Divider().opacity(0.5)
            
            // Lista compacta de vehículos
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Vehículos registrados").font(.headline)
                    Spacer()
                    Text("\(cliente.vehiculos.count)")
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color("MercedesBackground"))
                        .cornerRadius(6)
                        .foregroundColor(.white)
                }
                
                if cliente.vehiculos.isEmpty {
                    Text("No hay vehículos registrados para este cliente.")
                        .font(.caption).foregroundColor(.gray)
                        .padding(.top, 2)
                } else {
                    ForEach(cliente.vehiculos) { vehiculo in
                        HStack(spacing: 10) {
                            Text("[\(vehiculo.placas)]")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)
                            Text("\(vehiculo.marca) \(vehiculo.modelo) (\(String(vehiculo.anio)))")
                                .font(.subheadline)
                            Spacer()
                            Button {
                                onEditVehiculo(vehiculo)
                            } label: {
                                Label("Editar Auto", systemImage: "pencil.circle")
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(Color("MercedesBackground"))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.white)
                        }
                        .padding(.vertical, 4)
                        .background(
                            ZStack {
                                Color("MercedesBackground").opacity(0.35)
                            }
                        )
                        .cornerRadius(8)
                    }
                }
            }
            
            // CTA añadir vehículo
            HStack {
                Button {
                    onAddVehiculo()
                } label: {
                    Label("+ Añadir Vehículo", systemImage: "car.badge.plus")
                        .font(.subheadline)
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(Color("MercedesCard"))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .foregroundColor(Color("MercedesPetrolGreen"))
                Spacer()
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
}


// --- 1. FORMULARIO COMBINADO (ADD CLIENTE + VEHÍCULO) (alineado a ProductFormView) ---
fileprivate struct ClienteConVehiculoFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Binding var modalMode: ModalMode?
    @Query private var allClientes: [Cliente]

    // States
    @State private var nombre = ""
    @State private var telefono = ""
    @State private var email = ""
    @State private var placas = ""
    @State private var marca = ""
    @State private var modelo = ""
    @State private var anioString = ""
    @State private var errorMsg: String?
    
    // Bools de Validación
    private var clienteExistente: Cliente? {
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if nombreLimpio.isEmpty { return nil }
        return allClientes.first { $0.nombre.lowercased() == nombreLimpio }
    }
    
    private var nombreDuplicado: Bool {
        clienteExistente != nil
    }
    
    private var nombreInvalido: Bool {
        // Aplica nueva regla y además revisa duplicado
        return !isNombreClienteValido(nombre) || nombreDuplicado
    }
    private var telefonoInvalido: Bool {
        let t = telefono.trimmingCharacters(in: .whitespaces)
        return t.isEmpty || t.count != 10
    }
    private var emailInvalido: Bool {
        let e = email.trimmingCharacters(in: .whitespaces)
        if e.isEmpty { return false } // Opcional
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return !NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: e)
    }
    private var clienteConMismoTelefono: Cliente? {
        let telLimpio = telefono.trimmingCharacters(in: .whitespaces)
        if telLimpio.isEmpty { return nil }
        return allClientes.first { $0.telefono == telLimpio }
    }
    
    private var placasInvalidas: Bool {
        placas.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var anioInvalido: Bool {
        guard let anio = Int(anioString) else { return true }
        let currentYear = Calendar.current.component(.year, from: Date())
        return anio < 1900 || anio > (currentYear + 1)
    }
    private var marcaInvalida: Bool {
        let m = marca.trimmingCharacters(in: .whitespaces)
        return m.count < 2
    }
    private var modeloInvalido: Bool {
        let m = modelo.trimmingCharacters(in: .whitespaces)
        return m.count < 2
    }

    var body: some View {
        VStack(spacing: 0) {
            // Título y guía
            VStack(spacing: 4) {
                Text("Añadir Cliente y Vehículo").font(.title).fontWeight(.bold)
                Text("Completa los datos. Los campos marcados con • son obligatorios.")
                    .font(.footnote).foregroundColor(.gray)
            }
            .padding(16)
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Sección 1: Datos del Cliente
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "1. Datos del Cliente", subtitle: "Información personal")
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("• Nombre Completo").font(.caption2).foregroundColor(.gray)
                            }
                            HStack(spacing: 6) {
                                TextField("ej. José Cisneros Torres", text: $nombre)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Color("MercedesBackground"))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .onChange(of: nombre) { _, newValue in
                                        if newValue.count > 80 {
                                            nombre = String(newValue.prefix(80))
                                        }
                                    }
                                
                                // Contador manual
                                Text("\(nombre.count)/80")
                                    .font(.caption2)
                                    .foregroundColor(nombre.count >= 80 ? .red : .gray)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .validationHint(
                                isInvalid: nombreInvalido,
                                message: nombreDuplicado
                                    ? "Este nombre ya está en uso."
                                    : "Nombre inválido. Debe tener al menos 3 palabras, cada una con 3 letras y sin números."
                            )
                            
                            // Botón para editar el existente si hay duplicado
                            if let existente = clienteExistente {
                                Button {
                                    // Cambiar a modo edición del cliente existente
                                    modalMode = .editCliente(existente)
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
                            FormField(title: "• Teléfono", placeholder: "10 dígitos", text: $telefono, characterLimit: 10)
                                .onChange(of: telefono) { _, newValue in
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        telefono = filtered
                                    }
                                    if telefono.count > 10 {
                                        telefono = String(telefono.prefix(10))
                                    }
                                }
                                .validationHint(isInvalid: telefonoInvalido, message: telefono.isEmpty ? "Requerido." : "Debe tener 10 dígitos.")
                                .validationHint(isInvalid: !telefonoInvalido && clienteConMismoTelefono != nil, 
                                                message: "Registrado en: \(clienteConMismoTelefono?.nombre ?? "")",
                                                color: .yellow)
                            FormField(title: "Email (Opcional)", placeholder: "ej. jose@cliente.com", text: $email, characterLimit: 60)
                                .onChange(of: email) { _, newValue in
                                    if newValue.count > 60 {
                                        email = String(newValue.prefix(60))
                                    }
                                }
                                .validationHint(isInvalid: emailInvalido, message: "Formato inválido.")
                        }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Sección 2: Datos del Vehículo
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "2. Datos del Primer Vehículo", subtitle: "Información del auto")
                        
                        HStack(spacing: 16) {
                            FormField(title: "• Placas", placeholder: "ej. ABC-123", text: $placas, characterLimit: 7)
                                .onChange(of: placas) { _, newValue in
                                    let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                                    if filtered != newValue {
                                        placas = filtered
                                    }
                                    if placas.count > 7 {
                                        placas = String(placas.prefix(7))
                                    }
                                }
                                .validationHint(isInvalid: placasInvalidas, message: "Requerido.")
                            FormField(title: "• Año", placeholder: "ej. 2020", text: $anioString, characterLimit: 4)
                                .onChange(of: anioString) { _, newValue in
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        anioString = filtered
                                    }
                                    if anioString.count > 4 {
                                        anioString = String(anioString.prefix(4))
                                    }
                                }
                                .validationHint(isInvalid: anioInvalido, message: "Año inválido (1900-\(Calendar.current.component(.year, from: Date()) + 1)).")
                        }
                        HStack(spacing: 16) {
                            FormField(title: "• Marca", placeholder: "ej. Nissan", text: $marca, characterLimit: 30)
                                .onChange(of: marca) { _, newValue in
                                    if newValue.count > 30 { marca = String(newValue.prefix(30)) }
                                }
                                .validationHint(isInvalid: marcaInvalida, message: "Mínimo 2 caracteres.")
                            FormField(title: "• Modelo", placeholder: "ej. Versa", text: $modelo, characterLimit: 40)
                                .onChange(of: modelo) { _, newValue in
                                    if newValue.count > 40 { modelo = String(newValue.prefix(40)) }
                                }
                                .validationHint(isInvalid: modeloInvalido, message: "Mínimo 2 caracteres.")
                        }
                    }
                }
                .padding(24)
            }
            
            // Mensaje de Error
            if let errorMsg {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.vertical, 6)
            }

            // Botones
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
                    Text("Guardar y Añadir")
                        .fontWeight(.semibold)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .shadow(color: Color("MercedesPetrolGreen").opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(nombreInvalido || telefonoInvalido || placasInvalidas || anioInvalido || emailInvalido || marcaInvalida || modeloInvalido)
                .opacity((nombreInvalido || telefonoInvalido || placasInvalidas || anioInvalido || emailInvalido || marcaInvalida || modeloInvalido) ? 0.6 : 1.0)
            }
            .padding(20)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 760, minHeight: 550, maxHeight: 600)
        .cornerRadius(15)
    }
    
    func guardarCambios() {
        errorMsg = nil
        let nombreTrimmed = nombre.trimmingCharacters(in: .whitespaces)
        let telefonoTrimmed = telefono.trimmingCharacters(in: .whitespaces)
        let placasTrimmed = placas.trimmingCharacters(in: .whitespaces)
        let marcaTrimmed = marca.trimmingCharacters(in: .whitespaces)
        let modeloTrimmed = modelo.trimmingCharacters(in: .whitespaces)

        // Validación nueva de nombre
        guard isNombreClienteValido(nombreTrimmed) else {
            errorMsg = "Nombre inválido. Debe tener al menos 3 palabras, cada una con 3 letras y sin números."
            return
        }
        if emailInvalido {
            errorMsg = "El formato del Email es inválido."
            return
        }
        guard !telefonoTrimmed.isEmpty, telefonoTrimmed.count == 10 else {
            errorMsg = "El Teléfono debe tener 10 dígitos."
            return
        }
        guard !placasTrimmed.isEmpty else {
            errorMsg = "Las Placas no pueden estar vacías."
            return
        }
        guard marcaTrimmed.count >= 2, modeloTrimmed.count >= 2 else {
            errorMsg = "La Marca y el Modelo deben tener al menos 2 caracteres."
            return
        }
        guard let anio = Int(anioString) else {
            errorMsg = "El Año debe ser un número."
            return
        }
        
        let nuevoCliente = Cliente(nombre: nombreTrimmed, telefono: telefonoTrimmed, email: email.trimmingCharacters(in: .whitespaces))
        let nuevoVehiculo = Vehiculo(placas: placasTrimmed, marca: marcaTrimined(marcaTrimmed), modelo: modeloTrimmed, anio: anio)
        
        nuevoVehiculo.cliente = nuevoCliente
        nuevoCliente.vehiculos.append(nuevoVehiculo)
        
        modelContext.insert(nuevoCliente)
        dismiss()
    }
    
    private func marcaTrimined(_ s: String) -> String { s } // helper placeholder si deseas normalizar marca
}


// --- 2. FORMULARIO DE CLIENTE (SOLO EDITAR) (alineado a ProductFormView) ---
fileprivate struct ClienteFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true

    @Bindable var cliente: Cliente
    @Binding var modalMode: ModalMode?
    @Query private var allClientes: [Cliente]

    // States para Seguridad y Errores
    @State private var isTelefonoUnlocked = false
    @State private var isNombreUnlocked = false // Nuevo lock para nombre
    @State private var showingAuthModal = false
    @State private var authError = ""
    @State private var passwordAttempt = ""
    @State private var errorMsg: String?
    
    private enum AuthReason {
        case unlockTelefono, unlockNombre, deleteCliente
    }
    @State private var authReason: AuthReason = .unlockTelefono
    
    private var clienteExistenteConMismoNombre: Cliente? {
        let nombreLimpio = cliente.nombre.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if nombreLimpio.isEmpty { return nil }
        // Buscar otro cliente con el mismo nombre (excluyendo al actual por ID persistente o referencia)
        return allClientes.first {
            $0.nombre.lowercased() == nombreLimpio && $0.persistentModelID != cliente.persistentModelID
        }
    }
    
    private var nombreDuplicado: Bool {
        clienteExistenteConMismoNombre != nil
    }
    
    private var nombreInvalido: Bool {
        // Nueva regla + duplicado
        return !isNombreClienteValido(cliente.nombre) || nombreDuplicado
    }
    
    private var clienteConMismoTelefono: Cliente? {
        let telLimpio = cliente.telefono.trimmingCharacters(in: .whitespaces)
        if telLimpio.isEmpty { return nil }
        return allClientes.first { 
            $0.telefono == telLimpio && $0.persistentModelID != cliente.persistentModelID 
        }
    }
    
    private var emailInvalido: Bool {
        let e = cliente.email.trimmingCharacters(in: .whitespaces)
        if e.isEmpty { return false }
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return !NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: e)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Título y guía
            VStack(spacing: 4) {
                Text("Editar Cliente").font(.title).fontWeight(.bold)
                Text("Autoriza para editar el teléfono si es necesario.")
                    .font(.footnote).foregroundColor(.gray)
            }
            .padding(16)
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Sección 1: Datos del Cliente
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Datos del Cliente", subtitle: "Información personal")
                        
                        // Nombre con candado en edición y validación
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("• Nombre Completo (ID Único)").font(.caption2).foregroundColor(.gray)
                                Image(systemName: isNombreUnlocked ? "lock.open.fill" : "lock.fill")
                                    .foregroundColor(isNombreUnlocked ? .green : .red)
                                    .font(.caption2)
                            }
                            HStack(spacing: 6) {
                                TextField("", text: $cliente.nombre)
                                    .disabled(!isNombreUnlocked)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Color("MercedesBackground"))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .onChange(of: cliente.nombre) { _, newValue in
                                        if newValue.count > 80 {
                                            cliente.nombre = String(newValue.prefix(80))
                                        }
                                    }
                                
                                // Contador manual para Nombre
                                Text("\(cliente.nombre.count)/80")
                                    .font(.caption2)
                                    .foregroundColor(cliente.nombre.count >= 80 ? .red : .gray)
                                    .frame(width: 40, alignment: .trailing)
                                
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
                            .validationHint(
                                isInvalid: nombreInvalido,
                                message: nombreDuplicado
                                    ? "Este nombre ya está en uso."
                                    : "Nombre inválido. Debe tener al menos 3 palabras, cada una con 3 letras y sin números."
                            )
                            
                            // Botón para editar el existente si hay duplicado
                            if let existente = clienteExistenteConMismoNombre {
                                Button {
                                    // Cambiar a modo edición del otro cliente
                                    modalMode = .editCliente(existente)
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
                        
                        // Teléfono con Candado
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("• Teléfono").font(.caption2).foregroundColor(.gray)
                                Image(systemName: isTelefonoUnlocked ? "lock.open.fill" : "lock.fill")
                                    .foregroundColor(isTelefonoUnlocked ? .green : .red)
                                    .font(.caption2)
                            }
                            HStack(spacing: 6) {
                                TextField("", text: $cliente.telefono)
                                    .disabled(!isTelefonoUnlocked)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Color("MercedesBackground"))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .onChange(of: cliente.telefono) { _, newValue in
                                        let filtered = newValue.filter { $0.isNumber }
                                        if filtered != newValue {
                                            cliente.telefono = filtered
                                        }
                                        if cliente.telefono.count > 10 {
                                            cliente.telefono = String(cliente.telefono.prefix(10))
                                        }
                                    }
                                    .overlay(alignment: .trailing) {
                                        if cliente.telefono.isEmpty {
                                            Text("10 dígitos")
                                                .font(.caption2)
                                                .foregroundColor(.gray.opacity(0.5))
                                                .padding(.trailing, 8)
                                                .allowsHitTesting(false)
                                        } else {
                                            Text("\(cliente.telefono.count)/10")
                                                .font(.caption2)
                                                .foregroundColor(cliente.telefono.count == 10 ? .green : .gray)
                                                .padding(.trailing, 8)
                                        }
                                    }
                                
                                Button {
                                    if isTelefonoUnlocked { isTelefonoUnlocked = false }
                                    else {
                                        authReason = .unlockTelefono
                                        showingAuthModal = true
                                    }
                                } label: {
                                    Text(isTelefonoUnlocked ? "Bloquear" : "Desbloquear")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(isTelefonoUnlocked ? .green : .red)
                            }
                            .validationHint(isInvalid: cliente.telefono.isEmpty || cliente.telefono.count != 10, 
                                            message: cliente.telefono.isEmpty ? "El teléfono no puede estar vacío." : "Debe tener 10 dígitos.")
                            .validationHint(isInvalid: !cliente.telefono.isEmpty && clienteConMismoTelefono != nil, 
                                            message: "Registrado en: \(clienteConMismoTelefono?.nombre ?? "")",
                                            color: .yellow)
                        }
                        
                        FormField(title: "Email (Opcional)", placeholder: "ej. jose@cliente.com", text: $cliente.email, characterLimit: 60)
                            .onChange(of: cliente.email) { _, newValue in
                                if newValue.count > 60 {
                                    cliente.email = String(newValue.prefix(60))
                                }
                            }
                            .validationHint(isInvalid: emailInvalido, message: "Formato inválido.")
                    }
                    
                    Divider().background(Color.red.opacity(0.3))
                    
                    // Zona de Peligro
                    VStack(spacing: 12) {
                        Text("Esta acción no se puede deshacer y eliminará al cliente y sus vehículos.")
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        
                        Button(role: .destructive) {
                            authReason = .deleteCliente
                            showingAuthModal = true
                        } label: {
                            Label("Eliminar cliente permanentemente", systemImage: "trash.fill")
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
                .padding(24)
            }
            
            // Mensaje de Error
            if let errorMsg {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.vertical, 6)
            }
            
            // Botones
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
                    if isNombreClienteValido(cliente.nombre) {
                        dismiss()
                    } else {
                        errorMsg = "Nombre inválido. Debe tener al menos 3 palabras, cada una con 3 letras y sin números."
                    }
                } label: {
                    Text("Guardar Cambios")
                        .fontWeight(.semibold)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .shadow(color: Color("MercedesPetrolGreen").opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(nombreInvalido || (cliente.telefono.count != 10) || emailInvalido)
                .opacity((nombreInvalido || (cliente.telefono.count != 10) || emailInvalido) ? 0.6 : 1.0)
            }
            .padding(20)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 760, minHeight: 500, maxHeight: 600)
        .cornerRadius(15)
        .sheet(isPresented: $showingAuthModal) {
            authModalView()
        }
    }
    
    // Modal de Autenticación (alineado a ProductFormView)
    @ViewBuilder
    func authModalView() -> some View {
        let prompt: String
        switch authReason {
        case .unlockTelefono: prompt = "Autoriza para editar el Teléfono."
        case .unlockNombre: prompt = "Autoriza para editar el Nombre."
        case .deleteCliente: prompt = "¡Acción irreversible! Autoriza para ELIMINAR a este cliente."
        }
        
        return ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Autorización Requerida").font(.title2).fontWeight(.bold)
                Text(prompt)
                    .font(.callout).foregroundColor(authReason == .deleteCliente ? .red : .gray)
                if isTouchIDEnabled {
                    Button { Task { await authenticateWithTouchID() } } label: {
                        Label("Usar Huella (Touch ID)", systemImage: "touchid")
                            .font(.headline).padding().frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                    }.buttonStyle(.plain)
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
                }.buttonStyle(.plain)
            }
            .padding(22)
        }
        .frame(minWidth: 520, minHeight: 360)
        .preferredColorScheme(.dark)
        .onAppear { authError = ""; passwordAttempt = "" }
    }
    
    // Lógica de Autenticación
    func authenticateWithTouchID() async {
        let context = LAContext()
        let reason: String
        switch authReason {
        case .unlockTelefono: reason = "Autoriza la edición del Teléfono."
        case .unlockNombre: reason = "Autoriza la edición del Nombre."
        case .deleteCliente: reason = "Autoriza la ELIMINACIÓN del cliente."
        }
        
        do {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                if success { await MainActor.run { onAuthSuccess() } }
            }
        } catch { await MainActor.run { authError = "Huella no reconocida." } }
    }
    
    func authenticateWithPassword() {
        if passwordAttempt == userPassword { onAuthSuccess() }
        else { authError = "Contraseña incorrecta."; passwordAttempt = "" }
    }
    
    func onAuthSuccess() {
        switch authReason {
        case .unlockTelefono:
            isTelefonoUnlocked = true
        case .unlockNombre:
            isNombreUnlocked = true
        case .deleteCliente:
            modelContext.delete(cliente)
            dismiss()
        }
        showingAuthModal = false
        authError = ""
        passwordAttempt = ""
    }
}


// --- 3. FORMULARIO DE VEHÍCULO (AÑADIR/EDITAR) (alineado a ProductFormView) ---
fileprivate struct VehiculoFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true

    @State private var vehiculo: Vehiculo
    private var clientePadre: Cliente?
    private var esModoEdicion: Bool
    
    // States para Seguridad y Errores
    @State private var isPlacasUnlocked = false
    @State private var showingAuthModal = false
    @State private var authError = ""
    @State private var passwordAttempt = ""
    @State private var errorMsg: String?
    
    private enum AuthReason {
        case unlockPlacas, deleteVehiculo
    }
    @State private var authReason: AuthReason = .unlockPlacas
    
    var formTitle: String { esModoEdicion ? "Editar Vehículo" : "Añadir Vehículo" }
    
    // Bools de Validación
    private var placasInvalida: Bool {
        vehiculo.placas.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var anioInvalido: Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return vehiculo.anio < 1900 || vehiculo.anio > (currentYear + 1)
    }
    private var marcaInvalida: Bool {
        vehiculo.marca.trimmingCharacters(in: .whitespaces).count < 2
    }
    private var modeloInvalido: Bool {
        vehiculo.modelo.trimmingCharacters(in: .whitespaces).count < 2
    }
    
    init(cliente: Cliente) {
        self.clientePadre = cliente
        self._vehiculo = State(initialValue: Vehiculo(placas: "", marca: "", modelo: "", anio: 2020))
        self.esModoEdicion = false
    }
    
    init(vehiculo: Vehiculo) {
        self._vehiculo = State(initialValue: vehiculo)
        self.clientePadre = vehiculo.cliente
        self.esModoEdicion = true
    }
    
    // Binding para el año (convierte Int a String)
    private var anioString: Binding<String> {
        Binding(
            get: { String(vehiculo.anio) },
            set: { vehiculo.anio = Int($0) ?? 0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Título y guía
            VStack(spacing: 4) {
                Text(formTitle).font(.title).fontWeight(.bold)
                Text("Cliente: \(clientePadre?.nombre ?? "Error")")
                    .font(.footnote).foregroundColor(.gray)
            }
            .padding(16)
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Sección 1: Datos del Vehículo
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Datos del Vehículo", subtitle: "Información del auto")
                        
                        // Placas con Candado (solo si es edición)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("• Placas (ID Único)").font(.caption2).foregroundColor(.gray)
                                if esModoEdicion {
                                    Image(systemName: isPlacasUnlocked ? "lock.open.fill" : "lock.fill")
                                        .foregroundColor(isPlacasUnlocked ? .green : .red)
                                        .font(.caption2)
                                }
                            }
                            HStack(spacing: 6) {
                                TextField("", text: $vehiculo.placas)
                                    .disabled(esModoEdicion && !isPlacasUnlocked)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Color("MercedesBackground"))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .onChange(of: vehiculo.placas) { _, newValue in
                                        let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                                        if filtered != newValue {
                                            vehiculo.placas = filtered
                                        }
                                        if vehiculo.placas.count > 7 {
                                            vehiculo.placas = String(vehiculo.placas.prefix(7))
                                        }
                                    }
                                    .overlay(
                                        HStack {
                                            Spacer()
                                            if vehiculo.placas.isEmpty {
                                                Text("ej. ABC123D")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray.opacity(0.5))
                                                    .padding(.trailing, 8)
                                                    .allowsHitTesting(false)
                                            } else {
                                                Text("\(vehiculo.placas.count)/7")
                                                    .font(.caption2)
                                                    .foregroundColor(vehiculo.placas.count == 7 ? .green : .gray)
                                                    .padding(.trailing, 8)
                                            }
                                        }
                                    )
                                
                                if esModoEdicion {
                                    Button {
                                        if isPlacasUnlocked { isPlacasUnlocked = false }
                                        else {
                                            authReason = .unlockPlacas
                                            showingAuthModal = true
                                        }
                                    } label: {
                                        Text(isPlacasUnlocked ? "Bloquear" : "Desbloquear")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(isPlacasUnlocked ? .green : .red)
                                }
                            }
                            .validationHint(isInvalid: placasInvalida, message: "Las placas son obligatorias.")
                        }
                        
                        HStack(spacing: 16) {
                            FormField(title: "• Marca", placeholder: "ej. Nissan", text: $vehiculo.marca, characterLimit: 30)
                                .onChange(of: vehiculo.marca) { _, newValue in
                                    if newValue.count > 30 { vehiculo.marca = String(newValue.prefix(30)) }
                                }
                                .validationHint(isInvalid: marcaInvalida, message: "Mínimo 2 caracteres.")
                            FormField(title: "• Modelo", placeholder: "ej. Versa", text: $vehiculo.modelo, characterLimit: 40)
                                .onChange(of: vehiculo.modelo) { _, newValue in
                                    if newValue.count > 40 { vehiculo.modelo = String(newValue.prefix(40)) }
                                }
                                .validationHint(isInvalid: modeloInvalido, message: "Mínimo 2 caracteres.")
                            FormField(title: "• Año", placeholder: "ej. 2020", text: anioString, characterLimit: 4)
                                .onChange(of: anioString.wrappedValue) { _, newValue in
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        anioString.wrappedValue = filtered
                                    }
                                    if anioString.wrappedValue.count > 4 {
                                        anioString.wrappedValue = String(anioString.wrappedValue.prefix(4))
                                    }
                                }
                                .validationHint(isInvalid: anioInvalido, message: "Año inválido.")
                        }
                    }
                    
                    if esModoEdicion {
                        Divider().background(Color.red.opacity(0.3))
                        
                        // Zona de Peligro
                        VStack(spacing: 12) {
                            Text("Esta acción no se puede deshacer y eliminará el vehículo permanentemente.")
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                            
                            Button(role: .destructive) {
                                authReason = .deleteVehiculo
                                showingAuthModal = true
                            } label: {
                                Label("Eliminar vehículo permanentemente", systemImage: "trash.fill")
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
            
            // Mensaje de Error
            if let errorMsg {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.vertical, 6)
            }
            
            // Botones
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
                    Text(esModoEdicion ? "Guardar Cambios" : "Añadir Vehículo")
                        .fontWeight(.semibold)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .shadow(color: Color("MercedesPetrolGreen").opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(placasInvalida || anioInvalido || marcaInvalida || modeloInvalido)
                .opacity((placasInvalida || anioInvalido || marcaInvalida || modeloInvalido) ? 0.6 : 1.0)
            }
            .padding(20)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 760, minHeight: 500, maxHeight: 600)
        .cornerRadius(15)
        .sheet(isPresented: $showingAuthModal) {
            authModalView()
        }
    }
    
    // Modal de Autenticación (alineado a ProductFormView)
    @ViewBuilder
    func authModalView() -> some View {
        let prompt = (authReason == .unlockPlacas) ? "Autoriza para editar las Placas." : "Autoriza para ELIMINAR este vehículo."
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Autorización Requerida").font(.title2).fontWeight(.bold)
                Text(prompt)
                    .font(.callout).foregroundColor(authReason == .deleteVehiculo ? .red : .gray)
                if isTouchIDEnabled {
                    Button { Task { await authenticateWithTouchID() } } label: {
                        Label("Usar Huella (Touch ID)", systemImage: "touchid")
                            .font(.headline).padding().frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                    }.buttonStyle(.plain)
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
                }.buttonStyle(.plain)
            }
            .padding(22)
        }
        .frame(minWidth: 520, minHeight: 360)
        .preferredColorScheme(.dark)
        .onAppear { authError = ""; passwordAttempt = "" }
    }
    
    // Lógica de Guardar/Auth
    func guardarCambios() {
        errorMsg = nil
        
        let placasTrimmed = vehiculo.placas.trimmingCharacters(in: .whitespaces)
        let marcaTrimmed = vehiculo.marca.trimmingCharacters(in: .whitespaces)
        let modeloTrimmed = vehiculo.modelo.trimmingCharacters(in: .whitespaces)
        
        guard !placasTrimmed.isEmpty else {
            errorMsg = "Las placas no pueden estar vacías."
            return
        }
        guard !placasTrimmed.isEmpty else {
            errorMsg = "Las placas no pueden estar vacías."
            return
        }
        guard marcaTrimmed.count >= 2, modeloTrimmed.count >= 2 else {
            errorMsg = "La Marca y el Modelo deben tener al menos 2 caracteres."
            return
        }
        guard vehiculo.anio > 1900 && vehiculo.anio <= (Calendar.current.component(.year, from: Date()) + 1) else {
            errorMsg = "Por favor, ingresa un año válido."
            return
        }
        
        vehiculo.placas = placasTrimmed
        vehiculo.marca = marcaTrimmed
        vehiculo.modelo = modeloTrimmed
        
        if !esModoEdicion {
            vehiculo.cliente = clientePadre
            clientePadre?.vehiculos.append(vehiculo)
            modelContext.insert(vehiculo)
        }
        dismiss()
    }
    
    func authenticateWithTouchID() async {
        let context = LAContext()
        let reason = (authReason == .unlockPlacas) ? "Autoriza la edición de las Placas." : "Autoriza la ELIMINACIÓN del vehículo."
        do {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                if success { await MainActor.run { onAuthSuccess() } }
            }
        } catch { await MainActor.run { authError = "Huella no reconocida." } }
    }
    
    func authenticateWithPassword() {
        if passwordAttempt == userPassword { onAuthSuccess() }
        else { authError = "Contraseña incorrecta."; passwordAttempt = "" }
    }
    
    func onAuthSuccess() {
        switch authReason {
        case .unlockPlacas:
            isPlacasUnlocked = true
        case .deleteVehiculo:
            modelContext.delete(vehiculo)
            dismiss()
        }
        showingAuthModal = false
        authError = ""
        passwordAttempt = ""
    }
}


// --- VISTAS HELPER REUTILIZABLES (alineadas a InventarioView) ---

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

fileprivate extension View {
    func validationHint(isInvalid: Bool, message: String, color: Color = .red.opacity(0.9)) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            self
            if isInvalid {
                Text(message)
                    .font(.caption2)
                    .foregroundColor(color)
            }
        }
    }
}
