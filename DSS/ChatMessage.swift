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
    
    // Servicio compartido (App-wide)
    @EnvironmentObject private var service: AIStrategistService
    
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
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
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
            // Auto-arranque OFFLINE si ya fue inicializado alguna vez
            if aiModelInitialized && !service.isModelLoaded {
                Task {
                    service.isGenerating = true
                    let ok = await service.autoStartIfPossible()
                    await MainActor.run {
                        service.isGenerating = false
                        if ok && messages.isEmpty {
                            insertAssistantMessage("Modelo iniciado. ¿En qué puedo ayudarte hoy?")
                        }
                    }
                }
            }
        }
        .onDisappear {
            monitor.cancel()
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header estilo InventarioView
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
                // Estado breve
                HStack(spacing: 8) {
                    estadoChip(text: service.isModelLoaded ? "Listo" : (service.isGenerating ? "Cargando..." : "Apagado"),
                               color: service.isModelLoaded ? .green : (service.isGenerating ? .yellow : .red))
                    estadoChip(text: isWifiAvailable ? "Wi‑Fi OK" : "Sin Wi‑Fi", color: isWifiAvailable ? .green : .red)
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
                            // Solo bloquear por falta de Wi‑Fi si es la PRIMERA VEZ
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
            // Mensaje de bienvenida si no hay mensajes
            if messages.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bienvenido al Asistente Estratégico")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Haz preguntas sobre precios, servicios, inventario, personal o decisiones estratégicas del taller.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(messages) { msg in
                        messageBubble(for: msg)
                    }
                    
                    if service.isGenerating {
                        HStack(spacing: 8) {
                            Circle().frame(width: 6, height: 6).foregroundColor(.gray).opacity(0.6)
                            Circle().frame(width: 6, height: 6).foregroundColor(.gray).opacity(0.6)
                            Circle().frame(width: 6, height: 6).foregroundColor(.gray).opacity(0.6)
                        }
                        .padding(8)
                        .background(Color("MercedesBackground"))
                        .cornerRadius(8)
                    }
                }
                .padding(.vertical, 6)
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
        }
    }
    
    private func messageBubble(for msg: ChatMessage) -> some View {
        HStack {
            if msg.isFromUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                Text(msg.content)
                    .font(.body)
                    .foregroundColor(.white)
                Text(msg.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(10)
            .background(msg.isFromUser ? Color("MercedesPetrolGreen").opacity(0.25) : Color("MercedesBackground"))
            .cornerRadius(8)
            if !msg.isFromUser { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: msg.isFromUser ? .trailing : .leading)
        .transition(.opacity.combined(with: .move(edge: msg.isFromUser ? .trailing : .leading)))
        .animation(.easeInOut(duration: 0.15), value: messages.count)
    }
    
    // MARK: - Input Bar
    private var inputBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(Color("MercedesPetrolGreen"))
                TextField("Escribe tu consulta estratégica aquí...", text: $userPrompt)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit { sendMessage() }
            }
            .padding(10)
            .background(Color("MercedesCard"))
            .cornerRadius(8)
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Color("MercedesPetrolGreen"))
            }
            .buttonStyle(.plain)
            .disabled(userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !service.isModelLoaded || service.isGenerating)
            .opacity((userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !service.isModelLoaded || service.isGenerating) ? 0.6 : 1.0)
        }
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
        await MainActor.run { service.isGenerating = true } // para mostrar el estado en la tarjeta
        await service.loadModel()
        await MainActor.run {
            service.isGenerating = false
            if service.isModelLoaded {
                aiModelInitialized = true
                // Mensaje de sistema de que el modelo está listo
                insertAssistantMessage("Modelo iniciado. ¿En qué puedo ayudarte hoy?")
            }
        }
    }
    
    private func sendMessage() {
        let prompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, service.isModelLoaded, !service.isGenerating else { return }
        userPrompt = ""
        
        // Insertar mensaje de usuario
        insertUserMessage(prompt)
        
        Task {
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
