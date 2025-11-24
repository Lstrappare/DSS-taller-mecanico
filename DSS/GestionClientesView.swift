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
        case .editCliente(let cliente): return cliente.telefono
        case .addVehiculo(let cliente): return "addVehiculoA-\(cliente.telefono)"
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
                ClienteConVehiculoFormView()
                    .environment(\.modelContext, modelContext)
            case .editCliente(let cliente):
                ClienteFormView(cliente: cliente)
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
                VStack(alignment: .leading, spacing: 6) {
                    Text(cliente.nombre)
                        .font(.headline).fontWeight(.semibold)
                    // Chips de contacto
                    HStack(spacing: 6) {
                        if let telURL = URL(string: "tel:\(cliente.telefono)") {
                            Link(destination: telURL) {
                                chip(text: cliente.telefono, systemImage: "phone.fill")
                            }
                            .buttonStyle(.plain)
                        } else {
                            chip(text: cliente.telefono, systemImage: "phone.fill")
                        }
                        if cliente.email.isEmpty {
                            chip(text: "Sin email", systemImage: "envelope.fill", muted: true)
                        } else if let mailURL = URL(string: "mailto:\(cliente.email)") {
                            Link(destination: mailURL) {
                                chip(text: cliente.email, systemImage: "envelope.fill")
                            }
                            .buttonStyle(.plain)
                        } else {
                            chip(text: cliente.email, systemImage: "envelope.fill")
                        }
                    }
                }
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
                                .foregroundColor(Color("MercedesPetrolGreen"))
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
    
    private func chip(text: String, systemImage: String, muted: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption2)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color("MercedesBackground"))
        .cornerRadius(6)
        .foregroundColor(muted ? .gray : .white)
    }
}


// --- 1. FORMULARIO COMBINADO (ADD CLIENTE + VEHÍCULO) (alineado a ProductFormView) ---
fileprivate struct ClienteConVehiculoFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
    private var nombreInvalido: Bool {
        nombre.trimmingCharacters(in: .whitespaces).split(separator: " ").count < 2
    }
    private var telefonoInvalido: Bool {
        telefono.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var placasInvalidas: Bool {
        placas.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var anioInvalido: Bool {
        Int(anioString) == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("Añadir Cliente y Vehículo").font(.title2).fontWeight(.bold)
                Text("Completa los datos. Los campos marcados con • son obligatorios.")
                    .font(.caption).foregroundColor(.gray)
            }
            .padding(.top, 10).padding(.bottom, 6)
            
            Form {
                Section {
                    SectionHeader(title: "Datos del Cliente", subtitle: nil)
                    FormField(title: "• Nombre Completo", placeholder: "ej. José Cisneros Torres", text: $nombre)
                        .validationHint(isInvalid: nombreInvalido, message: "Escribe nombre y apellido.")
                    HStack(spacing: 12) {
                        FormField(title: "• Teléfono (ID Único)", placeholder: "10 dígitos", text: $telefono)
                            .validationHint(isInvalid: telefonoInvalido, message: "El teléfono es obligatorio.")
                        FormField(title: "Email (Opcional)", placeholder: "ej. jose@cliente.com", text: $email)
                    }
                }
                
                Section {
                    SectionHeader(title: "Datos del Primer Vehículo", subtitle: nil)
                    HStack(spacing: 12) {
                        FormField(title: "• Placas (ID Único)", placeholder: "ej. ABC-123", text: $placas)
                            .validationHint(isInvalid: placasInvalidas, message: "Las placas son obligatorias.")
                        FormField(title: "• Año", placeholder: "ej. 2020", text: $anioString)
                            .validationHint(isInvalid: anioInvalido, message: "Debe ser un número.")
                    }
                    HStack(spacing: 12) {
                        FormField(title: "• Marca", placeholder: "ej. Nissan", text: $marca)
                        FormField(title: "• Modelo", placeholder: "ej. Versa", text: $modelo)
                    }
                }
            }
            .textFieldStyle(PlainTextFieldStyle())
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            
            if let errorMsg {
                Text(errorMsg)
                    .font(.caption2).foregroundColor(.red).padding(.vertical, 4)
            }

            // Botones
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding(.vertical, 4).padding(.horizontal, 6).foregroundColor(.gray)
                Spacer()
                Button("Guardar y Añadir") {
                    guardarCambios()
                }
                .buttonStyle(.plain).padding(.vertical, 6).padding(.horizontal, 10)
                .foregroundColor(Color("MercedesPetrolGreen")).cornerRadius(6)
                .disabled(nombreInvalido || telefonoInvalido || placasInvalidas || anioInvalido)
                .opacity((nombreInvalido || telefonoInvalido || placasInvalidas || anioInvalido) ? 0.6 : 1.0)
            }
            .padding(.horizontal).padding(.bottom, 6)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 760, minHeight: 520, maxHeight: 580)
        .cornerRadius(12)
    }
    
    func guardarCambios() {
        errorMsg = nil
        let nombreTrimmed = nombre.trimmingCharacters(in: .whitespaces)
        let telefonoTrimmed = telefono.trimmingCharacters(in: .whitespaces)
        let placasTrimmed = placas.trimmingCharacters(in: .whitespaces)
        let marcaTrimmed = marca.trimmingCharacters(in: .whitespaces)
        let modeloTrimmed = modelo.trimmingCharacters(in: .whitespaces)

        // Validación
        guard nombreTrimmed.split(separator: " ").count >= 2 else {
            errorMsg = "El Nombre Completo debe tener al menos 2 palabras."
            return
        }
        guard !telefonoTrimmed.isEmpty else {
            errorMsg = "El Teléfono no puede estar vacío."
            return
        }
        guard !placasTrimmed.isEmpty else {
            errorMsg = "Las Placas no pueden estar vacías."
            return
        }
        guard !marcaTrimmed.isEmpty, !modeloTrimmed.isEmpty else {
            errorMsg = "La Marca y el Modelo son obligatorios."
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

    // States para Seguridad y Errores
    @State private var isTelefonoUnlocked = false
    @State private var showingAuthModal = false
    @State private var authError = ""
    @State private var passwordAttempt = ""
    @State private var errorMsg: String?
    
    private enum AuthReason {
        case unlockTelefono, deleteCliente
    }
    @State private var authReason: AuthReason = .unlockTelefono
    
    private var nombreInvalido: Bool {
        cliente.nombre.trimmingCharacters(in: .whitespaces).split(separator: " ").count < 2
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("Editar Cliente").font(.title2).fontWeight(.bold)
                Text("Autoriza para editar el teléfono si es necesario.")
                    .font(.caption).foregroundColor(.gray)
            }
            .padding(.top, 10).padding(.bottom, 6)
            
            Form {
                Section {
                    SectionHeader(title: "Datos del Cliente", subtitle: nil)
                    FormField(title: "• Nombre Completo", placeholder: "ej. José Cisneros", text: $cliente.nombre)
                        .validationHint(isInvalid: nombreInvalido, message: "Escribe nombre y apellido.")
                    
                    // Teléfono con Candado
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("• Teléfono (ID Único)").font(.caption2).foregroundColor(.gray)
                            Image(systemName: isTelefonoUnlocked ? "lock.open.fill" : "lock.fill")
                                .foregroundColor(isTelefonoUnlocked ? .green : .red)
                                .font(.caption2)
                        }
                        HStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                TextField("", text: $cliente.telefono)
                                    .disabled(!isTelefonoUnlocked)
                                    .padding(6).background(Color("MercedesBackground").opacity(0.9)).cornerRadius(6)
                                if cliente.telefono.isEmpty {
                                    Text("10 dígitos")
                                        .foregroundColor(Color.white.opacity(0.35))
                                        .padding(.horizontal, 10).allowsHitTesting(false)
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
                                    .font(.caption2)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(isTelefonoUnlocked ? .green : .red)
                        }
                        .validationHint(isInvalid: cliente.telefono.isEmpty, message: "El teléfono no puede estar vacío.")
                    }
                    
                    FormField(title: "Email (Opcional)", placeholder: "ej. jose@cliente.com", text: $cliente.email)
                }
            }
            .textFieldStyle(PlainTextFieldStyle())
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            if let errorMsg {
                Text(errorMsg)
                    .font(.caption2).foregroundColor(.red).padding(.vertical, 4)
            }
            
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding(.vertical, 4).padding(.horizontal, 6).foregroundColor(.gray)
                Button("Eliminar", role: .destructive) {
                    authReason = .deleteCliente
                    showingAuthModal = true
                }
                .buttonStyle(.plain).padding(.vertical, 4).padding(.horizontal, 6).foregroundColor(.red)
                Spacer()
                Button("Guardar Cambios") {
                    let nameParts = cliente.nombre.trimmingCharacters(in: .whitespaces).split(separator: " ")
                    if nameParts.count >= 2 {
                        dismiss()
                    } else {
                        errorMsg = "El Nombre Completo debe tener al menos 2 palabras."
                    }
                }
                .buttonStyle(.plain).padding(.vertical, 6).padding(.horizontal, 10)
                .foregroundColor(Color("MercedesPetrolGreen")).cornerRadius(6)
                .disabled(nombreInvalido)
                .opacity(nombreInvalido ? 0.6 : 1.0)
            }
            .padding(.horizontal).padding(.bottom, 6)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 760, minHeight: 480, maxHeight: 560)
        .cornerRadius(12)
        .sheet(isPresented: $showingAuthModal) {
            authModalView()
        }
    }
    
    // Modal de Autenticación (alineado a ProductFormView)
    @ViewBuilder
    func authModalView() -> some View {
        let prompt = (authReason == .unlockTelefono) ? "Autoriza para editar el Teléfono." : "¡Acción irreversible! Autoriza para ELIMINAR a este cliente."
        ZStack {
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
        let reason = (authReason == .unlockTelefono) ? "Autoriza la edición del Teléfono." : "Autoriza la ELIMINACIÓN del cliente."
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
        vehiculo.anio <= 1900
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
            VStack(spacing: 2) {
                Text(formTitle).font(.title2).fontWeight(.bold)
                Text("Cliente: \(clientePadre?.nombre ?? "Error")")
                    .font(.caption).foregroundColor(.gray)
            }
            .padding(.top, 10).padding(.bottom, 6)
            
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("• Placas (ID Único)").font(.caption2).foregroundColor(.gray)
                            if esModoEdicion {
                                Image(systemName: isPlacasUnlocked ? "lock.open.fill" : "lock.fill")
                                    .foregroundColor(isPlacasUnlocked ? .green : .red)
                                    .font(.caption2)
                            }
                        }
                        HStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                TextField("", text: $vehiculo.placas)
                                    .disabled(esModoEdicion && !isPlacasUnlocked)
                                    .padding(6).background(Color("MercedesBackground").opacity(0.9)).cornerRadius(6)
                                if vehiculo.placas.isEmpty {
                                    Text("ej. ABC-123-D")
                                        .foregroundColor(Color.white.opacity(0.35))
                                        .padding(.horizontal, 10).allowsHitTesting(false)
                                }
                            }
                            if esModoEdicion {
                                Button {
                                    if isPlacasUnlocked { isPlacasUnlocked = false }
                                    else {
                                        authReason = .unlockPlacas
                                        showingAuthModal = true
                                    }
                                } label: {
                                    Text(isPlacasUnlocked ? "Bloquear" : "Desbloquear")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(isPlacasUnlocked ? .green : .red)
                            }
                        }
                        .validationHint(isInvalid: placasInvalida, message: "Las placas son obligatorias.")
                    }
                
                    HStack(spacing: 12) {
                        FormField(title: "• Marca", placeholder: "ej. Nissan", text: $vehiculo.marca)
                        FormField(title: "• Modelo", placeholder: "ej. Versa", text: $vehiculo.modelo)
                        FormField(title: "• Año", placeholder: "ej. 2020", text: anioString)
                            .validationHint(isInvalid: anioInvalido, message: "Año no válido.")
                    }
                }
            }
            .textFieldStyle(PlainTextFieldStyle())
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            
            if let errorMsg {
                Text(errorMsg)
                    .font(.caption2).foregroundColor(.red).padding(.vertical, 4)
            }
            
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding(.vertical, 4).padding(.horizontal, 6).foregroundColor(.gray)
                if esModoEdicion {
                    Button("Eliminar", role: .destructive) {
                        authReason = .deleteVehiculo
                        showingAuthModal = true
                    }
                    .buttonStyle(.plain).padding(.vertical, 4).padding(.horizontal, 6).foregroundColor(.red)
                }
                Spacer()
                Button(esModoEdicion ? "Guardar Cambios" : "Añadir Vehículo") {
                    guardarCambios()
                }
                .buttonStyle(.plain).padding(.vertical, 6).padding(.horizontal, 10)
                .foregroundColor(Color("MercedesPetrolGreen")).cornerRadius(6)
                .disabled(placasInvalida || anioInvalido || vehiculo.marca.isEmpty || vehiculo.modelo.isEmpty)
                .opacity((placasInvalida || anioInvalido || vehiculo.marca.isEmpty || vehiculo.modelo.isEmpty) ? 0.6 : 1.0)
            }
            .padding(.horizontal).padding(.bottom, 6)
            .background(Color("MercedesCard"))
        }
        .background(Color("MercedesBackground"))
        .preferredColorScheme(.dark)
        .frame(minWidth: 760, minHeight: 480, maxHeight: 560)
        .cornerRadius(12)
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
        guard !marcaTrimmed.isEmpty, !modeloTrimmed.isEmpty else {
            errorMsg = "La Marca y el Modelo son obligatorios."
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
                    .padding(6)
                    .background(Color("MercedesBackground").opacity(0.9))
                    .cornerRadius(6)
                
                if text.isEmpty && !placeholder.isEmpty {
                    Text(placeholder)
                        .foregroundColor(Color.white.opacity(0.35))
                        .padding(.horizontal, 10)
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
