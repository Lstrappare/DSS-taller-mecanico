import Foundation
import SwiftData

import Foundation
import SwiftData

// (El enum NivelHabilidad no cambia)
enum NivelHabilidad: String, CaseIterable, Codable {
    case aprendiz = "Aprendiz"
    case tecnico = "Técnico"
    case maestro = "Maestro Mecánico"
}

@Model
class Personal {
    @Attribute(.unique) var dni: String
    var nombre: String
    var email: String
    
    // --- CAMBIO AQUÍ ---
    // Reemplazamos 'horario: String' por esto:
    var horaEntrada: Int // Formato 24h (ej. 9)
    var horaSalida: Int  // Formato 24h (ej. 18)
    
    var nivelHabilidad: NivelHabilidad
    var especialidades: [String]
    
    // 'estaDisponible' ahora significa "No está ocupado en OTRO servicio"
    var estaDisponible: Bool

    // --- NUEVA PROPIEDAD "INTELIGENTE" ---
    // ¡Aquí está la magia que pediste!
    // Esto se calcula en tiempo real.
    var estaEnHorario: Bool {
        let calendario = Calendar.current
        let ahora = Date()
        
        // Obtiene el día de la semana (1=Domingo, 2=Lunes, ... 7=Sábado)
        let diaDeSemana = calendario.component(.weekday, from: ahora)
        // Obtiene la hora actual (0-23)
        let horaActual = calendario.component(.hour, from: ahora)
        
        // Revisa si es un día laboral (Lunes a Sábado)
        let esDiaLaboral = (2...7).contains(diaDeSemana)
        // Revisa si la hora actual está DENTRO del turno
        let esHoraLaboral = (horaEntrada..<horaSalida).contains(horaActual)
        
        return esDiaLaboral && esHoraLaboral
    }

    init(nombre: String, email: String, dni: String,
         horaEntrada: Int = 9,  // Valor por defecto
         horaSalida: Int = 18, // Valor por defecto
         nivelHabilidad: NivelHabilidad = .aprendiz,
         especialidades: [String] = [],
         estaDisponible: Bool = true)
    {
        self.nombre = nombre
        self.email = email
        self.dni = dni
        self.horaEntrada = horaEntrada // <-- CAMBIADO
        self.horaSalida = horaSalida   // <-- CAMBIADO
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
    
    // -- Cuántas horas tarda el servicio --
    var duracionHoras: Double

    init(nombre: String,
         descripcion: String = "",
         especialidadRequerida: String,
         nivelMinimoRequerido: NivelHabilidad = .aprendiz,
         productosRequeridos: [String] = [],
         precioAlCliente: Double,
         duracionHoras: Double = 1.0)
    {
        self.nombre = nombre
        self.descripcion = descripcion
        self.especialidadRequerida = especialidadRequerida
        self.nivelMinimoRequerido = nivelMinimoRequerido
        self.productosRequeridos = productosRequeridos
        self.precioAlCliente = precioAlCliente
        self.duracionHoras = duracionHoras
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

@Model
class ServicioEnProceso {
    @Attribute(.unique) var id: UUID // ID único para la orden de trabajo
    
    var nombreServicio: String
    var dniMecanicoAsignado: String   // Para saber a quién liberar
    var nombreMecanicoAsignado: String // Para mostrar en la UI
    
    var horaInicio: Date
    var horaFinEstimada: Date
    
    // Guardamos qué productos se usaron, para un futuro historial
    var productosConsumidos: [String]

    init(nombreServicio: String,
         dniMecanicoAsignado: String,
         nombreMecanicoAsignado: String,
         horaInicio: Date,
         duracionHoras: Double, // Lo leeremos del 'Servicio'
         productosConsumidos: [String])
    {
        self.id = UUID() // Genera un nuevo ID único
        self.nombreServicio = nombreServicio
        self.dniMecanicoAsignado = dniMecanicoAsignado
        self.nombreMecanicoAsignado = nombreMecanicoAsignado
        self.horaInicio = horaInicio
        
        // Calcula la hora de fin
        let segundosDeDuracion = duracionHoras * 3600
        self.horaFinEstimada = horaInicio.addingTimeInterval(segundosDeDuracion)
        
        self.productosConsumidos = productosConsumidos
    }
    
    // --- Propiedades Calculadas (para la UI) ---
    
    // Devuelve cuántos segundos quedan
    var tiempoRestanteSegundos: Double {
        return max(0, horaFinEstimada.timeIntervalSinceNow)
    }
    
    // Devuelve 'true' si el temporizador ya llegó a cero
    var estaCompletado: Bool {
        return tiempoRestanteSegundos == 0
    }
}
