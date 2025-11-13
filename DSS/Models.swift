import Foundation
import SwiftData

import Foundation
import SwiftData

enum Rol: String, CaseIterable, Codable {
    case jefeDeTaller = "Jefe de Taller"
    case adminFinanzas = "Administración / Finanzas"
    case atencionCliente = "Atención al Cliente"
    case mecanicoFrenos = "Mecánico"
    case ayudante = "Ayudante"
}

// --- ¡NUEVO! ---
// El nuevo estado de disponibilidad
enum EstadoEmpleado: String, CaseIterable, Codable {
    case disponible = "Disponible"
    case ocupado = "Ocupado (En Servicio)"
    case descanso = "En Descanso"
    case ausente = "Ausente (Faltó)"
}

@Model
class Personal {
    @Attribute(.unique) var dni: String
    var nombre: String
    var email: String // Ahora será obligatorio
    
    // --- ¡NUEVOS CAMPOS! ---
    var telefono: String
    var telefonoActivo: Bool // El Toggle que pediste
    
    var horaEntrada: Int
    var horaSalida: Int
    
    var rol: Rol
    var estado: EstadoEmpleado
    
    var especialidades: [String]
    
    // (La lógica de 'estaEnHorario' y 'isAsignable' no cambia)
    var estaEnHorario: Bool {
        let calendario = Calendar.current
        let ahora = Date()
        let diaDeSemana = calendario.component(.weekday, from: ahora)
        let horaActual = calendario.component(.hour, from: ahora)
        let esDiaLaboral = (2...7).contains(diaDeSemana)
        let esHoraLaboral = (horaEntrada..<horaSalida).contains(horaActual)
        return esDiaLaboral && esHoraLaboral
    }
    
    var isAsignable: Bool {
        return estaEnHorario && (estado == .disponible)
    }

    init(nombre: String,
         email: String, // Ahora requerido
         dni: String,
         telefono: String = "", // <-- NUEVO
         telefonoActivo: Bool = false, // <-- NUEVO
         horaEntrada: Int = 9,
         horaSalida: Int = 18,
         rol: Rol = .ayudante,
         estado: EstadoEmpleado = .disponible,
         especialidades: [String] = [])
    {
        self.nombre = nombre
        self.email = email
        self.dni = dni
        self.telefono = telefono // <-- NUEVO
        self.telefonoActivo = telefonoActivo // <-- NUEVO
        self.horaEntrada = horaEntrada
        self.horaSalida = horaSalida
        self.rol = rol
        self.estado = estado
        self.especialidades = especialidades
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
    
    // --- ¡CAMPOS ACTUALIZADOS! ---
    var especialidadRequerida: String
    var rolRequerido: Rol // Reemplaza a 'nivelMinimoRequerido'
    
    var ingredientes: [Ingrediente]
    var precioAlCliente: Double
    var duracionHoras: Double

    init(nombre: String,
         descripcion: String = "",
         especialidadRequerida: String,
         rolRequerido: Rol, // <-- CAMBIADO
         ingredientes: [Ingrediente] = [],
         precioAlCliente: Double,
         duracionHoras: Double = 1.0)
    {
        self.nombre = nombre
        self.descripcion = descripcion
        self.especialidadRequerida = especialidadRequerida
        self.rolRequerido = rolRequerido // <-- CAMBIADO
        self.ingredientes = ingredientes
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
    @Attribute(.unique) var id: UUID
    
    var nombreServicio: String
    var dniMecanicoAsignado: String
    var nombreMecanicoAsignado: String
    
    var horaInicio: Date
    var horaFinEstimada: Date
    
    var productosConsumidos: [String]
    
    // --- ¡NUEVA RELACIÓN! ---
    // Un ticket pertenece a UN vehículo
    var vehiculo: Vehiculo?

    init(nombreServicio: String,
         dniMecanicoAsignado: String,
         nombreMecanicoAsignado: String,
         horaInicio: Date,
         duracionHoras: Double,
         productosConsumidos: [String],
         vehiculo: Vehiculo?) // <-- AÑADIDO AL INIT
    {
        self.id = UUID()
        self.nombreServicio = nombreServicio
        self.dniMecanicoAsignado = dniMecanicoAsignado
        self.nombreMecanicoAsignado = nombreMecanicoAsignado
        self.horaInicio = horaInicio
        
        let segundosDeDuracion = duracionHoras * 3600
        self.horaFinEstimada = horaInicio.addingTimeInterval(segundosDeDuracion)
        
        self.productosConsumidos = productosConsumidos
        self.vehiculo = vehiculo // <-- AÑADIDO
    }
    
    // --- Propiedades Calculadas (no cambian) ---
    var tiempoRestanteSegundos: Double {
        return max(0, horaFinEstimada.timeIntervalSinceNow)
    }
    
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

@Model
class Vehiculo {
    @Attribute(.unique) var placas: String // "Plates"
    var marca: String
    var modelo: String
    var anio: Int
    
    // Un vehículo pertenece a UN cliente
    var cliente: Cliente?
    
    // Un vehículo puede tener MUCHOS servicios en proceso
    @Relationship(deleteRule: .cascade)
    var serviciosEnProceso: [ServicioEnProceso] = []
    
    init(placas: String, marca: String, modelo: String, anio: Int) {
        self.placas = placas
        self.marca = marca
        self.modelo = modelo
        self.anio = anio
    }
}

@Model
class Cliente {
    @Attribute(.unique) var telefono: String
    var nombre: String
    var email: String
    
    // Un cliente puede tener MUCHOS vehículos
    @Relationship(deleteRule: .cascade)
    var vehiculos: [Vehiculo] = []
    
    init(nombre: String, telefono: String, email: String = "") {
        self.nombre = nombre
        self.telefono = telefono
        self.email = email
    }
}

