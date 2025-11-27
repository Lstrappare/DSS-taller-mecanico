//
//  AIStrategistService.swift
//  DSS
//
//  Created by Jose Cisneros on 26/11/25.
//

import Foundation
import MLXLLM
import MLXLMCommon
internal import Combine
import SwiftData

// Usamos @Observable (macro moderna) para simplificar, o ObservableObject si prefieres el estilo clásico.
// Aquí mantengo ObservableObject como lo tenías, pero añadimos el Singleton.
final class AIStrategistService: ObservableObject {
    
    // --- SINGLETON (Para que no se reinicie al cambiar de vistas) ---
    static let shared = AIStrategistService()
    // ---------------------------------------------------------------
    
    // Estado de la carga del modelo
    @Published var isModelLoaded = false
    @Published var isGenerating = false
    @Published var outputText = ""
    @Published var errorMessage: String?
    
    // Prompt maestro (contexto de negocio)
    @Published private(set) var systemPrompt: String = ""
    
    // Componentes de MLX
    // CORRECCIÓN 1: Especificamos que este ModelContainer es de la librería MLXLMCommon
    private var modelContainer: MLXLMCommon.ModelContainer?
    private var chatSession: ChatSession?
    
    // Configuración del modelo
    private let modelId = "mlx-community/Llama-3.2-3B-Instruct-4bit"
    
    private init() {} // Constructor privado para forzar el uso de 'shared'
    
    /// Carga el modelo en memoria.
    @MainActor
    func loadModel() async {
        // Si ya está cargado, no hacemos nada
        if isModelLoaded { return }
        
        do {
            // CORRECCIÓN 2: Aquí MLXLMCommon ya sabe qué devolver, pero es bueno ser explícito
            self.modelContainer = try await MLXLMCommon.loadModelContainer(configuration: ModelConfiguration(id: modelId))
            
            if let container = self.modelContainer {
                self.chatSession = ChatSession(container) // Nota: ChatSession suele pedir 'model:', verifica si en tu versión es 'init(_ model:)' o 'init(model:)'
                self.isModelLoaded = true
                self.errorMessage = nil
            }
        } catch {
            self.errorMessage = "Error cargando el modelo: \(error.localizedDescription)"
            print(error)
        }
    }
    
    /// Intenta arrancar el modelo si no está cargado.
    @discardableResult
    func autoStartIfPossible() async -> Bool {
        if isModelLoaded { return true }
        await loadModel()
        return isModelLoaded
    }
    
    // MARK: - System Prompt
    
    func setSystemPrompt(_ text: String) {
        self.systemPrompt = text
    }
    
    /// Reconstruye el prompt maestro con la información clave del negocio.
    // CORRECCIÓN 3: Especificamos que este ModelContext es de la base de datos (SwiftData)
    func refreshMasterContext(modelContext: SwiftData.ModelContext) async {
        
        // Fetch sincronizados (rápidos y resumidos).
        let personales: [Personal] = (try? modelContext.fetch(FetchDescriptor<Personal>())) ?? []
        let productos: [Producto] = (try? modelContext.fetch(FetchDescriptor<Producto>())) ?? []
        let servicios: [Servicio] = (try? modelContext.fetch(FetchDescriptor<Servicio>())) ?? []
        let tickets: [ServicioEnProceso] = (try? modelContext.fetch(FetchDescriptor<ServicioEnProceso>())) ?? []
        
        // Últimas 20 decisiones
        var decFetch = FetchDescriptor<DecisionRecord>(sortBy: [SortDescriptor(\.fecha, order: .reverse)])
        decFetch.fetchLimit = 20
        let decisiones: [DecisionRecord] = (try? modelContext.fetch(decFetch)) ?? []
        
        // Reducir y sintetizar
        let personalResumen = buildPersonalSummary(personales)
        let inventarioResumen = buildInventarioSummary(productos)
        let serviciosResumen = buildServiciosSummary(servicios)
        let procesoResumen = buildServiciosEnProcesoSummary(tickets)
        let historialResumen = buildHistorialSummary(decisiones)
        
        let prompt =
        """
        Eres un “Asistente Estratégico DSS”, un experto en soporte de decisiones asistente del dueño o administrador del taller. Siempre contesta en español, de manera concisa y con precisión, usa el contexto actual del negocio. Si los datos se pierden, dilo de una manera transparente.

        CONTEXTO DEL NEGOCIO (Actualizado):
        1) Personal:
        \(personalResumen)

        2) Inventario (top críticos y totales):
        \(inventarioResumen)

        3) Servicios en Catálogo:
        \(serviciosResumen)

        4) Servicios Programados / En Proceso:
        \(procesoResumen)

        5) Últimas decisiones registradas:
        \(historialResumen)

        Reglas:
        - No inventes datos fuera del contexto.
        - Si se solicita cálculo, explica en 1-3 pasos y da recomendación clara.
        - Si falta stock o personal, sugiere acciones concretas.
        - Mantén la respuesta breve.
        """
        
        await MainActor.run {
            self.systemPrompt = prompt
        }
    }
    
    // MARK: - Helper Builders (Sin cambios, solo copiados para integridad)
    
    private func buildPersonalSummary(_ arr: [Personal]) -> String {
        if arr.isEmpty { return "- No hay personal registrado." }
        let total = arr.count
        let disponibles = arr.filter { $0.estado == .disponible && $0.estaEnHorario }.count
        let porRol = Dictionary(grouping: arr, by: { $0.rol.rawValue })
            .map { "\($0.key): \($0.value.count)" }
            .sorted()
            .joined(separator: " | ")
        let top3 = arr.prefix(3).map { "- \($0.nombre) [\($0.rol.rawValue)] Estado: \($0.estado.rawValue)" }.joined(separator: "\n")
        return "Total: \(total) | Disponibles: \(disponibles)\nRoles: \(porRol)\nEjemplos:\n\(top3)"
    }
    
    private func buildInventarioSummary(_ arr: [Producto]) -> String {
        if arr.isEmpty { return "- No hay productos." }
        let lowStock = arr.filter { $0.cantidad <= 2.0 }.sorted { $0.cantidad < $1.cantidad }.prefix(5)
            .map { "- \($0.nombre): \($0.cantidad) \($0.unidadDeMedida)" }.joined(separator: "\n")
        return "Total: \(arr.count)\nCríticos:\n\(lowStock.isEmpty ? "Ninguno" : lowStock)"
    }
    
    private func buildServiciosSummary(_ arr: [Servicio]) -> String {
        if arr.isEmpty { return "- No hay servicios." }
        let top5 = arr.prefix(5).map { "- \($0.nombre) ($\($0.precioFinalAlCliente))" }.joined(separator: "\n")
        return "Total: \(arr.count)\nEjemplos:\n\(top5)"
    }
    
    private func buildServiciosEnProcesoSummary(_ arr: [ServicioEnProceso]) -> String {
        if arr.isEmpty { return "- Sin actividad." }
        let activos = arr.filter { $0.estado == .enProceso }
        return "Total tickets: \(arr.count) | En proceso activo: \(activos.count)"
    }
    
    private func buildHistorialSummary(_ arr: [DecisionRecord]) -> String {
        if arr.isEmpty { return "- Sin historial." }
        return arr.prefix(5).map { "- \($0.fecha.formatted(date: .numeric, time: .omitted)): \($0.titulo)" }.joined(separator: "\n")
    }
    
    // MARK: - Chat
    
    func ask(_ prompt: String) async {
        await ask(prompt, withSystemOverride: nil)
    }
    
    func ask(_ prompt: String, withSystemOverride systemOverride: String?) async {
        guard let session = chatSession else { return }
        
        await MainActor.run {
            self.isGenerating = true
            self.outputText = ""
        }
        
        do {
            let system = (systemOverride ?? systemPrompt).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Construimos el prompt final combinando System + User
            // Nota: Llama 3 suele usar formatos específicos, pero texto plano con indicadores funciona bien.
            let composedPrompt: String
            if system.isEmpty {
                composedPrompt = prompt
            } else {
                composedPrompt = """
                <|begin_of_text|><|start_header_id|>system<|end_header_id|>
                \(system)
                <|eot_id|><|start_header_id|>user<|end_header_id|>
                \(prompt)
                <|eot_id|><|start_header_id|>assistant<|end_header_id|>
                """
            }
            
            let response = try await session.respond(to: composedPrompt)
            
            await MainActor.run {
                self.outputText = response
                self.isGenerating = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error: \(error.localizedDescription)"
                self.isGenerating = false
            }
        }
    }
}
