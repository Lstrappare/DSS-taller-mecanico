import SwiftUI
import SwiftData

// 1. AÑADE .configuracion
//    RENOMBRA .person/.inventario/.servicios
enum Vista: Hashable { // Añadimos Hashable para el DisclosureGroup
    case inicio, consultaNegocio, decisiones, historial, serviciosEnProceso
    case operaciones_personal, operaciones_inventario, operaciones_servicios
    case configuracion
}

struct ContentView: View {
    
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @State private var seleccion: Vista? = .inicio

    var body: some View {
        NavigationSplitView {
            List(selection: $seleccion) {
                
                Text("TALLER")
                    .font(.caption).foregroundColor(.gray).padding(.top)

                Label("Inicio", systemImage: "gauge.medium")
                    .tag(Vista.inicio)
                
                // DECISIONES
                Text("DECISIONES")
                    .font(.caption).foregroundColor(.gray).padding(.top)
                
                Label("Asistente estratégico", systemImage: "bubble.left.and.bubble.right.fill")
                    .tag(Vista.consultaNegocio)
                
                Label("Asignar servicios", systemImage: "brain.head.profile")
                    .tag(Vista.decisiones)
                
                Label("Historial de Decisiones", systemImage: "clock.arrow.circlepath")
                    .tag(Vista.historial)
                
                Text("GESTIÓN DEL TALLER")
                    .font(.caption).foregroundColor(.gray).padding(.top)
                    Label("Gestión de Personal", systemImage: "person.2.fill")
                        .tag(Vista.operaciones_personal)
                    
                    Label("Gestión de Inventario", systemImage: "archivebox.fill")
                        .tag(Vista.operaciones_inventario)
                    
                    Label("Gestión de Servicios", systemImage: "wrench.and.screwdriver.fill")
                        .tag(Vista.operaciones_servicios)
                
                Text("PROCESOS")
                    .font(.caption).foregroundColor(.gray).padding(.top)
                Label("Servicios en Proceso", systemImage: "timer")
                    .tag(Vista.serviciosEnProceso)
                
                Text("CUENTA")
                    .font(.caption).foregroundColor(.gray).padding(.top)
                // --- 3. BOTÓN DE CONFIGURACIÓN (NUEVO) ---
                Label("Configuración de Cuenta", systemImage: "gear")
                    .tag(Vista.configuracion)
                
                
                Spacer()
                Divider()
                Button { isLoggedIn = false }
                label: {
                    Label("Cerrar Sesión", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                }.buttonStyle(.plain).padding(.bottom, 10)
            }
            .listStyle(.sidebar)
            .navigationTitle("DSS Taller")
            
        } detail: {
            ZStack {
                Color("MercedesBackground").ignoresSafeArea()
                
                // --- 4. ACTUALIZAR EL SWITCH ---
                switch seleccion {
                case .inicio:
                    DashboardView(seleccion: $seleccion)
                case .consultaNegocio:
                    ConsultaView()
                // Casos de Operaciones
                case .operaciones_personal:
                    PersonalView()
                case .operaciones_inventario:
                    InventarioView()
                case .operaciones_servicios:
                    ServiciosView()
                //
                case .decisiones:
                    DecisionView(seleccion: $seleccion)
                    
                case .historial:
                    HistorialView()
                    
                case .serviciosEnProceso: // <-- NUEVO CASE
                    EnProcesoView()
                // Caso de Configuración
                case .configuracion:
                    AccountSettingsView()
                default:
                    Text("Selecciona una opción")
                        .font(.largeTitle).foregroundColor(.gray)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
