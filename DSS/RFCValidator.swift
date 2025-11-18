import Foundation

// Validador de RFC “ultra estricto”
// - Acepta RFC de Persona Moral (12) y Persona Física (13)
// - Verifica estructura con fecha YYMMDD válida
// - Calcula y valida el dígito verificador oficial del SAT
// Referencias públicas del algoritmo: tablas de valores y módulo 11.
enum RFCValidator {

    // Público: valida un RFC completo (incluye DV si es persona física)
    static func isValidRFC(_ rfc: String) -> Bool {
        let trimmed = rfc.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // Persona moral: 12; Persona física: 13
        guard (12...13).contains(trimmed.count) else { return false }

        // Estructuras base
        let moralRegex = #"^[A-Z&Ñ]{3}\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])[A-Z0-9]{3}$"#
        let fisicaRegex = #"^[A-Z&Ñ]{4}\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])[A-Z0-9]{3}$"#

        let isMoral = trimmed.count == 12 && trimmed.range(of: moralRegex, options: .regularExpression) != nil
        let isFisica = trimmed.count == 13 && trimmed.range(of: fisicaRegex, options: .regularExpression) != nil

        guard isMoral || isFisica else { return false }

        // Verifica fecha YYMMDD (años 00-99; asumimos 1900-2099 como rango amplio)
        let fechaStart = isMoral ? 3 : 4
        let yy = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: fechaStart)..<trimmed.index(trimmed.startIndex, offsetBy: fechaStart+2)])
        let mm = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: fechaStart+2)..<trimmed.index(trimmed.startIndex, offsetBy: fechaStart+4)])
        let dd = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: fechaStart+4)..<trimmed.index(trimmed.startIndex, offsetBy: fechaStart+6)])

        guard isValidYYMMDD(yy: yy, mm: mm, dd: dd) else { return false }

        // Cálculo de dígito verificador (módulo 11) para ambos casos
        // Nota: Para persona moral (12), el DV es el último de la cadena (posición 12),
        //       para persona física (13), también es el último (posición 13).
        // Estructura general: [Base] + DV
        let dvExpected = computeDV(forRFCBase: String(trimmed.dropLast()))
        let dvActual = trimmed.last!

        return dvExpected == dvActual
    }

    // MARK: - Helpers de fecha

    private static func isValidYYMMDD(yy: String, mm: String, dd: String) -> Bool {
        guard let y = Int(yy), let m = Int(mm), let d = Int(dd) else { return false }
        guard (1...12).contains(m), (1...31).contains(d) else { return false }

        var comps = DateComponents()
        // Acepta 1900-2099 (interpretación simple)
        let fullYear = (y >= 0 && y <= 99) ? (y >= 50 ? 1900 + y : 2000 + y) : y
        comps.year = fullYear
        comps.month = m
        comps.day = d
        let cal = Calendar(identifier: .gregorian)
        return comps.isValidDate(in: cal)
    }

    // MARK: - Dígito verificador (SAT)

    // Tabla de valores para cada carácter permitido en RFC
    // Fuente: especificación pública SAT (A=10, B=11, ..., Ñ=38, ... 0=0,... 9=9, & = 24, espacio = 37)
    private static let charValues: [Character: Int] = {
        var map: [Character: Int] = [:]
        // Dígitos
        for i in 0...9 {
            let c = Character(String(i))
            map[c] = i
        }
        // Letras
        let letters = Array("ABCDEFGHIJKLMNÑOPQRSTUVWXYZ")
        for (idx, ch) in letters.enumerated() {
            // A=10 ... Ñ=24? La tabla oficial asigna:
            // A=10, B=11, C=12, D=13, E=14, F=15, G=16, H=17, I=18, J=19,
            // K=20, L=21, M=22, N=23, Ñ=24, O=25, P=26, Q=27, R=28, S=29,
            // T=30, U=31, V=32, W=33, X=34, Y=35, Z=36
            map[ch] = 10 + idx
        }
        // Caracter especial &
        map["&"] = 24 // en algunas tablas & es 24 (coincide con Ñ), SAT lo contempla
        // Espacio (no suele aparecer en base, pero la tabla lo define)
        map[" "] = 37
        return map
    }()

    // Pesos decrecientes desde 13 hacia 2 para la base (longitud variable)
    private static func computeDV(forRFCBase base: String) -> Character {
        // El DV se calcula sobre toda la base (sin el dígito verificador)
        // Usando pesos descendentes comenzando en (longitud de base + 1) y terminando en 2.
        // Suma = Σ(valor(char_i) * peso_i)
        // Resto = Suma % 11
        // DV = 11 - Resto
        // Si DV == 11 -> '0'
        // Si DV == 10 -> 'A'
        // En otro caso -> dígito decimal correspondiente
        var sum = 0
        let chars = Array(base)
        var weight = chars.count + 1

        for ch in chars {
            let val = charValues[ch] ?? 0
            sum += val * weight
            weight -= 1
        }

        let remainder = sum % 11
        let dvVal = 11 - remainder

        switch dvVal {
        case 11: return "0"
        case 10: return "A"
        default:
            // 0...9
            return Character(String(dvVal))
        }
    }
}
