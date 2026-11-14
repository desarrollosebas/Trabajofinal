# Migración SQLite → PostgreSQL

Este directorio contiene los scripts y la documentación del proceso de migración
de datos desde el SQLite original de OpenCEM hacia PostgreSQL.

## Estructura

```
migration/
├── scripts/       # Scripts Python para exportar, transformar y cargar datos
└── README.md      # Este archivo
```

## Proceso general

1. Exportar datos desde SQLite por lotes
2. Transformar y validar contra reglas de calidad
3. Cargar en tablas de staging en PostgreSQL
4. Validar y separar registros válidos de rechazados
5. Insertar válidos en tablas definitivas
6. Enviar rechazados a cuarentena
7. Verificar integridad final
