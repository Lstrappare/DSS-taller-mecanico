import SwiftUI
import SwiftData
import LocalAuthentication
import Network

// ID Constante para el chat
private let strategicConversationID = UUID()
// IDs consistentes (UUID) para filas especiales del ScrollView
private let welcomeID = UUID()
private let typingID = UUID()

struct ConsultaView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var service: AIStrategistService
    @EnvironmentObject private var appState: AppNavigationState
    
    @State private var userPrompt = ""
    
    // Conectividad Wi‑Fi
    @State private var isWifiAvailable: Bool = false
    private let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let monitorQueue = DispatchQueue(label: "wifi.monitor.queue")
    
    // Primera inicialización
    @AppStorage("ai_model_initialized") private var aiModelInitialized: Bool = false
    
    // Mensajes (chat) persistidos con SwiftData
    @Query(filter: #Predicate<ChatMessage> { $0.conversationID == strategicConversationID },
           sort: \ChatMessage.date) private var messages: [ChatMessage]
    
    // Observadores de datos para refrescar el contexto maestro automáticamente
    @Query private var personal: [Personal]
    @Query private var productos: [Producto]
    @Query private var servicios: [Servicio]
    @Query private var tickets: [ServicioEnProceso]
    @Query(sort: \DecisionRecord.fecha, order: .reverse) private var decisiones: [DecisionRecord]
    
    // Estados para Modales (Shortcuts)
    @State private var productModalMode: ProductModalMode?
    @State private var serviceModalMode: ServiceModalMode?
    @State private var personalModalMode: PersonalModalMode?
    
    // UI
    @State private var showClearConfirm = false
    @State private var showCopiedToast = false
    @State private var scrollAnchor: UUID = UUID()
    
    // Límite de caracteres para el input del usuario
    private let maxUserChars = 500
    
    // Tipos de Acción Detectados
    enum ActionTag: Equatable {
        case openProduct(String)
        case openService(String)
        case openPersonal(String)
        case scheduleService(String)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            
            // Estado del Motor
            engineStateCard
            
            // Conversación
            chatArea
            
            // Input
            inputBar
            
            if let error = service.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                    Text(error).foregroundColor(.white).font(.caption)
                    Spacer()
                }
                .padding(8)
                .background(Color.red.opacity(0.25))
                .cornerRadius(8)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            LinearGradient(colors: [Color("MercedesBackground"), Color("MercedesBackground").opacity(0.9)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .onAppear {
            startWifiMonitor()
            Task { await service.refreshMasterContext(modelContext: modelContext) }
            if aiModelInitialized && !service.isModelLoaded {
                Task {
                    service.isGenerating = true
                    let ok = await service.autoStartIfPossible()
                    await MainActor.run {
                        service.isGenerating = false
                        if ok && messages.isEmpty {
                            insertAssistantMessage("Asistente Estratégico iniciado. ¿En qué puedo ayudarte hoy?")
                        }
                    }
                }
            }
        }
        .onDisappear {
            monitor.cancel()
        }
        .onChange(of: personal) { _, _ in Task { await service.refreshMasterContext(modelContext: modelContext) } }
        .onChange(of: productos) { _, _ in Task { await service.refreshMasterContext(modelContext: modelContext) } }
        .onChange(of: servicios) { _, _ in Task { await service.refreshMasterContext(modelContext: modelContext) } }
        .onChange(of: tickets) { _, _ in Task { await service.refreshMasterContext(modelContext: modelContext) } }
        .onChange(of: decisiones) { _, _ in Task { await service.refreshMasterContext(modelContext: modelContext) } }
        .preferredColorScheme(.dark)
        .toast(isPresented: $showCopiedToast, message: "Copiado al portapapeles")
        .confirmationDialog("¿Limpiar conversación?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Eliminar todos los mensajes", role: .destructive) {
                clearConversation()
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Esta acción eliminará el historial de esta conversación.")
        }
        // Sheets para Acciones
        .sheet(item: $productModalMode) { mode in
            ProductFormView(mode: $productModalMode, initialMode: mode)
                .environment(\.modelContext, modelContext)
                .id(mode.id)
        }
        .sheet(item: $personalModalMode) { mode in
            PersonalFormView(mode: mode, parentMode: $personalModalMode)
                .environment(\.modelContext, modelContext)
                .id(mode.id)
        }
        .sheet(item: $serviceModalMode) { mode in
            Group {
                switch mode {
                case .add:
                    ServicioFormView(mode: .add, modalMode: $serviceModalMode)
                case .edit(let s):
                    ServicioFormView(mode: .edit(s), modalMode: $serviceModalMode)
                case .schedule(let s):
                    ProgramarServicioModal(servicio: s, appState: appState)
                }
            }
            .environment(\.modelContext, modelContext)
            .id(mode.id)
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
                    Text("Asistente Estratégico DSS")
                        .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    Text("Consulta de decisiones y estrategias del taller.")
                        .font(.footnote).foregroundColor(.gray)
                }
                Spacer()
                HStack(spacing: 8) {
                    estadoChip(text: service.isModelLoaded ? "Listo" : (service.isGenerating ? "Cargando..." : "Apagado"),
                               color: service.isModelLoaded ? .green : (service.isGenerating ? .yellow : .red))
                    estadoChip(text: isWifiAvailable ? "Wi‑Fi OK" : "Sin Wi‑Fi", color: isWifiAvailable ? .green : .red)
                    Menu {
                        Button {
                            showClearConfirm = true
                        } label: {
                            Label("Limpiar conversación", systemImage: "trash")
                        }
                        Button {
                            Task { await service.refreshMasterContext(modelContext: modelContext) }
                        } label: {
                            Label("Refrescar contexto", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color("MercedesBackground"))
                            .cornerRadius(8)
                    }
                    .menuStyle(.borderlessButton)
                }
            }
            .padding(.horizontal, 12)
        }
    }
    
    // MARK: - Estado Motor IA
    private var engineStateCard: some View {
        Group {
            if !service.isModelLoaded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.slash.fill")
                            .foregroundColor(.yellow)
                        Text("El motor de IA está apagado.")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    Text(aiModelInitialized
                         ? "Puedes iniciar el motor de IA incluso sin Wi‑Fi si el modelo ya está cacheado."
                         : "Se requiere conexión Wi‑Fi para iniciar el motor de IA la primera vez.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if service.isGenerating {
                        HStack(spacing: 10) {
                            ProgressView()
                            VStack(alignment: .leading, spacing: 2) {
                                Text(aiModelInitialized ? "Iniciando modelo en memoria..." :
                                     "Descargando e iniciando por primera vez...")
                                    .foregroundColor(.white)
                                if !aiModelInitialized {
                                    Text("La primera vez puede tardar unos minutos según tu conexión.")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            Spacer()
                        }
                        .padding(.top, 4)
                    } else {
                        HStack(spacing: 8) {
                            Button {
                                Task { await startModel() }
                            } label: {
                                Label("Iniciar Motor IA", systemImage: "play.circle.fill")
                                    .font(.subheadline)
                                    .padding(.vertical, 8).padding(.horizontal, 10)
                                    .background(Color("MercedesPetrolGreen"))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(!aiModelInitialized && !isWifiAvailable)
                            .opacity((!aiModelInitialized && !isWifiAvailable) ? 0.6 : 1.0)
                            
                            if !aiModelInitialized && !isWifiAvailable {
                                Text("Conéctate a una red Wi‑Fi para continuar.")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(12)
                .background(Color("MercedesCard"))
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Chat Area
    private var chatArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { msg in
                            messageBubble(for: msg)
                                .id(msg.id)
                                .padding(.horizontal, 4) // separa cada burbuja del borde del contenedor
                        }
                        if service.isGenerating {
                            typingBubble
                                .id(typingID)
                                .padding(.horizontal, 4) // separa el indicador de tipeo
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8) // margen general dentro del ScrollView
                }
                .frame(minHeight: 260)
                .background(
                    ZStack {
                        Color("MercedesCard")
                        LinearGradient(colors: [Color.white.opacity(0.012), Color("MercedesBackground").opacity(0.06)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                )
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                .onChange(of: messages.count) { _, _ in
                    // Scroll al último mensaje
                    if let last = messages.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: service.isGenerating) { _, generating in
                    let target = generating ? typingID : messages.last?.id
                    if let target {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(target, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let last = messages.last?.id {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private func messageBubble(for msg: ChatMessage) -> some View {
        // Parsing de Acciones
        let (displayText, actions) = parseMessageActions(msg.content)
        
        return HStack(alignment: .bottom, spacing: 8) {
            if msg.isFromUser == false {
                avatar(system: "sparkles", color: Color("MercedesPetrolGreen"))
            } else {
                Spacer(minLength: 20)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(displayText)
                    .font(.body)
                    .foregroundColor(.white)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // --- BOTONES DE ACCIÓN (Shortcuts) ---
                if !actions.isEmpty && !msg.isFromUser {
                    HStack(spacing: 8) {
                        ForEach(actions.indices, id: \.self) { i in
                            actionButton(for: actions[i])
                        }
                    }
                    .padding(.top, 4)
                }
                // -------------------------------------
                
                HStack(spacing: 8) {
                    Text(msg.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.gray)
                    if !msg.isFromUser {
                        Button {
                            // Copiar al portapapeles en macOS
                            #if os(macOS)
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(displayText, forType: .string)
                            #endif
                            withAnimation { showCopiedToast = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                withAnimation { showCopiedToast = false }
                            }
                        } label: {
                            Label("Copiar", systemImage: "doc.on.doc")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Color("MercedesPetrolGreen"))
                        .accessibilityLabel("Copiar respuesta")
                    }
                    Spacer()
                }
            }
            .padding(12)
            .background(
                ZStack {
                    (msg.isFromUser ? Color("MercedesPetrolGreen").opacity(0.22) : Color("MercedesBackground"))
                    LinearGradient(colors: [Color.white.opacity(0.02), Color.black.opacity(0.04)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("MercedesBackground").opacity(0.25), lineWidth: 1)
            )
            
            if msg.isFromUser {
                avatar(system: "person.fill", color: .gray)
            } else {
                Spacer(minLength: 20)
            }
        }
        .frame(maxWidth: .infinity, alignment: msg.isFromUser ? .trailing : .leading)
        .transition(.opacity.combined(with: .move(edge: msg.isFromUser ? .trailing : .leading)))
        .animation(.easeInOut(duration: 0.15), value: messages.count)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(msg.isFromUser ? "Mensaje del usuario" : "Mensaje del asistente")
    }
    
    // Renderizado del botón de acción
    private func actionButton(for action: ActionTag) -> some View {
        Button {
            executeAction(action)
        } label: {
            HStack(spacing: 6) {
                switch action {
                case .openProduct(let name):
                    Label("Ver/Editar \(name)", systemImage: "shippingbox.fill")
                case .openService(let name):
                    Label("Ver/Editar \(name)", systemImage: "wrench.and.screwdriver.fill")
                case .openPersonal(let name):
                    Label("Ver/Editar \(name)", systemImage: "person.fill")
                case .scheduleService(let name):
                    Label("Programar \(name)", systemImage: "calendar.badge.plus")
                }
            }
            .font(.caption).fontWeight(.medium)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color("MercedesPetrolGreen").opacity(0.2))
            .foregroundColor(Color("MercedesPetrolGreen"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("MercedesPetrolGreen").opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // --- LÓGICA DE EJECUCIÓN ---
    private func executeAction(_ action: ActionTag) {
        switch action {
        case .openProduct(let name):
            if let p = productos.first(where: { $0.nombre.localizedCaseInsensitiveContains(name) }) {
                productModalMode = .edit(p)
            } else {
                // Si no se encuentra exacto, abrir modal de buscar o nada
            }
        case .openService(let name):
            if let s = servicios.first(where: { $0.nombre.localizedCaseInsensitiveContains(name) }) {
                serviceModalMode = .edit(s)
            }
        case .openPersonal(let name):
            if let p = personal.first(where: { $0.nombre.localizedCaseInsensitiveContains(name) }) {
                personalModalMode = .edit(p)
            }
        case .scheduleService(let name):
            // Buscar si existe el servicio
            if let s = servicios.first(where: { $0.nombre.localizedCaseInsensitiveContains(name) }) {
                serviceModalMode = .schedule(s)
            } else {
                // Si no encuentra nombre exacto...
            }
        }
    }
    
    // --- PARSING ---
    private func parseMessageActions(_ content: String) -> (String, [ActionTag]) {
        var cleanText = content
        var actions: [ActionTag] = []
        
        // Expresiones regulares para los tags generados por la IA
        let patterns: [(String, (String) -> ActionTag)] = [
            ("\\[\\[OPEN:PRODUCT:(.*?)\\]\\]", { .openProduct($0) }),
            ("\\[\\[OPEN:SERVICE:(.*?)\\]\\]", { .openService($0) }),
            ("\\[\\[OPEN:PERSONAL:(.*?)\\]\\]", { .openPersonal($0) }),
            ("\\[\\[ACTION:SCHEDULE_SERVICE:(.*?)\\]\\]", { .scheduleService($0) })
        ]
        
        for (pattern, constructor) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsString = cleanText as NSString
                let matches = regex.matches(in: cleanText, options: [], range: NSRange(location: 0, length: nsString.length))
                
                // Procesar matchs inversa para no romper rangos
                for match in matches.reversed() {
                    if let range = Range(match.range, in: cleanText),
                       let groupRange = Range(match.range(at: 1), in: cleanText) {
                        let name = String(cleanText[groupRange])
                        actions.append(constructor(name))
                        cleanText.removeSubrange(range) // Quitar el tag del texto visible
                    }
                }
            }
        }
        
        return (cleanText.trimmingCharacters(in: .whitespacesAndNewlines), actions.reversed())
    }
    
    private var typingBubble: some View {
        HStack(spacing: 8) {
            avatar(system: "sparkles", color: Color("MercedesPetrolGreen"))
            HStack(spacing: 6) {
                TypingDot(delay: 0.0)
                TypingDot(delay: 0.2)
                TypingDot(delay: 0.4)
            }
            .padding(10)
            .background(Color("MercedesBackground"))
            .cornerRadius(10)
            Spacer()
        }
        .transition(.opacity.combined(with: .move(edge: .leading)))
        .padding(.leading, 6) // separa del borde izquierdo
        .padding(.horizontal, 4) // margen adicional dentro de la zona de chat
        .accessibilityLabel("El asistente está escribiendo")
    }
    
    private func avatar(system: String, color: Color) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.18))
            Image(systemName: system)
                .foregroundColor(color)
        }
        .frame(width: 28, height: 28)
    }
    
    // MARK: - Input Bar
    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundColor(Color("MercedesPetrolGreen"))
                    TextField("Escribe tu consulta estratégica aquí...", text: $userPrompt, axis: .vertical)
                        .textFieldStyle(PlainTextFieldStyle())
                        .lineLimit(1...5)
                        .onSubmit { sendMessage() }
                        .onChange(of: userPrompt) { _, newValue in
                            // Truncar en caliente a maxUserChars
                            if newValue.count > maxUserChars {
                                userPrompt = String(newValue.prefix(maxUserChars))
                                // Feedback háptico opcional en macOS
                                #if os(macOS)
                                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                                #endif
                            }
                        }
                }
                .padding(10)
                .background(Color("MercedesCard"))
                .cornerRadius(10)
                
                if service.isGenerating {
                    Button {
                        // Acción de “detener”: no hay cancel en el servicio; limpiamos bandera para UI
                        service.isGenerating = false
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Detener generación")
                } else {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(Color("MercedesPetrolGreen"))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSendDisabled)
                    .opacity(isSendDisabled ? 0.6 : 1.0)
                }
            }
            
            // Contador x/500
            HStack(spacing: 6) {
                let count = userPrompt.count
                Text("\(count)/\(maxUserChars)")
                    .font(.caption2)
                    .foregroundColor(count >= maxUserChars ? .red : .gray)
                if count >= maxUserChars {
                    Text("Límite alcanzado")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                Spacer()
            }
            .padding(.leading, 4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Barra de entrada de texto")
    }
    
    private var isSendDisabled: Bool {
        let trimmed = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || !service.isModelLoaded || service.isGenerating || trimmed.count > maxUserChars
    }
    
    // MARK: - Actions
    private func startWifiMonitor() {
        monitor.pathUpdateHandler = { path in
            let available = path.status == .satisfied
            DispatchQueue.main.async {
                self.isWifiAvailable = available
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    private func startModel() async {
        await MainActor.run { service.isGenerating = true }
        await service.loadModel()
        await MainActor.run {
            service.isGenerating = false
            if service.isModelLoaded {
                aiModelInitialized = true
                insertAssistantMessage("Modelo iniciado. ¿En qué puedo ayudarte hoy?")
            }
        }
    }
    
    private func sendMessage() {
        let prompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty,
              service.isModelLoaded,
              !service.isGenerating,
              prompt.count <= maxUserChars else { return }
        userPrompt = ""
        
        insertUserMessage(prompt)
        
        Task {
            await service.refreshMasterContext(modelContext: modelContext)
            await MainActor.run { service.isGenerating = true }
            await service.ask(prompt)
            await MainActor.run {
                service.isGenerating = false
                if !service.outputText.isEmpty {
                    insertAssistantMessage(service.outputText)
                }
            }
        }
    }
    
    private func insertUserMessage(_ text: String) {
        let msg = ChatMessage(conversationID: strategicConversationID, content: text, isFromUser: true)
        modelContext.insert(msg)
    }
    private func insertAssistantMessage(_ text: String) {
        let msg = ChatMessage(conversationID: strategicConversationID, content: text, isFromUser: false)
        modelContext.insert(msg)
    }
    
    private func clearConversation() {
        for m in messages {
            modelContext.delete(m)
        }
    }
    
    // MARK: - UI helpers
    private func estadoChip(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

// MARK: - Typing indicator
fileprivate struct TypingDot: View {
    @State private var scale: CGFloat = 0.6
    let delay: Double
    
    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.7))
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).delay(delay).repeatForever(autoreverses: true)) {
                    scale = 1.0
                }
            }
    }
}

// MARK: - Toast helper
fileprivate struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    
    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc.fill")
                            .foregroundColor(.white)
                        Text(message)
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.25), value: isPresented)
    }
}

fileprivate extension View {
    func toast(isPresented: Binding<Bool>, message: String) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message))
    }
}
