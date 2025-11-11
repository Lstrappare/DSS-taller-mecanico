import SwiftUI
import SwiftData

@main
struct TallerDSSApp: App {
    
    // Lee el valor guardado en la memoria de la Mac
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("hasCompletedRegistration") private var hasCompletedRegistration = false
    
    // --- Contenedor de Base de Datos ---
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Personal.self,
            Producto.self,
            Servicio.self,
            DecisionRecord.self,
            ServicioEnProceso.self,
            ChatMessage.self,
            Cliente.self,
            Vehiculo.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("No se pudo crear el ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            // --- LÓGICA DE VISTA MEJORADA ---
            if isLoggedIn {
                // 1. Si ya inició sesión, va a la app
                ContentView()
                    .modelContainer(sharedModelContainer)
            } else if hasCompletedRegistration {
                // 2. Si NO ha iniciado sesión, PERO YA SE REGISTRÓ,
                //    lo mandamos al Login.
                LoginView()
            } else {
                // 3. Si NUNCA SE HA REGISTRADO, lo mandamos
                //    a registrarse (esto solo pasa 1 vez).
                RegisterView()
            }
        }
    }
}
