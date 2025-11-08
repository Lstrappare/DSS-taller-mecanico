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

// --- VISTA PRINCIPAL (Actualizada) ---
struct InventarioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Producto.nombre) private var productos: [Producto]
    
    @State private var modalMode: ProductModalMode?

    var body: some View {
        VStack(alignment: .leading) {
            // ... (Cabecera no cambia)
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
            
            // --- Lista de Productos (Actualizada) ---
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(productos) { producto in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(producto.nombre)
                                .font(.title2).fontWeight(.semibold)
                            
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Costo: $\(producto.costo, specifier: "%.2f")")
                                    // Muestra cantidad con unidad
                                    Text("Cantidad: \(producto.cantidad, specifier: "%.2f") \(producto.unidadDeMedida)(s)")
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Precio: $\(producto.precioVenta, specifier: "%.2f")")
                                    // Mostramos margen (no cambia)
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


// --- VISTA DEL FORMULARIO (Actualizada) ---
fileprivate struct ProductFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: ProductModalMode
    
    // States para los campos
    @State private var nombre = ""
    @State private var costoString = ""
    @State private var precioVentaString = ""
    @State private var cantidadString = ""
    @State private var informacion = ""
    @State private var unidadDeMedida = "Pieza" // <-- NUEVO
    let opcionesUnidad = ["Pieza", "Litro", "Galón", "Botella", "Lata", "Juego", "Kit", "Caja", "Metro"]
    
    private var productoAEditar: Producto?
    
    var formTitle: String {
        switch mode {
        case .add: return "Add New Product"
        case .edit: return "Edit Product"
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
            _unidadDeMedida = State(initialValue: producto.unidadDeMedida) // <-- NUEVO
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
                // Picker para la Unidad
                Picker("Unidad de medida", selection: $unidadDeMedida) {
                    ForEach(opcionesUnidad, id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)
            }
            
            TextField("Información (opcional)", text: $informacion)
            
            HStack {
                // ... (Botones Cancel/Delete no cambian)
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
    
    // --- Lógica del Formulario (Actualizada) ---
    func guardarCambios() {
        guard let costo = Double(costoString),
              let precioVenta = Double(precioVentaString),
              let cantidad = Double(cantidadString), // <-- AHORA ES DOUBLE
              !nombre.isEmpty else {
            print("Error: Campos inválidos")
            return
        }
        
        if let producto = productoAEditar {
            producto.costo = costo
            producto.precioVenta = precioVenta
            producto.cantidad = cantidad // <-- CAMBIADO
            producto.informacion = informacion
            producto.unidadDeMedida = unidadDeMedida // <-- CAMBIADO
        } else {
            let nuevoProducto = Producto(
                nombre: nombre,
                costo: costo,
                precioVenta: precioVenta,
                cantidad: cantidad, // <-- CAMBIADO
                unidadDeMedida: unidadDeMedida, // <-- CAMBIADO
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
