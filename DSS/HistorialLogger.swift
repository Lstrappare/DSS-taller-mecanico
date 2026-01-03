import Foundation
import SwiftData

struct HistorialLogger {
    
    /// Registra un evento automático del sistema en el historial de decisiones.
    /// - Parameters:
    ///   - context: El contexto de datos (ModelContext).
    ///   - titulo: Título del evento (ej. "Nuevo Personal").
    ///   - detalle: Descripción detallada o diff del cambio.
    ///   - categoria: Categoría del evento (personal, inventario, servicio, programacion).
    ///   - entidadAfectada: (Opcional) Nombre o identificador de lo que cambió.
    @MainActor
    static func logAutomatico(context: ModelContext, 
                              titulo: String, 
                              detalle: String, 
                              categoria: CategoriaDecision, 
                              entidadAfectada: String? = nil) {
        
        let nuevoRegistro = DecisionRecord(
            fecha: Date(),
            titulo: titulo,
            razon: detalle,
            queryUsuario: "Sistema Automático",
            tipo: .automaticoSistema,
            categoria: categoria,
            entidadAfectada: entidadAfectada
        )
        
        context.insert(nuevoRegistro)
        // SwiftData suele autoguardar, pero si se prefiere forzar:
        // try? context.save()
    }
    
    /// Genera un reporte de cambios (Diff) comparando dos valores.
    /// Útil para generar el string 'detalle' en ediciones.
    static func generarDiff<T: Equatable>(nombreCampo: String, anterior: T, nuevo: T) -> String? {
        if anterior != nuevo {
            return "- \(nombreCampo): \(anterior) -> \(nuevo)"
        }
        return nil
    }
    
    /// Helpers específicos para generar Diffs legibles
    
    static func generarDiffCambioTexto(campo: String, ant: String, nue: String) -> String? {
        if ant != nue {
            return "- \(campo): Cambió de '\(ant)' a '\(nue)'"
        }
        return nil
    }
    
    static func generarDiffCambioNumero<T: Numeric & Comparable>(campo: String, ant: T, nue: T, format: String = "%.2f") -> String? {
         if ant != nue {
             // Formateo simple si es Double
             if let dAnt = ant as? Double, let dNue = nue as? Double {
                 return String(format: "- \(campo): \(format) -> \(format)", dAnt, dNue)
             }
             return "- \(campo): \(ant) -> \(nue)"
         }
         return nil
    }
    
    static func generarDiffCambioBool(campo: String, ant: Bool, nue: Bool) -> String? {
        if ant != nue {
            return "- \(campo): \(ant ? "Sí" : "No") -> \(nue ? "Sí" : "No")"
        }
        return nil
    }

    // Helper para generar diff de fechas (ignorando hora si es solo fecha)
    static func generarDiffFecha(campo: String, ant: Date, nue: Date, includeTime: Bool = false) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = includeTime ? "dd/MM/yyyy HH:mm" : "dd/MM/yyyy"
        let antStr = formatter.string(from: ant)
        let nueStr = formatter.string(from: nue)
        
        guard antStr != nueStr else { return nil }
        return "- \(campo): \(antStr) -> \(nueStr)"
    }
    
    // Helper para generar diff de Arrays (ej. Especialidades, Días)
    static func generarDiffArray(campo: String, ant: [String], nue: [String]) -> String? {
        let antSet = Set(ant)
        let nueSet = Set(nue)
        
        if antSet == nueSet { return nil }
        
        var parts: [String] = []
        let agregados = nueSet.subtracting(antSet).sorted()
        if !agregados.isEmpty { parts.append("Agregado: [\(agregados.joined(separator: ", "))]") }
        
        let eliminados = antSet.subtracting(nueSet).sorted()
        if !eliminados.isEmpty { parts.append("Eliminado: [\(eliminados.joined(separator: ", "))]") }
        
        if parts.isEmpty { return nil }
        return "- \(campo): \(parts.joined(separator: "; "))"
    }
}
