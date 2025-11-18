import SwiftUI

// Calcula un puntaje de 0 a 4 para la contraseña
// Reglas: longitud, variedad de caracteres y penalización de contraseñas comunes.
enum PasswordStrength {
    static func score(for password: String) -> Int {
        let length = password.count
        let hasLower = password.range(of: "[a-záéíóúñ]", options: .regularExpression) != nil
        let hasUpper = password.range(of: "[A-ZÁÉÍÓÚÑ]", options: .regularExpression) != nil
        let hasDigit = password.range(of: "\\d", options: .regularExpression) != nil
        let hasSymbol = password.range(of: #"[^A-Za-zÁÉÍÓÚáéíóúÑñ0-9]"#, options: .regularExpression) != nil
        
        var s = 0
        if length >= 8 { s += 1 }
        if length >= 12 { s += 1 }
        if (hasLower && hasUpper) { s += 1 }
        if hasDigit { s += 1 }
        if hasSymbol { s += 1 }
        
        // Penalizaciones básicas
        let common = ["password", "123456", "qwerty", "admin", "letmein"]
        if common.contains(password.lowercased()) { s = max(0, s - 2) }
        if length < 8 { s = 0 }
        
        return min(s, 4)
    }
    
    static func label(for score: Int) -> String {
        switch score {
        case 0: return "Muy débil"
        case 1: return "Débil"
        case 2: return "Media"
        case 3: return "Fuerte"
        default: return "Muy fuerte"
        }
    }
    
    static func color(for score: Int) -> Color {
        switch score {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        case 3: return .green
        default: return Color("MercedesPetrolGreen")
        }
    }
}

// Barra de fortaleza reutilizable
struct PasswordStrengthMeter: View {
    var password: String
    
    private var score: Int { PasswordStrength.score(for: password) }
    private var label: String { PasswordStrength.label(for: score) }
    private var color: Color { PasswordStrength.color(for: score) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.25))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat((Double(score + 1) / 5.0)))
                }
            }
            .frame(height: 6)
            Text("Fortaleza: \(label)")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}
