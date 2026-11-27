# actiware-io-docker

Dieses Repository stellt die zentrale Docker-Umgebung für ACTIWARE.IO bereit.
Es enthält alle notwendigen Docker Compose Dateien, Beispielkonfigurationen und Anleitungen, um die Plattform im Produktivbetrieb, Test oder für Entwicklung zu betreiben.

---

## Verzeichnisstruktur

```
actiware-io-docker/
├── setup.sh                        # Geführte Einrichtung (erzeugt .env-Dateien und Installationsnachweis)
├── io-backend/                     # Infrastruktur-Stack (PostgreSQL, Redis, Solr, S3, Qdrant, Weaviate)
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── base.yml
│   └── config/
│       ├── https/                  # TLS-Konfiguration für Backend-Services
│       ├── postgres/               # PostgreSQL-Konfiguration
│       └── qdrant/                 # Qdrant-Konfiguration
├── io3/                            # Applikations-Stack (alle ACTIWARE.IO Services, Clients, Module)
│   ├── docker-compose.yml
│   ├── clients.docker-compose.yml
│   ├── services.docker-compose.yml
│   ├── modules.docker-compose.yml
│   ├── .env.example
│   ├── base.yml
│   └── config/
│       └── https/                  # TLS-Konfiguration für io3-Services
├── CAs/                            # CA-Zertifikate (Host-Verzeichnis, wird gemountet)
├── certs/                          # Server-Zertifikate (Host-Verzeichnis, wird gemountet)
├── kerberos/                       # Kerberos Keytab (optional, nur für AD-Integration)
└── imports/                        # Import-Verzeichnis für Module
```

---

## Voraussetzungen

- Docker Engine >= 24.x
- Docker Compose Plugin >= 2.x
- Gültige TLS-Zertifikate (selbstsigniert oder CA-signiert)
- Zugang zur ACTIWARE Container Registry (`ghcr.io/actiware-partner/`, privat, siehe [Anmelden an der Registry](#anmelden-an-der-registry))

---

## Anmelden an der Registry

Die Release-Images (Tags `3.x.y` und `3-latest`) liegen privat in `ghcr.io/actiware-partner`. Zum Herunterladen brauchen Sie:

- Mitgliedschaft im GitHub-Team `aw-partner-container-registry` der Organisation `actiware-partner`
- ein Token (Personal Access Token classic) mit dem Recht `read:packages`

Melden Sie sich auf jedem Host einmal an. Das Token wird über stdin übergeben, damit es nicht in der Shell-Historie oder in der Prozessliste landet:

```bash
echo "$GHCR_TOKEN" | docker login ghcr.io -u <github-benutzername> --password-stdin
```

Danach funktioniert `docker compose pull` mit den Standard-Images. Preview- und Prototyp-Images bleiben in `ghcr.io/actiware-io` und gehören nicht zu den Release-Images.

---

## Schnellstart — geführte Einrichtung

Das Skript `setup.sh` ersetzt das manuelle Befüllen der `.env`-Dateien (Schritt 1.2 und 2.2):

```bash
./setup.sh
```

- fragt die Eckdaten ab (Hostname, Port-Präfix, Benutzernamen, E-Mail, optional KI und OCR)
- schlägt für jedes Kennwort bzw. jeden Schlüssel einen zufälligen Wert vor: `Enter` übernimmt, `n` erzeugt einen neuen Vorschlag, `e` erlaubt die Eingabe eines eigenen Werts
- erzeugt `io-backend/.env` und `io3/.env` aus den `.env.example`-Vorlagen, gemeinsame Zugangsdaten (Datenbank, S3, Solr, Qdrant, Weaviate) sind in beiden Dateien identisch
- erzeugt `INSTALLATIONSNACHWEIS.md` mit allen Kennwörtern im Klartext

> [!CAUTION]
> `INSTALLATIONSNACHWEIS.md` dient nur als Installationsnachweis. Kennwörter daraus **sofort in einem Passwortmanager sichern** und die Datei anschließend **löschen** (`rm INSTALLATIONSNACHWEIS.md`).

Läuft der Backend-Stack auf einem anderen Server, im Skript „nur io3“ wählen und die gemeinsamen Zugangsdaten aus der `io-backend/.env` eingeben. Eine bereits vorhandene `.env` wird vor dem Überschreiben als `.env.bak-<Zeitstempel>` gesichert.

Danach weiter mit den Zertifikaten (Schritt 1.1) und dem Start der Stacks (1.3, 2.3). Die manuelle Variante bleibt unten beschrieben.

---

## Schritt 1 — io-backend starten

Der Backend-Stack stellt die gesamte Infrastruktur bereit und **muss vor dem io3-Stack gestartet werden**.

### 1.1 Zertifikate bereitstellen

Alle Zertifikate werden per Bind-Mount in die Container eingebunden. Die Pfade sind über die `.env` konfigurierbar — die **Standardpfade** sind:

| Datei | Standardpfad auf dem Host | Zweck |
|---|---|---|
| `server.crt` | `/aw/certs/server.crt` | TLS-Serverzertifikat (PEM) |
| `server.key` | `/aw/certs/server.key` | Privater Schlüssel des Serverzertifikats (PEM) |
| `ca.crt` | `/aw/CAs/ca.crt` | CA-Zertifikat / Root-CA (PEM) |

> Die Dateinamen **müssen exakt** `server.crt`, `server.key` und `ca.crt` lauten — sie werden so in die Container gemountet und von den Services erwartet.

**Verzeichnisse anlegen und Zertifikate ablegen:**
```bash
mkdir -p /aw/certs /aw/CAs
cp <dein-zertifikat>.crt /aw/certs/server.crt
cp <dein-privkey>.key    /aw/certs/server.key
cp <deine-ca>.crt        /aw/CAs/ca.crt

# Berechtigungen absichern
chmod 640 /aw/certs/server.key
```

Zusätzlich werden `CERT_DIR` und `CA_DIR` von **Redis** und **Qdrant** direkt als Verzeichnis gemountet:

| Variable | Standard | Verwendung |
|---|---|---|
| `CERT_DIR` | `/aw/certs` | Verzeichnis mit `server.crt` + `server.key` → Redis, Qdrant |
| `CA_DIR` | `/aw/CAs` | Verzeichnis mit `ca.crt` → Redis, Qdrant |

### 1.2 `.env` konfigurieren

```bash
cd io-backend
cp .env.example .env
```

**Zwingend erforderliche Variablen:**

| Variable | Beschreibung |
|---|---|
| `EXTERNALADDRESS` | Hostname oder IP-Adresse des Servers (extern erreichbar) |
| `DATABASE_USER` | PostgreSQL-Superuser-Name |
| `DATABASE_PASS` | PostgreSQL-Superuser-Passwort |
| `S3_ACCESS_KEY` | Zugangsdaten für S3/MinIO (Root-User) |
| `S3_SECRET_KEY` | Zugangsdaten für S3/MinIO (Root-Passwort) |
| `SOLR_TOKEN` | Solr API-Token |
| `SOLR_USER` | Solr Basic-Auth Benutzername |
| `SOLR_PASS` | Solr Basic-Auth Passwort |
| `QDRANT_API_KEY` | API-Key für Qdrant |
| `WEAVIATE_API_KEY` | API-Key für Weaviate |

**Optional (Defaults sind produktionsreif):**

| Variable | Default | Beschreibung |
|---|---|---|
| `INSTANCE_PORT_PREFIX` | `30` | Port-Präfix für alle Services (Prod=30, Test=40) |
| `TIMEZONE` | `Europe/Berlin` | Zeitzone aller Container |
| `LANG_POSTGRES` | `en_US.utf8` | Locale für PostgreSQL |
| `SOLR_HEAP` | `1G` | JVM Heap-Größe für Solr |
| `CERT_DIR` | `/aw/certs` | Zertifikatsverzeichnis (redis, qdrant) |
| `CA_DIR` | `/aw/CAs` | CA-Verzeichnis (redis, qdrant) |
| `CERT_SERVER_CRT` | `/aw/certs/server.crt` | Pfad zum Serverzertifikat |
| `CERT_SERVER_KEY` | `/aw/certs/server.key` | Pfad zum privaten Schlüssel |
| `CERT_CA_CRT` | `/aw/CAs/ca.crt` | Pfad zum CA-Zertifikat |

**Image-Versionen (vollständiger Image-Pfad steuerbar):**

| Variable | Default |
|---|---|
| `VERSION_IO_BACKEND_POSTGRES` | `postgres:18` |
| `VERSION_IO_BACKEND_REDIS` | `redis:8` |
| `VERSION_IO_BACKEND_QDRANT` | `qdrant/qdrant:v1` |
| `VERSION_IO_BACKEND_SOLR` | `solr:9` |
| `VERSION_IO_BACKEND_S3` | `docker.io/pgsty/silo:latest` |
| `VERSION_IO_BACKEND_WEAVIATE` | `semitechnologies/weaviate:1.38.3` |
| `VERSION_IO_BACKEND_RERANKER` | `cr.weaviate.io/semitechnologies/reranker-transformers:baai-bge-reranker-v2-m3` |

> Der gesamte Image-Pfad inklusive Registry und Tag ist über die jeweilige Variable steuerbar. Beispiel für eine private Registry:
> ```env
> VERSION_IO_BACKEND_POSTGRES=myregistry.example.com/postgres:18-custom
> ```

### 1.3 Backend starten

```bash
cd io-backend
docker compose up -d
```

**Startsequenz und Abhängigkeiten:**
- `postgres` startet zuerst und stellt den Healthcheck bereit (`pg_isready`)
- `redis` startet mit TLS — erfordert `server.crt`, `server.key`, `ca.crt` unter `CERT_DIR` / `CA_DIR`
- `solr` erzeugt automatisch den Core `io3-objects` beim ersten Start
- `weaviate` wartet auf `reranker-transformers`
- `qdrant` hat keinen Healthcheck (`healthcheck: disable: true`)

**Status prüfen:**
```bash
docker compose ps
docker compose logs -f postgres
```

---

## Schritt 2 — io3 starten

Der Applikations-Stack enthält alle ACTIWARE.IO Services, Clients und Module. Er setzt einen laufenden Backend-Stack voraus.

### 2.1 Zertifikate bereitstellen

Die Zertifikatspfade sind identisch zum Backend — dieselben Dateien werden verwendet:

| Datei | Standardpfad auf dem Host | Zweck |
|---|---|---|
| `server.crt` | `/aw/certs/server.crt` | TLS-Serverzertifikat (PEM) |
| `server.key` | `/aw/certs/server.key` | Privater Schlüssel (PEM) |
| `ca.crt` | `/aw/CAs/ca.crt` | CA-Zertifikat (PEM) |

> Falls bereits für den Backend-Stack vorhanden, ist kein weiterer Schritt nötig.

**Optional — Kerberos (nur bei Active Directory / GSSAPI-Integration):**

Die Keytab wird im Designer hochgeladen: Wartung → Identity Service → Kerberos. Der Identity Service speichert sie
verschlüsselt in seiner Datenbank und schreibt sie beim Hochladen und bei jedem Start nach `KRB5_KTNAME`
(in der Vorlage `/opt/awio/keytab/krb5.keytab`, auf dem Host `KERBEROS_KEYTAB_DIR`, Standard `/aw/kerberos`). Der
Designer warnt, wenn die Keytab keinen Eintrag `HTTP/<Host>` für den Host des Logins enthält; speichern lässt sie sich
trotzdem.

Dafür braucht der Container Schreibrecht auf das Verzeichnis. Der Dienst läuft als Benutzer `io` (UID 3000) mit der
Gruppe `0` (`group_add` in der Vorlage):

```bash
mkdir -p /aw/kerberos
chgrp 0 /aw/kerberos
chmod 770 /aw/kerberos
```

- Fehlt das Schreibrecht, scheitert der Upload mit einer Meldung, die Pfad, Benutzer und Abhilfe nennt; gespeichert
  wird dann nichts.
- Wer die Keytab lieber selbst verwaltet, legt sie als Datei ab und hängt sie schreibgeschützt ein (`:ro`). Der
  Designer zeigt sie dann nur an, und der Identity Service überschreibt sie nicht.
- Ist `KRB5_KTNAME` leer oder nicht gesetzt, zeigt der Designer „Kerberos nicht eingerichtet“.

### 2.2 `.env` konfigurieren

```bash
cd io3
cp .env.example .env
```

**Zwingend erforderliche Variablen:**

| Variable | Beschreibung |
|---|---|
| `EXTERNALADDRESS` | Hostname oder IP-Adresse des Servers (identisch zum Backend) |
| `DEFAULT_USER` | Benutzername des initialen Admin-Accounts |
| `DEFAULT_PASS` | Passwort des initialen Admin-Accounts — **sofort nach erstem Login ändern!** |
| `CLIENT_SECRET` | OAuth2 Client-Secret für inter-Service-Kommunikation |
| `SHARED_SECRET` | Shared Secret für interne Service-to-Service-Authentifizierung |
| `MODULE_SHARED_SECRET` | Modul-Secret für die Aufrufe der Dienste an die Module, gleich in allen Diensten und Modulen, ungleich `SHARED_SECRET`, nur HEX oder base64. Ohne Wert schlagen alle Modulaufrufe fehl, siehe [Passwortverwaltung](docs/administration/passwortverwaltung.md#modul-secret) |
| `ENCRYPTION_KEY` | Schlüssel für Datenverschlüsselung at rest |
| `IDENTITY_ENCRYPTION_KEY` | Eigener Schlüssel des Identity Service, ohne ihn startet er nicht |
| `WORKFLOW_ENCRYPTION_KEY` | Hauptschlüssel für die Daten sensibler Workflows, Base64 von 32 Byte (`openssl rand -base64 32`), ohne ihn startet der Workflow Service nicht, siehe [Verschlüsselung und KI-Aufträge](docs/administration/verschluesselung-und-ki-auftraege.md) |
| `TRANSCRIPTION_ENCRYPTION_KEY` | Hauptschlüssel des AI Transcription Service, Base64 von 32 Byte, ohne ihn startet der Dienst nicht |
| `DATABASE_USER` | PostgreSQL-Benutzer (identisch zur Backend-`.env`) |
| `DATABASE_PASS` | PostgreSQL-Passwort (identisch zur Backend-`.env`) |
| `DATABASE_SERVER` | Hostname/IP des PostgreSQL-Servers |
| `S3_ACCESS_KEY` | S3/MinIO Access Key (identisch zur Backend-`.env`) |
| `S3_SECRET_KEY` | S3/MinIO Secret Key (identisch zur Backend-`.env`) |
| `S3_BUCKET_NAME_PREFIX` | Präfix für alle S3-Buckets (z. B. `io3`) — muss instanzweit eindeutig sein |
| `SOLR_TOKEN` | Solr API-Token (identisch zur Backend-`.env`) |
| `SOLR_USER` | Solr Basic-Auth Benutzername |
| `SOLR_PASS` | Solr Basic-Auth Passwort |
| `QDRANT_API_KEY` | Qdrant API-Key |
| `WEAVIATE_API_KEY` | Weaviate API-Key |
| `SMTP_GRAPH_TENANT_ID` | Microsoft Graph Tenant ID (E-Mail-Versand) |
| `SMTP_GRAPH_CLIENT_ID` | Microsoft Graph Client ID |
| `SMTP_GRAPH_CLIENT_SECRET` | Microsoft Graph Client Secret |
| `SMTP_PROFILE_FROM_ADDRESS` | Absenderadresse für E-Mails |
| `SMTP_BLOCKED_REPORT_RECIPIENTS` | E-Mail-Adresse für Blocked-Reports |

**Optional (Defaults sind produktionsreif):**

| Variable | Default | Beschreibung |
|---|---|---|
| `INSTANCE_PORT_PREFIX` | `30` | Port-Präfix (Prod=30, Test=40) |
| `INSTANCE_HTTP_TYPE` | `https` | HTTP-Schema |
| `CLIENT_ID` | `IoClient` | OAuth2 Client-ID |
| `ADDITIONAL_CLIENT_ORIGINS` | — | Weitere Herkünfte der Clients für CORS und Anmeldung von BFF Client, Project Service und Identity Service, getrennt durch `;`, z. B. eine eigene Domain; Designer, Web-Client und Integration-Client unter `EXTERNALADDRESS` trägt die Vorlage selbst ein, siehe [Herkünfte der Clients](docs/administration/client-herkuenfte.md) |
| `ADDITIONAL_REDIRECT_URIS` | — | Weitere Anmelde-Rücksprungadressen, getrennt durch `;` (z. B. Edge-Sidebar), siehe [Anmelde-Adressen](docs/administration/anmelde-adressen.md) |
| `REDIRECT_URI_CHECK` | `enforce` | Prüfung der Anmelde-Adressen; `warn` nur kurzzeitig zur Fehlersuche |
| `DEFAULT_VALIDITY_PERIOD` | `86400` | Token-Gültigkeit in Sekunden |
| `WORKFLOW_ENCRYPTION_KEY_ID` | `kek-1` | Name des Workflow-Schlüssels im Schlüsselring |
| `TRANSCRIPTION_AUDIT_PSEUDONYM_KEY` | — | Pseudonyme der Benutzer im Audit der AI Transcription; leer: „Person“ |
| `MODULE_ORIGIN_TEMPLATE` | — | Herkunft eines Moduls für die Modul-Oberflächen im Client, z. B. `https://{module}.modules.<EXTERNALADDRESS>:30012`; braucht Wildcard-DNS und -Zertifikat. Leer: Modul-Oberflächen aus, siehe [Modul-Oberflächen im Client](docs/administration/modul-oberflaechen.md) |
| `MODULE_PROXY_EXTRA_HOST_ORIGIN` | — | Weitere Herkunft, die Module einbetten darf, z. B. `chrome-extension://<erweiterungs-id>` der Edge-Sidebar |
| `WORKFLOW_AI_JOBS_ENABLED` | `true` | KI-Aufträge der Workflow-Regeln („KI ausführen“, „KI-Transition“) abarbeiten |
| `WORKFLOW_REPORT_JOBS_ENABLED` | `true` | Berichts-Aufträge am Ende eines Workflow-Vorgangs abarbeiten |
| `MODULE_DEPENDENCY_ENABLED` | `false` | Laufzeit der Modul-Abhängigkeiten im SDK Service, siehe [Modul-Abhängigkeiten](docs/administration/modul-abhaengigkeiten.md) |
| `DATABASE_PORT` | `30432` | PostgreSQL-Port |
| `DATABASE_ENCODING` | `UTF8` | Datenbankzeichensatz |
| `DATABASE_PREFIX` | `io3` | Präfix für alle Datenbanknamen |
| `S3_REGION` | `eu-central-1` | S3-Region |
| `SOL_BASE_INDEXNAME` | `io3-objects` | Solr Core-Name |
| `AI_PROVIDER` | `openai` | KI-Provider (OpenAI, AzureOpenAI, Anthropic, Google, Mistral, Ollama, Custom) |
| `AI_MODEL` | — | KI-Modell |
| `AI_API_KEY` | — | KI API-Key |
| `OCR_ENGINE` | `AI` | OCR-Engine |
| `OCR_PROVIDER` | `MistralOcr` | OCR-Provider |
| `MISTRAL_API_KEY` | — | Mistral API-Key (für OCR) |
| `MISTRAL_OCR_MODEL` | `mistral-ocr-latest` | Mistral OCR-Modell |
| `KERBEROS_KEYTAB_DIR` | `/aw/kerberos` | Pfad zum Kerberos Keytab-Verzeichnis |
| `IMPORTS_DIR` | `/aw/imports` | Pfad für Import-Dateien (Module) |
| `TIMEZONE` | `Europe/Berlin` | Zeitzone |

**Image-Versionen (vollständiger Image-Pfad steuerbar):**

Der gesamte Image-Pfad inklusive Registry und Tag ist pro Service individuell konfigurierbar:

```env
# Beispiel: Standard
VERSION_IO_SERVICE_IDENTITY=ghcr.io/actiware-partner/io-identity-service:3-latest

# Beispiel: Private Registry / anderer Tag
VERSION_IO_SERVICE_IDENTITY=myregistry.example.com/io-identity-service:3.1.0
```

Alle verfügbaren Image-Variablen sind in `io3/.env.example` vollständig dokumentiert und vorbefüllt.

**Service-Endpunkte:**

Die Adressen der Services untereinander stehen als YAML-Anker (`x-<service>Env`) am Anfang von `io3/services.docker-compose.yml` und werden pro Service eingebunden. Sie zeigen auf `${INSTANCE_HTTP_TYPE}://${EXTERNALADDRESS}:${INSTANCE_PORT_PREFIX}<Port>` (siehe Port-Schema) und tragen `SHARED_SECRET` als gemeinsames Secret; zusätzliche Werte in der `.env` sind dafür nicht nötig.

Das Modul-Secret setzt der Anker `x-moduleGrpcEnv` (`SERVICE__MODULEGRPC__SHAREDSECRET` aus `MODULE_SHARED_SECRET`). Ihn bekommen die Dienste, die Module aufrufen (Project, Worker Queue, Workflow, Inbox, AI RAG, AI Chat, Client Service, Data Flow, Integration Flow, Lookup), und in `io3/modules.docker-compose.yml` alle Module. Eigene Module in Override-Dateien brauchen dieselbe Zeile.

| Service | Eingebundene Endpunkte (Auszug) | Wofür |
|---|---|---|
| io-integration-flow-service | `DATAFLOWSERVICE`, `OBJECTSTORAGESERVICE`, `OCRSERVICE`, `WORKFLOWSERVICE`, `INBOXSERVICE`, `DOCSSERVICE` | Knoten „Data Flow ausführen“, Object-Storage-Knoten, Knoten „OCR“, Workflow starten, Knoten „Inbox lesen“, Knoten „Docs suchen/lesen“ |
| io-worker-queue-service | `INTEGRATIONFLOWSERVICE`, `WORKFLOWSERVICE`, `INBOXSERVICE` | Outputs „Integration Flow starten“, „Workflow starten“ und „In Inbox ablegen“ |
| io-inbox-service | `INTEGRATIONFLOWSERVICE` | Archivierung über einen Prozess und Pipeline-Schritt „Integration Flow“ |
| io-workflow-service | `INTEGRATIONFLOWSERVICE`, `DOCSSERVICE` | Regel-Aktion „Prozess starten“, Docs-Elemente in Workflows verknüpfen |
| io-client-service | `INTEGRATIONFLOWSERVICE` | Prozesse aus Modul-Operationen (Back-Channel) |

### 2.3 io3 starten

```bash
cd io3
docker compose up -d
```

Der `docker-compose.yml` im `io3/`-Verzeichnis inkludiert automatisch alle drei Teil-Stacks:
- `clients.docker-compose.yml` — Web-Clients und Designer
- `services.docker-compose.yml` — alle Backend-Services; am Ende steht der optionale Skill Runner auskommentiert, siehe [Skill Runner einschalten](docs/administration/skill-runner.md)
- `modules.docker-compose.yml` — Core- und Output-Manager-Module

**Status prüfen:**
```bash
docker compose ps
docker compose logs -f io-identity-service
```

---

## Port-Schema

Alle Ports folgen dem Schema `{INSTANCE_PORT_PREFIX}{3-stellige Nummer}`.
Bei `INSTANCE_PORT_PREFIX=30` (Standard Produktion):

| Port | Service |
|---|---|
| `30000` | io-vault-service |
| `30001` | io-identity-service |
| `30002` | io-project-service |
| `30003` | io-integration-flow-service |
| `30004` | io-notification-service |
| `30005` | io-ocr-service |
| `30006` | io-worker-queue-service |
| `30007` | io-ai-chat-service |
| `30008` | io-workflow-service |
| `30009` | io-data-flow-service |
| `30010` | io-object-storage-service |
| `30011` | io-client-service |
| `30012` | io-bff-client-service (Web-Einstiegspunkt; mit Modul-Proxy auch `*.modules.<EXTERNALADDRESS>:30012`) |
| `30013` | io-ai-rag-service |
| `30014` | io-inbox-service |
| `30015` | io-sdk-service |
| `30016` | io-ai-agent-functions-service |
| `30018` | io-docs-service |
| `30019` | io-document-viewer-service |
| `30020` | io-lookup-service |
| `30021` | io-ai-transcription-service |
| `30050` | Weaviate HTTP/REST |
| `30051` | Weaviate gRPC |
| `30102` | io-module-core |
| `30134` | io-module-output-manager |
| `30201` | io-client-designer |
| `30202` | io-client-web (Frontend) |
| `30203` | io-integration-client |
| `30333` | Qdrant HTTP |
| `30334` | Qdrant gRPC |
| `30379` | Redis (TLS) |
| `30432` | PostgreSQL |
| `30900` | S3/MinIO API |
| `30901` | S3/MinIO Console |
| `30983` | Solr |

> Der optionale Skill Runner wird nicht am Host veröffentlicht. Er ist nur für den AiChat über das interne Netz `skill_runner_net` erreichbar (gRPC `30024`, Health `30025` im Container).

> Für eine zweite Instanz (z. B. Test) `INSTANCE_PORT_PREFIX=40` setzen — alle Ports verschieben sich entsprechend.

---

## Hinweise

- **Startreihenfolge:** Immer zuerst `io-backend`, dann `io3`.
- **Passwörter:** Alle Secrets (`SHARED_SECRET`, `MODULE_SHARED_SECRET`, `ENCRYPTION_KEY`, `CLIENT_SECRET`) müssen kryptographisch stark sein (min. 32 Zeichen, zufällig). `MODULE_SHARED_SECRET` darf nicht gleich `SHARED_SECRET` sein; eine Änderung verlangt einen Neustart von Diensten und Modulen. Der `DEFAULT_PASS` ist **sofort nach dem ersten Login zu ändern**.
- **Zertifikate:** Alle Services erwarten TLS. Selbstsignierte Zertifikate sind möglich, sofern die CA (`ca.crt`) in alle Container eingebunden ist.
- **Große Dateien:** Uploads gehen direkt an den BFF (Port `…012`), die Vorlage hat keinen Reverse Proxy. Grenzen im Designer, technische Obergrenze (Standard 50 GiB) und Einstellungen für einen eigenen Proxy: [Große Dateien und Upload-Grenzen](docs/administration/upload-grenzen.md).
- **Mehrere Instanzen:** Unterschiedliche `INSTANCE_PORT_PREFIX`-Werte und `DATABASE_PREFIX`-/`S3_BUCKET_NAME_PREFIX`-Werte verwenden, um Kollisionen zu vermeiden.
- **Image-Versionen:** Jeder Service-Image-Pfad ist vollständig über eine ENV-Variable steuerbar — Registry, Image-Name und Tag. Defaults sind in den jeweiligen `.env.example`-Dateien vordefiniert und können direkt überschrieben werden.
