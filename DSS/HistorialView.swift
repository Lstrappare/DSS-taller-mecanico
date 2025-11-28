//
//  HistorialView.swift
//  DSS
//
//  Created by Jose Cisneros on 04/11/25.
//

import SwiftUI
import SwiftData
import LocalAuthentication

fileprivate enum TipoDecision: String, CaseIterable, Identifiable {
    case todas = "Todas"
    case automatica = "Automática"
    case manual = "Manual"
    var id: String { rawValue }
}

struct HistorialView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DecisionRecord.fecha, order: .reverse) private var historial: [DecisionRecord]
    
    // Seguridad
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true
    
    // Estado de UI
    @State private var searchQuery = ""
    @State private var filtroTipo: TipoDecision = .todas
    @State private var fechaDesde: Date? = nil
    @State private var fechaHasta: Date? = nil
    @State private var sortAscending: Bool = false
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
    private var filtered: [DecisionRecord] {
        var base = historial
        
        // Texto
        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let q = searchQuery.lowercased()
            base = base.filter { r in
                r.titulo.lowercased().contains(q) ||
                r.razon.lowercased().contains(q) ||
                r.queryUsuario.lowercased().contains(q)
            }
        }
        // Tipo
        if filtroTipo != .todas {
            base = base.filter { r in
                let q = r.queryUsuario.lowercased()
                if filtroTipo == .manual {
                    return q.contains("manual")
                } else {
                    // automática: no contiene “manual”
                    return !q.contains("manual")
                }
            }
        }
        // Rango de fechas (comparando solo día)
        if let desde = fechaDesde {
            let start = Calendar.current.startOfDay(for: desde)
            base = base.filter { $0.fecha >= start }
        }
        if let hasta = fechaHasta {
            // incluir todo el día de “hasta”
            let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: hasta) ?? hasta
            base = base.filter { $0.fecha <= end }
        }
        // Orden
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
            // Detectar biometría disponible para mostrar opción Touch ID si procede
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
                HStack(spacing: 8) {
                    Button {
                        showingAddManualFlow = true
                        // Arranca en modo de autenticación
                        isAuthorizedForManual = false
                        manualTitulo = ""
                        manualRazon = ""
                        manualError = nil
                    } label: {
                        Label("Agregar decisión manual", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                            .padding(.vertical, 6).padding(.horizontal, 10)
                            .background(Color("MercedesPetrolGreen"))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .help("Registrar una decisión manual (requiere contraseña)")
                    
                    if tieneFiltrosActivos {
                        Button {
                            limpiarFiltros()
                        } label: {
                            Label("Limpiar", systemImage: "xmark.circle")
                                .font(.subheadline)
                                .padding(.vertical, 6).padding(.horizontal, 10)
                                .background(Color("MercedesCard"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .help("Quitar filtros activos")
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }
    
    // MARK: - Filtros
    private var filtrosView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Buscar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    TextField("Buscar por Título, Razón o Consulta original...", text: $searchQuery)
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
                
                // Tipo
                Picker("Tipo", selection: $filtroTipo) {
                    ForEach(TipoDecision.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 160)
                .help("Filtrar por tipo de decisión")
                
                // Rango de fechas
                HStack(spacing: 6) {
                    DatePicker("Desde", selection: Binding(get: {
                        fechaDesde ?? Date()
                    }, set: { new in
                        fechaDesde = new
                    }), displayedComponents: .date)
                    .labelsHidden()
                    .frame(maxWidth: 160)
                    .opacity(fechaDesde == nil ? 0.5 : 1)
                    .overlay(
                        HStack {
                            if fechaDesde != nil {
                                Button {
                                    fechaDesde = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 4)
                            }
                        }, alignment: .trailing
                    )
                    
                    Text("-").foregroundColor(.gray)
                    
                    DatePicker("Hasta", selection: Binding(get: {
                        fechaHasta ?? Date()
                    }, set: { new in
                        fechaHasta = new
                    }), displayedComponents: .date)
                    .labelsHidden()
                    .frame(maxWidth: 160)
                    .opacity(fechaHasta == nil ? 0.5 : 1)
                    .overlay(
                        HStack {
                            if fechaHasta != nil {
                                Button {
                                    fechaHasta = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 4)
                            }
                        }, alignment: .trailing
                    )
                }
                .padding(6)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                .help("Filtrar por rango de fechas (opcional)")
                
                // Orden
                HStack(spacing: 6) {
                    Picker("Ordenar", selection: $sortOption) {
                        ForEach(SortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 140)
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
                
                // Chips de filtros activos
                if tieneFiltrosActivos {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("Filtros activos")
                        if !searchQuery.isEmpty {
                            Text("“\(searchQuery)”")
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color("MercedesBackground")).cornerRadius(6)
                        }
                        if filtroTipo != .todas {
                            Text("Tipo: \(filtroTipo.rawValue)")
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color("MercedesBackground")).cornerRadius(6)
                        }
                        if let d = fechaDesde {
                            Text("Desde: \(d.formatted(date: .abbreviated, time: .omitted))")
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color("MercedesBackground")).cornerRadius(6)
                        }
                        if let h = fechaHasta {
                            Text("Hasta: \(h.formatted(date: .abbreviated, time: .omitted))")
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color("MercedesBackground")).cornerRadius(6)
                        }
                        if sortOption != .fecha || sortAscending {
                            Text("Orden: \(sortOption.rawValue) \(sortAscending ? "↑" : "↓")")
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color("MercedesBackground")).cornerRadius(6)
                        }
                        Button {
                            withAnimation { limpiarFiltros() }
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
    
    private var tieneFiltrosActivos: Bool {
        return !searchQuery.isEmpty || filtroTipo != .todas || fechaDesde != nil || fechaHasta != nil || sortOption != .fecha || sortAscending
    }
    
    private func limpiarFiltros() {
        searchQuery = ""
        filtroTipo = .todas
        fechaDesde = nil
        fechaHasta = nil
        sortOption = .fecha
        sortAscending = false
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
            Text(searchQuery.isEmpty ? "No hay decisiones registradas aún." :
                 "No se encontraron resultados para “\(searchQuery)”.")
                .font(.subheadline)
                .foregroundColor(.gray)
            if searchQuery.isEmpty {
                Text("Aquí verás las decisiones automáticas y manuales que se vayan registrando.")
                    .font(.caption2)
                    .foregroundColor(.gray)
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
