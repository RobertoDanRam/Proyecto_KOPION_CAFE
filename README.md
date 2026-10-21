# Kopion & La Capital del Café — App Móvil (iOS)

Solución móvil integral nativa desarrollada para **EL KOPION S.A. DE C.V.** (papelerías en planteles del IPN: ESCA Santo Tomás y CECyT 1) y la cafetería **La Capital del Café** (ESE Santo Tomás).

Este proyecto representa la primera plataforma de autoservicio móvil (**CRM + Smart-Print**) de la empresa, reemplazando la interacción informal vía WhatsApp y superando las limitaciones operativas de su sistema de escritorio heredado **Sicar X**.

---

# Contexto y Problemática del Negocio

El modelo operativo tradicional de las sucursales enfrentaba tres cuellos de botella críticos:

## 1. Saturación en el Centro de Impresión

Más de **1,800 peticiones diarias por caja**, gestionadas manualmente descargando y convirtiendo formatos desde WhatsApp.

## 2. Inseguridad en el Control de Stock

Desabasto constante de artículos de alta demanda (ej. memorias USB) y pérdida de ventas por falta de visibilidad en tiempo real.

## 3. Saturación de Servidores en la Nube

Riesgo de cuellos de botella en bases de datos cloud por el almacenamiento continuo de historiales masivos de impresiones estudiantiles.

---

# Arquitectura de Almacenamiento Híbrido

Para mitigar los costos de escalado en la nube y evitar saturar la base de datos central, se implementó una arquitectura híbrida de persistencia.

## Nube (API Backend Laravel / Cloud DB)

Manejo exclusivo de órdenes activas:

- Recibido
- Imprimiendo
- Listo

Una vez entregada la orden, se purga del servidor activo.

## Local (SwiftData / Core Data)

Almacenamiento local del historial de compras, archivos e impresiones pasadas directamente en el iPhone del usuario.

**Beneficios:**

- Consulta de recibos anteriores sin conexión.
- Menor consumo de almacenamiento cloud.
- Menor ancho de banda utilizado.

---

# Funcionalidades Principales (MVP)

## 1. Portal Cliente (CRM)

### Autenticación Única

- Registro e inicio de sesión para estudiantes y profesores.
- Validación por plantel:
  - ESCA Santo Tomás
  - CECyT 1
  - ESE Santo Tomás

### Historial Local de Pedidos

- Consulta de compras previas.
- Historial de impresiones almacenado localmente.

### Calificación Proactiva del Servicio

Flujo automático mediante `.sheet` para solicitar:

- Calificación de 1 a 5 estrellas.
- Quejas y sugerencias.
- Retroalimentación estructurada.

---

## 2. Smart-Print

### Encolado Directo de Documentos

Carga de archivos desde iPhone:

- PDF
- DOCX
- JPG
- PNG

### Conversión Automatizada

Script backend encargado de convertir automáticamente todos los formatos a PDF.

### Rastreo de Estados en Tiempo Real

Seguimiento completo del trabajo de impresión:

```text
En Cola
   ↓
Imprimiendo
   ↓
Listo para Recoger
```

---

## 3. Catálogo y Cotizador de Stock

### Visibilidad de Inventario en Tiempo Real

Consulta por sucursal de:

- Memorias USB
- Papelería fina
- Productos de cafetería

### Cotizador Dinámico

Cálculo automático para:

- Copias
- Impresiones
- Engargolados
- Enmicados

---

# Stack Tecnológico

| Capa | Tecnología |
|--------|------------|
| Lenguaje Principal | Swift 5.9 |
| Framework UI | SwiftUI |
| Persistencia Local | SwiftData / Core Data |
| Integración Cloud | Firebase |
| Diseño e Iconografía | SF Symbols 5 + Apple Human Interface Guidelines |
| Autenticación | Firebase auth |


---

# Metodología de Desarrollo (Scrum)

**Periodo:** 2 de septiembre al 11 de noviembre de 2026

```text
[Sprint 1]
Arquitectura y UI Base
        ↓
[Sprint 2]
Conversión a PDF
        ↓
[Sprint 3]
Portal CRM y Stock
        ↓
[Sprint 4]
Analítica y Alertas
        ↓
[Sprint 5]
Pruebas de Estrés y MVP
```

## Sprint 1 (Semanas 1-2)

**2 al 16 de septiembre**

- Levantamiento de requerimientos.
- Diseño UI/UX en SwiftUI.

## Sprint 2 (Semanas 3-5)

**17 de septiembre al 7 de octubre**

- Recepción de archivos.
- Conversión automática a PDF.

## Sprint 3 (Semanas 6-7)

**8 al 21 de octubre**

- Desarrollo CRM.
- Autenticación.
- Consulta de stock.

## Sprint 4 (Semanas 8-9)

**22 de octubre al 4 de noviembre**

- Analítica de consumo.
- Indicadores de inventario.
- Alertas operativas.

## Sprint 5 (Semanas 10-11)

**5 al 11 de noviembre**

- Pruebas concurrentes.
- Corrección de errores.
- Entrega del MVP.

---

# Cumplimiento Normativo y Privacidad (LFPDPPP)

Debido al manejo de documentos académicos y datos personales, la aplicación cumple con la:

**Ley Federal de Protección de Datos Personales en Posesión de los Particulares (LFPDPPP)**

## Aviso de Privacidad

Visible y aceptado durante el proceso de registro.

## Derechos ARCO

### Acceso y Rectificación

Gestión directa desde el perfil del usuario.

### Cancelación y Oposición

Eliminación automática de documentos almacenados una vez concluido el proceso de impresión.

## Seguridad Operativa

- Acceso restringido al personal autorizado.
- Gestión controlada de la cola de impresión.
- Protección de documentos sensibles.

---

# Impacto y Resultados Proyectados

## Reducción del 40%

Disminución en tiempos de procesamiento operativo por documento impreso.

## Reducción del 75%

Reducción en tareas administrativas mediante automatización e IA.

## Optimización del 91.7%

Mejora en tiempos de arranque operativo:

```text
Antes: 5 minutos
Después: 25 segundos
```

Tras migración de HDD a SSD.

## Eliminación del 100%

Eliminación de pérdidas de archivos y desorden operativo generado por solicitudes en WhatsApp.

---

# Referencias Bibliográficas

## 1. La Prensa (2026)

*CDMX cierra 2025 con 45.7% de empleo informal.*

https://oem.com.mx/la-prensa/metropoli/cdmx-cierra-2025-con-45-7-por-ciento-de-empleo-informal-28637309

## 2. El Economista (2025)

*Así usan las empresas la tecnología en México, según el INEGI.*

https://www.eleconomista.com.mx/tecnologia/asi-empresas-tecnologia-mexico-inegi-20250125-743584.html

---

# Estado del Proyecto

**Fase:** Desarrollo MVP  
**Plataforma:** iOS  
**Arquitectura:** CRM + Smart-Print + Inventario  
**Empresa:** EL KOPION S.A. DE C.V.  
**Tecnologías clave:** SwiftUI, SwiftData, Firebase, Laravel, MySQL
