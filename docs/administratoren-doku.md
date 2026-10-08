# Administratoren-Dokumentation

Diese Dokumentation richtet sich an IT-Techniker und Administratoren, die die ACTIWARE.IO Docker-Umgebung betreiben und verwalten.

---

## 1. Compose-Dateien Übersicht

Die Umgebung ist in zwei voneinander getrennte Stacks aufgeteilt:

### io-backend (`io-backend/`)

| Datei | Inhalt |
|---|---|
| `docker-compose.yml` | Hauptdatei — startet alle Infrastruktur-Dienste |
| `base.yml` | Basis-Service-Definitionen (Logging, TLS-Mounts) |
| `.env.example` | Vorlage für die `.env` Datei |

Enthaltene Dienste: `postgres`, `redis`, `solr`, `s3`, `qdrant`, `weaviate`, `reranker-transformers`

### io3 (`io3/`)

| Datei | Inhalt |
|---|---|
| `docker-compose.yml` | Hauptdatei — inkludiert alle drei Teil-Stacks |
| `clients.docker-compose.yml` | Web-Clients (`io-client-web`, `io-client-designer`) |
| `services.docker-compose.yml` | Alle Backend-Services (20 Services) |
| `modules.docker-compose.yml` | Module (`io-module-core`, `io-module-output-manager`) |
| `base.yml` | Basis-Service-Definitionen (Logging, TLS-Mounts) |
| `.env.example` | Vorlage für die `.env` Datei |

> Der `docker-compose.yml` im `io3/`-Verzeichnis inkludiert automatisch alle drei Teil-Stacks — es reicht, `docker compose up -d` im `io3/`-Verzeichnis auszuführen.

---

## 2. Startreihenfolge

> [!IMPORTANT]
> Der io-backend-Stack **muss zuerst** gestartet und betriebsbereit sein, bevor io3 gestartet wird.

```bash
# Schritt 1: Backend starten
cd io-backend
docker compose up -d

# Schritt 2: Status prüfen
docker compose ps

# Schritt 3: io3 starten
cd ../io3
docker compose up -d
```

### Interne Abhängigkeiten im io-backend

| Service | Wartet auf |
|---|---|
| `weaviate` | `reranker-transformers` |
| alle anderen | unabhängig, starten parallel |

### Interne Abhängigkeiten im io3

Alle Services warten auf `io-identity-service` (`condition: service_started`).
`io-client-web` wartet zusätzlich auf `io-bff-client-service`.

---

## 3. Environments stoppen

```bash
# io3 stoppen
cd io3
docker compose down

# Backend stoppen
cd ../io-backend
docker compose down
```

> [!CAUTION]
> `docker compose down` entfernt die Container, aber **nicht** die Volumes (Datenbankdaten, S3-Daten etc. bleiben erhalten). Für eine vollständige Bereinigung: `docker compose down -v`

---

## 4. Environments aktualisieren

```bash
# 1. Neue Images ziehen
docker compose pull

# 2. Container neu erstellen und starten
docker compose up -d
```

### Image-Versionen steuern

Jeder Service-Image-Pfad ist vollständig über eine ENV-Variable in der `.env` steuerbar — inkl. Registry, Image-Name und Tag:

```env
# Standard (Docker Hub)
VERSION_IO_SERVICE_PROJECT=actiwareio/io-project-service:3-latest

# Private Registry
VERSION_IO_SERVICE_PROJECT=myregistry.example.com/io-project-service:3.1.0

# Infrastruktur-Images
VERSION_IO_BACKEND_POSTGRES=postgres:18
VERSION_IO_BACKEND_REDIS=redis:8
```

Alle verfügbaren Image-Variablen sind in den jeweiligen `.env.example`-Dateien vollständig aufgeführt.

> Nach Änderung einer Image-Variable: `docker compose pull && docker compose up -d`

---

## 5. Logs einsehen

```bash
# Alle Services
docker compose logs -f

# Einzelner Service
docker compose logs -f io-identity-service
docker compose logs -f postgres

# Letzte N Zeilen
docker compose logs --tail=100 io-project-service
```

---

## 6. EXTERNALADDRESS

Die Variable `EXTERNALADDRESS` ist in **beiden** `.env`-Dateien (io-backend und io3) zwingend zu setzen und muss in beiden identisch sein.

- Muss der **extern erreichbare** DNS-Name oder die IP-Adresse des Hosts sein
- Muss exakt mit dem `CN` / `SAN` des TLS-Zertifikats übereinstimmen
- Wird für alle Service-Endpunkte und OAuth2-Redirects verwendet

> [!CAUTION]
> Ein falscher Wert führt zu Zertifikatswarnungen, nicht erreichbaren Services und fehlgeschlagener OAuth2-Authentifizierung.

---

## 7. Mehrere Instanzen (Multi-Instance)

Um mehrere Instanzen (z. B. Produktion + Test) auf demselben Host zu betreiben:

| Variable | Produktion | Test |
|---|---|---|
| `INSTANCE_PORT_PREFIX` | `30` | `40` |
| `DATABASE_PREFIX` | `io3` | `io3-test` |
| `S3_BUCKET_NAME_PREFIX` | `io3` | `io3-test` |

Alle Ports verschieben sich entsprechend dem Präfix automatisch.

---

Weitere Details zur Zertifikatskonfiguration: [https-umstellung.md](./https-umstellung.md)
Weitere Details zu Passwörtern und Secrets: [passwortverwaltung.md](./passwortverwaltung.md)
