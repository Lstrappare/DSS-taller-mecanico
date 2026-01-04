import Foundation

enum PricingHelpers {
    struct DesglosePrecio {
        let costosDirectos: Double
        let partesInternas: Double
        let subtotal: Double
        let iva: Double
        let precioFinal: Double
        let isrSobreGanancia: Double
        let gananciaNeta: Double
    }
    
    static func calcularDesglose(
        manoDeObra: Double,
        refacciones: Double,
        costoInventario: Double,
        gananciaDeseada: Double,
        gastosAdmin: Double,
        aplicarIVA: Bool,
        aplicarISR: Bool,
        porcentajeISR: Double
    ) -> DesglosePrecio {
        // Se suman TODOS los costos directos (sin condiciones)
        let costosDirectos = manoDeObra + refacciones + costoInventario
        
        let partesInternas = gananciaDeseada + gastosAdmin
        let subtotal = costosDirectos + partesInternas
        let iva = aplicarIVA ? (subtotal * 0.16) : 0.0
        let precioFinal = subtotal + iva
        let isr = aplicarISR ? (gananciaDeseada * (porcentajeISR / 100.0)) : 0.0
        let gananciaNeta = max(0, gananciaDeseada - isr)
        return DesglosePrecio(
            costosDirectos: costosDirectos,
            partesInternas: partesInternas,
            subtotal: subtotal,
            iva: iva,
            precioFinal: precioFinal,
            isrSobreGanancia: isr,
            gananciaNeta: gananciaNeta
        )
    }
    
    static func costoIngredientes(servicio: Servicio, productos: [Producto]) -> Double {
        servicio.ingredientes.reduce(0) { acc, ing in
            if let p = productos.first(where: { $0.nombre == ing.nombreProducto }) {
                let contenido = max(p.contenidoNeto, 1.0)
                let unidades = ing.cantidadUsada / contenido
                // Usar precio SIN IVA para el costo interno
                let precioSinIVA = p.precioVenta / (1.0 + p.tipoFiscal.tasa)
                return acc + (precioSinIVA * unidades)
            }
            return acc
        }
    }
    
    static func precioSugeridoParaServicio(servicio: Servicio, productos: [Producto]) -> Double {
        let costoInsumos = costoIngredientes(servicio: servicio, productos: productos)
        let ref = servicio.requiereRefacciones ? servicio.costoRefacciones : 0.0
        
        let desglose = calcularDesglose(
            manoDeObra: servicio.costoManoDeObra,
            refacciones: ref,
            costoInventario: costoInsumos,
            gananciaDeseada: servicio.gananciaDeseada,
            gastosAdmin: servicio.gastosAdministrativos,
            aplicarIVA: servicio.aplicarIVA,
            aplicarISR: servicio.aplicarISR,
            porcentajeISR: servicio.isrPorcentajeEstimado
        )
        return desglose.precioFinal
    }
}

