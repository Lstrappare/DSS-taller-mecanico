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
    @Query(sort: \DecisionRecord.fecha, order: .reverse) private var historial: [DecisionRecord]
    
    @State private var searchQuery = ""
    @State private var expandedIDs: Set<PersistentIdentifier> = []
    @State private var registroAEliminar: DecisionRecord?
    @State private var showingDeleteConfirm = false
    
    var filtered: [DecisionRecord] {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return historial }
        let q = searchQuery.lowercased()
        return historial.filter { r in
            r.titulo.lowercased().contains(q) ||
            r.razon.lowercased().contains(q) ||
            r.queryUsuario.lowercased().contains(q)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Cabecera
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Historial de decisiones")
                        .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                    Text(subtitleText)
                        .font(.title3).foregroundColor(.gray)
                }
                Spacer()
                // Contador
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("\(historial.count)")
                        .font(.headline)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color("MercedesCard"))
                .cornerRadius(10)
                .foregroundColor(.white)
            }
            
            // Buscador
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Buscar por Título, Razón o Consulta original...", text: $searchQuery)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(12)
            .background(Color("MercedesCard"))
            .cornerRadius(10)
            
            // Lista
            ScrollView {
                if filtered.isEmpty {
                    VStack(spacing: 8) {
                        Text(searchQuery.isEmpty ? "No hay decisiones registradas aún." : "No se encontraron resultados para “\(searchQuery)”.")
                            .font(.headline).foregroundColor(.gray)
                        if !searchQuery.isEmpty {
                            Button("Limpiar búsqueda") { searchQuery = "" }
                                .buttonStyle(.plain)
                                .foregroundColor(Color("MercedesPetrolGreen"))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(filtered) { registro in
                            HistorialCard(
                                registro: registro,
                                isExpanded: expandedIDs.contains(registro.persistentModelID),
                                onToggleExpand: { toggleExpand(registro) },
                                onDelete: {
                                    registroAEliminar = registro
                                    showingDeleteConfirm = true
                                }
                            )
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(30)
        .confirmationDialog(
            "Eliminar registro",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                if let r = registroAEliminar {
                    eliminarRegistro(registro: r)
                }
            }
            Button("Cancelar", role: .cancel) { registroAEliminar = nil }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
    
    // MARK: - Helpers
    
    private var subtitleText: String {
        if historial.isEmpty { return "Aquí se registrarán todas las decisiones." }
        return "Últimas decisiones registradas."
    }
    
    private func toggleExpand(_ registro: DecisionRecord) {
        let id = registro.persistentModelID
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }
    
    private func eliminarRegistro(registro: DecisionRecord) {
        modelContext.delete(registro)
    }
}

fileprivate struct HistorialCard: View {
    let registro: DecisionRecord
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onDelete: () -> Void
    
    var isManual: Bool {
        let q = registro.queryUsuario.lowercased()
        return q.contains("manual")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    if isManual {
                        Label("Decisión Manual", systemImage: "pencil")
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color("MercedesBackground"))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                    } else {
                        Label("Automática", systemImage: "bolt.fill")
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color("MercedesBackground"))
                            .cornerRadius(6)
                            .foregroundColor(.white)
                    }
                    Text(registro.titulo)
                        .font(.title3).fontWeight(.semibold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(registro.fecha, format: .dateTime.day().month().year())
                        .font(.caption).foregroundColor(.gray)
                    Text(registro.fecha, format: .dateTime.hour().minute())
                        .font(.caption2).foregroundColor(.gray)
                }
            }
            
            // Razón (colapsable)
            VStack(alignment: .leading, spacing: 6) {
                Text(registro.razon)
                    .font(.body)
                    .foregroundColor(.gray)
                    .lineLimit(isExpanded ? nil : 3)
                
                Button(isExpanded ? "Ver menos" : "Ver más") {
                    onToggleExpand()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(Color("MercedesPetrolGreen"))
            }
            
            // Query original
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "quote.opening")
                    .foregroundColor(.gray)
                Text(registro.queryUsuario.isEmpty ? "Sin consulta original registrada." : registro.queryUsuario)
                    .font(.footnote)
                    .foregroundColor(.gray.opacity(0.9))
                    .italic()
                Spacer()
            }
            
            // Footer actions
            HStack {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Acción opcional futura: Guardar como nota, Exportar, etc.
                // Button { } label: {
                //     Label("Exportar", systemImage: "square.and.arrow.up")
                // }.buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("MercedesCard"))
        .cornerRadius(12)
    }
}

#Preview {
    let container = try! ModelContainer(for: DecisionRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let ejemplo1 = DecisionRecord(
        fecha: Date(),
        titulo: "Iniciando: Cambio de Frenos",
        razon: "Asignado a Juan Pérez para vehículo [ABC-123]. Costo piezas: $450.00",
        queryUsuario: "Asignación Automática de Servicio"
    )
    let ejemplo2 = DecisionRecord(
        fecha: Date().addingTimeInterval(-86400),
        titulo: "Decisión Manual",
        razon: "Se decidió posponer la compra de equipo por alta inversión y baja urgencia.",
        queryUsuario: "N/A (Manual)"
    )
    container.mainContext.insert(ejemplo1)
    container.mainContext.insert(ejemplo2)
    
    return HistorialView()
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
