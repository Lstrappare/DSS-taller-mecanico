import SwiftUI
import SwiftData

// --- MODO DEL MODAL ---
// Usamos el mismo 'ModalMode' de Personal, pero para Productos
fileprivate enum ProductModalMode: Identifiable {
    case add
    case edit(Producto)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let producto): return producto.nombre // Usamos 'nombre' como ID único
        }
    }
}


// --- VISTA PRINCIPAL ---
struct InventarioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Producto.nombre) private var productos: [Producto]
    
    @State private var modalMode: ProductModalMode?

    var body: some View {
        VStack(alignment: .leading) {
            // --- Cabecera ---
            HStack {
                Text("Inventory Management")
                    .font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Button {
                    modalMode = .add // Abre el modal en modo "Add"
                } label: {
                    Label("Add Product", systemImage: "plus")
                        .font(.headline).padding(.vertical, 10).padding(.horizontal)
                        .background(Color("MercedesPetrolGreen")).foregroundColor(.white).cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)
            
            Text("Track and manage your products")
                .font(.title3).foregroundColor(.gray).padding(.bottom, 20)
            
            // --- Lista de Productos (como en el mockup) ---
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(productos) { producto in
                        // Tarjeta de Producto
                        VStack(alignment: .leading, spacing: 10) {
                            Text(producto.nombre)
                                .font(.title2).fontWeight(.semibold)
                            
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Cost: $\(producto.costo, specifier: "%.2f")")
                                    Text("Quantity: \(producto.cantidad)")
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Price (Approx): $\(producto.precioVenta, specifier: "%.2f")")
                                    Text("Availability: \(producto.disponibilidad)")
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 5) {
                                    // Mostramos el margen calculado
                                    Text(String(format: "Margin: %.0f%%", producto.margen))
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
                        .onTapGesture {
                            modalMode = .edit(producto) // Abre el modal en modo "Edit"
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(30)
        .sheet(item: $modalMode) { mode in
            ProductFormView(mode: mode) // Llama al formulario
        }
    }
}


// --- VISTA DEL FORMULARIO (ADD/EDIT) ---
fileprivate struct ProductFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: ProductModalMode
    
    // States para los campos (Usamos Strings para números para evitar errores de '0')
    @State private var nombre = ""
    @State private var costoString = ""
    @State private var precioVentaString = ""
    @State private var cantidadString = ""
    @State private var informacion = ""
    @State private var disponibilidad = "In Stock"
    let opcionesDisponibilidad = ["In Stock", "Low Stock", "Out of Stock"]

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
            // Pre-llenamos los campos
            _nombre = State(initialValue: producto.nombre)
            _costoString = State(initialValue: "\(producto.costo)")
            _precioVentaString = State(initialValue: "\(producto.precioVenta)")
            _cantidadString = State(initialValue: "\(producto.cantidad)")
            _informacion = State(initialValue: producto.informacion)
            _disponibilidad = State(initialValue: producto.disponibilidad)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(formTitle)
                .font(.largeTitle).fontWeight(.bold)
            
            // Formulario
            TextField("Product Name", text: $nombre).disabled(productoAEditar != nil)
            TextField("Cost", text: $costoString)
            TextField("Sale Price (Approx.)", text: $precioVentaString)
            TextField("Quantity", text: $cantidadString)
            
            Picker("Availability", selection: $disponibilidad) {
                ForEach(opcionesDisponibilidad, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
            
            TextField("Information (Opcional)", text: $informacion)
            
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain).padding().foregroundColor(.gray)
                
                if case .edit(let producto) = mode {
                    Button("Delete", role: .destructive) {
                        eliminarProducto(producto)
                    }
                    .buttonStyle(.plain).padding().foregroundColor(.red)
                }
                
                Spacer()
                
                Button(productoAEditar == nil ? "Add Product" : "Save Changes") {
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
    
    // --- Lógica del Formulario ---
    
    func guardarCambios() {
        // Convertimos los strings a números de forma segura
        guard let costo = Double(costoString),
              let precioVenta = Double(precioVentaString),
              let cantidad = Int(cantidadString),
              !nombre.isEmpty else {
            print("Error: Campos inválidos")
            return
        }
        
        if let producto = productoAEditar {
            // MODO EDITAR
            producto.costo = costo
            producto.precioVenta = precioVenta
            producto.cantidad = cantidad
            producto.informacion = informacion
            producto.disponibilidad = disponibilidad
        } else {
            // MODO AÑADIR
            let nuevoProducto = Producto(
                nombre: nombre,
                costo: costo,
                precioVenta: precioVenta,
                cantidad: cantidad,
                informacion: informacion,
                disponibilidad: disponibilidad
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
