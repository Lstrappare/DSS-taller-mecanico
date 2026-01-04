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
        !personal.isEmpty && !productos.isEmpty && !servicios.isEmpty
    }
    var isPersonalDone: Bool { !personal.isEmpty }
    var isProductosDone: Bool { !productos.isEmpty }
    var isServiciosDone: Bool { !servicios.isEmpty }
    
    var firstName: String {
        userName.components(separatedBy: " ").first ?? "Admin"
    }
    
    // Inicial circular
    private var userInitial: String {
        let initial = firstName.first.map { String($0).uppercased() } ?? "A"
        return initial
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                
                // --- Cabecera con gradiente y avatar ---
                headerView
                    .transition(.opacity.combined(with: .move(edge: .top)))
                
                if !isBusinessConfigured {
                    // --- ESTADO: NO CONFIGURADO ---
                    SetupBusinessCard(
                        seleccion: $seleccion,
                        isPersonalDone: isPersonalDone,
                        isProductosDone: isProductosDone,
                        isServiciosDone: isServiciosDone
                    )
                    .transition(.opacity.combined(with: .scale))
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        QuickActionsCard(seleccion: $seleccion)
                        EmptyStateHistoryCard(historialCount: historial.count, onTapVerHistorial: {
                            seleccion = .historial
                        })
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isBusinessConfigured)
                    
                } else {
                    // --- ESTADO: CONFIGURADO ---
                    Text("Métricas del Negocio")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .accessibilityLabel("Sección de métricas del negocio")
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 20)], spacing: 20) {
                        MetricCardView(titulo: "Personal Total", valor: "\(personal.count)", color: Color("MercedesPetrolGreen"), icon: "person.2.fill")
                        MetricCardView(titulo: "Productos", valor: "\(productos.count)", color: .blue, icon: "shippingbox.fill")
                        MetricCardView(titulo: "Servicios", valor: "\(servicios.count)", color: .orange, icon: "wrench.and.screwdriver")
                        MetricCardView(titulo: "Decisiones Tomadas", valor: "\(historial.count)", color: .purple, icon: "clock.arrow.circlepath")
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.9), value: personal.count + productos.count + servicios.count + historial.count)
                    
                    QuickActionsCard(seleccion: $seleccion)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                Spacer(minLength: 0)
            }
            .padding(30)
        }
        .animation(.easeInOut(duration: 0.25), value: isBusinessConfigured)
    }
    
    private var headerView: some View {
        ZStack {
            LinearGradient(
                colors: [Color("MercedesCard").opacity(0.8), Color("MercedesBackground").opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color("MercedesPetrolGreen").opacity(0.15))
                        .frame(width: 56, height: 56)
                    Text(userInitial)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color("MercedesPetrolGreen"))
                }
                .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bienvenido, \(firstName)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .accessibilityLabel("Bienvenido, \(firstName)")
                    Text("Gestión empresarial orientada a la precisión")
                        .font(.title3)
                        .foregroundColor(.gray)
                        .accessibilityHint("Panel principal")
                }
                Spacer()
                
                // Atajos visibles de alto nivel
                HStack(spacing: 10) {
                    HeaderQuickButton(title: "Clientes", systemImage: "person.crop.rectangle.stack.fill") {
                        seleccion = .gestionClientes
                        triggerHaptic()
                    }
                    HeaderQuickButton(title: "Personal", systemImage: "person.2.fill") {
                        seleccion = .operaciones_personal
                        triggerHaptic()
                    }
                    HeaderQuickButton(title: "Servicios", systemImage: "wrench.and.screwdriver.fill") {
                        seleccion = .operaciones_servicios
                        triggerHaptic()
                    }
                    HeaderQuickButton(title: "Inventario", systemImage: "archivebox.fill") {
                        seleccion = .operaciones_inventario
                        triggerHaptic()
                    }
                }
            }
            .padding(16)
        }
        .accessibilityElement(children: .combine)
    }
    
    private func triggerHaptic() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
}


// MARK: - Sub-Vistas (Helpers)

struct MetricCardView: View {
    var titulo: String
    var valor: String
    var color: Color
    var icon: String
    
    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 18, weight: .semibold))
                }
                Spacer()
                Text(valor)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .minimumScaleFactor(0.6)
            }
            Text(titulo)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(2)
            
        }
        .padding(18)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(
            ZStack {
                Color("MercedesCard")
                LinearGradient(colors: [Color.white.opacity(0.02), color.opacity(0.05)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
        .scaleEffect(appear ? 1.0 : 0.98)
        .opacity(appear ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                appear = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titulo): \(valor)")
    }
}

// --- Tarjeta de Configuración Inicial ---
struct SetupBusinessCard: View {
    @Binding var seleccion: Vista?
    let isPersonalDone: Bool
    let isProductosDone: Bool
    let isServiciosDone: Bool
    
    private var progreso: Double {
        let total = 3.0
        let done = Double([isPersonalDone, isProductosDone, isServiciosDone].filter { $0 }.count)
        return done / total
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.title)
                    .foregroundColor(Color("MercedesPetrolGreen"))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Completa la Configuración de tu Negocio")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Para mejorar tu experiencia, completa los siguientes detalles del negocio")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
                ProgressView(value: progreso)
                    .progressViewStyle(.linear)
                    .frame(width: 160)
                    .tint(Color("MercedesPetrolGreen"))
                    .accessibilityLabel("Progreso de configuración")
            }
            Divider().opacity(0.5)
            HStack(spacing: 12) {
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
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 5)
        .accessibilityElement(children: .contain)
    }
}

// Botón para la tarjeta de configuración (con checkmark)
struct SetupButton: View {
    var titulo: String
    var icono: String
    var isCompleted: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            if !isCompleted { action() }
            #if os(macOS)
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            #endif
        }) {
            HStack(spacing: 10) {
                Image(systemName: isCompleted ? "checkmark.seal.fill" : icono)
                    .foregroundColor(isCompleted ? .green : .white)
                Text(titulo)
                    .foregroundColor(isCompleted ? .gray : .white)
                Spacer()
                if isCompleted {
                    Text("Completado")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(6)
                }
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color("MercedesBackground"))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
        .accessibilityLabel("\(titulo) \(isCompleted ? "completado" : "")")
    }
}

// --- Tarjeta de Acciones Rápidas (Extendida) ---
struct QuickActionsCard: View {
    @Binding var seleccion: Vista?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Acciones Rápidas")
                        .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    Text("Tareas comunes y accesos directos")
                        .font(.subheadline).foregroundColor(.gray)
                }
                Spacer()
                Button {
                    seleccion = .historial
                    triggerHaptic()
                } label: {
                    Label("Ver Historial", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color("MercedesBackground"))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
            }
            
            actionRow(
                title: "Asignar Servicios",
                subtitle: "Crea un ticket y comienza un trabajo",
                systemImage: "brain.head.profile",
                color: Color("MercedesPetrolGreen"),
                action: {
                    seleccion = .operaciones_servicios
                    triggerHaptic()
                }
            )
            
            HStack(spacing: 10) {
                actionTile(title: "Nuevo Cliente", systemImage: "person.badge.plus", color: .blue) {
                    seleccion = .gestionClientes
                    triggerHaptic()
                }
                actionTile(title: "Nuevo Servicio", systemImage: "plus.circle.fill", color: .orange) {
                    seleccion = .operaciones_servicios
                    triggerHaptic()
                }
                actionTile(title: "Añadir Producto", systemImage: "shippingbox.and.arrow.backward.fill", color: .purple) {
                    seleccion = .operaciones_inventario
                    triggerHaptic()
                }
            }
        }
        .padding(20)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(Color("MercedesCard"))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 5)
    }
    
    private func actionRow(title: String, subtitle: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: systemImage)
                        .foregroundColor(color)
                        .font(.system(size: 18, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundColor(.white)
                    Text(subtitle).font(.caption).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color("MercedesBackground"))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(subtitle)")
    }
    
    private func actionTile(title: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 42, height: 42)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color("MercedesBackground"))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
    
    private func triggerHaptic() {
        #if os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
}

// Tarjeta de estado/recordatorio para historial si está vacío o como complemento
struct EmptyStateHistoryCard: View {
    var historialCount: Int
    var onTapVerHistorial: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Historial de Decisiones")
                        .font(.title3).fontWeight(.bold).foregroundColor(.white)
                    if historialCount == 0 {
                        Text("Aún no hay registros. Toma decisiones automáticas al usar el sistema.")
                            .font(.subheadline).foregroundColor(.gray)
                    } else {
                        Text("Tienes \(historialCount) registro\(historialCount == 1 ? "" : "s").")
                            .font(.subheadline).foregroundColor(.gray)
                    }
                }
                Spacer()
                Button {
                    onTapVerHistorial()
                } label: {
                    Label("Ver", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .padding(.vertical, 8).padding(.horizontal, 12)
                        .background(Color("MercedesPetrolGreen"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.min")
                    .foregroundColor(Color("MercedesPetrolGreen"))
                Text("Usa el asistente estratégico para orientarte en el sistema.")
                    .font(.caption).foregroundColor(.gray)
            }
        }
        .padding(20)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(Color("MercedesCard"))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 5)
    }
}

// Botón compacto del header
fileprivate struct HeaderQuickButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void
    var body: some View {
        Button(action: {
            action()
            #if os(macOS)
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            #endif
        }) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color("MercedesBackground"))
            .cornerRadius(8)
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// --- Preview ---
#Preview {
    DashboardView(seleccion: .constant(.inicio))
        .modelContainer(for: [Personal.self, Producto.self, Servicio.self, DecisionRecord.self], inMemory: true)
        .preferredColorScheme(.dark)
}
