<div align="center">

  <img src="https://github.com/user-attachments/assets/a68a9da6-0c4f-49b2-b35d-bb2213afac5a" alt="App Icon" width="120" />

  # DSS para taller mecánico
  
  **Sistema de Soporte a la Decisión (DSS) para Talleres Mecánicos**
  
  [![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
  [![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)]()
  [![Year](https://img.shields.io/badge/Copyright-2026-orange.svg)]()

</div>

---

## 📋 Descripción

**DSS para taller mecánico** es una aplicación de escritorio nativa diseñada para optimizar la gestión operativa y administrativa de talleres mecánicos. Funciona como un Sistema de Soporte a la Decisión (DSS), permitiendo a los administradores y técnicos visualizar métricas clave, gestionar el flujo de trabajo y mantener un control preciso sobre los servicios automotrices.

El sistema está diseñado pensando en la realidad operativa de un taller, manejando desde la recepción del vehículo hasta la facturación, incluyendo lógica avanzada para la gestión del tiempo laboral.

## 📸 Capturas de Pantalla

### Dashboard Principal
Una vista centralizada de los indicadores de rendimiento (KPIs), vehículos en servicio y estado actual del taller.

<img width="100%" alt="Dashboard Screenshot" src="https://github.com/user-attachments/assets/f7cbdaf0-1392-4a6c-92d8-c145b038f4e5" />

---

## ✨ Características Principales

Basado en los módulos del sistema, la aplicación ofrece:

* **📊 Dashboard Ejecutivo:** Visualización gráfica de ingresos, citas activas, y carga de trabajo del personal en tiempo real.
* **🛠 Gestión de Servicios Inteligente:**
    * Registro detallado de reparaciones y mantenimientos.
    * **Lógica de Continuidad:** El sistema detecta si el tiempo estimado de un servicio excede la jornada laboral restante del personal. Si es la hora de salida, el proceso se pausa automáticamente y se reprograma para continuar al día siguiente (o al siguiente día hábil disponible), asegurando un cálculo preciso de horas/hombre.
* **👥 Administración de Clientes y Vehículos:** Historial completo de reparaciones por cliente y automóvil.
* **📝 Cotizaciones y Facturación:** Generación de documentos financieros basados en refacciones y mano de obra.
* **📦 Inventario:** Control de stock de refacciones con alertas de disponibilidad.

## 🚀 Instalación

1. Descarga el instalador `.dmg` desde la [página web](https://resplendent-crumble-dcd475.netlify.app): https://resplendent-crumble-dcd475.netlify.app
2. Arrastra el icono de la aplicación a tu carpeta de **Aplicaciones**.
3. Ejecuta la aplicación.
   * *Nota: Al ser una herramienta interna, asegúrate de tener los permisos necesarios en tu Mac.*

## 🛠 Tecnologías Utilizadas

* **Lenguaje:** Swift
* **Plataforma:** macOS (Nativa)
* **Arquitectura:** MVVM (Model-View-ViewModel)

## 👤 Autor

Desarrollado por **José Manuel Cisneros**.
* Copyright © 2026

## 📄 Licencia

Este proyecto está licenciado bajo la Licencia Apache 2.0 - ver el archivo [LICENSE](LICENSE) para más detalles.
