//
//  AIStrategistService.swift
//  DSS
//
//  Created by Jose Cisneros on 26/11/25.
//


import Foundation
import MLXLLM
import MLXLMCommon

@Observable // Usando la macro moderna de Swift (iOS 17/macOS 14+)
class AIStrategistService {
    
    // Estado de la carga del modelo
    var isModelLoaded = false
    var isGenerating = false
    var outputText = ""
    var errorMessage: String?
    
    // Componentes de MLX
    private var modelContainer: ModelContainer?
    private var chatSession: ChatSession?
    
    // Configuración del modelo (Usaremos Llama 3.2 3B por ser potente y ligero para laptops)
    // El ID debe coincidir con un repo de HuggingFace compatible con MLX
    private let modelId = "mlx-community/Llama-3.2-3B-Instruct-4bit"
    
    /// Carga el modelo en memoria. Esto descarga los pesos si no están en caché.
    func loadModel() async {
        do {
            // 1. Cargamos el modelo usando la API de alto nivel
            // Esto busca el modelo en HuggingFace, lo descarga y lo prepara para Apple Silicon
            self.modelContainer = try await MLXLMCommon.loadModelContainer(configuration: ModelConfiguration(id: modelId))
            
            // 2. Iniciamos una sesión de chat (mantiene el contexto)
            if let container = self.modelContainer {
                self.chatSession = ChatSession(container)
                
                await MainActor.run {
                    self.isModelLoaded = true
                    self.errorMessage = nil
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error cargando el modelo: \(error.localizedDescription)"
                print(error)
            }
        }
    }
    
    /// Envía una pregunta al asistente estratégico
    func ask(_ prompt: String) async {
        guard let session = chatSession else { return }
        
        await MainActor.run {
            self.isGenerating = true
            self.outputText = "" // Limpiamos o acumulamos según prefieras
        }
        
        do {
            // La función .respond(to:) maneja la tokenización y la generación
            let response = try await session.respond(to: prompt)
            
            await MainActor.run {
                self.outputText = response
                self.isGenerating = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error generando respuesta: \(error.localizedDescription)"
                self.isGenerating = false
            }
        }
    }
}
