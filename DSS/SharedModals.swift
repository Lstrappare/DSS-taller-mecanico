import SwiftUI

// Reusable titled modal container similar to others in the project.
struct ModalView<Content: View>: View {
    var title: String
    var isDanger: Bool = false
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 18) {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(isDanger ? .red : .white)
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(28)
            .background(Color("MercedesCard"))
            .cornerRadius(12)
        }
        .frame(minWidth: 520, minHeight: 380)
        .preferredColorScheme(.dark)
        .textFieldStyle(PlainTextFieldStyle())
    }
}

// Authentication modal used by AccountSettingsView
struct AuthModal: View {
    var title: String
    var prompt: String
    var error: String
    @Binding var passwordAttempt: String
    var isTouchIDEnabled: Bool
    var onAuthTouchID: () -> Void
    var onAuthPassword: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color("MercedesBackground").ignoresSafeArea()
            VStack(spacing: 16) {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(prompt)
                    .font(.title3)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 4)
                
                if isTouchIDEnabled {
                    Button(action: onAuthTouchID) {
                        Label("Usar Huella (Touch ID)", systemImage: "touchid")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color("MercedesPetrolGreen"))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    Text("o")
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Autorizar con contraseña:")
                        .font(.headline)
                        .foregroundColor(.white)
                    SecureField("Contraseña actual", text: $passwordAttempt)
                        .padding(12)
                        .background(Color("MercedesCard"))
                        .cornerRadius(10)
                        .onSubmit { onAuthPassword() }
                        .submitLabel(.done)
                }
                
                if !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancelar")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.25))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onAuthPassword) {
                        Label("Autorizar con Contraseña", systemImage: "lock.fill")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.4))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(28)
            .background(Color("MercedesCard"))
            .cornerRadius(12)
        }
        .frame(minWidth: 520, minHeight: 420)
        .preferredColorScheme(.dark)
    }
}
