import SwiftUI
import SwiftData
import LocalAuthentication

struct DecisionView: View {
    @Environment(\.modelContext) private var modelContext
    
    // --- Variables de AppStorage ---
    @AppStorage("user_password") private var userPassword = ""
    @AppStorage("isTouchIDEnabled") private var isTouchIDEnabled = true
    
    // --- Estados para la IA (Simulada) ---
    @State private var queryUsuario: String = ""
    @State private var estaCargando = false
    @State private var decisionRecomendada: String?
    @State private var razonamiento: String?

    // --- Estados para la Decisión Manual ---
    @State private var isCustomDecisionUnlocked = false
    @State private var customDecisionText = ""

    // --- Estados para el Modal de Autenticación ---
    @State private var showingAuthModal = false
    @State private var passwordAttempt = ""
    @State private var authError = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                
                // --- 1. Cabecera (Como el mockup) ---
                Text("Toma de Decisiones")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Recomendaciones e información de negocio impulsadas por IA")
                    .font(.title3)
                    .foregroundColor(.gray)
                
                // --- 2. Tarjeta de Consulta (Como el mockup) ---
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .font(.title2)
                            .foregroundColor(Color("MercedesPetrolGreen"))
                        Text("¿Qué quieres hacer hoy?")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Text("Describe tu desafío o meta de negocio y obtén recomendaciones basadas en datos")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("Tu Consulta")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 10)
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $queryUsuario)
                            .frame(minHeight: 150)
                            .font(.body)
                            .background(Color.clear)
                            .cornerRadius(10)
                        
                        if queryUsuario.isEmpty {
                            Text("ej. ¿Debo contratar más personal? ¿Qué productos debo almacenar? ¿Cómo puedo incrementar ingresos?")
                                .font(.body)
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .padding(20)
                .background(Color("MercedesCard"))
                .cornerRadius(15)

                
                // --- 3. Botones (Como el mockup) ---
                HStack(spacing: 15) {
                    Button {
                        generarDecision()
                    } label: {
                        Label("Generar Reporte", systemImage: "doc.text.fill")
                            .font(.headline)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen"))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        showingAuthModal = true
                    } label: {
                        Label("Escribir Decisión Personalizada", systemImage: "pencil")
                            .font(.headline)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Color("MercedesCard"))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                
                // --- 4. Área de Resultados de IA (si existen) ---
                if estaCargando {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let decision = decisionRecomendada, let razon = razonamiento {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Recommended Decision").font(.title2).fontWeight(.bold)
                        Text("Best Decision:").font(.headline).foregroundColor(Color("MercedesPetrolGreen"))
                        Text(decision)
                        Text("Reasoning:").font(.headline).foregroundColor(Color("MercedesPetrolGreen"))
                        Text(razon)
                        
                        Button {
                            guardarDecision(titulo: decision, razon: razon, query: queryUsuario)
                        } label: {
                            Label("Accept & Record Decision", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.4))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .padding(.top)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("MercedesCard"))
                    .cornerRadius(10)
                }
                
                // --- 5. Área de Decisión Manual (si está desbloqueada) ---
                if isCustomDecisionUnlocked {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Write Your Own Decision")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Debe de ser lo más específico posible, ya que esta información será reutilizada para futuras decisiones.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .italic()
                            .padding(.bottom, 5)

                        TextEditor(text: $customDecisionText)
                            .frame(minHeight: 150)
                            .font(.body)
                            .background(Color("MercedesCard"))
                            .cornerRadius(10)
                        
                        Button {
                            guardarDecision(titulo: "Decisión Manual", razon: customDecisionText, query: "N/A (Manual)")
                        } label: {
                            Label("Record This Decision", systemImage: "square.and.arrow.down")
                                .font(.headline)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(Color("MercedesPetrolGreen"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
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
        // --- 6. El Modal de Autenticación ---
        .sheet(isPresented: $showingAuthModal) {
            authModalView(isTouchIDEnabled: isTouchIDEnabled)
        }
    }
    
    // --- Vista para el Modal de Autenticación ---
    @ViewBuilder
    func authModalView(isTouchIDEnabled: Bool) -> some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Verificación Requerida")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Autoriza para registrar una decisión manual.")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .padding(.bottom)
                
                // --- ESTE ES EL BLOQUE CORRECTO ---
                if isTouchIDEnabled {
                    Button {
                        Task { await authenticateWithTouchID() }
                    } label: {
                        Label("Usar Huella (Touch ID)", systemImage: "touchid")
                            .font(.headline).padding().frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                    }.buttonStyle(.plain)
                        
                    Text("o").foregroundColor(.gray)
                }
                
                // --- EL BLOQUE DUPLICADO FUE ELIMINADO ---
                
                // Opción 2: Contraseña
                Text("Usa la contraseña con la que te registraste:")
                    .font(.headline)
                
                SecureField("Contraseña", text: $passwordAttempt)
                    .padding(12)
                    .background(Color("MercedesCard"))
                    .cornerRadius(8)
                
                if !authError.isEmpty {
                    Text(authError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Button {
                    authenticateWithPassword()
                } label: {
                    Label("Autorizar con Contraseña", systemImage: "lock.fill")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
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
    
    // --- Lógica de la Vista ---
    
    func generarDecision() {
        isCustomDecisionUnlocked = false
        decisionRecomendada = nil
        razonamiento = nil
        estaCargando = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            decisionRecomendada = "Invertir en la nueva máquina de diagnóstico."
            razonamiento = "Basado en el análisis de costos, la máquina de $80,000 reduce el tiempo de inspección a la mitad. Esto permite duplicar la capacidad de diagnóstico."
            estaCargando = false
        }
    }
    
    // Nueva Lógica de Autenticación
    
    func authenticateWithTouchID() async {
        let context = LAContext()
        let reason = "Autoriza con tu huella para registrar una decisión manual."

        do {
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                
                if success {
                    await MainActor.run {
                        isCustomDecisionUnlocked = true
                        showingAuthModal = false
                        decisionRecomendada = nil
                        razonamiento = nil
                        queryUsuario = ""
                    }
                }
            }
        } catch {
            await MainActor.run {
                authError = "Huella no reconocida. Intenta con tu contraseña."
            }
        }
    }
    
    func authenticateWithPassword() {
        if passwordAttempt == userPassword {
            isCustomDecisionUnlocked = true
            showingAuthModal = false
            decisionRecomendada = nil
            razonamiento = nil
            queryUsuario = ""
        } else {
            authError = "Contraseña incorrecta. Intenta de nuevo."
            passwordAttempt = ""
        }
    }
    
    func guardarDecision(titulo: String, razon: String, query: String) {
        guard !titulo.isEmpty, !razon.isEmpty else { return }
        let registro = DecisionRecord(fecha: Date(), titulo: titulo, razon: razon, queryUsuario: query)
        modelContext.insert(registro)
        
        queryUsuario = ""
        decisionRecomendada = nil
        razonamiento = nil
        customDecisionText = ""
        isCustomDecisionUnlocked = false
    }
}
