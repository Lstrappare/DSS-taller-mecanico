//
//  ChatMessage.swift
//  DSS
//
//  Created by Jose Cisneros on 04/11/25.
//

import SwiftUI

// Un modelo simple para cada mensaje en el chat
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
}

struct ConsultaView: View {
    
    // Aquí se guardarán todos los mensajes del chat
    @State private var messages: [ChatMessage] = [
        // El mensaje de bienvenida de la IA (como en tu captura)
        ChatMessage(content: "¡Hola! Soy tu asistente de IA para consultas de negocio. Puedo ayudarte a explorar datos, analizar escenarios hipotéticos y responder preguntas sobre tu negocio. ¿En qué puedo ayudarte hoy?", isFromUser: false)
    ]
    
    @State private var inputText = "" // El texto que el usuario escribe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // --- Cabecera ---
            Text("Consulta sobre el negocio")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.bottom, 5)
            
            // --- Leyenda Principal (la que pediste) ---
            Text("Chat exploratorio con IA – Las conversaciones no se guardan en el historial de decisiones")
                .font(.title3)
                .foregroundColor(.gray)
                .padding(.bottom, 20)

            // --- Área del Chat ---
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                        }
                    }
                    .padding(.top, 10)
                }
                .onChange(of: messages.count) {
                    // Auto-scroll al último mensaje
                    // Encolar al siguiente ciclo del runloop para asegurar que la vista esté actualizada
                    DispatchQueue.main.async {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
            }

            // --- Barra de Entrada de Texto ---
            HStack(spacing: 15) {
                // Icono (como en tu captura)
                Image(systemName: "sparkles") // O "wand.and.stars"
                    .foregroundColor(Color("MercedesPetrolGreen"))

                // Campo de texto
                TextField("Escribe tu consulta...", text: $inputText)
                    .textFieldStyle(.plain)
                    .onSubmit(sendMessage) // Enviar con 'Enter'
                
                // Botón de Enviar
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.title2)
                        .foregroundColor(Color("MercedesPetrolGreen"))
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)
            }
            .padding(15)
            .background(Color("MercedesCard"))
            .cornerRadius(10)
            .padding(.vertical, 10)

            // --- Leyenda Inferior (la que pediste) ---
            Text("Modo exploratorio - No se guardan las conversaciones")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.bottom, 20)
            
            // --- Tarjetas de Información (como en tu captura) ---
            HStack(spacing: 15) {
                InfoCardView(icono: "sparkles.square.filled.on.square", titulo: "Consultas Exploratorias", texto: "Pregunta sobre datos sin afectar tu negocio")
                InfoCardView(icono: "brain.head.profile", titulo: "Análisis IA", texto: "Respuestas instantáneas basadas en tus datos")
                InfoCardView(icono: "nosign", titulo: "Sin Guardar", texto: "Las conversaciones no se registran")
            }
            
            Spacer()
        }
        .padding(30)
    }
    
    // --- Lógica del Chat ---
    func sendMessage() {
        let userMessage = inputText
        if userMessage.isEmpty { return }
        
        // 1. Añade el mensaje del usuario
        messages.append(ChatMessage(content: userMessage, isFromUser: true))
        inputText = ""
        
        // 2. Simula la respuesta de la IA
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let aiResponse = "Esta es una respuesta simulada sobre: '\(userMessage)'. Recuerda que esto es solo exploratorio y no se guardará."
            messages.append(ChatMessage(content: aiResponse, isFromUser: false))
        }
    }
}

// --- Vista Reutilizable: Burbuja de Chat ---
struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer() // Empuja el mensaje del usuario a la derecha
                Text(message.content)
                    .padding(12)
                    .background(Color("MercedesPetrolGreen"))
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .frame(maxWidth: 600, alignment: .trailing)
            } else {
                // Mensaje de la IA (con ícono, como en tu captura)
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
                Spacer() // Empuja el mensaje de la IA a la izquierda
            }
        }
    }
}

// --- Vista Reutilizable: Tarjeta de Información ---
struct InfoCardView: View {
    var icono: String
    var titulo: String
    var texto: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icono)
                .font(.title2)
                .foregroundColor(Color("MercedesPetrolGreen"))
            Text(titulo)
                .font(.headline)
                .foregroundColor(.white)
            Text(texto)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(Color("MercedesCard"))
        .cornerRadius(10)
    }
}
