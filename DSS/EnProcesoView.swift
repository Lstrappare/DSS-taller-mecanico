//
//  EnProcesoView.swift
//  DSS
//
//  Created by Jose Cisneros on 05/11/25.
//


import SwiftUI
import SwiftData
internal import Combine

// --- VISTA PRINCIPAL DE "EN PROCESO" ---
struct EnProcesoView: View {
    
    // Consulta todos los servicios activos, ordenados por cuándo terminan
    @Query(sort: \ServicioEnProceso.horaFinEstimada) private var serviciosActivos: [ServicioEnProceso]

    var body: some View {
        VStack(alignment: .leading) {
            // --- Cabecera ---
            Text("Servicios en Proceso")
                .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
            Text("Monitor de trabajos activos en el taller.")
                .font(.title3).foregroundColor(.gray).padding(.bottom, 20)
            
            // --- Cuadrícula de Tickets ---
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 350), spacing: 20)], spacing: 20) {
                    
                    if serviciosActivos.isEmpty {
                        Text("No hay servicios activos en este momento.")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.top, 50)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(serviciosActivos) { servicio in
                            ServicioEnProcesoCard(servicio: servicio)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(30)
    }
}


// --- TARJETA DE "TICKET" INDIVIDUAL (CON TEMPORIZADOR) ---
struct ServicioEnProcesoCard: View {
    @Environment(\.modelContext) private var modelContext
    
    // Necesitamos la lista de Personal para encontrar al mecánico y liberarlo
    @Query private var personal: [Personal]
    
    let servicio: ServicioEnProceso
    
    // --- States del Temporizador ---
    @State private var segundosRestantes: Double
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(servicio: ServicioEnProceso) {
        self.servicio = servicio
        // Inicializa el estado con el tiempo restante del objeto
        _segundosRestantes = State(initialValue: servicio.tiempoRestanteSegundos)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            
            // --- Info del Servicio ---
            Text(servicio.nombreServicio)
                .font(.title2).fontWeight(.bold)
            
            Label(servicio.nombreMecanicoAsignado, systemImage: "person.fill")
                .font(.headline)
                .foregroundColor(Color("MercedesPetrolGreen"))
            
            Divider()
            
            // --- Temporizador ---
            VStack {
                Text("Tiempo Restante:")
                    .font(.caption).foregroundColor(.gray)
                Text(formatearTiempo(segundos: segundosRestantes))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            
            // --- Botón de "Terminar Ahora" (Tu idea) ---
            Button {
                completarServicio()
            } label: {
                Label("Terminar Trabajo Ahora", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.4))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
        }
        .padding()
        .background(Color("MercedesCard"))
        .cornerRadius(15)
        .onReceive(timer) { _ in
            // Cada segundo, resta 1
            if segundosRestantes > 0 {
                segundosRestantes -= 1
            } else {
                // Cuando llega a 0, se completa solo
                completarServicio()
            }
        }
    }
    
    // --- Lógica de Completar Servicio ---
    func completarServicio() {
        // 1. Detener el temporizador para evitar trabajo extra
        timer.upstream.connect().cancel()
        
        // 2. Buscar al mecánico por su DNI
        if let mecanico = personal.first(where: { $0.dni == servicio.dniMecanicoAsignado }) {
            // 3. Liberarlo
            mecanico.estaDisponible = true
        } else {
            print("Error: No se encontró al mecánico con DNI \(servicio.dniMecanicoAsignado)")
        }
        
        // 4. Borrar el "ticket" de la base de datos
        // (Usamos un 'try?' para ignorar errores si el objeto ya fue borrado)
        try? modelContext.delete(servicio)
    }

    // --- Helper para formatear 3600s en "01:00:00" ---
    func formatearTiempo(segundos: Double) -> String {
        let horas = Int(segundos) / 3600
        let minutos = (Int(segundos) % 3600) / 60
        let segs = Int(segundos) % 60
        
        return String(format: "%02i:%02i:%02i", horas, minutos, segs)
    }
}


// --- Preview ---
#Preview {
    EnProcesoView()
        .modelContainer(for: [ServicioEnProceso.self, Personal.self], inMemory: true)
        .preferredColorScheme(.dark)
}
