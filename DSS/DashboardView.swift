import SwiftUI
import SwiftData

struct DashboardView: View {
    
    // --- Conexión a la Navegación ---
    @Binding var seleccion: Vista?
    
    // --- Datos de la App ---
    @AppStorage("user_name") private var userName = ""
    
    // --- Consultas a la Base de Datos ---
    @Query private var personal: [Personal]
    @Query private var productos: [Producto]
    @Query private var servicios: [Servicio]
    @Query(sort: \DecisionRecord.fecha, order: .reverse) private var historial: [DecisionRecord]

    // --- Lógica de la Vista ---
    var isBusinessConfigured: Bool {
        return !personal.isEmpty && !productos.isEmpty && !servicios.isEmpty
    }
    var isPersonalDone: Bool { !personal.isEmpty }
    var isProductosDone: Bool { !productos.isEmpty }
    var isServiciosDone: Bool { !servicios.isEmpty }
    
    var firstName: String {
        return userName.components(separatedBy: " ").first ?? "Admin"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                
                // --- Cabecera de Bienvenida ---
                Text("Bienvenido, \(firstName)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Gestión empresarial orientada a la precisión")
                    .font(.title3)
                    .foregroundColor(.gray)
                
                
                if !isBusinessConfigured {
                    // --- ESTADO: NO CONFIGURADO ---
                    
                    // 1. Tarjeta de Configuración
                    SetupBusinessCard(
                        seleccion: $seleccion,
                        isPersonalDone: isPersonalDone,
                        isProductosDone: isProductosDone,
                        isServiciosDone: isServiciosDone
                    )
                    
                    // 2. Tarjeta de Acciones (en cuadrícula 50/50)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        QuickActionsCard(seleccion: $seleccion)
                        // Dejamos la otra mitad vacía
                    }
                    
                } else {
                    // --- ESTADO: CONFIGURADO ---
                    
                    // 1. Nueva Cuadrícula de Métricas
                    Text("Métricas del Negocio")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Rejilla de 2 columnas para las 4 tarjetas
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 20)], spacing: 20) {
                        
                        // Aquí llamamos 4 veces a la tarjeta que ya tenías
                        MetricCardView(titulo: "Personal Total", valor: "\(personal.count)", color: Color("MercedesPetrolGreen"))
                        MetricCardView(titulo: "Productos", valor: "\(productos.count)", color: .blue)
                        MetricCardView(titulo: "Servicios", valor: "\(servicios.count)", color: .orange)
                        MetricCardView(titulo: "Decisiones Tomadas", valor: "\(historial.count)", color: .purple)
                    }
                    
                    // 2. Tarjeta de Acciones (debajo, ancho completo)
                    QuickActionsCard(seleccion: $seleccion)
                }
                
                Spacer()
            }
            .padding(30)
        }
    }
}


// MARK: - Sub-Vistas (Helpers)

// --- Tarjeta de Métrica (La que ya tenías, ¡es perfecta!) ---
struct MetricCardView: View {
    var titulo: String
    var valor: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading) {
            Text(valor)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(color)
            
            Text(titulo)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(20)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(Color("MercedesCard"))
        .cornerRadius(10)
    }
}

// --- Tarjeta de Configuración Inicial ---
struct SetupBusinessCard: View {
    @Binding var seleccion: Vista?
    let isPersonalDone: Bool
    let isProductosDone: Bool
    let isServiciosDone: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.title)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                VStack(alignment: .leading) {
                    Text("Completa la Configuración de tu Negocio")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Para mejorar tu experiencia, completa los siguientes detalles del negocio")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            Divider()
            HStack(spacing: 15) {
                SetupButton(titulo: "Registrar Personal", icono: "person.2.fill", isCompleted: isPersonalDone) {
                    seleccion = .operaciones_personal
                }
                SetupButton(titulo: "Registrar Productos", icono: "archivebox.fill", isCompleted: isProductosDone) {
                    seleccion = .operaciones_inventario
                }
                SetupButton(titulo: "Registrar Servicios", icono: "wrench.and.screwdriver.fill", isCompleted: isServiciosDone) {
                    seleccion = .operaciones_servicios
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("MercedesCard"))
        .cornerRadius(15)
    }
}

// Botón para la tarjeta de configuración (con checkmark)
struct SetupButton: View {
    var titulo: String
    var icono: String
    var isCompleted: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : icono)
                    .foregroundColor(isCompleted ? .green : .white)
                Text(titulo)
                    .foregroundColor(isCompleted ? .gray : .white)
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color("MercedesBackground"))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
    }
}

// --- Tarjeta de Acciones Rápidas (Simplificada) ---
struct QuickActionsCard: View {
    @Binding var seleccion: Vista?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Acciones Rápidas")
                .font(.title2).fontWeight(.bold).foregroundColor(.white)
            Text("Tareas comunes")
                .font(.subheadline).foregroundColor(.gray)
            
            Button {
            } label: {
                Label("Asignar Servicios", systemImage: "brain.head.profile")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("MercedesBackground"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(Color("MercedesCard"))
        .cornerRadius(15)
    }
}

// --- Preview ---
#Preview {
    DashboardView(seleccion: .constant(.inicio))
        .modelContainer(for: [Personal.self, Producto.self, Servicio.self, DecisionRecord.self], inMemory: true)
        .preferredColorScheme(.dark)
}
