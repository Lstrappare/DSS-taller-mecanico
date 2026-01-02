//
//  FileImportHandler.swift
//  DSS
//
//  Created by AI Agent on 02/01/26.
//

import Foundation
import UniformTypeIdentifiers

class FileImportHandler {
    
    /// Estructura para devolver el contenido leído
    struct ImportedFile {
        let name: String
        let content: String
        let url: URL
    }
    
    /// Lee el contenido de texto de una URL de archivo seleccionada.
    /// Maneja el acceso seguro a recursos (security-scoped resources).
    /// - Parameter url: La URL del archivo seleccionado.
    /// - Returns: Un objeto ImportedFile con el nombre y contenido, o nil si falla.
    static func readText(from url: URL) -> ImportedFile? {
        // En iOS/macOS, al usar .fileImporter, obtenemos una URL fuera de nuestro sandbox inmediato.
        // Debemos pedir acceso seguro.
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            // Check extension for .xlsx
            if url.pathExtension.lowercased() == "xlsx" {
                // Intentamos parsear usando unzip (Native Hack)
                if let extractedText = try extractTextFromXLSX(url: url) {
                    return ImportedFile(name: url.lastPathComponent, content: extractedText, url: url)
                } else {
                    // Fallback si falla el unzip
                     return ImportedFile(
                        name: url.lastPathComponent,
                        content: "[[SYSTEM WARNING: Intenté leer el archivo Excel pero falló la extracción automática. Por favor pide al usuario que lo convierta a CSV.]]",
                        url: url
                    )
                }
            }
            
            // Intentamos leer como UTF-8
            let content = try String(contentsOf: url, encoding: .utf8)
            return ImportedFile(name: url.lastPathComponent, content: content, url: url)
        } catch {
            print("Error leyendo archivo: \(error)")
            // Intento secundario
            if let content = try? String(contentsOf: url, encoding: .windowsCP1252) {
                 return ImportedFile(name: url.lastPathComponent, content: content, url: url)
            }
            return nil
        }
    }
    
    // MARK: - XLSX Native Extraction Logic
    
    private static func extractTextFromXLSX(url: URL) throws -> String? {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let tempFile = tempDir.appendingPathComponent("source.xlsx")
        
        // 1. Crear dir temporal y copiar archivo (porque unzip necesita acceso de fichero)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        try fileManager.copyItem(at: url, to: tempFile)
        
        // 2. Extraer sharedStrings.xml (Diccionario de textos)
        // Nota: unzip imprime a stdout con -p
        let sharedStringsXML = runUnzip(path: tempFile.path, internalPath: "xl/sharedStrings.xml")
        let sharedStrings = parseSharedStrings(xml: sharedStringsXML)
        
        // 3. Extraer sheet1.xml (Estructura)
        // Asumimos que la info principal está en la primera hoja
        let sheet1XML = runUnzip(path: tempFile.path, internalPath: "xl/worksheets/sheet1.xml")
        
        // 4. Reconstruir tabla
        let textContent = parseSheet(xml: sheet1XML, sharedStrings: sharedStrings)
        
        if textContent.isEmpty { return nil }
        return textContent
    }
    
    // Ejecuta /usr/bin/unzip -p <zipfile> <internalfile>
    private static func runUnzip(path: String, internalPath: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        task.arguments = ["-p", path, internalPath]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            print("Unzip falló: \(error)")
            return nil
        }
    }
    
    // Parseo muy básico de XML para sacar <t>...</t> de sharedStrings
    private static func parseSharedStrings(xml: String?) -> [String] {
        guard let xml = xml else { return [] }
        var strings: [String] = []
        // Regex simple para buscar <t>VALOR</t>
        // Nota: Esto es frágil si hay xml namespaces o anidación, pero suficiente para XLSX estándar plano.
        // Mejor usamos componentes simples.
        let pattern = "<t>(.*?)</t>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) {
             let nsString = xml as NSString
             let matches = regex.matches(in: xml, options: [], range: NSRange(location: 0, length: nsString.length))
             for match in matches {
                 if let range = Range(match.range(at: 1), in: xml) {
                     strings.append(String(xml[range]))
                 }
             }
        }
        return strings
    }
    
    // Parseo básico de Sheet1 para celdas
    // <c r="A1" t="s"><v>0</v></c> -> t="s" usa sharedString index de <v>
    // <c r="B1"><v>123</v></c> -> normal number
    private static func parseSheet(xml: String?, sharedStrings: [String]) -> String {
        guard let xml = xml else { return "" }
        var output = ""
        
        // Buscamos filas <row ...> ... </row>
        // Dentro, celdas <c ...> ... </c>
        // Esto es complejo con regex, vamos a intentar simplificar:
        // Extraemos cada bloque <c ... </c> y procesamos linealmente.
        // Ojo: esto perderá la estructura de filas exactas si no parseamos <row>.
        // Para "leer contexto" basta con un volcado secuencial de valores.
        
        let cellPattern = #"<c[^>]*?(?:t="s")?[^>]*?>.*?<v>(.*?)</v>.*?</c>"# 
        // Nota: Regex es muy limitado para XML. Mejor estrategia: XMLParser delegado.
        // Dado que estamos en un solo archivo, usaremos un Parser delegado simple.
        
        let parser = SimpleXLSXSheetParser(xml: xml, sharedStrings: sharedStrings)
        return parser.parse()
    }
}

// Helper interno para parsear la hoja
class SimpleXLSXSheetParser: NSObject, XMLParserDelegate {
    private let xmlData: Data
    private let sharedStrings: [String]
    
    private var resultString = ""
    private var currentElement = ""
    private var currentVal = ""
    private var cellType = "" // "s" para string, "n" o nada para numero
    
    init(xml: String, sharedStrings: [String]) {
        self.xmlData = xml.data(using: .utf8) ?? Data()
        self.sharedStrings = sharedStrings
    }
    
    func parse() -> String {
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        parser.parse()
        return resultString
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "row" {
            resultString += "\n" // Nueva línea por cada fila
        } else if elementName == "c" {
            cellType = attributeDict["t"] ?? ""
            currentVal = ""
        } else if elementName == "v" {
            currentVal = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElement == "v" || currentElement == "t" {
            currentVal += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "c" {
            // Fin de celda, procesar valor
            var finalVal = currentVal.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cellType == "s", let index = Int(finalVal), index < sharedStrings.count {
                finalVal = sharedStrings[index]
            }
            // Añadimos coma o espacio
            resultString += finalVal + ", "
        } else if elementName == "row" {
            // Ya añadimos \n al inicio de la siguiente, o podríamos hacerlo aquí
            // resultString += "\n"
        }
        
        // Limpiar
        if elementName == "c" {
            cellType = ""
            currentVal = ""
        }
    }
}
