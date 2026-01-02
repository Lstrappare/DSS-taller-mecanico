//
//  HistorialView.swift
//  DSS
//
//  Created by Jose Cisneros on 04/11/25.
//

import SwiftUI
import SwiftData
import LocalAuthentication

// --- MODO DE VISTA UNIFICADO (Historial) ---
fileprivate enum ViewMode: Equatable {
    case todas
    case automaticas
    case manuales
    case byDateRange // Solo como estado interno si se quiere manejar así, o implícito.
                     // En PersonalView usan .standard, .byStatus... aqui usaremos algo similar.
    
    // Para el menú, "Todas", "Solo Automáticas", "Solo Manuales" parece ser el equivalente.
    // Además, en PersonalView el "Ordenar" es parte de la selección en algunos casos,
    // pero aquí mantendremos Filtro (Tipo) y Orden (Fecha/Titulo) algo separados pero en el mismo menú unificado.
}

struct HistorialView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DecisionRecord.fecha, order: .reverse) private var historial: [DecisionRecord]
    
    // Seguridad
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true
    
    // Estado de UI
    @State private var searchQuery = ""
    
    // Configuración de vista unificada coincidiendo con PersonalView
    @State private var viewMode: ViewMode = .todas
    
    // Filtros Adicionales (que conviven con el ViewMode)
    @State private var fechaDesde: Date? = nil
    @State private var fechaHasta: Date? = nil
    @State private var showingDatePicker = false
    
    // Ordenamiento
    @State private var sortAscending: Bool = true // Por defecto fechas recientes primero (Descendente en Fecha)
    enum SortOption: String, CaseIterable, Identifiable {
        case fecha = "Fecha"
        case titulo = "Título"
        var id: String { rawValue }
    }
    @State private var sortOption: SortOption = .fecha
    
    @State private var expandedIDs: Set<PersistentIdentifier> = []
    @State private var registroAEliminar: DecisionRecord?
    @State private var showingDeleteConfirm = false
    
    // Nuevo: flujo de decisión manual
    @State private var showingAddManualFlow = false
    @State private var showingAuthModal = false
    @State private var authError = ""
    @State private var passwordAttempt = ""
    @State private var touchIDAvailable = true
    @State private var isAuthorizedForManual = false
    
    // Formulario de decisión manual
    @State private var manualTitulo = ""
    @State private var manualRazon = ""
    private let manualOrigen = "N/A (Manual)"
    @State private var manualError: String?
    
    // Derivados
    var filtered: [DecisionRecord] {
        var base = historial
        
        // 1. Filtro por Modo (Tipo)
        switch viewMode {
        case .todas:
            break // No filtrar nada extra
        case .automaticas:
            base = base.filter { !$0.queryUsuario.lowercased().contains("manual") }
        case .manuales:
            base = base.filter { $0.queryUsuario.lowercased().contains("manual") }
        case .byDateRange:
            break // Se mezcla con todas, el rango aplica a todo
        }
        
        // 2. Filtro por Fechas (Siempre activo si están definidas)
        if let desde = fechaDesde {
            let start = Calendar.current.startOfDay(for: desde)
            base = base.filter { $0.fecha >= start }
        }
        if let hasta = fechaHasta {
            let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: hasta) ?? hasta
            base = base.filter { $0.fecha <= end }
        }
        
        // 3. Búsqueda
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let q = searchQuery.lowercased()
            base = base.filter { r in
                r.titulo.lowercased().contains(q) ||
                r.razon.lowercased().contains(q) ||
                r.queryUsuario.lowercased().contains(q)
            }
        }
        
        // 4. Ordenamiento
        base.sort { a, b in
            switch sortOption {
            case .fecha:
                return sortAscending ? (a.fecha < b.fecha) : (a.fecha > b.fecha)
            case .titulo:
                let cmp = a.titulo.localizedCaseInsensitiveCompare(b.titulo)
                return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
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
                    // Contador
                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .foregroundColor(Color("MercedesPetrolGreen"))
                        Text("\(filtered.count) resultado\(filtered.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    if filtered.isEmpty {
                        emptyStateView
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                    } else {
                        ForEach(filtered) { registro in
                            HistorialCard(
                                registro: registro,
                                isExpanded: expandedIDs.contains(registro.persistentModelID),
                                onToggleExpand: { toggleExpand(registro) },
                                onDelete: {
                                    registroAEliminar = registro
                                    showingDeleteConfirm = true
                                },
                                onCopy: {
                                    copiarRegistro(registro)
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
        .sheet(isPresented: $showingAddManualFlow) {
            addManualDecisionFlow()
        }
        .confirmationDialog(
            "Eliminar registro",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                if let r = registroAEliminar {
                    eliminarRegistro(registro: r)
                }
            }
            Button("Cancelar", role: .cancel) { registroAEliminar = nil }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
        .onAppear {
            let context = LAContext()
            var error: NSError?
            touchIDAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        }
    }
    
    // MARK: - Header
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
                    Text("Historial de Decisiones")
                        .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    HStack(spacing: 10) {
                        Label("\(historial.count) total", systemImage: "clock.arrow.circlepath")
                            .font(.footnote).foregroundColor(.gray)
                        if tieneFiltrosActivos {
                            Label("Filtros activos", systemImage: "line.3.horizontal.decrease.circle")
                                .font(.footnote).foregroundColor(.gray)
                        } else {
                            Text("Últimas decisiones registradas.")
                                .font(.footnote).foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
                Button {
                    showingAddManualFlow = true
                    isAuthorizedForManual = false
                    manualTitulo = ""
                    manualRazon = ""
                    manualError = nil
                } label: {
                    Label("Agregar manual", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .padding(.vertical, 6).padding(.horizontal, 10)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help("Registrar una decisión manual (requiere contraseña)")
            }
            .padding(.horizontal, 12)
        }
    }
    
    // MARK: - Filtros Unificados (Style PersonalView)
    private var filtrosView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Barra de Búsqueda
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    TextField("Buscar...", text: $searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.subheadline)
                    if !searchQuery.isEmpty {
                        Button { searchQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                
                // Menú Unificado de Ordenar / Filtros
                Menu {
                    // Sección 1: Filtro Principal (Vista)
                    Button {
                        viewMode = .todas
                    } label: {
                        if viewMode == .todas { Label("Ver Todas", systemImage: "checkmark") }
                        else { Text("Ver Todas") }
                    }
                    
                    Button {
                        viewMode = .automaticas
                    } label: {
                        if viewMode == .automaticas { Label("Ver Automáticas", systemImage: "checkmark") }
                        else { Text("Ver Automáticas") }
                    }
                    
                    Button {
                        viewMode = .manuales
                    } label: {
                        if viewMode == .manuales { Label("Ver Manuales", systemImage: "checkmark") }
                        else { Text("Ver Manuales") }
                    }
                    
                    Divider()
                    
                    // Sección 2: Criterio de Orden
                    Button {
                        sortOption = .fecha
                    } label: {
                        if sortOption == .fecha { Label("Ordenar por Fecha", systemImage: "checkmark") }
                        else { Text("Ordenar por Fecha") }
                    }
                    Button {
                        sortOption = .titulo
                    } label: {
                        if sortOption == .titulo { Label("Ordenar por Título", systemImage: "checkmark") }
                        else { Text("Ordenar por Título") }
                    }
                    
                    Divider()
                    
                    // Sección 3: Rango de Fechas (Toggle simple o reset)
                    // Aquí podríamos abrir un sheet, pero para mantener simpleza visual dentro del menú
                    // podemos tener opciones de "Última semana", "Último mes" o "Seleccionar Rango..."
                    // Por ahora mantendremos "Seleccionar Rango" que muestra los pickers abajo si se selecciona
                    // O simplemente usamos los pickers fuera del menú si el usuario quiere.
                    // Dado el request de "lucir como PersonalView", PersonalView no tiene fechas.
                    // Mantendremos los DatePickers VISIBLES si el usuario activa "Filtrar por Fecha" en el menú?
                    // O mejor, dejémoslo limpio: El menú controla Criterio y Filtro Tipo.
                    // Y un botón de "Fechas" al lado abre popover?
                    // Para alinearnos ESTRICTAMENTE a PersonalView, solo hay Menú + Botón SortDirection.
                    // Pero Historial necesita fechas. Lo pondremos como opcion extra en el menú: "Limpiar Fechas" si existen.
                    
                    if fechaDesde != nil || fechaHasta != nil {
                        Button(role: .destructive) {
                            withAnimation {
                                fechaDesde = nil
                                fechaHasta = nil
                            }
                        } label: {
                            Label("Limpiar filtro de fechas", systemImage: "xmark")
                        }
                    }
                    
                } label: {
                    HStack(spacing: 6) {
                        // Texto dinámico
                        let labelText: String = {
                            switch viewMode {
                            case .todas: return "Ver Todas"
                            case .automaticas: return "Ver Automáticas"
                            case .manuales: return "Ver Manuales"
                            default: return "Historial"
                            }
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
                .frame(width: 170)
                
                // Botón Fechas (Popover interactivo)
                Button {
                    showingDatePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                        if fechaDesde != nil || fechaHasta != nil {
                            Circle().fill(Color("MercedesPetrolGreen")).frame(width: 6, height: 6)
                        }
                    }
                    .font(.subheadline)
                    .padding(8)
                    .background(Color("MercedesCard"))
                    .cornerRadius(8)
                    .foregroundColor((fechaDesde != nil || fechaHasta != nil) ? Color("MercedesPetrolGreen") : .gray)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingDatePicker) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Filtrar por Rango de Fechas")
                            .font(.headline)
                            .padding(.bottom, 5)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Desde:").font(.caption).foregroundColor(.gray)
                            DatePicker("", selection: Binding(get: { fechaDesde ?? Date() }, set: { fechaDesde = $0 }), displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Hasta:").font(.caption).foregroundColor(.gray)
                             DatePicker("", selection: Binding(get: { fechaHasta ?? Date() }, set: { fechaHasta = $0 }), displayedComponents: .date)
                                .labelsHidden()
                                 .datePickerStyle(.compact)
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            fechaDesde = nil
                            fechaHasta = nil
                            showingDatePicker = false
                        } label: {
                            Label("Limpiar filtro de fechas", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding()
                    .frame(width: 320)
                }

                // Botón Ascendente/Descendente
                Button {
                    withAnimation { sortAscending.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                        Text(sortAscending ? "Ascendente" : "Descendente") // Abreviado para consistencia visual
                    }
                    .font(.subheadline)
                    .padding(8)
                    .background(Color("MercedesCard"))
                    .cornerRadius(8)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                }
                .help(sortAscending ? "Ascendente" : "Descendente")
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }
    
    private var tieneFiltrosActivos: Bool {
        return !searchQuery.isEmpty || viewMode != .todas || fechaDesde != nil || fechaHasta != nil
    }
    
    private func limpiarFiltros() {
        searchQuery = ""
        viewMode = .todas
        fechaDesde = nil
        fechaHasta = nil
        sortOption = .fecha
        sortAscending = true
    }
    
    // MARK: - Helpers
    private func toggleExpand(_ registro: DecisionRecord) {
        let id = registro.persistentModelID
        if expandedIDs.contains(id) { expandedIDs.remove(id) }
        else { expandedIDs.insert(id) }
    }
    
    private func eliminarRegistro(registro: DecisionRecord) {
        modelContext.delete(registro)
    }
    
    private func copiarRegistro(_ registro: DecisionRecord) {
        let texto = """
        [\(registro.fecha.formatted(date: .abbreviated, time: .shortened))] \(registro.titulo)
        Razón: \(registro.razon)
        Origen: \(registro.queryUsuario)
        """
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(texto, forType: .string)
        #else
        UIPasteboard.general.string = texto
        #endif
    }
    
    // Empty state
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(Color("MercedesPetrolGreen"))
            
            if !searchQuery.isEmpty {
                Text("No se encontraron resultados para “\(searchQuery)”.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                // Mensajes contextuales según ViewMode
                Group {
                    switch viewMode {
                    case .todas:
                        if fechaDesde != nil || fechaHasta != nil {
                            Text("No hay decisiones en el rango de fechas seleccionado.")
                        } else {
                            Text("No hay decisiones registradas aún.")
                        }
                    case .automaticas:
                        Text("No hay decisiones automáticas registradas.")
                    case .manuales:
                        Text("No hay decisiones manuales registradas.")
                    default:
                        Text("No hay resultados.")
                    }
                }
                .font(.subheadline)
                .foregroundColor(.gray)
                
                if viewMode == .todas && fechaDesde == nil && fechaHasta == nil {
                     Text("Aquí verás las decisiones automáticas y manuales que se vayan registrando.")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    // MARK: - Flujo de agregar decisión manual
    @ViewBuilder
    private func addManualDecisionFlow() -> some View {
        if !isAuthorizedForManual {
            // Paso 1: Autenticación
            AuthModal(
                title: "Autorización Requerida",
                prompt: "Autoriza para escribir una decisión manual.",
                error: authError,
                passwordAttempt: $passwordAttempt,
                isTouchIDEnabled: isTouchIDEnabled && touchIDAvailable,
                onAuthTouchID: { Task { await authenticateWithTouchID() } },
                onAuthPassword: { authenticateWithPassword() }
            )
            .onAppear { authError = "" }
        } else {
            // Paso 2: Formulario
            ModalView(title: "Nueva Decisión Manual") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Por favor, sé lo más específico posible; esto ayudará al asistente estratégico a tomar mejores decisiones.")
                        .font(.callout)
                        .foregroundColor(.yellow)
                        .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Título").font(.caption).foregroundColor(.gray)
                        TextField("Ej. Ajuste de presupuesto mensual de refacciones", text: $manualTitulo)
                            .padding(8)
                            .background(Color("MercedesBackground"))
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Razón / Detalle de la decisión").font(.caption).foregroundColor(.gray)
                        TextEditor(text: $manualRazon)
                            .frame(minHeight: 160)
                            .padding(8)
                            .background(Color("MercedesBackground"))
                            .cornerRadius(8)
                    }
                    
                    if let manualError {
                        Text(manualError).font(.caption).foregroundColor(.red)
                    }
                    
                    HStack {
                        Button("Cancelar") {
                            showingAddManualFlow = false
                            isAuthorizedForManual = false
                            manualTitulo = ""
                            manualRazon = ""
                            manualError = nil
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .foregroundColor(.gray)
                        
                        Spacer()
                        Button {
                            guardarDecisionManual()
                        } label: {
                            Label("Guardar", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color("MercedesPetrolGreen"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(manualTitulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  manualRazon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity((manualTitulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  manualRazon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.6 : 1.0)
                    }
                }
            }
        }
    }
    
    private func guardarDecisionManual() {
        manualError = nil
        let titulo = manualTitulo.trimmingCharacters(in: .whitespacesAndNewlines)
        let razon = manualRazon.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !titulo.isEmpty else {
            manualError = "El título es obligatorio."
            return
        }
        guard !razon.isEmpty else {
            manualError = "La razón/detalle es obligatoria."
            return
        }
        let registro = DecisionRecord(
            fecha: Date(),
            titulo: titulo,
            razon: razon,
            queryUsuario: manualOrigen
        )
        modelContext.insert(registro)
        showingAddManualFlow = false
        isAuthorizedForManual = false
        manualTitulo = ""
        manualRazon = ""
        manualError = nil
    }
    
    // Autenticación
    private func authenticateWithPassword() {
        if passwordAttempt == userPassword {
            onAuthSuccess()
        } else {
            authError = "Contraseña incorrecta."
            passwordAttempt = ""
        }
    }
    
    private func onAuthSuccess() {
        authError = ""
        passwordAttempt = ""
        isAuthorizedForManual = true
    }
    
    private func authenticateWithTouchID() async {
        let context = LAContext()
        let reason = "Autoriza para registrar una decisión manual."
        do {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                if success { await MainActor.run { onAuthSuccess() } }
            }
        } catch {
            await MainActor.run { authError = "Huella no reconocida." }
        }
    }
}

fileprivate struct HistorialCard: View {
    let registro: DecisionRecord
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onDelete: () -> Void
    let onCopy: () -> Void
    
    private var isManual: Bool {
        let q = registro.queryUsuario.lowercased()
        return q.contains("manual")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        badge(text: isManual ? "Decisión Manual" : "Automática", systemImage: isManual ? "pencil" : "bolt.fill")
                        Text(registro.titulo)
                            .font(.headline).fontWeight(.semibold)
                    }
                    // Fecha
                    HStack(spacing: 8) {
                        Label(registro.fecha.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        Label(registro.fecha.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                }
                Spacer()
                HStack(spacing: 6) {
                    Button {
                        onCopy()
                    } label: {
                        Label("Copiar", systemImage: "doc.on.doc")
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(Color("MercedesBackground"))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(Color.red.opacity(0.22))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
            }
            
            // Razón (colapsable)
            VStack(alignment: .leading, spacing: 6) {
                Text(registro.razon)
                    .font(.body)
                    .foregroundColor(.gray)
                    .lineLimit(isExpanded ? nil : 3)
                Button(isExpanded ? "Ver menos" : "Ver más") {
                    onToggleExpand()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(Color("MercedesPetrolGreen"))
            }
            
            // Origen / Consulta original
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "quote.opening")
                        .foregroundColor(.gray)
                    Text("Origen")
                        .font(.caption).foregroundColor(.gray)
                }
                Text(registro.queryUsuario.isEmpty ? "Sin consulta original registrada." : registro.queryUsuario)
                    .font(.footnote)
                    .foregroundColor(.gray.opacity(0.9))
                    .italic()
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
    
    private func badge(text: String, systemImage: String) -> some View {
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

#Preview {
    let container = try! ModelContainer(for: DecisionRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let ejemplo1 = DecisionRecord(
        fecha: Date(),
        titulo: "Iniciando: Cambio de Frenos",
        razon: "Asignado a Juan Pérez para vehículo [ABC-123]. Costo piezas: $450.00",
        queryUsuario: "Asignación Automática de Servicio"
    )
    let ejemplo2 = DecisionRecord(
        fecha: Date().addingTimeInterval(-86400),
        titulo: "Decisión Manual",
        razon: "Se decidió posponer la compra de equipo por alta inversión y baja urgencia.",
        queryUsuario: "N/A (Manual)"
    )
    container.mainContext.insert(ejemplo1)
    container.mainContext.insert(ejemplo2)
    
    return HistorialView()
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
