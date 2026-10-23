---
title: Preview (Unreleased)
---

# Preview (Unreleased)

_Stand: 23.10.2026_

Diese Seite sammelt alle Änderungen seit dem letzten Release (`release-3.0`) bis zum aktuellen Stand.
Beim nächsten Release wird der Inhalt in die versionierte Release-Note übernommen.

## Sicherheitshinweise

> ⚠️ **Sicherheitsrelevant:** Der Identity Service prüft Anmelde-Rücksprungadressen. Die Vorlage trägt die Adressen von Designer, Web-Client, Integration-Client und Desktop ein, unbekannte Adressen werden standardmäßig abgelehnt (`REDIRECT_URI_CHECK=enforce`). Zusätzliche Adressen, etwa die der Edge-Sidebar, gehören in `ADDITIONAL_REDIRECT_URIS` (IO3-2571). (#2)

> ⚠️ **Sicherheitsrelevant:** Qdrant, Weaviate und Solr sind nur noch mit Zugangsdaten erreichbar (`QDRANT_API_KEY`, `WEAVIATE_API_KEY`, `SOLR_USER`/`SOLR_PASS`/`SOLR_TOKEN`), anonymer Zugriff auf Weaviate ist abgeschaltet.

> ⚠️ **Sicherheitsrelevant:** `.env`-Dateien werden nicht mehr im Repository geführt. Als Vorlage dienen `io-backend/.env.example` und `io3/.env.example`, damit Kennwörter und Schlüssel nicht versehentlich eingecheckt werden.

> ⚠️ **Sicherheitsrelevant:** Das Einrichtungsskript `setup.sh` schlägt zufällige Kennwörter und Schlüssel vor und schreibt sie zusätzlich im Klartext in `INSTALLATIONSNACHWEIS.md`. Diese Datei nach dem sicheren Ablegen der Werte löschen.

## Features

- Docker-Umgebung für ACTIWARE.IO 3 in zwei getrennten Stacks: `io-backend` für die Infrastruktur (PostgreSQL 18, Redis 8, Solr 9, S3, Qdrant, Weaviate) und `io3` für alle Services, Clients und Module
- Interaktives Einrichtungsskript `setup.sh`, das die Eckdaten abfragt und beide `.env`-Dateien erzeugt
- Anmelde-Adressen für die Redirect-Prüfung des Identity Service, mit eigener Doku-Seite „Anmelde-Adressen“ **[Sicherheit]** (#2)
- Vektorspeicher Weaviate mit Reranker, standardmäßig mit dem mehrsprachigen Modell `baai-bge-reranker-v2-m3`
- Notification Service mit E-Mail-Versand über Microsoft Graph, inklusive Absenderprofil und Empfänger für Sperrberichte
- Lookup Service und Integration Flow Service als neue Services
- Integration-Client als eigener Client (Port `…203`), inklusive SSO-Freigabe im Identity Service

## Improvements

- Der Project Service kennt den Document Viewer Service und kann dessen Einstellungen aktualisieren
- S3-Speicher wechselt von MinIO auf Silo (`pgsty/silo`)
- Container-Images sind über vollständige Image-Angaben konfigurierbar (z.B. `VERSION_IO_SERVICE_IDENTITY=actiwareio/io-identity-service:3-latest`), Standard ist jeweils `3-latest`
- Einheitliche Namen für Docker-Volumes (`postgres-data`, `qdrant-data`, `s3-data`, `weaviate-data`, `redis-data`, `solr-data`)
- Zertifikate, CA-Zertifikat, Kerberos-Keytab und Importverzeichnis liegen unter festen Pfaden auf dem Host (`/aw/certs`, `/aw/CAs`, `/aw/kerberos`, `/aw/imports`) und sind über `CERT_DIR`, `CA_DIR`, `KERBEROS_KEYTAB_DIR` und `IMPORTS_DIR` anpassbar
- Healthcheck für Weaviate, Redis speichert seine Daten in einem eigenen Volume
- Standardsprache der Container ist `de_DE.UTF-8`
- Administratoren-Dokumentation überarbeitet und erweitert (Einrichtung, HTTPS-Umstellung, Passwortverwaltung) und in den zentralen Dokumentationsdienst übernommen

## Bugfixes

- Docs Service: Verknüpfungen zu Business-Objekten und Workflows werden nicht mehr als defekt gemeldet, weil die Endpunkte von Object Storage und Workflow Service gesetzt sind (#1)
- Document Viewer Service: Der Project Service verwendet das gemeinsame Secret (`SHARED_SECRET`) statt des Client-Secrets
- Identity Service erhält seine eigene Endpunkt-Konfiguration, die SSO-Freigaben umfassen nun auch Integration-Client und Anmelde-Callback
- Log-Level-Einstellungen greifen wieder: SQL-Befehle erscheinen nicht mehr auf Stufe `Information`
- Importverzeichnis wird für Core-Modul und Output Manager mit geteilter Mount-Propagation eingebunden, nachträglich eingehängte Laufwerke sind damit im Container sichtbar
- Solr-Healthcheck nutzt die Zugangsdaten und den tatsächlich angelegten Core (`SOL_BASE_INDEXNAME`)

## Migrationshinweise

Dieses Preview ersetzt die Docker-Umgebung von ACTIWARE.IO 3 vollständig. Ein Update einer bestehenden 3.0-Installation in place ist nicht vorgesehen.

- **Neue Verzeichnisstruktur:** Die Compose-Dateien im Wurzelverzeichnis (`docker-compose.yml`, `backend.docker-compose.yml`, `services.docker-compose.yml`, `module.docker-compose.yml`) und die Apache-Proxy-Konfiguration entfallen. Gestartet wird zuerst `io-backend`, danach `io3`.
- **Infrastruktur:** RabbitMQ und MinIO entfallen, neu sind Redis, Silo (S3), Qdrant und Weaviate. PostgreSQL läuft standardmäßig in Version 18.
- **Konfiguration:** `.env` aus `.env.example` erzeugen, am einfachsten mit `./setup.sh`. Die Versionsvariablen heißen jetzt `VERSION_*` statt `VERSION_TAG_*` und enthalten die vollständige Image-Angabe.
- **Volumes:** Wer einen frühen Stand dieser Umgebung betreibt, findet Daten aus `postgre-data`, `qdrant-storage`, `weaviate_data` und `./data/s3` nicht automatisch in den neu benannten Volumes wieder. Daten vor dem Umstieg sichern und übernehmen.
- **Pfade:** Zertifikate, CA, Kerberos-Keytab und Importe werden standardmäßig unter `/aw/…` auf dem Host erwartet statt relativ zum Repository.
- **Anmeldung:** Ab Identity Service 3.0.9 schlägt die Anmeldung mit `Invalid redirect_uri` fehl, wenn eine Client-Adresse fehlt. Zusätzliche Adressen in `ADDITIONAL_REDIRECT_URIS` eintragen, siehe „Anmelde-Adressen“.
- **Logging:** Die Serilog-Variablen heißen `SERILOG__…` statt `SERVICE__SERILOG__…`. Eigene Overrides entsprechend umbenennen.
