import hashlib
import os

data_dir = r"c:\Users\Sebas\Desktop\Bases datos 1\ULTIMOWORK\data"
sums_file = os.path.join(data_dir, "opencem-v1.0.0-SHA256SUMS.txt")

with open(sums_file, "r", encoding="utf-8") as f:
    lines = [l.strip() for l in f if l.strip()]

print("=== MANIFIESTO OFICIAL DE ZENODO ===")
for line in lines:
    print(line)

print("\n=== VERIFICACIÓN DE INTEGRIDAD SHA-256 ===")
for line in lines:
    parts = line.split()
    if len(parts) >= 2:
        expected_hash = parts[0]
        fname = parts[1].lstrip("*")
        local_path = os.path.join(data_dir, fname)
        if os.path.exists(local_path):
            hasher = hashlib.sha256()
            with open(local_path, "rb") as lf:
                while chunk := lf.read(4 * 1024 * 1024):
                    hasher.update(chunk)
            calc_hash = hasher.hexdigest()
            status = "COINCIDE (OK)" if calc_hash.lower() == expected_hash.lower() else "ERROR DE INTEGRIDAD"
            print(f"[{status}] {fname}")
            print(f"  Esperado: {expected_hash}")
            print(f"  Calculado: {calc_hash}")
        else:
            print(f"[OMITIDO - NO DESCARGADO] {fname}")
