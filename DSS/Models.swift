import Foundation
import SwiftData

enum NivelHabilidad: String, CaseIterable, Codable {
    case aprendiz = "Aprendiz"
    case tecnico = "Técnico"
    case maestro = "Maestro Mecánico"
}

@Model
class Personal {
    @Attribute(.unique) var dni: String // El DNI debe ser único
    
    var nombre: String
    var email: String
    
    // El horario que pediste.
    var horario: String
    
    // El Nivel de Habilidad que pediste.
    var nivelHabilidad: NivelHabilidad
    
    // "Especialidad" ahora es "Especialidades" (plural)
    var especialidades: [String]
    
    // El estado de disponibilidad que ya tenías
    var estaDisponible: Bool

    init(nombre: String, email: String, dni: String,
         horario: String = "L-V 9:00-18:00",
         nivelHabilidad: NivelHabilidad = .aprendiz,
         especialidades: [String] = [], // Inicia vacío
         estaDisponible: Bool = true)
    {
        self.nombre = nombre
        self.email = email
        self.dni = dni
        self.horario = horario
        self.nivelHabilidad = nivelHabilidad
        self.especialidades = especialidades
        self.estaDisponible = estaDisponible
    }
}

@Model
class Producto {
    @Attribute(.unique) var nombre: String // El nombre del producto debe ser único
    
    var costo: Double        // "Cost" del mockup
    var precioVenta: Double  // "Sale Price (Approx.)" del mockup
    var cantidad: Int        // "Quantity" del mockup
    var informacion: String  // "Information" del formulario
    var disponibilidad: String // Ej: "In Stock", "Low Stock"
    
    init(nombre: String, costo: Double, precioVenta: Double, cantidad: Int, informacion: String = "", disponibilidad: String = "In Stock") {
        self.nombre = nombre
        self.costo = costo
        self.precioVenta = precioVenta
        self.cantidad = cantidad
        self.informacion = informacion
        self.disponibilidad = disponibilidad
    }
    
    // --- La Magia del DSS ---
    // Propiedad calculada para el "Margin" (Margen)
    var margen: Double {
        // Evita división por cero si el precio es 0
        guard precioVenta > 0 else { return 0 }
        
        // Fórmula: ((Precio - Costo) / Precio) * 100
        return (1 - (costo / precioVenta)) * 100
    }
}

@Model
class Servicio {
    @Attribute(.unique) var nombre: String // "Cambio de Frenos Delanteros"
    
    var descripcion: String
    
    // --- El Enlace con Personal ---
    var especialidadRequerida: String // Ej: "Frenos", "Motor", "Eléctrico"
    var nivelMinimoRequerido: NivelHabilidad // Ej: "Técnico"
    
    // --- El Enlace con Productos ---
    // Guardamos una lista de los NOMBRES de los productos
    var productosRequeridos: [String]
    
    // --- Costos ---
    var precioAlCliente: Double // Cuánto le cobras al cliente por el servicio (sin incluir piezas)

    init(nombre: String,
         descripcion: String = "",
         especialidadRequerida: String,
         nivelMinimoRequerido: NivelHabilidad = .aprendiz,
         productosRequeridos: [String] = [],
         precioAlCliente: Double)
    {
        self.nombre = nombre
        self.descripcion = descripcion
        self.especialidadRequerida = especialidadRequerida
        self.nivelMinimoRequerido = nivelMinimoRequerido
        self.productosRequeridos = productosRequeridos
        self.precioAlCliente = precioAlCliente
    }
}

@Model
class DecisionRecord {
    var fecha: Date       // Cuándo se tomó
    var titulo: String    // El "Best Decision" o título
    var razon: String     // El "Reasoning"
    var queryUsuario: String // La pregunta original del usuario
    
    init(fecha: Date, titulo: String, razon: String, queryUsuario: String) {
        self.fecha = fecha
        self.titulo = titulo
        self.razon = razon
        self.queryUsuario = queryUsuario
    }
}

