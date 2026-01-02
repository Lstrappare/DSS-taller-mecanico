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
        // Nombre del dueño/cuenta desde AppStorage (UserDefaults)
        let ownerName = (UserDefaults.standard.string(forKey: "user_name") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let ownerLine: String = {
            if ownerName.isEmpty {
                return "0) Cuenta/Dueño: (no configurado) (Rol: Dueño Administrador)"
            } else {
                return "0)Nombre de la Cuenta/Dueño con quien charlarás siempre: \(ownerName) (Rol: Dueño Administrador)"
            }
        }()
        
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
        let serviciosResumen = buildServiciosSummary(servicios, productos: productos)
        let procesoResumen = buildServiciosEnProcesoSummary(tickets)
        let historialResumen = buildHistorialSummary(decisiones)
        
        let prompt =
        """
        Eres un “Asistente Estratégico DSS”, un experto en soporte de decisiones asistente del dueño del taller con quien siempre hablarás. Siempre contesta en español, de manera concisa y con precisión, usa el contexto actual del negocio. Si los datos se pierden, dilo de una manera transparente.

        \(ownerLine)

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
        
        HERRAMIENTAS INTERACTIVAS (IMPORTANTE):
        Tu objetivo no es solo dar texto, sino facilitar la navegación.
        SIEMPRE que el usuario mencione querer VER, EDITAR o GESTIONAR un producto, servicio o empleado ESPECÍFICO, debes incluir al final de tu respuesta una etiqueta especial para generar un botón de acceso directo.
        
        Formatos de etiquetas (úsalos si aplica):
        - Para abrir un producto: [[OPEN:PRODUCT:NombreExacto]]
        - Para abrir un servicio: [[OPEN:SERVICE:NombreExacto]]
        - Para abrir un empleado: [[OPEN:PERSONAL:NombreExacto]]
        - Para programar un servicio nuevo: [[ACTION:SCHEDULE_SERVICE:NombreServicioOpcional]]
        
        Ejemplos:
        Usuario: "Necesito editar el costo del Aceite Sintetico"
        Asistente: "Entendido, aquí tienes el acceso al producto para que actualices su costo. [[OPEN:PRODUCT:Aceite Sintetico]]"
        
        Usuario: "Quiero agendar una Afinación"
        Asistente: "Claro, abre el panel de programación para comenzar. [[ACTION:SCHEDULE_SERVICE:Afinación]]"
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
        
        // Formateadores
        let currency: (Double) -> String = { String(format: "$%.2f", $0) }
        
        // Top 5 Empleados más eficientes (por servicios realizados)
        let topEficientes = arr
            .sorted { $0.serviciosRealizados > $1.serviciosRealizados }
            .prefix(5)
            .map { p in
                "- \(p.nombre) (\(p.rol.rawValue)) | Servicios completados: \(p.serviciosRealizados) | Costo hora: \(currency(p.costoHora))"
            }
            .joined(separator: "\n")
        
        // Suma de costos mensuales de nómina activos
        let totalNomina = arr.filter({ $0.activo }).reduce(0) { $0 + $1.costoRealMensual }
        
        return """
        Total: \(total) | Disponibles ahora: \(disponibles)
        Roles: \(porRol)
        Costo Nómina Mensual Aprox: \(currency(totalNomina))
        
        Top 5 Personal más activo (Servicios Realizados):
        \(topEficientes.isEmpty ? "- Sin datos aún." : topEficientes)
        """
    }
    
    private func buildInventarioSummary(_ arr: [Producto]) -> String {
        if arr.isEmpty { return "- No hay productos." }
        
        // Recaudación estimada (Total Inventory Value)
        let valorTotalInventarioCost = arr.reduce(0) { $0 + ($1.costo * $1.cantidad) }
        let valorTotalInventarioVenta = arr.reduce(0) { $0 + ($1.precioVenta * $1.cantidad) }
        
        // Críticos por stock (<= 2)
        let lowStock = arr
            .filter { $0.cantidad <= 2.0 }
            .sorted { $0.cantidad < $1.cantidad }
            .prefix(5)
            .map { "- \($0.nombre): \($0.cantidad) \($0.unidadDeMedida)" }
            .joined(separator: "\n")
        
        // Top 5 Más Vendidos (vecesVendido)
        let topVendidos = arr
            .sorted { $0.vecesVendido > $1.vecesVendido }
            .prefix(5)
            .map { p in
                "- \(p.nombre) | Vendido: \(p.vecesVendido) veces | Stock actual: \(p.cantidad)"
            }
            .joined(separator: "\n")
        
        return """
        Total items: \(arr.count)
        Valor Total Costo: $\(String(format: "%.2f", valorTotalInventarioCost))
        Valor Total Venta Potencial: $\(String(format: "%.2f", valorTotalInventarioVenta))
        
        Críticos (Stock Bajo):
        \(lowStock.isEmpty ? "Ninguno" : lowStock)
        
        Top 5 Más Vendidos:
        \(topVendidos.isEmpty ? "- Sin ventas registradas aún." : topVendidos)
        """
    }
    
    private func buildServiciosSummary(_ servicios: [Servicio], productos: [Producto]) -> String {
        if servicios.isEmpty { return "- No hay servicios." }
        
        func fmt(_ v: Double) -> String { String(format: "%.2f", v) }
        
        // Top 5 Servicios más populares (vecesRealizado)
        let topServicios = servicios
            .sorted { $0.vecesRealizado > $1.vecesRealizado }
            .prefix(5)
            .map { s in
                let gananciaNeta = s.precioFinalAlCliente - s.costoManoDeObra - s.costoRefacciones - PricingHelpers.costoIngredientes(servicio: s, productos: productos) - s.gastosAdministrativos
                // Nota: Cálculo simplificado para el contexto
                return "- \(s.nombre) | Realizado: \(s.vecesRealizado) veces | Precio: $\(fmt(s.precioFinalAlCliente)) | Ganancia Est. Unit: $\(fmt(gananciaNeta))"
            }
            .joined(separator: "\n")
            
        // Catálogo General (nombres y precios)
        let catalogoSimple = servicios.map { "\($0.nombre) [$\(fmt($0.precioFinalAlCliente))]" }.joined(separator: ", ")
        
        return """
        Total Servicios en Catálogo: \(servicios.count)
        
        Top 5 Servicios más solicitados:
        \(topServicios.isEmpty ? "- Sin historial de servicios." : topServicios)
        
        Lista rápida: \(catalogoSimple)
        """
    }
    
    private func buildServiciosEnProcesoSummary(_ arr: [ServicioEnProceso]) -> String {
        if arr.isEmpty { return "- Sin actividad." }
        
        let enProceso = arr.filter { $0.estado == .enProceso }
            .sorted { $0.horaFinEstimada < $1.horaFinEstimada }
        let programados = arr.filter { $0.estado == .programado }
            .sorted { (a, b) in
                let ai = a.fechaProgramadaInicio ?? a.horaInicio
                let bi = b.fechaProgramadaInicio ?? b.horaInicio
                return ai < bi
            }
        
        let header = "Total tickets: \(arr.count) | En proceso activo: \(enProceso.count) | Programados: \(programados.count)"
        
        // Detalle de EN PROCESO (máx. 10)
        let detalleEnProceso: String = {
            guard !enProceso.isEmpty else { return "- En proceso: Ninguno" }
            let items = enProceso.prefix(10).map { s in
                let inicio = s.horaInicio.formatted(date: .abbreviated, time: .shortened)
                let fin = s.horaFinEstimada.formatted(date: .omitted, time: .shortened)
                let mecanico = s.nombreMecanicoAsignado
                let vehiculo = s.vehiculo?.placas ?? "N/A"
                return "• \(s.nombreServicio) | Mecánico: \(mecanico) | Vehículo: [\(vehiculo)] | Inicio: \(inicio) | Fin est.: \(fin)"
            }
            return items.joined(separator: "\n")
        }()
        
        // Detalle de PROGRAMADOS (máx. 10)
        let detalleProgramados: String = {
            guard !programados.isEmpty else { return "- Programados: Ninguno" }
            let items = programados.prefix(10).map { s in
                let inicioProg = (s.fechaProgramadaInicio ?? s.horaInicio).formatted(date: .abbreviated, time: .shortened)
                let mecanico = s.nombreMecanicoSugerido ?? s.nombreMecanicoAsignado
                let vehiculo = s.vehiculo?.placas ?? "N/A"
                return "• \(s.nombreServicio) | Sugerido: \(mecanico) | Vehículo: [\(vehiculo)] | Inicio prog.: \(inicioProg) | Duración: \(String(format: "%.1f", s.duracionHoras)) h"
            }
            return items.joined(separator: "\n")
        }()
        
        return """
        \(header)
        En proceso:
        \(detalleEnProceso)
        Programados:
        \(detalleProgramados)
        """
    }
    
    private func buildServiciosEnProcesoSummary(_ arrAntiguo: [ServicioEnProceso], limit _: Int = 10) -> String {
        // Duplicado accidentalmente para evitar romper referencias si existieran; mantenemos solo el nuevo arriba.
        // Esta versión no se usa.
        return buildServiciosEnProcesoSummary(arrAntiguo)
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
