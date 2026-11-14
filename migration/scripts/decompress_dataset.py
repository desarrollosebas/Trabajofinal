import os
import zipfile
import time
import zstandard as zstd

data_dir = r"c:\Users\Sebas\Desktop\Bases datos 1\ULTIMOWORK\data"
zip_path = os.path.join(data_dir, "opencem-v1.0.0-support.zip")
extract_dir = os.path.join(data_dir, "support")
zst_path = os.path.join(data_dir, "opencem-v1.0.0.sqlite.zst")
sqlite_path = os.path.join(data_dir, "opencem-v1.0.0.sqlite")

# 1. Unzip support
print("=== 1. DESCOMPRIMIENDO SUPPORT.ZIP ===")
if not os.path.exists(extract_dir):
    os.makedirs(extract_dir, exist_ok=True)
with zipfile.ZipFile(zip_path, 'r') as zf:
    zf.extractall(extract_dir)
print(f"Archivos extraídos en: {extract_dir}")
for root, dirs, files in os.walk(extract_dir):
    for f in files:
        rel = os.path.relpath(os.path.join(root, f), extract_dir)
        size = os.path.getsize(os.path.join(root, f))
        print(f"  - {rel} ({size:,} bytes)")

# 2. Decompress zst SQLite
print("\n=== 2. DESCOMPRIMIENDO OPENCEM SQLITE.ZST ===")
start_time = time.time()
compressed_size = os.path.getsize(zst_path)
print(f"Archivo origen: {zst_path} ({compressed_size:,} bytes / {compressed_size / (1024*1024):.2f} MB)")
print(f"Archivo destino: {sqlite_path}")

dctx = zstd.ZstdDecompressor()
with open(zst_path, 'rb') as ifh, open(sqlite_path, 'wb') as ofh:
    dctx.copy_stream(ifh, ofh, read_size=1024*1024*4, write_size=1024*1024*4)

elapsed = time.time() - start_time
uncompressed_size = os.path.getsize(sqlite_path)
print(f"Descompresión completada con éxito en {elapsed:.2f} segundos.")
print(f"Tamaño descomprimido: {uncompressed_size:,} bytes ({uncompressed_size / (1024*1024):.2f} MB / {uncompressed_size / (1024*1024*1024):.2f} GB)")
