import SwiftUI
import SwiftData

// (El enum ProductModalMode no cambia)
fileprivate enum ProductModalMode: Identifiable {
    case add
    case edit(Producto)
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let producto): return producto.nombre
        }
    }
}

// --- VISTA PRINCIPAL (¡ACTUALIZADA!) ---
struct InventarioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Producto.nombre) private var productos: [Producto]
    
    @State private var modalMode: ProductModalMode?
    
    // --- 1. STATE PARA EL BUSCADOR ---
    @State private var searchQuery = ""
    
    // --- 2. LÓGICA DE FILTRADO ---
    var filteredProductos: [Producto] {
        if searchQuery.isEmpty {
            return productos
        } else {
            let query = searchQuery.lowercased()
            return productos.filter { producto in
                // Revisa nombre o unidad de medida
                producto.nombre.lowercased().contains(query) ||
                producto.unidadDeMedida.lowercased().contains(query)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            // --- Cabecera (Sin cambios) ---
            HStack {
                Text("Gestión de Inventario")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Button { modalMode = .add }
                label: {
                    Label("Añadir Producto", systemImage: "plus")
                        .font(.headline).padding(.vertical, 10).padding(.horizontal)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)
            Text("Registra y modifica tus productos.")
                .font(.title3).foregroundColor(.gray).padding(.bottom, 20)
            
            // --- 3. TEXTFIELD DE BÚSQUEDA ---
            TextField("Buscar por Nombre o Unidad de Medida...", text: $searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(Color("MercedesCard"))
                .cornerRadius(8)
                .padding(.bottom, 20)
            
            // --- Lista de Productos (Actualizada) ---
            ScrollView {
                LazyVStack(spacing: 15) {
                    // --- 4. USA LA LISTA FILTRADA ---
                    ForEach(filteredProductos) { producto in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(producto.nombre)
                                .font(.title2).fontWeight(.semibold)
                            
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Costo: $\(producto.costo, specifier: "%.2f")")
                                    Text("Cantidad: \(producto.cantidad, specifier: "%.2f") \(producto.unidadDeMedida)(s)")
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Precio: $\(producto.precioVenta, specifier: "%.2f")")
                                    Text(String(format: "Margen de ganancia: %.0f%%", producto.margen))
                                        .font(.headline)
                                        .foregroundColor(producto.margen > 50 ? .green : (producto.margen > 20 ? .yellow : .red))
                                }
                            }
                            .font(.body)
                            .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("MercedesCard"))
                        .cornerRadius(10)
                        .onTapGesture { modalMode = .edit(producto) }
                    }
                }
            }
            Spacer()
        }
        .padding(30)
        .sheet(item: $modalMode) { mode in
            ProductFormView(mode: mode)
        }
    }
}


// --- VISTA DEL FORMULARIO (Sin cambios) ---
// (Esta parte es idéntica a la que ya tenías)
fileprivate struct ProductFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: ProductModalMode
    
    @State private var nombre = ""
    @State private var costoString = ""
    @State private var precioVentaString = ""
    @State private var cantidadString = ""
    @State private var informacion = ""
    @State private var unidadDeMedida = "Pieza"
    let opcionesUnidad = ["Pieza", "Litro", "Onza (Oz)", "Galón", "Botella", "Lata", "Juego", "Kit", "Kg", "g", "Caja", "Metro"]

    
    private var productoAEditar: Producto?
    
    var formTitle: String {
        switch mode {
        case .add: return "Añadir Nuevo Producto"
        case .edit: return "Editar Producto"
        }
    }
    
    // Inicializador
    init(mode: ProductModalMode) {
        self.mode = mode
        
        if case .edit(let producto) = mode {
            self.productoAEditar = producto
            _nombre = State(initialValue: producto.nombre)
            _costoString = State(initialValue: "\(producto.costo)")
            _precioVentaString = State(initialValue: "\(producto.precioVenta)")
            _cantidadString = State(initialValue: "\(producto.cantidad)")
            _informacion = State(initialValue: producto.informacion)
            _unidadDeMedida = State(initialValue: producto.unidadDeMedida)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(formTitle).font(.largeTitle).fontWeight(.bold)
            
            TextField("Nombre del Producto", text: $nombre).disabled(productoAEditar != nil)
            TextField("Costo", text: $costoString)
            TextField("Precio de venta", text: $precioVentaString)
            
            HStack {
                TextField("Cantidad", text: $cantidadString)
                Picker("Unidad de medida", selection: $unidadDeMedida) {
                    ForEach(opcionesUnidad, id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)
            }
            
            TextField("Información (opcional)", text: $informacion)
            
            HStack {
                Button("Cancelar") { dismiss() }
                    .buttonStyle(.plain).padding().foregroundColor(.gray)
                if case .edit(let producto) = mode {
                    Button("Eliminar", role: .destructive) { eliminarProducto(producto) }
                    .buttonStyle(.plain).padding().foregroundColor(.red)
                }
                Spacer()
                Button(productoAEditar == nil ? "Añadir Producto" : "Guardar Cambios") {
                    guardarCambios()
                }
                .buttonStyle(.plain).padding()
                .foregroundColor(Color("MercedesPetrolGreen")).cornerRadius(8)
            }
            .padding(.top, 30)
        }
        .padding(40)
        .background(Color("MercedesBackground"))
        .cornerRadius(15)
        .preferredColorScheme(.dark)
        .textFieldStyle(PlainTextFieldStyle())
        .padding()
        .background(Color("MercedesCard"))
        .cornerRadius(15)
    }
    
    // --- Lógica del Formulario (Sin cambios) ---
    func guardarCambios() {
        guard let costo = Double(costoString),
              let precioVenta = Double(precioVentaString),
              let cantidad = Double(cantidadString),
              !nombre.isEmpty else {
            print("Error: Campos inválidos")
            return
        }
        
        if let producto = productoAEditar {
            producto.costo = costo
            producto.precioVenta = precioVenta
            producto.cantidad = cantidad
            producto.informacion = informacion
            producto.unidadDeMedida = unidadDeMedida
        } else {
            let nuevoProducto = Producto(
                nombre: nombre,
                costo: costo,
                precioVenta: precioVenta,
                cantidad: cantidad,
                unidadDeMedida: unidadDeMedida,
                informacion: informacion
            )
            modelContext.insert(nuevoProducto)
        }
        dismiss()
    }
    
    func eliminarProducto(_ producto: Producto) {
        modelContext.delete(producto)
        dismiss()
    }
}
