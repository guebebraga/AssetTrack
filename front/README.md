# AssetTrack

Aplicación Android de demostración para identificación y trazabilidad de activos
mediante RFID. Está construida en Flutter, funciona **sin backend** y persiste los
datos localmente en el dispositivo.

> **DEMO — DATOS SIMULADOS — RFID NO CONECTADO**

La aplicación está íntegramente en español. No contiene datos clínicos ni
información de pacientes: solo identifica activos, ubicaciones, préstamos,
proveedores y movimientos.

## Funcionalidades

- **Tablero** con indicadores derivados del estado real: total, dentro, fuera,
  préstamos, proveedor, movimientos del día, alertas y pendientes de revisión.
  Incluye gráficos de distribución y actividad semanal.
- **Inventario de activos** con búsqueda, filtros por categoría, ubicación,
  situación y estado operativo, y ordenamiento.
- **Alta y edición de activos** con código interno, nombre, categoría, EPC,
  ubicación, situación administrativa y estado operativo. Las combinaciones
  contradictorias requieren una justificación explícita.
- **Detalle del activo** con historial, última detección, lectores, acceso,
  préstamo/proveedor asociado y correcciones auditables.
- **Movimientos** con filtros por tipo, estado y rango de fechas (hoy, 7 días,
  30 días). Los eventos ambiguos quedan pendientes de revisión; las lecturas
  repetidas no crean movimientos nuevos.
- **Préstamos** con responsable, motivo, vencimiento y devolución. La devolución
  exige confirmación de ingreso físico o una corrección administrativa explícita.
- **Proveedores** con entregas, operaciones preparadas, salidas, recepciones
  parciales, intercambios de unidades con EPC distinto, unidades no registradas y
  cierre explícito con pendientes.
- **Alertas** clasificadas por severidad (crítica, advertencia, información), con
  filtros, resolución y acceso al activo relacionado.
- **Simulador RFID** con lectura de entrada/salida, eventos ambiguos, EPC
  desconocidos y lotes de prueba. No requiere hardware.
- **Configuración** de organización, nombre de la app, umbrales de horas, ventana
  de deduplicación, antenas simuladas, accesos, categorías y restablecimiento de
  la demostración.
- **Persistencia local** en un snapshot JSON con escritura atómica.

## Datos de demostración

El conjunto inicial es determinista y contiene:

- 50 balones de oxígeno codificados `O2-001` a `O2-050`, con EPC ficticios únicos.
- 37 activos dentro y 13 fuera.
- 4 préstamos abiertos.
- 3 activos en poder de proveedor.
- Historial coherente y 28 movimientos generados para el día actual.
- Proveedor configurable **Linde** y otros proveedores de ejemplo.
- Accesos, categorías, alertas y lecturas pendientes de ejemplo.

Todos los nombres, EPC, personas y operaciones son ficticios.

## Arquitectura

```text
lib/
  app.dart, main.dart          Arranque, tema y localización es-AR
  application/                 AppController y providers de Riverpod
  core/                        Tema, almacenamiento y utilidades
  data/                        Repositorio de snapshots
  domain/
    enums.dart                 Enumeraciones y etiquetas en español
    models.dart                Modelos persistidos y AppState
    rfid/rfid.dart             Abstracción de lector, simulador y procesador
    seed/demo_seed.dart        Datos de demostración deterministas
  services/                    Inventario, movimientos, préstamos,
                               proveedores y alertas
  features/                    Pantallas por módulo
  widgets/                     Componentes reutilizables
```

La fuente de verdad es `AppState`, expuesta por `AsyncNotifierProvider`. Cada
mutación se valida en servicios, se guarda en JSON y reconstruye las alertas
derivadas. `LocalStore` abstrae la persistencia: `JsonFileStore` en producción y
`MemoryStore` en pruebas.

## Requisitos

- Flutter 3.47 o superior (Dart 3.13).
- JDK 17.
- Android SDK 36, build-tools y platform-tools.
- Android 7.0 (API 24) o superior.

## Ejecutar

```powershell
flutter pub get
flutter run
```

## Verificar

```powershell
flutter analyze
flutter test
```

Resultado esperado: análisis sin incidencias y 7 pruebas aprobadas. Las pruebas
cubren los datos iniciales, el tablero, la deduplicación de lecturas, los eventos
ambiguos, las devoluciones de préstamos y las recepciones parciales/intercambios
de proveedores.

## Compilar APK

```powershell
flutter build apk --release
```

APK generado:

```text
build/app/outputs/flutter-apk/app-release.apk
```

La build release actual usa la firma de depuración de Flutter. Antes de distribuir
en producción hay que configurar una clave de firma propia.

## Integración con RFID real

La demo **no se conecta a lectores físicos**. El punto de extensión es la interfaz
`RfidReader` (`lib/domain/rfid/rfid.dart`), implementada hoy por `MockRfidReader`.
Para llevarla a producción se requiere:

1. Implementar `RfidReader` con el SDK del fabricante (RAIN RFID / EPC Gen2),
   incluyendo conexión, reconexión, diagnóstico y eventos de antena.
2. Mapear cada lector y antena a un acceso físico y definir si representa entrada,
   salida o zona interna.
3. Definir la política de deduplicación física y resolución de lecturas ambiguas.
4. Gestionar credenciales, red, actualizaciones y monitoreo de lectores.
5. Validar EPC reales contra el inventario y definir el alta de EPC desconocidos.
6. Incorporar autenticación, auditoría y sincronización si se requiere operación
   multiusuario o centralizada.

## Alcance y limitaciones

- Sin backend, autenticación, usuarios ni sincronización entre dispositivos.
- Sin conexión a hardware RFID ni SDK de fabricante.
- Los datos y las alertas son simulados.
- No se almacenan datos de pacientes ni información clínica.
- La APK release está firmada con la clave de depuración.
- El restablecimiento de la demostración borra los cambios locales y vuelve al
  conjunto inicial.

## Privacidad

Toda la información permanece en el almacenamiento local de la aplicación. La app
no envía datos a Internet ni utiliza servicios externos.
