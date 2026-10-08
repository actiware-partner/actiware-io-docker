# Passwortverwaltung und sicherheitsrelevante Einstellungen

Diese Dokumentation beschreibt alle sicherheitsrelevanten Variablen beider Stacks (io-backend und io3), die vor dem ersten Start gesetzt werden müssen.

---

## 1. io-backend — sicherheitsrelevante Variablen

Datei: `io-backend/.env`

### Datenbank (PostgreSQL)

| Variable | Pflicht | Beschreibung |
|---|---|---|
| `DATABASE_USER` | ✅ | PostgreSQL-Superuser-Name |
| `DATABASE_PASS` | ✅ | PostgreSQL-Superuser-Passwort — sicheres Passwort verwenden! |

### S3 / MinIO

| Variable | Pflicht | Beschreibung |
|---|---|---|
| `S3_ACCESS_KEY` | ✅ | Root-Benutzername für S3/MinIO — GUID oder sprechender Name |
| `S3_SECRET_KEY` | ✅ | Root-Passwort für S3/MinIO — mindestens 32 Zeichen, zufällig |

### Solr

| Variable | Pflicht | Beschreibung |
|---|---|---|
| `SOLR_TOKEN` | ✅ | API-Token für den Zugriff der Services auf Solr |
| `SOLR_USER` | ✅ | Solr Basic-Auth Benutzername |
| `SOLR_PASS` | ✅ | Solr Basic-Auth Passwort |

### Vektorspeicher

| Variable | Pflicht | Beschreibung |
|---|---|---|
| `QDRANT_API_KEY` | ✅ | API-Key für Qdrant — mindestens 32 Zeichen, zufällig |
| `WEAVIATE_API_KEY` | ✅ | API-Key für Weaviate — mindestens 32 Zeichen, zufällig |

---

## 2. io3 — sicherheitsrelevante Variablen

Datei: `io3/.env`

### Interne Service-Sicherheit

| Variable | Pflicht | Beschreibung |
|---|---|---|
| `SHARED_SECRET` | ✅ | Shared Secret für interne Service-to-Service-Kommunikation — 32 Zeichen HEX |
| `ENCRYPTION_KEY` | ✅ | Schlüssel für Datenverschlüsselung at rest — 32 Zeichen HEX |
| `CLIENT_SECRET` | ✅ | OAuth2 Client-Secret für inter-Service-Authentifizierung |
| `CLIENT_ID` | ➖ | OAuth2 Client-ID — Default: `IoClient` |

### Standard-Admin-Zugang

| Variable | Pflicht | Beschreibung |
|---|---|---|
| `DEFAULT_USER` | ✅ | Benutzername des initialen Admin-Accounts |
| `DEFAULT_PASS` | ✅ | Passwort des initialen Admin-Accounts — **sofort nach erstem Login ändern!** |
| `DEFAULT_VALIDITY_PERIOD` | ➖ | Token-Gültigkeit in Sekunden — Default: `86400` |

### Datenbank (identisch zu io-backend)

| Variable | Pflicht | Beschreibung |
|---|---|---|
| `DATABASE_USER` | ✅ | Identisch zur io-backend `.env` |
| `DATABASE_PASS` | ✅ | Identisch zur io-backend `.env` |
| `DATABASE_SERVER` | ✅ | Hostname/IP des PostgreSQL-Servers |

### S3 / MinIO (identisch zu io-backend)

| Variable | Pflicht | Beschreibung |
|---|---|---|
| `S3_ACCESS_KEY` | ✅ | Identisch zur io-backend `.env` |
| `S3_SECRET_KEY` | ✅ | Identisch zur io-backend `.env` |
| `S3_BUCKET_NAME_PREFIX` | ✅ | Präfix für alle S3-Buckets — muss instanzweit eindeutig sein (z. B. `io3`) |

### Solr (identisch zu io-backend)

| Variable | Pflicht | Beschreibung |
|---|---|---|
| `SOLR_TOKEN` | ✅ | Identisch zur io-backend `.env` |
| `SOLR_USER` | ✅ | Identisch zur io-backend `.env` |
| `SOLR_PASS` | ✅ | Identisch zur io-backend `.env` |

### Vektorspeicher (identisch zu io-backend)

| Variable | Pflicht | Beschreibung |
|---|---|---|
| `QDRANT_API_KEY` | ✅ | Identisch zur io-backend `.env` |
| `WEAVIATE_API_KEY` | ✅ | Identisch zur io-backend `.env` |

### E-Mail-Versand (Microsoft Graph)

| Variable | Pflicht | Beschreibung |
|---|---|---|
| `SMTP_GRAPH_TENANT_ID` | ✅ | Tenant-ID der Microsoft Entra ID Anwendung |
| `SMTP_GRAPH_CLIENT_ID` | ✅ | Client-ID der Microsoft Entra ID Anwendung |
| `SMTP_GRAPH_CLIENT_SECRET` | ✅ | Client-Secret der Microsoft Entra ID Anwendung |
| `SMTP_PROFILE_FROM_ADDRESS` | ✅ | Absenderadresse für E-Mails |
| `SMTP_BLOCKED_REPORT_RECIPIENTS` | ✅ | Empfänger für Blocked-Reports |
| `SMTP_PROFILE_FROM_NAME` | ➖ | Absenderprofil-Name — Default: `service-default` |
| `SMTP_PROFILE_FROM_DISPLAYNAME` | ➖ | Anzeigename des Absenders — Default: `ACTIWARE.IO` |
| `SMTP_PROFILE_FROM_TRANSPORT` | ➖ | Versandart — Default: `MicrosoftGraph` |

### KI-Integration (optional)

| Variable | Pflicht | Beschreibung |
|---|---|---|
| `AI_API_KEY` | ➖ | API-Key für den KI-Provider (OpenAI, Azure, Anthropic, Mistral etc.) |
| `AI_PROVIDER` | ➖ | KI-Provider — Default: `openai` |
| `AI_MODEL` | ➖ | KI-Modell |
| `MISTRAL_API_KEY` | ➖ | API-Key für Mistral OCR |
| `MISTRAL_OCR_MODEL` | ➖ | Mistral OCR-Modell — Default: `mistral-ocr-latest` |

---

## 3. Vorgehen vor dem ersten Start

1. `cp io-backend/.env.example io-backend/.env`
2. `cp io3/.env.example io3/.env`
3. Alle mit ✅ markierten Variablen in beiden Dateien befüllen
4. Alle Platzhalter (`<PASSWORD>`, `<KEY>`, `<USERNAME>` etc.) ersetzen
5. Zertifikate bereitstellen — siehe [https-umstellung.md](./https-umstellung.md)
6. io-backend starten, dann io3 starten

---

## 4. Empfehlungen zur Passwortsicherheit

- `SHARED_SECRET` und `ENCRYPTION_KEY`: mindestens 32 Zeichen, HEX-Format — Generator: https://www.browserling.com/tools/random-hex
- `S3_ACCESS_KEY`: GUID oder sprechender Name — Generator: https://www.guidgenerator.com
- `S3_SECRET_KEY`: mindestens 32 Zeichen, HEX oder zufällig
- `DATABASE_PASS`, `CLIENT_SECRET`, `QDRANT_API_KEY`, `WEAVIATE_API_KEY`: mindestens 20 Zeichen, Groß-/Kleinbuchstaben, Zahlen, Sonderzeichen
- `DEFAULT_PASS`: nach dem ersten Login **sofort** im System ändern
- Passwörter und Tokens **niemals** unverschlüsselt übertragen oder in Git einchecken
- Passwörter sicher verwahren — z. B. in einem zentralen Secret Manager oder Passwortmanager

> [!IMPORTANT]
> Die `.env`-Dateien enthalten Klartext-Secrets und dürfen **niemals** in ein Git-Repository eingecheckt werden. Nur die `.env.example`-Dateien sind für Git bestimmt.

---

Weitere Details zur Konfiguration: [administratoren-doku.md](./administratoren-doku.md)
