import SwiftUI
import SwiftData
import LocalAuthentication

// ID Constante para el chat
private let strategicConversationID = UUID()
// IDs consistentes (UUID) para filas especiales del ScrollView
private let welcomeID = UUID()
private let typingID = UUID()

struct ConsultaView: View {
    @Environment(\.modelContext) private var modelContext
    
    // --- Almacenamiento ---
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true

    // --- DATOS DEL TALLER (Para la IA) ---
    @Query private var personal: [Personal]
    @Query private var productos: [Producto]
    @Query private var servicios: [Servicio]
    @Query private var historial: [DecisionRecord]

    // --- States del Chat ---
    @State private var conversationID: UUID
    @Query(sort: \ChatMessage.date) private var conversation: [ChatMessage]
    @State private var inputText = ""
    @State private var estaCargandoIA = false
    @State private var isTypingAnimation = false
    @State private var characterCountLimit: Int = 800
    @FocusState private var inputFocused: Bool
    
    // --- States para la Decisión Manual ---
    @State private var isCustomDecisionUnlocked = false
    @State private var customDecisionText = ""
    @State private var showingAuthModal = false
    @State private var passwordAttempt = ""
    @State private var authError = ""
    @State private var showSavedToast = false
    
    // --- Constructor (Filtra por el ID Constante) ---
    init() {
        _conversationID = State(initialValue: strategicConversationID)
        _conversation = Query(
            filter: #Predicate { $0.conversationID == strategicConversationID },
            sort: \.date
        )
    }

    var body: some View {
        HSplitView {
            // --- Columna 1: Chat Exploratorio ---
            VStack(alignment: .leading, spacing: 16) {
                header(title: "Asistente Estratégico",
                       subtitle: "Chat con IA. El historial se guarda en la base de datos.",
                       icon: "bubble.left.and.bubble.right.fill")
                
                chatList
                
                inputBar
            }
            .padding(30)
            
            // --- Columna 2: Decisión Manual ---
            VStack(alignment: .leading, spacing: 16) {
                header(title: "Registro Manual",
                       subtitle: "Registra una decisión estratégica manualmente.",
                       icon: "pencil.and.list.clipboard")
                
                Button {
                    showingAuthModal = true
                } label: {
                    Label("Escribir Decisión Personalizada", systemImage: "pencil")
                        .font(.headline)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color("MercedesCard"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Escribir decisión personalizada")
                
                if isCustomDecisionUnlocked {
                    decisionComposer
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    infoCard(
                        title: "Protegido",
                        message: "Autoriza para desbloquear el registro manual.",
                        systemImage: "lock.fill",
                        accent: .gray
                    )
                }
                Spacer()
            }
            .padding(30)
        }
        .background(
            LinearGradient(colors: [Color("MercedesBackground"), Color("MercedesBackground").opacity(0.9)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
        .sheet(isPresented: $showingAuthModal) {
            authModalView(isTouchIDEnabled: isTouchIDEnabled)
        }
        .overlay(alignment: .top) {
            if showSavedToast {
                toast(message: "Decisión guardada en Historial")
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .onChange(of: estaCargandoIA) {
            withAnimation(.easeInOut(duration: 0.25)) {
                isTypingAnimation = estaCargandoIA
            }
        }
        .onAppear {
            // Enfoca la barra de entrada al entrar
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                inputFocused = true
            }
        }
    }
    
    // MARK: - Subvistas

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14, pinnedViews: []) {
                    // Mensaje de bienvenida (solo UI)
                    ChatBubbleView(message: ChatMessage(conversationID: conversationID,
                                                        content: "¡Hola! Soy tu asistente. Tengo acceso a tus datos de Personal, Productos y Servicios. ¿En qué puedo ayudarte hoy?",
                                                        isFromUser: false))
                        .id(welcomeID)
                    
                    ForEach(conversation) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            ChatBubbleView(message: message)
                            timestampView(for: message.date, isFromUser: message.isFromUser)
                        }
                        .id(message.id)
                        .transition(.asymmetric(insertion: .move(edge: message.isFromUser ? .trailing : .leading).combined(with: .opacity),
                                                removal: .opacity))
                    }
                    
                    if estaCargandoIA {
                        typingIndicator
                            .id(typingID)
                    }
                }
                .padding(.top, 6)
            }
            .onChange(of: conversation.count) {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(conversation.last?.id ?? typingID, anchor: .bottom)
                }
            }
            .onChange(of: estaCargandoIA) {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(typingID, anchor: .bottom)
                }
            }
        }
    }
    
    private var typingIndicator: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "robot")
                .font(.title3)
                .padding(8)
                .background(Color.gray.opacity(0.3))
                .clipShape(Circle())
            HStack(spacing: 6) {
                dot()
                dot(delay: 0.15)
                dot(delay: 0.3)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color("MercedesCard"))
            .cornerRadius(14)
        }
        .frame(maxWidth: 600, alignment: .leading)
        .padding(.leading, 2)
    }
    
    private func dot(delay: Double = 0) -> some View {
        Circle()
            .fill(Color.white.opacity(0.8))
            .frame(width: 6, height: 6)
            .opacity(isTypingAnimation ? 1 : 0.2)
            .scaleEffect(isTypingAnimation ? 1 : 0.7)
            .animation(.easeInOut(duration: 0.8).repeatForever().delay(delay), value: isTypingAnimation)
    }
    
    private func timestampView(for date: Date, isFromUser: Bool) -> some View {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let text = formatter.localizedString(for: date, relativeTo: Date())
        return Text(text)
            .font(.caption2)
            .foregroundColor(.gray)
            .frame(maxWidth: 600, alignment: isFromUser ? .trailing : .leading)
            .padding(.horizontal, 6)
            .accessibilityLabel("Hace \(text)")
    }
    
    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .foregroundColor(Color("MercedesPetrolGreen"))
                Text("Escribe tu consulta. Usa Cmd+Enter para enviar.")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(inputText.count)/\(characterCountLimit)")
                    .font(.caption2)
                    .foregroundColor(inputText.count > characterCountLimit ? .red : .gray)
            }
            HStack(spacing: 12) {
                TextField("Escribe tu consulta...", text: $inputText, onCommit: enviarMensaje)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(12)
                    .background(Color("MercedesCard"))
                    .cornerRadius(10)
                    .focused($inputFocused)
                    .onSubmit { enviarMensaje() }
                    .onChange(of: inputText) { _, new in
                        if new.count > characterCountLimit {
                            inputText = String(new.prefix(characterCountLimit))
                        }
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                
                if !inputText.isEmpty {
                    Button {
                        inputText = ""
                        inputFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                            .accessibilityLabel("Limpiar texto")
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: enviarMensaje) {
                    Image(systemName: "paperplane.fill")
                        .font(.title2)
                        .foregroundColor(estaCargandoIA || inputText.isEmpty ? .gray : Color("MercedesPetrolGreen"))
                        .accessibilityLabel("Enviar mensaje")
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || estaCargandoIA)
            }
        }
    }
    
    // --- VISTA: Burbuja de Chat ---
    @ViewBuilder
    func ChatBubbleView(message: ChatMessage) -> some View {
        HStack {
            if message.isFromUser {
                Spacer()
                Text(message.content)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(Color("MercedesPetrolGreen"))
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .frame(maxWidth: 600, alignment: .trailing)
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "robot")
                        .font(.title3)
                        .padding(8)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())
                    Text(message.content)
                        .textSelection(.enabled)
                        .padding(12)
                        .background(Color("MercedesCard"))
                        .cornerRadius(15)
                }
                .frame(maxWidth: 600, alignment: .leading)
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                Spacer()
            }
        }
    }
    
    // --- VISTA: Modal de Autenticación ---
    @ViewBuilder
    func authModalView(isTouchIDEnabled: Bool) -> some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(Color("MercedesPetrolGreen"))
                
                Text("Verificación Requerida")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Autoriza para registrar una decisión manual.")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .padding(.bottom, 8)
                
                if isTouchIDEnabled {
                    Button(action: { Task { await authenticateWithTouchID() } }) {
                        Label("Usar Huella (Touch ID)", systemImage: "touchid")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen"))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    Text("o").foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Usa la contraseña con la que te registraste:")
                        .font(.headline)
                    SecureField("Contraseña", text: $passwordAttempt)
                        .padding(12)
                        .background(Color("MercedesCard"))
                        .cornerRadius(10)
                        .onSubmit { authenticateWithPassword() }
                        .submitLabel(.done)
                        .keyboardShortcut(.escape, modifiers: [])
                }
                
                if !authError.isEmpty {
                    Text(authError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                HStack(spacing: 12) {
                    Button {
                        showingAuthModal = false
                        authError = ""
                        passwordAttempt = ""
                    } label: {
                        Text("Cancelar")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.25))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { authenticateWithPassword() }) {
                        Label("Autorizar con Contraseña", systemImage: "lock.fill")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.4))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
        }
        .frame(minWidth: 520, minHeight: 420)
        .preferredColorScheme(.dark)
        .onAppear { authError = ""; passwordAttempt = "" }
    }
    
    private func header(title: String, subtitle: String, icon: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color("MercedesPetrolGreen").opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                    .font(.system(size: 18, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.title3)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
    
    private func infoCard(title: String, message: String, systemImage: String, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundColor(accent)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(16)
        .background(Color("MercedesCard"))
        .cornerRadius(12)
    }
    
    private var decisionComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detalla tu decisión")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Esta decisión se guardará en tu Historial.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .italic()
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $customDecisionText)
                    .font(.body)
                    .padding(8)
                    .background(Color("MercedesCard"))
                    .cornerRadius(10)
                    .frame(minHeight: 160)
                if customDecisionText.isEmpty {
                    Text("Escribe aquí los motivos, contexto y resultado esperado…")
                        .foregroundColor(Color.white.opacity(0.35))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            
            HStack {
                Text("\(customDecisionText.count)/1000")
                    .font(.caption2)
                    .foregroundColor(customDecisionText.count > 1000 ? .red : .gray)
                Spacer()
                Button {
                    guardarDecision(titulo: "Decisión Manual", razon: customDecisionText, query: "N/A (Manual)")
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        showSavedToast = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showSavedToast = false
                        }
                    }
                } label: {
                    Label("Guardar Decisión", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(customDecisionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.4) : Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(customDecisionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(Color("MercedesCard"))
        .cornerRadius(12)
    }
    
    private func toast(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.green)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .padding(.top, 10)
        .padding(.horizontal, 30)
    }
    
    // MARK: - LÓGICA
    
    func enviarMensaje() {
        let userMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessage.isEmpty, !estaCargandoIA else { return }

        // 1. Guarda el mensaje del usuario en la BD
        let userMsg = ChatMessage(conversationID: strategicConversationID, content: userMessage, isFromUser: true)
        modelContext.insert(userMsg)
        
        inputText = ""
        estaCargandoIA = true
        isCustomDecisionUnlocked = false
        
        Task {
            let respuesta = generarRespuestaIA(para: userMessage)
            // Simula latencia de IA
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                estaCargandoIA = false
                let aiMsg = ChatMessage(conversationID: strategicConversationID, content: respuesta, isFromUser: false)
                modelContext.insert(aiMsg)
            }
        }
    }
    
    // CEREBRO DE IA v3 (ajustado a modelos actuales)
    func generarRespuestaIA(para mensaje: String) -> String {
        let prompt = mensaje.lowercased()
        var respuesta: String
        
        if prompt.contains("contratar") || prompt.contains("personal") {
            let totalPersonal = personal.count
            let jefes = personal.filter { $0.rol == .jefeDeTaller }.count
            let ayudantes = personal.filter { $0.rol == .ayudante }.count
            let mecanicos = totalPersonal - jefes - ayudantes
            respuesta = "He analizado tu plantilla. Actualmente tienes \(totalPersonal) empleados: \(jefes) Jefes, \(mecanicos) Mecánicos, y \(ayudantes) Ayudantes. Basado en tus \(servicios.count) servicios, te recomiendo contratar otro 'Ayudante' si la carga de trabajo es alta."
            
        } else if prompt.contains("inventario") || prompt.contains("productos") {
            let totalProductos = productos.count
            // cantidad es Double; interpretamos “bajo” como < 10 unidades
            let productosBajos = productos.filter { $0.cantidad < 10.0 }.count
            respuesta = "He analizado tu inventario. Tienes \(totalProductos) tipos de productos. Detecto que \(productosBajos) productos tienen un stock bajo (menos de 10 unidades). Te recomiendo hacer un pedido pronto."
            
        } else if prompt.contains("rentable") || prompt.contains("servicios") {
            let servicioMasCaro = servicios.max(by: { $0.precioAlCliente < $1.precioAlCliente })
            if let servicio = servicioMasCaro {
                let price = String(format: "%.2f", servicio.precioAlCliente)
                respuesta = "He analizado tus \(servicios.count) servicios. Tu servicio más rentable (por mano de obra) es '\(servicio.nombre)', que cobra $\(price). Enfocarse en este servicio podría incrementar ingresos."
            } else {
                respuesta = "No tienes servicios registrados, así que no puedo calcular la rentabilidad."
            }
        } else if prompt.contains("desbloquear") || prompt.contains("manual") || prompt.contains("registrar decisión") {
            respuesta = "Para registrar una decisión manual, presiona el botón 'Escribir Decisión Personalizada'. Se te pedirá autorización con huella o contraseña."
        } else {
            respuesta = "Es una consulta interesante. Basado en tus \(historial.count) decisiones pasadas y tus \(personal.count) empleados, te recomiendo analizar los costos de oportunidad antes de proceder."
        }
        return respuesta
    }
    
    // --- Lógica de Auth/Guardar ---
    func authenticateWithTouchID() async {
        let context = LAContext()
        let reason = "Autoriza con tu huella para registrar una decisión manual."
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
        isCustomDecisionUnlocked = true
        showingAuthModal = false
        authError = ""
        passwordAttempt = ""
    }
    
    func guardarDecision(titulo: String, razon: String, query: String) {
        let tituloTrim = titulo.trimmingCharacters(in: .whitespacesAndNewlines)
        let razonTrim = razon.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tituloTrim.isEmpty, !razonTrim.isEmpty else { return }
        let registro = DecisionRecord(fecha: Date(), titulo: tituloTrim, razon: razonTrim, queryUsuario: query)
        modelContext.insert(registro)
        
        customDecisionText = ""
        isCustomDecisionUnlocked = false
    }
}
