//
//  HistorialView.swift
//  DSS
//
//  Created by Jose Cisneros on 04/11/25.
//


import SwiftUI
import SwiftData

struct HistorialView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Consultamos los DecisionRecord, ordenados por fecha (el más nuevo primero)
    @Query(sort: \DecisionRecord.fecha, order: .reverse) private var historial: [DecisionRecord]

    var body: some View {
        VStack(alignment: .leading) {
            // --- Cabecera ---
            Text("Historial de decisiones")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Aquí se registran todas las decisiones.")
                .font(.title3)
                .foregroundColor(.gray)
                .padding(.bottom, 20)
            
            // --- Lista del Historial ---
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(historial) { registro in
                        // Tarjeta de Historial (basado en el mockup)
                        VStack(alignment: .leading, spacing: 10) {
                            
                            // Título y Fecha
                            HStack {
                                Text(registro.titulo)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Spacer()
                                // Formateamos la fecha
                                Text(registro.fecha, style: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding(.bottom, 5)
                            
                            // Razón
                            Text("Reason: \(registro.razon)")
                                .font(.body)
                                .foregroundColor(.gray)
                            
                            // Query Original (opcional, pero útil)
                            Text("Original Query: \"\(registro.queryUsuario)\"")
                                .font(.footnote)
                                .foregroundColor(.gray.opacity(0.7))
                                .italic()
                                .padding(.top, 5)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("MercedesCard"))
                        .cornerRadius(10)
                        // Botón de eliminar (como en el mockup)
                        .overlay(alignment: .topTrailing) {
                            Button(role: .destructive) {
                                eliminarRegistro(registro: registro)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .padding()
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(30)
    }
    
    // --- Lógica de la Vista ---
    
    private func eliminarRegistro(registro: DecisionRecord) {
        modelContext.delete(registro)
    }
}

#Preview {
    // Añadimos datos de ejemplo para la vista previa
    let container = try! ModelContainer(for: DecisionRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    
    // Dato de ejemplo
    let ejemplo = DecisionRecord(fecha: Date(), titulo: "Hired two new staff members", razon: "Increasing customer demand...", queryUsuario: "Should I hire?")
    container.mainContext.insert(ejemplo)
    
    return HistorialView()
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
