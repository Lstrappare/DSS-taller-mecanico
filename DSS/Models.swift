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
    @Attribute(.unique) var nombre: String
    
    var costo: Double
    var precioVenta: Double
    
    // --- CAMBIO AQUÍ ---
    var cantidad: Double // De Int a Double (para 10.5 litros)
    var unidadDeMedida: String // "Pieza", "Litro", "Botella"
    // 'disponibilidad' se ha eliminado
    
    var informacion: String
    
    init(nombre: String,
         costo: Double,
         precioVenta: Double,
         cantidad: Double, // <-- CAMBIADO
         unidadDeMedida: String, // <-- NUEVO
         informacion: String = "")
    {
        self.nombre = nombre
        self.costo = costo
        self.precioVenta = precioVenta
        self.cantidad = cantidad // <-- CAMBIADO
        self.unidadDeMedida = unidadDeMedida // <-- NUEVO
        self.informacion = informacion
    }
    
    // El 'margen' (propiedad calculada) no cambia
    var margen: Double {
        guard precioVenta > 0 else { return 0 }
        return (1 - (costo / precioVenta)) * 100
    }
}

@Model
class Servicio {
    @Attribute(.unique) var nombre: String
    var descripcion: String
    
    var especialidadRequerida: String
    var nivelMinimoRequerido: NivelHabilidad
    
    // --- ¡ESTE ES EL CAMBIO! ---
    // Reemplazamos [String] por [Ingrediente]
    var ingredientes: [Ingrediente]
    
    var precioAlCliente: Double
    var duracionHoras: Double

    init(nombre: String,
         descripcion: String = "",
         especialidadRequerida: String,
         nivelMinimoRequerido: NivelHabilidad = .aprendiz,
         ingredientes: [Ingrediente] = [], // <-- CAMBIADO
         precioAlCliente: Double,
         duracionHoras: Double = 1.0)
    {
        self.nombre = nombre
        self.descripcion = descripcion
        self.especialidadRequerida = especialidadRequerida
        self.nivelMinimoRequerido = nivelMinimoRequerido
        self.ingredientes = ingredientes // <-- CAMBIADO
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

@Model
class ChatMessage {
    @Attribute(.unique) var id: UUID
    var conversationID: UUID // Para agrupar los mensajes
    
    var date: Date
    var content: String
    var isFromUser: Bool
    
    init(conversationID: UUID, content: String, isFromUser: Bool) {
        self.id = UUID()
        self.conversationID = conversationID
        self.date = Date()
        self.content = content
        self.isFromUser = isFromUser
    }
}

struct Ingrediente: Codable, Hashable {
    var nombreProducto: String
    var cantidadUsada: Double
}
