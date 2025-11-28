import Foundation

enum CURPValidator {
    
    static func isValidCURP(_ curp: String) -> Bool {
        let trimmed = curp.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        guard trimmed.count == 18 else { return false }
        
        // Regex oficial
        let regex = #"^[A-Z]{4}\d{6}[HM][A-Z]{2}[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9]\d$"#
        guard NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed) else { return false }
        
        // Extraer fecha YYMMDD (posiciones 4-9)
        let yy = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 4)...trimmed.index(trimmed.startIndex, offsetBy: 5)])
        let mm = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 6)...trimmed.index(trimmed.startIndex, offsetBy: 7)])
        let dd = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 8)...trimmed.index(trimmed.startIndex, offsetBy: 9)])
        
        guard isValidDate(yy: yy, mm: mm, dd: dd, centuryCode: trimmed[trimmed.index(trimmed.startIndex, offsetBy: 16)]) else {
            return false
        }
        
        return validateCheckDigit(trimmed)
    }
    
    /// Valida fecha real usando Calendar, deduciendo siglo por el 17° carácter.
    private static func isValidDate(yy: String, mm: String, dd: String, centuryCode: Character) -> Bool {
        guard let y = Int(yy), let m = Int(mm), let d = Int(dd) else { return false }
        
        // RENAPO: siglo depende del carácter 17
        // 0–9 = 1900–1999
        // A–Z = 2000–2039 aprox.
        
        let year: Int
        if centuryCode.isNumber {
            year = 1900 + y
        } else {
            year = 2000 + y
        }
        
        var comps = DateComponents()
        comps.year = year
        comps.month = m
        comps.day = d
        
        let cal = Calendar(identifier: .gregorian)
        return cal.date(from: comps) != nil
    }
    
    // Dígito verificador oficial RENAPO
    private static func validateCheckDigit(_ curp: String) -> Bool {
        let chars = Array(curp)
        let checkDigitChar = chars.last!
        
        guard let checkDigit = Int(String(checkDigitChar)) else { return false }
        
        let renapoMap: [Character: Int] = [
            "0":0,"1":1,"2":2,"3":3,"4":4,"5":5,"6":6,"7":7,"8":8,"9":9,
            "A":10,"B":11,"C":12,"D":13,"E":14,"F":15,"G":16,"H":17,"I":18,"J":19,
            "K":20,"L":21,"M":22,"N":23,"Ñ":24,"O":25,"P":26,"Q":27,"R":28,"S":29,
            "T":30,"U":31,"V":32,"W":33,"X":34,"Y":35,"Z":36
        ]
        
        var sum = 0
        
        for i in 0..<17 {
            guard let value = renapoMap[chars[i]] else { return false }
            sum += value * (18 - i)
        }
        
        let expected = (10 - (sum % 10)) % 10
        return expected == checkDigit
    }
}
