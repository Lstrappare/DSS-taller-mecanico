//
//  StrategicAIService.swift
//  DSS
//
//  Created by Jose Cisneros on 25/11/25.
//
import llama

import Foundation

actor StrategicAIService {
    private var llamaContext: LlamaContext?
    
    init() {
        // Inicialización diferida
    }
    
    // 1. Cargar el modelo (Hacerlo al iniciar la app o la primera vez que se abre el chat)
    func initializeModel() throws {
        guard let modelPath = Bundle.main.path(forResource: "Meta-Llama-3.1-8B-Instruct-Q4_K_M", ofType: "gguf") else {
            throw NSError(domain: "DSS", code: 404, userInfo: [NSLocalizedDescriptionKey: "Modelo no encontrado en el Bundle"])
        }
        
        // Configuración para M1 (Metal)
        // ngl = n-gpu-layers. Un valor alto (ej. 99) fuerza todo a la GPU/Neural Engine
        self.llamaContext = try LlamaContext.create_context(path: modelPath, n_ctx: 2048, n_gpu_layers: 99) 
    }
    
    // 2. Generar respuesta
    func query(systemPrompt: String, userMessage: String) async throws -> String {
        guard let context = llamaContext else {
            try initializeModel()
            return try await query(systemPrompt: systemPrompt, userMessage: userMessage)
        }
        
        // Formato de Prompt para Llama 3 (Tokens especiales)
        let fullPrompt = """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>
        \(systemPrompt)
        <|eot_id|><|start_header_id|>user<|end_header_id|>
        \(userMessage)
        <|eot_id|><|start_header_id|>assistant<|end_header_id|>
        """
        
        // Ejecutar inferencia (la sintaxis exacta depende del wrapper que uses)
        let response = await context.completion_init(text: fullPrompt)
        return response
    }
}
