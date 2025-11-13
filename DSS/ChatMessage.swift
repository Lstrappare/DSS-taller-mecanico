import SwiftUI
import SwiftData
import LocalAuthentication

// ID Constante para el chat
private let strategicConversationID = UUID()

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
    
    // --- States para la Decisión Manual ---
    @State private var isCustomDecisionUnlocked = false
    @State private var customDecisionText = ""
    @State private var showingAuthModal = false
    @State private var passwordAttempt = ""
    @State private var authError = ""
    
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
            VStack(alignment: .leading) {
                Text("Asistente Estratégico")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Text("Chat con IA. El historial se guarda en la base de datos.")
                    .font(.title3).foregroundColor(.gray).padding(.bottom)
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            // Mensaje de bienvenida (no se guarda, es solo UI)
                            ChatBubbleView(message: ChatMessage(conversationID: conversationID, content: "¡Hola! Soy tu asistente. Tengo acceso a tus datos de Personal, Productos y Servicios. ¿En qué puedo ayudarte hoy?", isFromUser: false))
                            
                            // Mensajes guardados
                            ForEach(conversation) { message in
                                ChatBubbleView(message: message)
                            }
                            
                            if estaCargandoIA {
                                ChatBubbleView(message: ChatMessage(conversationID: conversationID, content: "...", isFromUser: false))
                            }
                        }
                        .padding(.top, 10)
                    }
                    .onChange(of: conversation.count) {
                        proxy.scrollTo(conversation.last?.id, anchor: .bottom)
                    }
                }
                
                // Barra de Entrada
                HStack(spacing: 15) {
                    TextField("Escribe tu consulta...", text: $inputText, onCommit: enviarMensaje)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(12)
                        .background(Color("MercedesCard"))
                        .cornerRadius(8)
                    
                    Button(action: enviarMensaje) {
                        Image(systemName: "paperplane.fill")
                            .font(.title2)
                            .foregroundColor(Color("MercedesPetrolGreen"))
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty || estaCargandoIA)
                }
            }
            .padding(30)
            
            
            // --- Columna 2: Decisión Manual ---
            VStack(alignment: .leading) {
                Text("Registro Manual")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Text("Registra una decisión estratégica manualmente.")
                    .font(.title3).foregroundColor(.gray).padding(.bottom)
                
                Button {
                    showingAuthModal = true
                } label: {
                    Label("Escribir Decisión Personalizada", systemImage: "pencil")
                        .font(.headline).padding(.vertical, 10).frame(maxWidth: .infinity)
                        .background(Color("MercedesCard")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                if isCustomDecisionUnlocked {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Detalla tu decisión")
                            .font(.headline).foregroundColor(.white)
                        Text("Esta decisión se guardará en tu Historial.")
                            .font(.subheadline).foregroundColor(.gray).italic().padding(.bottom, 5)
                        TextEditor(text: $customDecisionText)
                            .frame(minHeight: 150, maxHeight: .infinity)
                            .font(.body)
                            .background(Color("MercedesCard"))
                            .cornerRadius(10)
                        Button {
                            guardarDecision(titulo: "Decisión Manual", razon: customDecisionText, query: "N/A (Manual)")
                        } label: {
                            Label("Record This Decision", systemImage: "square.and.arrow.down")
                                .font(.headline).padding(.vertical, 10).frame(maxWidth: .infinity)
                                .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 20)
                }
                Spacer()
            }
            .padding(30)
        }
        .sheet(isPresented: $showingAuthModal) {
            authModalView(isTouchIDEnabled: isTouchIDEnabled)
        }
    }
    
    // --- VISTA: Burbuja de Chat ---
    @ViewBuilder
    func ChatBubbleView(message: ChatMessage) -> some View {
        HStack {
            if message.isFromUser {
                Spacer()
                Text(message.content)
                    .padding(12)
                    .background(Color("MercedesPetrolGreen"))
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .frame(maxWidth: 600, alignment: .trailing)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "robot")
                        .font(.title)
                        .padding(8)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())
                    Text(message.content)
                        .padding(12)
                        .background(Color("MercedesCard"))
                        .cornerRadius(15)
                }
                .frame(maxWidth: 600, alignment: .leading)
                Spacer()
            }
        }
    }
    
    // --- VISTA: Modal de Autenticación ---
    @ViewBuilder
    func authModalView(isTouchIDEnabled: Bool) -> some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Verificación Requerida").font(.largeTitle).fontWeight(.bold)
                Text("Autoriza para registrar una decisión manual.").font(.title3).foregroundColor(.gray).padding(.bottom)
                if isTouchIDEnabled {
                    Button(action: { Task { await authenticateWithTouchID() } }) {
                        Label("Usar Huella (Touch ID)", systemImage: "touchid")
                            .font(.headline).padding().frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    Text("o").foregroundColor(.gray)
                }
                Text("Usa la contraseña con la que te registraste:").font(.headline)
                SecureField("Contraseña", text: $passwordAttempt)
                    .padding(12).background(Color("MercedesCard")).cornerRadius(8)
                if !authError.isEmpty {
                    Text(authError).font(.caption).foregroundColor(.red)
                }
                Button(action: { authenticateWithPassword() }) {
                    Label("Autorizar con Contraseña", systemImage: "lock.fill")
                        .font(.headline).padding().frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.4)).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(40)
        }
        .frame(minWidth: 500, minHeight: 450)
        .preferredColorScheme(.dark)
        .onAppear { authError = ""; passwordAttempt = "" }
    }
    
    // --- LÓGICA DE LA VISTA (¡ACTUALIZADA!) ---
    
    func enviarMensaje() {
        let userMessage = inputText
        guard !userMessage.isEmpty else { return }

        // 1. Guarda el mensaje del usuario en la BD
        let userMsg = ChatMessage(conversationID: strategicConversationID, content: userMessage, isFromUser: true)
        modelContext.insert(userMsg)
        
        inputText = ""
        estaCargandoIA = true
        isCustomDecisionUnlocked = false
        
        // --- 2. CEREBRO DE IA v3 (ACTUALIZADO) ---
        let prompt = userMessage.lowercased()
        var respuesta: String
        
        if prompt.contains("contratar") || prompt.contains("personal") {
            let totalPersonal = personal.count
            // ¡Lógica actualizada a Roles!
            let jefes = personal.filter { $0.rol == .jefeDeTaller }.count
            let ayudantes = personal.filter { $0.rol == .ayudante }.count
            let mecanicos = totalPersonal - jefes - ayudantes // (Asumiendo que el resto son mecánicos)
            respuesta = "He analizado tu plantilla. Actualmente tienes \(totalPersonal) empleados: \(jefes) Jefes, \(mecanicos) Mecánicos, y \(ayudantes) Ayudantes. Basado en tus \(servicios.count) servicios, te recomiendo contratar otro 'Ayudante' si la carga de trabajo es alta."
            
        } else if prompt.contains("inventario") || prompt.contains("productos") {
            let totalProductos = productos.count
            // ¡Lógica actualizada a Cantidad! (ya no usa 'disponibilidad')
            let productosBajos = productos.filter { $0.cantidad < 10 }.count // (Nueva métrica: menos de 10 unidades)
            respuesta = "He analizado tu inventario. Tienes \(totalProductos) tipos de productos. Detecto que \(productosBajos) productos tienen un stock bajo (menos de 10 unidades). Te recomiendo hacer un pedido pronto."
            
        } else if prompt.contains("rentable") || prompt.contains("servicios") {
            // (Esta lógica sigue funcionando)
            let servicioMasCaro = servicios.max(by: { $0.precioAlCliente < $1.precioAlCliente })
            if let servicio = servicioMasCaro {
                let price = String(format: "%.2f", servicio.precioAlCliente)
                respuesta = "He analizado tus \(servicios.count) servicios. Tu servicio más rentable (por mano de obra) es '\(servicio.nombre)', que cobra $\(price). Enfocarse en este servicio podría incrementar ingresos."
            } else {
                respuesta = "No tienes servicios registrados, así que no puedo calcular la rentabilidad."
            }
            
        } else {
            // (Esta lógica sigue funcionando)
            respuesta = "Es una consulta interesante. Basado en tus \(historial.count) decisiones pasadas y tus \(personal.count) empleados, te recomiendo analizar los costos de oportunidad antes de proceder."
        }
        
        // 3. Guarda la respuesta de la IA en la BD
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            estaCargandoIA = false
            let aiMsg = ChatMessage(conversationID: strategicConversationID, content: respuesta, isFromUser: false)
            modelContext.insert(aiMsg)
        }
    }
    
    // --- Lógica de Auth/Guardar (Sin cambios) ---
    
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
    }
    
    func guardarDecision(titulo: String, razon: String, query: String) {
        guard !titulo.isEmpty, !razon.isEmpty else { return }
        let registro = DecisionRecord(fecha: Date(), titulo: titulo, razon: razon, queryUsuario: query)
        modelContext.insert(registro)
        
        customDecisionText = ""
        isCustomDecisionUnlocked = false
    }
}
