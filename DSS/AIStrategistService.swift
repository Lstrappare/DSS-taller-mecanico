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
                return "0)Nombre de la Cuenta/Dueño con quien charlas: \(ownerName) (Rol: Dueño Administrador)"
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
        Eres un “Asistente Estratégico DSS”, un experto en soporte de decisiones asistente del dueño del taller. Siempre contesta en español, de manera concisa y con precisión, usa el contexto actual del negocio. Si los datos se pierden, dilo de una manera transparente.

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
        let dateFmt: (Date) -> String = { $0.formatted(date: .abbreviated, time: .omitted) }
        let antiguedad: (Date) -> String = { fecha in
            let comps = Calendar.current.dateComponents([.year, .month], from: fecha, to: Date())
            let y = comps.year ?? 0
            let m = comps.month ?? 0
            if y > 0 { return "\(y)a \(m)m" }
            return "\(m)m"
        }
        
        // Top 5 por mayor costo mensual (más relevantes para decisiones)
        let top = arr.sorted { $0.costoRealMensual > $1.costoRealMensual }.prefix(5).map { p in
            var ficha = "- \(p.nombre) [\(p.rol.rawValue)] • Estado: \(p.estado.rawValue)\n"
            ficha += "  Ingreso: \(dateFmt(p.fechaIngreso)) • Antigüedad: \(antiguedad(p.fechaIngreso)) • Contrato: \(p.tipoContrato.rawValue)\n"
            ficha += "  Sueldo neto mensual: \(currency(p.sueldoNetoMensual)) • Costo al taller: \(currency(p.costoRealMensual)) • Costo/hora: \(currency(p.costoHora))\n"
            if p.tipoSalario == .mixto || p.comisiones > 0 {
                ficha += "  Comisiones acumuladas: \(currency(p.comisiones)) • Tipo salario: \(p.tipoSalario.rawValue)\n"
            } else {
                ficha += "  Tipo salario: \(p.tipoSalario.rawValue)\n"
            }
            return ficha
        }.joined(separator: "\n")
        
        return """
        Total: \(total) | Disponibles ahora: \(disponibles)
        Roles: \(porRol)
        Detalle (Top 5 por costo mensual):
        \(top.isEmpty ? "- Sin detalle disponible." : top)
        """
    }
    
    private func buildInventarioSummary(_ arr: [Producto]) -> String {
        if arr.isEmpty { return "- No hay productos." }
        
        // Críticos por stock (<= 2)
        let lowStock = arr
            .filter { $0.cantidad <= 2.0 }
            .sorted { $0.cantidad < $1.cantidad }
            .prefix(5)
            .map { "- \($0.nombre): \($0.cantidad) \($0.unidadDeMedida)" }
            .joined(separator: "\n")
        
        // Listado detallado de productos (máx. 8) por mayor valor de stock (costo * cantidad)
        let detallados = arr
            .sorted { ($0.costo * $0.cantidad) > ($1.costo * $1.cantidad) }
            .prefix(8)
            .map { p -> String in
                let ganancia = p.costo * (p.porcentajeMargenSugerido / 100.0)
                let gastosAdmin = p.costo * (p.porcentajeGastosAdministrativos / 100.0)
                let isr = ganancia * (p.isrPorcentajeEstimado / 100.0)
                let gananciaNeta = max(0, ganancia - isr)
                let stockStr = String(format: "%.2f", p.cantidad)
                let gananciaStr = String(format: "%.2f", ganancia)
                let adminStr = String(format: "%.2f", gastosAdmin)
                let netaStr = String(format: "%.2f", gananciaNeta)
                return "• \(p.nombre) | Stock: \(stockStr) \(p.unidadDeMedida) | Margen: $\(gananciaStr) | Gastos Adm.: $\(adminStr) | Ganancia neta (post ISR): $\(netaStr)"
            }
            .joined(separator: "\n")
        
        return """
        Total: \(arr.count)
        Críticos:
        \(lowStock.isEmpty ? "Ninguno" : lowStock)
        
        Detalle (máx. 8 por valor de stock):
        \(detallados)
        """
    }
    
    private func buildServiciosSummary(_ servicios: [Servicio], productos: [Producto]) -> String {
        if servicios.isEmpty { return "- No hay servicios." }
        
        func fmt(_ v: Double) -> String { String(format: "%.2f", v) }
        
        let lines: [String] = servicios.prefix(8).map { s in
            // Costo de inventario a partir de ingredientes
            let costoInventario = PricingHelpers.costoIngredientes(servicio: s, productos: productos)
            // Refacciones si aplican
            let ref = s.requiereRefacciones ? s.costoRefacciones : 0.0
            // Desglose total
            let desg = PricingHelpers.calcularDesglose(
                manoDeObra: s.costoManoDeObra,
                refacciones: ref,
                costoInventario: costoInventario,
                gananciaDeseada: s.gananciaDeseada,
                gastosAdmin: s.gastosAdministrativos,
                aplicarIVA: s.aplicarIVA,
                aplicarISR: s.aplicarISR,
                porcentajeISR: s.isrPorcentajeEstimado
            )
            
            // Ingredientes detallados con unidades y proporciones
            let ingredientesDetalle: String = {
                if s.ingredientes.isEmpty { return "- Sin productos." }
                let totalCostoInv = max(costoInventario, 0.000001)
                let totalPrecioFinal = max(desg.precioFinal, 0.000001)
                return s.ingredientes.map { ing in
                    let prod = productos.first(where: { $0.nombre == ing.nombreProducto })
                    let unidad = prod?.unidadDeMedida ?? ""
                    let costoIng = (prod?.precioVenta ?? 0) * ing.cantidadUsada
                    let propInv = costoIng / totalCostoInv
                    let propFinal = costoIng / totalPrecioFinal
                    return "  • \(ing.nombreProducto): \(fmt(ing.cantidadUsada)) \(unidad) | Costo: $\(fmt(costoIng)) | % en inventario: \(fmt(propInv * 100))% | % en precio final: \(fmt(propFinal * 100))%"
                }.joined(separator: "\n")
            }()
            
            var ficha = "- \(s.nombre) [\(s.especialidadRequerida) • \(s.rolRequerido.rawValue)] • Duración: \(fmt(s.duracionHoras)) h\n"
            ficha += "  Mano de obra: $\(fmt(s.costoManoDeObra)) | Ganancia deseada: $\(fmt(s.gananciaDeseada)) | Gastos Adm.: $\(fmt(s.gastosAdministrativos))\n"
            if s.requiereRefacciones {
                ficha += "  Refacciones: $\(fmt(ref))\n"
            }
            ficha += "  Insumos (inventario): $\(fmt(costoInventario))\n"
            ficha += "  Totales => Costos directos: $\(fmt(desg.costosDirectos)) | Subtotal: $\(fmt(desg.subtotal)) | IVA: $\(fmt(desg.iva)) | Precio final: $\(fmt(s.precioFinalAlCliente)) (calc: $\(fmt(desg.precioFinal)))\n"
            ficha += "  ISR sobre ganancia: $\(fmt(desg.isrSobreGanancia)) | Ganancia neta (post ISR): $\(fmt(desg.gananciaNeta))\n"
            ficha += "  Ingredientes:\n\(ingredientesDetalle)"
            return ficha
        }
        
        return """
        Total: \(servicios.count)
        Detalle (máx. 8):
        \(lines.joined(separator: "\n"))
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
