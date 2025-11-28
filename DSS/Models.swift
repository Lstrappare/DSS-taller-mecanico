import Foundation
import SwiftData

// MARK: - Catálogos / Enums

enum Rol: String, CaseIterable, Codable {
    case jefeDeTaller = "Jefe de Taller"
    case adminFinanzas = "Administración / Finanzas"
    case atencionCliente = "Atención al Cliente"
    case mecanicoFrenos = "Mecánico"
    case ayudante = "Ayudante"
}

// Disponibilidad operacional (UI de asignaciones)
enum EstadoEmpleado: String, CaseIterable, Codable {
    case disponible = "Disponible"
    case ocupado = "Ocupado (En Servicio)"
    case descanso = "En Descanso"
    case ausente = "Ausente (Faltó)"
}

// Asistencia diaria (resultado final del día)
enum EstadoAsistencia: String, Codable, CaseIterable {
    case presente
    case ausente
    case incompleto
}

// Tipo de contrato laboral
enum TipoContrato: String, Codable, CaseIterable {
    case indefinido = "Indefinido"
    case determinado = "Determinado"
    case honorarios = "Honorarios"
    case temporal = "Temporal"
    case aprendiz = "Aprendiz"
    case otro = "Otro"
}

// Tipo de salario para nómina (reducido a 2 opciones)
enum TipoSalario: String, Codable, CaseIterable {
    case minimo = "Mínimo"
    case mixto = "Mixto"
}

// Frecuencia de pago
enum FrecuenciaPago: String, Codable, CaseIterable {
    case quincena = "Quincena"
    case mes = "Mes"
}

// Estado del ticket/servicio
enum EstadoServicio: String, Codable, CaseIterable {
    case programado
    case enProceso
    case completado
    case cancelado
}

// MARK: - Modelos

@Model
class Personal {
    // Identidad
    @Attribute(.unique) var rfc: String
    var curp: String?
    var nombre: String
    var email: String
    var telefono: String
    var telefonoActivo: Bool

    // Trabajo
    var horaEntrada: Int
    var horaSalida: Int
    var rol: Rol
    var estado: EstadoEmpleado
    var especialidades: [String]
    var fechaIngreso: Date
    var tipoContrato: TipoContrato
    // Días laborables: Calendar weekday (1=Dom, 7=Sáb)
    var diasLaborales: [Int]

    // Alta/Baja
    var activo: Bool
    var fechaBaja: Date?

    // Nómina - configuración y snapshots
    var prestacionesMinimas: Bool
    var tipoSalario: TipoSalario
    var frecuenciaPago: FrecuenciaPago
    var salarioMinimoReferencia: Double

    // Nuevo: comisiones acumuladas (editable y automatizable)
    var comisiones: Double
    // Nuevo: factor de integración configurable
    var factorIntegracion: Double

    // Campos automáticos (persistidos como snapshot de cálculo)
    var salarioDiario: Double
    var sbc: Double
    var isrMensualEstimado: Double
    var imssMensualEstimado: Double
    var cuotaObrera: Double
    var cuotaPatronal: Double
    var sueldoNetoMensual: Double
    var costoRealMensual: Double
    var costoHora: Double
    var horasSemanalesRequeridas: Double
    var manoDeObraSugerida: Double
    var ultimoCalculoNomina: Date?

    // Documentación (rutas opcionales a archivos)
    var ineAdjuntoPath: String?
    var comprobanteDomicilioPath: String?
    var comprobanteEstudiosPath: String?

    // Antigüedad / Asistencia
    var antiguedadDias: Int
    var bloqueoAsistenciaFecha: Date?

    // Relación de asistencias
    @Relationship(deleteRule: .cascade, inverse: \AsistenciaDiaria.empleado)
    var asistencias: [AsistenciaDiaria] = []

    // Calculadas
    var estaEnHorario: Bool {
        let calendario = Calendar.current
        let ahora = Date()
        let diaDeSemana = calendario.component(.weekday, from: ahora)
        let horaActual = calendario.component(.hour, from: ahora)
        let esDiaLaboral = diasLaborales.contains(diaDeSemana)
        let esHoraLaboral = (horaEntrada..<horaSalida).contains(horaActual)
        return esDiaLaboral && esHoraLaboral
    }

    var isAsignable: Bool {
        return activo && estaEnHorario && (estado == .disponible)
    }

    init(
        rfc: String,
        curp: String? = nil,
        nombre: String,
        email: String,
        telefono: String = "",
        telefonoActivo: Bool = false,
        horaEntrada: Int = 9,
        horaSalida: Int = 18,
        rol: Rol = .ayudante,
        estado: EstadoEmpleado = .disponible,
        especialidades: [String] = [],
        fechaIngreso: Date = Date(),
        tipoContrato: TipoContrato = .indefinido,
        diasLaborales: [Int] = [2,3,4,5,6], // L-V por defecto

        // Alta/Baja
        activo: Bool = true,
        fechaBaja: Date? = nil,

        prestacionesMinimas: Bool = true,
        tipoSalario: TipoSalario = .minimo,
        frecuenciaPago: FrecuenciaPago = .quincena,
        salarioMinimoReferencia: Double = 248.93,

        // Nuevos
        comisiones: Double = 0.0,
        factorIntegracion: Double = 1.0452,

        salarioDiario: Double = 0,
        sbc: Double = 0,
        isrMensualEstimado: Double = 0,
        imssMensualEstimado: Double = 0,
        cuotaObrera: Double = 0,
        cuotaPatronal: Double = 0,
        sueldoNetoMensual: Double = 0,
        costoRealMensual: Double = 0,
        costoHora: Double = 0,
        horasSemanalesRequeridas: Double = 48,
        manoDeObraSugerida: Double = 0,
        ultimoCalculoNomina: Date? = nil,

        ineAdjuntoPath: String? = nil,
        comprobanteDomicilioPath: String? = nil,
        comprobanteEstudiosPath: String? = nil,

        antiguedadDias: Int = 0,
        bloqueoAsistenciaFecha: Date? = nil
    ) {
        self.rfc = rfc
        self.curp = curp
        self.nombre = nombre
        self.email = email
        self.telefono = telefono
        self.telefonoActivo = telefonoActivo
        self.horaEntrada = horaEntrada
        self.horaSalida = horaSalida
        self.rol = rol
        self.estado = estado
        self.especialidades = especialidades
        self.fechaIngreso = fechaIngreso
        self.tipoContrato = tipoContrato
        self.diasLaborales = diasLaborales

        self.activo = activo
        self.fechaBaja = fechaBaja

        self.prestacionesMinimas = prestacionesMinimas
        self.tipoSalario = tipoSalario
        self.frecuenciaPago = frecuenciaPago
        self.salarioMinimoReferencia = salarioMinimoReferencia

        self.comisiones = comisiones
        self.factorIntegracion = factorIntegracion

        self.salarioDiario = salarioDiario
        self.sbc = sbc
        self.isrMensualEstimado = isrMensualEstimado
        self.imssMensualEstimado = imssMensualEstimado
        self.cuotaObrera = cuotaObrera
        self.cuotaPatronal = cuotaPatronal
        self.sueldoNetoMensual = sueldoNetoMensual
        self.costoRealMensual = costoRealMensual
        self.costoHora = costoHora
        self.horasSemanalesRequeridas = horasSemanalesRequeridas
        self.manoDeObraSugerida = manoDeObraSugerida
        self.ultimoCalculoNomina = ultimoCalculoNomina

        self.ineAdjuntoPath = ineAdjuntoPath
        self.comprobanteDomicilioPath = comprobanteDomicilioPath
        self.comprobanteEstudiosPath = comprobanteEstudiosPath

        self.antiguedadDias = antiguedadDias
        self.bloqueoAsistenciaFecha = bloqueoAsistenciaFecha
    }

    // MARK: - Nómina: Funciones de negocio

    // 1) Promedio de comisiones según días (quincena 15, mes 30.4)
    func calcularComisiones(promedioSobreDias dias: Double) -> Double {
        guard dias > 0 else { return 0 }
        return comisiones / dias
    }

    // 2) SBC = (Salario Diario + Comisiones Promediadas) / FactorIntegracion
    static func calcularSBC(salarioDiario: Double, comisionesPromedioDiarias: Double, factorIntegracion: Double) -> Double {
        let factor = max(factorIntegracion, 0.0001)
        return max(0, (salarioDiario + comisionesPromedioDiarias) / factor)
    }

    // 3) IMSS aproximado desde SBC y salario diario (coherente con UI actual)
    static func calcularIMSS(desdeSBC sbc: Double, salarioDiario: Double, prestacionesMinimas: Bool) -> (obrera: Double, patronal: Double, total: Double) {
        let ingresoMensual = salarioDiario * 30.4
        let factorPrest = prestacionesMinimas ? 1.0452 : 1.0
        let base = max(0, ingresoMensual * factorPrest)
        let obrera = base * 0.02
        let patronal = base * 0.05
        return (obrera, patronal, obrera + patronal)
    }

    // 4) ISR aproximado: 0 si mínimo; si mixto, 10% sobre excedente del mínimo
    static func calcularISR(salarioDiario: Double, comisionesPromedioDiarias: Double, tipoSalario: TipoSalario) -> Double {
        guard tipoSalario == .mixto else { return 0 }
        let ingresoMensual = (salarioDiario + comisionesPromedioDiarias) * 30.4
        let baseMinimo = salarioDiario * 30.4
        guard ingresoMensual > baseMinimo else { return 0 }
        return max(0, ingresoMensual - baseMinimo) * 0.10
    }

    // 5) Recalcular y actualizar snapshots encadenando todas las reglas
    func recalcularYActualizarSnapshots() {
        // Salario diario base = salario mínimo de referencia
        let salarioDiarioBase = salarioMinimoReferencia

        // Promedio de comisiones según frecuencia
        let diasPromedio: Double = (frecuenciaPago == .quincena) ? 15.0 : 30.4
        let comisionesPromedioDiarias = (tipoSalario == .mixto) ? calcularComisiones(promedioSobreDias: diasPromedio) : 0.0

        // SBC
        let sbcCalc = Personal.calcularSBC(
            salarioDiario: salarioDiarioBase,
            comisionesPromedioDiarias: comisionesPromedioDiarias,
            factorIntegracion: factorIntegracion
        )

        // IMSS
        let (obrera, patronal, imssTotal) = Personal.calcularIMSS(
            desdeSBC: sbcCalc,
            salarioDiario: salarioDiarioBase,
            prestacionesMinimas: prestacionesMinimas
        )

        // ISR
        let isr = Personal.calcularISR(
            salarioDiario: salarioDiarioBase,
            comisionesPromedioDiarias: comisionesPromedioDiarias,
            tipoSalario: tipoSalario
        )

        // Ingreso mensual bruto (salario + comisiones del periodo)
        let ingresoMensualBruto = (salarioDiarioBase * 30.4) + (tipoSalario == .mixto ? comisiones : 0.0)

        // Sueldo neto y costo real
        let sueldoNeto = max(0, ingresoMensualBruto - isr - obrera)
        let costoReal = ingresoMensualBruto + patronal
        let horasMes = max(1, horasSemanalesRequeridas) * 4.0
        let costoHoraCalc = costoReal / horasMes

        // Sugerencia de mano de obra (markup)
        let moSug = costoHoraCalc * 2.2

        // Asignar snapshots
        self.salarioDiario = salarioDiarioBase
        self.sbc = sbcCalc
        self.isrMensualEstimado = max(0, isr)
        self.imssMensualEstimado = imssTotal
        self.cuotaObrera = obrera
        self.cuotaPatronal = patronal
        self.sueldoNetoMensual = sueldoNeto
        self.costoRealMensual = costoReal
        self.costoHora = costoHoraCalc
        self.manoDeObraSugerida = moSug
        self.ultimoCalculoNomina = Date()
    }
}

@Model
class AsistenciaDiaria {
    @Attribute(.unique) var id: UUID
    // Relación inversa con Personal
    var empleado: Personal

    // Día (normalizado a medianoche)
    var fecha: Date

    // Control de jornada
    var horaEntrada: Date?
    var horaSalida: Date?
    // Pausas como pares inicio/fin serializados
    var pausasJSON: Data? // Codable [(inicio: Date, fin: Date?)]
    var minutosProductivos: Int
    var minutosImproductivos: Int

    // Estado final y bloqueo
    var estadoFinal: EstadoAsistencia
    var bloqueada: Bool

    // Auditoría
    var timestampCreacion: Date

    init(empleado: Personal, fecha: Date) {
        self.id = UUID()
        self.empleado = empleado
        // Normalizar fecha a medianoche
        self.fecha = Calendar.current.startOfDay(for: fecha)
        self.horaEntrada = nil
        self.horaSalida = nil
        self.pausasJSON = nil
        self.minutosProductivos = 0
        self.minutosImproductivos = 0
        self.estadoFinal = .incompleto
        self.bloqueada = false
        self.timestampCreacion = Date()
    }
}

@Model
class PayrollSettings {
    @Attribute(.unique) var id: UUID
    var salarioMinimoVigente: Double
    var proporcionPatronDefault: Double
    var proporcionTrabajadorDefault: Double
    var fechaUltimaActualizacion: Date

    init(
        salarioMinimoVigente: Double = 248.93,
        proporcionPatronDefault: Double = 0.77, // ejemplo aproximado
        proporcionTrabajadorDefault: Double = 0.23,
        fechaUltimaActualizacion: Date = Date()
    ) {
        self.id = UUID()
        self.salarioMinimoVigente = salarioMinimoVigente
        self.proporcionPatronDefault = proporcionPatronDefault
        self.proporcionTrabajadorDefault = proporcionTrabajadorDefault
        self.fechaUltimaActualizacion = fechaUltimaActualizacion
    }
}

// Tipo fiscal del producto
enum TipoFiscalProducto: String, Codable, CaseIterable {
    case iva16 = "IVA 16%"
    case exento = "Exento"
    case tasaCero = "Tasa 0%"

    var tasa: Double {
        switch self {
        case .iva16: return 0.16
        case .exento, .tasaCero: return 0.0
        }
    }
}

// Productos

@Model
class Producto {
    @Attribute(.unique) var nombre: String
    var costo: Double
    var precioVenta: Double
    var cantidad: Double
    var unidadDeMedida: String
    var informacion: String

    // Nuevos campos
    var categoria: String
    var proveedor: String
    var lote: String
    var fechaCaducidad: Date?
    var costoIncluyeIVA: Bool
    var porcentajeMargenSugerido: Double
    var porcentajeGastosAdministrativos: Double
    var tipoFiscal: TipoFiscalProducto
    var isrPorcentajeEstimado: Double
    var precioModificadoManualmente: Bool

    init(
        nombre: String,
        costo: Double,
        precioVenta: Double,
        cantidad: Double,
        unidadDeMedida: String,
        informacion: String = "",
        categoria: String = "",
        proveedor: String = "",
        lote: String = "",
        fechaCaducidad: Date? = nil,
        costoIncluyeIVA: Bool = true,
        porcentajeMargenSugerido: Double = 30.0,
        porcentajeGastosAdministrativos: Double = 10.0,
        tipoFiscal: TipoFiscalProducto = .iva16,
        isrPorcentajeEstimado: Double = 10.0,
        precioModificadoManualmente: Bool = false
    ) {
        self.nombre = nombre
        self.costo = costo
        self.precioVenta = precioVenta
        self.cantidad = cantidad
        self.unidadDeMedida = unidadDeMedida
        self.informacion = informacion

        self.categoria = categoria
        self.proveedor = proveedor
        self.lote = lote
        self.fechaCaducidad = fechaCaducidad
        self.costoIncluyeIVA = costoIncluyeIVA
        self.porcentajeMargenSugerido = porcentajeMargenSugerido
        self.porcentajeGastosAdministrativos = porcentajeGastosAdministrativos
        self.tipoFiscal = tipoFiscal
        self.isrPorcentajeEstimado = isrPorcentajeEstimado
        self.precioModificadoManualmente = precioModificadoManualmente
    }

    var margen: Double {
        guard precioVenta > 0 else { return 0 }
        return (1 - (costo / precioVenta)) * 100
    }
}

// Servicios catálogo

struct Ingrediente: Codable, Hashable {
    var nombreProducto: String
    var cantidadUsada: Double
}

@Model
class Servicio {
    @Attribute(.unique) var nombre: String
    var descripcion: String
    var especialidadRequerida: String
    var rolRequerido: Rol
    var ingredientes: [Ingrediente]
    var precioAlCliente: Double
    var duracionHoras: Double

    // Nuevos campos de configuración y precios (Actualizado para montos fijos)
    var costoBase: Double // Deprecado o usado como backup
    var requiereRefacciones: Bool
    var costoRefacciones: Double
    
    // Nuevos campos por montos (Requerimiento actual)
    var costoManoDeObra: Double
    var gananciaDeseada: Double
    var gastosAdministrativos: Double
    
    // Campos deprecados (mantener para migración si es necesario, o ignorar)
    var porcentajeManoDeObra: Double
    var porcentajeGastosAdministrativos: Double
    var porcentajeMargen: Double
    
    var aplicarIVA: Bool
    var aplicarISR: Bool
    var isrPorcentajeEstimado: Double
    var precioFinalAlCliente: Double
    var precioModificadoManualmente: Bool

    init(nombre: String,
         descripcion: String = "",
         especialidadRequerida: String,
         rolRequerido: Rol,
         ingredientes: [Ingrediente] = [],
         precioAlCliente: Double,
         duracionHoras: Double = 1.0,
         costoBase: Double = 0.0,
         requiereRefacciones: Bool = false,
         costoRefacciones: Double = 0.0,
         
         // Nuevos parámetros con defaults
         costoManoDeObra: Double = 0.0,
         gananciaDeseada: Double = 0.0,
         gastosAdministrativos: Double = 0.0,
         
         porcentajeManoDeObra: Double = 40.0,
         porcentajeGastosAdministrativos: Double = 20.0,
         porcentajeMargen: Double = 30.0,
         aplicarIVA: Bool = false,
         aplicarISR: Bool = false,
         isrPorcentajeEstimado: Double = 10.0,
         precioFinalAlCliente: Double? = nil,
         precioModificadoManualmente: Bool = false)
    {
        self.nombre = nombre
        self.descripcion = descripcion
        self.especialidadRequerida = especialidadRequerida
        self.rolRequerido = rolRequerido
        self.ingredientes = ingredientes
        self.precioAlCliente = precioAlCliente
        self.duracionHoras = duracionHoras

        self.costoBase = costoBase
        self.requiereRefacciones = requiereRefacciones
        self.costoRefacciones = costoRefacciones
        
        self.costoManoDeObra = costoManoDeObra
        self.gananciaDeseada = gananciaDeseada
        self.gastosAdministrativos = gastosAdministrativos
        
        self.porcentajeManoDeObra = porcentajeManoDeObra
        self.porcentajeGastosAdministrativos = porcentajeGastosAdministrativos
        self.porcentajeMargen = porcentajeMargen
        
        self.aplicarIVA = aplicarIVA
        self.aplicarISR = aplicarISR
        self.isrPorcentajeEstimado = isrPorcentajeEstimado
        // Si no viene un precio final, usa el precioAlCliente como inicial para compatibilidad
        self.precioFinalAlCliente = precioFinalAlCliente ?? precioAlCliente
        self.precioModificadoManualmente = precioModificadoManualmente
    }
}

// Decisiones (historial)

@Model
class DecisionRecord {
    var fecha: Date
    var titulo: String
    var razon: String
    var queryUsuario: String

    init(fecha: Date, titulo: String, razon: String, queryUsuario: String) {
        self.fecha = fecha
        self.titulo = titulo
        self.razon = razon
        self.queryUsuario = queryUsuario
    }
}

// Tickets en proceso o programados

@Model
class ServicioEnProceso {
    @Attribute(.unique) var id: UUID
    var nombreServicio: String
    var rfcMecanicoAsignado: String
    var nombreMecanicoAsignado: String
    var horaInicio: Date
    var horaFinEstimada: Date
    var productosConsumidos: [String]
    var vehiculo: Vehiculo?
    
    // Nuevos/extendidos para programación y estados
    var estado: EstadoServicio
    var fechaProgramadaInicio: Date?
    var duracionHoras: Double
    var rfcMecanicoSugerido: String?
    var nombreMecanicoSugerido: String?

    init(nombreServicio: String,
         rfcMecanicoAsignado: String,
         nombreMecanicoAsignado: String,
         horaInicio: Date,
         duracionHoras: Double,
         productosConsumidos: [String],
         vehiculo: Vehiculo?)
    {
        self.id = UUID()
        self.nombreServicio = nombreServicio
        self.rfcMecanicoAsignado = rfcMecanicoAsignado
        self.nombreMecanicoAsignado = nombreMecanicoAsignado
        self.horaInicio = horaInicio
        let segundosDeDuracion = duracionHoras * 3600
        self.horaFinEstimada = horaInicio.addingTimeInterval(segundosDeDuracion)
        self.productosConsumidos = productosConsumidos
        self.vehiculo = vehiculo
        
        // Inicializa nuevos campos
        self.estado = .enProceso
        self.fechaProgramadaInicio = nil
        self.duracionHoras = duracionHoras
        self.rfcMecanicoSugerido = nil
        self.nombreMecanicoSugerido = nil
    }

    var tiempoRestanteSegundos: Double {
        return max(0, horaFinEstimada.timeIntervalSinceNow)
    }

    var estaCompletado: Bool {
        return tiempoRestanteSegundos == 0
    }
    
    // Helper de solape: [inicio, fin) se solapa si inicio < tf && fin > ti
    static func existeSolape(paraRFC rfc: String, inicio: Date, fin: Date, tickets: [ServicioEnProceso]) -> Bool {
        for t in tickets {
            guard (t.estado == .programado || t.estado == .enProceso) else { continue }
            guard t.rfcMecanicoAsignado == rfc || t.rfcMecanicoSugerido == rfc else { continue }
            let ti = t.fechaProgramadaInicio ?? t.horaInicio
            let tf: Date = {
                if t.estado == .programado {
                    return (t.fechaProgramadaInicio ?? t.horaInicio).addingTimeInterval(t.duracionHoras * 3600)
                } else {
                    return t.horaFinEstimada
                }
            }()
            if inicio < tf && fin > ti { return true }
        }
        return false
    }
}

// Chat / Consulta

@Model
class ChatMessage {
    @Attribute(.unique) var id: UUID
    var conversationID: UUID
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

// Clientes y vehículos

@Model
class Vehiculo {
    @Attribute(.unique) var placas: String
    var marca: String
    var modelo: String
    var anio: Int

    var cliente: Cliente?

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

    @Relationship(deleteRule: .cascade)
    var vehiculos: [Vehiculo] = []

    init(nombre: String, telefono: String, email: String = "") {
        self.nombre = nombre
        self.telefono = telefono
        self.email = email
    }
}
