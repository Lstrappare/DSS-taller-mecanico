import SwiftUI
import SwiftData
import LocalAuthentication // ¡Importante para la huella!

struct ConsultaView: View {
    @Environment(\.modelContext) private var modelContext
    
    // --- Variables de AppStorage ---
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true

    // --- States para la IA (Simulada) ---
    @State private var queryUsuario: String = ""
    @State private var estaCargando = false
    @State private var decisionRecomendada: String?
    @State private var razonamiento: String?

    // --- States para la Decisión Manual ---
    @State private var isCustomDecisionUnlocked = false
    @State private var customDecisionText = ""

    // --- States para el Modal de Autenticación ---
    @State private var showingAuthModal = false
    @State private var passwordAttempt = ""
    @State private var authError = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                
                // --- 1. Cabecera ---
                Text("Consulta de Negocio")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Text("Análisis de IA y registro manual de decisiones")
                    .font(.title3).foregroundColor(.gray)
                
                // --- 2. Tarjeta de Consulta IA (Simulada) ---
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .font(.title2).foregroundColor(Color("MercedesPetrolGreen"))
                        Text("¿Qué quieres consultar hoy?")
                            .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    }
                    Text("Describe tu desafío o meta (ej. '¿Debo contratar más personal?', '¿Cómo puedo incrementar ingresos?')")
                        .font(.subheadline).foregroundColor(.gray)
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $queryUsuario)
                            .frame(minHeight: 150)
                            .font(.body)
                            .background(Color.clear)
                            .cornerRadius(10)
                        
                        if queryUsuario.isEmpty {
                            Text("Tu consulta...")
                                .font(.body).foregroundColor(.gray.opacity(0.6))
                                .padding(.top, 8).padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .padding(20)
                .background(Color("MercedesCard"))
                .cornerRadius(15)
                
                // --- 3. Botones ---
                HStack(spacing: 15) {
                    // Botón de Generar Reporte (IA)
                    Button {
                        generarReporteIA()
                    } label: {
                        Label("Generar Reporte", systemImage: "doc.text.fill")
                            .font(.headline).padding(.vertical, 10).frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(queryUsuario.isEmpty || estaCargando)
                    
                    // Botón de Escribir Decisión Manual
                    Button {
                        showingAuthModal = true
                    } label: {
                        Label("Escribir Decisión Personalizada", systemImage: "pencil")
                            .font(.headline).padding(.vertical, 10).frame(maxWidth: .infinity)
                            .background(Color("MercedesCard")).foregroundColor(.white).cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                // --- 4. Área de Resultados (IA o Manual) ---
                
                // Resultado de la IA
                if estaCargando {
                    ProgressView()
                        .frame(maxWidth: .infinity).padding()
                } else if let decision = decisionRecomendada, let razon = razonamiento {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Recomendación de la IA").font(.title2).fontWeight(.bold)
                        Text("Best Decision:").font(.headline).foregroundColor(Color("MercedesPetrolGreen"))
                        Text(decision)
                        Text("Reasoning:").font(.headline).foregroundColor(Color("MercedesPetrolGreen"))
                        Text(razon)
                        
                        // Botón para guardar la decisión de la IA
                        Button {
                            guardarDecision(titulo: decision, razon: razon, query: queryUsuario)
                        } label: {
                            Label("Accept & Record Decision", systemImage: "checkmark.circle.fill")
                                .font(.headline).padding(.vertical, 10).frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.4)).foregroundColor(.white).cornerRadius(8)
                        }
                        .buttonStyle(.plain).padding(.top)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("MercedesCard"))
                    .cornerRadius(10)
                }
                
                // Área de Decisión Manual
                if isCustomDecisionUnlocked {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Write Your Own Decision")
                            .font(.title2).fontWeight(.bold)
                        Text("Debe de ser lo más específico posible, ya que esta información será reutilizada para futuras decisiones.")
                            .font(.subheadline).foregroundColor(.gray).italic().padding(.bottom, 5)
                        TextEditor(text: $customDecisionText)
                            .frame(minHeight: 150)
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
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("MercedesCard").opacity(0.5))
                    .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding(30)
        }
        .sheet(isPresented: $showingAuthModal) {
            authModalView(isTouchIDEnabled: isTouchIDEnabled)
        }
    }
    
    // --- Vista para el Modal de Autenticación ---
    // (Copiada de DecisionView/AccountSettingsView)
    @ViewBuilder
    func authModalView(isTouchIDEnabled: Bool) -> some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Verificación Requerida")
                    .font(.largeTitle).fontWeight(.bold)
                Text("Autoriza para registrar una decisión manual.")
                    .font(.title3).foregroundColor(.gray).padding(.bottom)
                
                if isTouchIDEnabled {
                    Button { Task { await authenticateWithTouchID() } }
                    label: {
                        Label("Usar Huella (Touch ID)", systemImage: "touchid")
                            .font(.headline).padding().frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                    }.buttonStyle(.plain)
                    Text("o").foregroundColor(.gray)
                }
                
                Text("Usa la contraseña con la que te registraste:").font(.headline)
                SecureField("Contraseña", text: $passwordAttempt)
                    .padding(12).background(Color("MercedesCard")).cornerRadius(8)
                
                if !authError.isEmpty {
                    Text(authError).font(.caption).foregroundColor(.red)
                }
                
                Button { authenticateWithPassword() }
                label: {
                    Label("Autorizar con Contraseña", systemImage: "lock.fill")
                        .font(.headline).padding().frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.4)).foregroundColor(.white).cornerRadius(8)
                }.buttonStyle(.plain)
            }
            .padding(40)
        }
        .frame(minWidth: 500, minHeight: 450)
        .preferredColorScheme(.dark)
        .onAppear {
            authError = ""
            passwordAttempt = ""
        }
    }
    
    // --- LÓGICA DE LA VISTA ---
    
    // Simula una respuesta de IA para preguntas generales
    func generarReporteIA() {
        isCustomDecisionUnlocked = false
        decisionRecomendada = nil
        razonamiento = nil
        estaCargando = true
        
        // Simulación
        let prompt = queryUsuario.lowercased()
        var respuesta = "Basado en tus datos, esta es una recomendación genérica."
        
        if prompt.contains("contratar") {
            respuesta = "Analizando tu carga de trabajo actual, contratar más personal podría aumentar tu capacidad de servicio en un 25%, pero reduciría tu margen de ganancia a corto plazo."
        } else if prompt.contains("ingresos") {
            respuesta = "Para incrementar ingresos, considera subir el precio de los 'Servicios de Motor' un 10%. Es tu categoría más solicitada y con mayor margen."
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            decisionRecomendada = "Análisis de: '\(queryUsuario)'"
            razonamiento = respuesta
            estaCargando = false
        }
    }
    
    // Lógica de Autenticación para el botón manual
    
    func authenticateWithTouchID() async {
        let context = LAContext()
        let reason = "Autoriza con tu huella para registrar una decisión manual."
        do {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                if success {
                    await MainActor.run { onAuthSuccess() }
                }
            }
        } catch {
            await MainActor.run { authError = "Huella no reconocida." }
        }
    }
    
    func authenticateWithPassword() {
        if passwordAttempt == userPassword {
            onAuthSuccess()
        } else {
            authError = "Contraseña incorrecta."
            passwordAttempt = ""
        }
    }
    
    // Se llama cuando la huella O la contraseña son correctas
    func onAuthSuccess() {
        // Resetea la IA
        decisionRecomendada = nil
        razonamiento = nil
        queryUsuario = ""
        // Muestra la sección manual
        isCustomDecisionUnlocked = true
        showingAuthModal = false
    }
    
    // Guarda la decisión (de la IA o Manual) en el Historial
    func guardarDecision(titulo: String, razon: String, query: String) {
        guard !titulo.isEmpty, !razon.isEmpty else { return }
        let registro = DecisionRecord(fecha: Date(), titulo: titulo, razon: razon, queryUsuario: query)
        modelContext.insert(registro)
        
        // Limpiar toda la UI
        queryUsuario = ""
        decisionRecomendada = nil
        razonamiento = nil
        customDecisionText = ""
        isCustomDecisionUnlocked = false
    }
}
