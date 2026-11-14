# Directorio de Datos

Este directorio almacena los archivos del dataset OpenCEM **localmente**.

> ⚠️ **NO subir estos archivos a Git.** Están excluidos en `.gitignore`.

## Archivos esperados

| Archivo | Tamaño | Cómo obtener |
|---------|--------|--------------|
| `opencem-v1.0.0.sqlite.zst` | 302.1 MB | Descargar de [Zenodo](https://zenodo.org/records/21436223) |
| `opencem-v1.0.0.sqlite` | ~1-2 GB | Descomprimir con `zstd -d opencem-v1.0.0.sqlite.zst` |
| `opencem-v1.0.0-support.zip` | 10.0 MB | Descargar de Zenodo |
| `opencem-v1.0.0-SHA256SUMS.txt` | 849 B | Descargar de Zenodo |

## Verificación de integridad

```bash
# Comparar con el manifiesto oficial
sha256sum -c opencem-v1.0.0-SHA256SUMS.txt
```

## Referencia

Bartels, T. S. et al. (2026). OpenCEM v1.0.0. Zenodo. https://doi.org/10.5281/zenodo.21436223
