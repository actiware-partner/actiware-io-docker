# HTTPS-Konfiguration

Alle Services in io-backend und io3 kommunizieren ausschließlich über TLS/HTTPS. Die Zertifikate werden per Bind-Mount in die Container eingebunden und müssen auf dem Host-System an definierten Pfaden bereitliegen.

---

## 1. Erforderliche Zertifikatsdateien

| Datei | Zielpfad im Container | Standardpfad auf dem Host |
|---|---|---|
| `server.crt` | `/certs/server.crt` | `/aw/certs/server.crt` |
| `server.key` | `/certs/server.key` | `/aw/certs/server.key` |
| `ca.crt` | `/aw/CAs/ca.crt` | `/aw/CAs/ca.crt` |

> [!IMPORTANT]
> Die Dateinamen **müssen exakt** `server.crt`, `server.key` und `ca.crt` lauten. Sie werden fest so in die Container gemountet.

Die Pfade sind über folgende ENV-Variablen konfigurierbar (in beiden `.env`-Dateien):

| Variable | Standard | Beschreibung |
|---|---|---|
| `CERT_SERVER_CRT` | `/aw/certs/server.crt` | Pfad zum Serverzertifikat |
| `CERT_SERVER_KEY` | `/aw/certs/server.key` | Pfad zum privaten Schlüssel |
| `CERT_CA_CRT` | `/aw/CAs/ca.crt` | Pfad zum CA-Zertifikat |
| `CERT_DIR` | `/aw/certs` | Verzeichnis (für Redis + Qdrant) |
| `CA_DIR` | `/aw/CAs` | CA-Verzeichnis (für Redis + Qdrant) |

> `CERT_DIR` und `CA_DIR` existieren nur in `io-backend/.env`.

---

## 2. Option A — Selbstsigniertes Zertifikat (mit eigener CA)

Empfohlen, damit alle Container die CA als vertrauenswürdig akzeptieren.

```bash
mkdir -p /aw/certs /aw/CAs

# 1. CA-Schlüssel und CA-Zertifikat erzeugen
openssl genrsa -out /aw/CAs/ca.key 4096
openssl req -x509 -new -nodes \
  -key /aw/CAs/ca.key \
  -sha256 -days 3650 \
  -subj "/CN=ACTIWARE-CA" \
  -out /aw/CAs/ca.crt

# 2. Server-Schlüssel und CSR erzeugen
openssl genrsa -out /aw/certs/server.key 2048
openssl req -new \
  -key /aw/certs/server.key \
  -subj "/CN=<EXTERNALADDRESS>" \
  -out /aw/certs/server.csr

# 3. SAN-Extension definieren (wichtig für moderne Browser und Services)
cat > /tmp/san.ext <<EOF
subjectAltName = DNS:<EXTERNALADDRESS>, IP:<IP-ADRESSE>
EOF

# 4. Zertifikat durch CA ausstellen
openssl x509 -req \
  -in /aw/certs/server.csr \
  -CA /aw/CAs/ca.crt \
  -CAkey /aw/CAs/ca.key \
  -CAcreateserial \
  -out /aw/certs/server.crt \
  -days 365 -sha256 \
  -extfile /tmp/san.ext

# 5. Berechtigungen absichern
chmod 640 /aw/certs/server.key /aw/CAs/ca.key
```

> Ersetze `<EXTERNALADDRESS>` und `<IP-ADRESSE>` mit dem tatsächlichen DNS-Namen und der IP des Hosts. Beide müssen exakt mit dem Wert in `EXTERNALADDRESS` in der `.env` übereinstimmen.

---

## 3. Option B — Einfaches selbstsigniertes Zertifikat (ohne separate CA)

Schnelle Variante für Testumgebungen. In diesem Fall dient `server.crt` gleichzeitig als CA.

```bash
mkdir -p /aw/certs /aw/CAs

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /aw/certs/server.key \
  -out /aw/certs/server.crt \
  -subj "/CN=<EXTERNALADDRESS>" \
  -addext "subjectAltName=DNS:<EXTERNALADDRESS>"

# server.crt als CA verwenden
cp /aw/certs/server.crt /aw/CAs/ca.crt

chmod 640 /aw/certs/server.key
```

---

## 4. CA als vertrauenswürdig auf dem Host einrichten

Damit auch der Host (z. B. für `curl`, Browser oder Docker-interne Kommunikation) der CA vertraut:

**Ubuntu / Debian:**
```bash
sudo cp /aw/CAs/ca.crt /usr/local/share/ca-certificates/actiware-ca.crt
sudo update-ca-certificates
```

**RHEL / Rocky / AlmaLinux:**
```bash
sudo cp /aw/CAs/ca.crt /etc/pki/ca-trust/source/anchors/actiware-ca.crt
sudo update-ca-trust
```

---

## 5. ENV-Variablen prüfen

In `io-backend/.env` und `io3/.env` müssen die Pfade übereinstimmen:

```env
CERT_SERVER_CRT=/aw/certs/server.crt
CERT_SERVER_KEY=/aw/certs/server.key
CERT_CA_CRT=/aw/CAs/ca.crt

# Nur in io-backend/.env:
CERT_DIR=/aw/certs
CA_DIR=/aw/CAs

# EXTERNALADDRESS muss exakt dem CN/SAN im Zertifikat entsprechen:
EXTERNALADDRESS=meinserver.example.com
```

> `INSTANCE_HTTP_TYPE` ist in `io3/.env` standardmäßig auf `https` gesetzt und muss nicht geändert werden.

---

## 6. Umgebung (neu) starten

```bash
# Backend
cd io-backend
docker compose up -d

# io3
cd ../io3
docker compose up -d
```

> [!IMPORTANT]
> Nach Zertifikatstausch alle betroffenen Container neu starten: `docker compose up -d --force-recreate`

---

Weitere Hinweise zur Konfiguration: [administratoren-doku.md](./administratoren-doku.md)
