---
title: Betrieb mit Docker
---

# ACTIWARE.IO mit Docker betreiben

Diese Dokumentation beschreibt die Docker-Umgebung für ACTIWARE.IO. Compose-Dateien, Beispielkonfigurationen und das Einrichtungsskript liegen im Repository [actiware-partner/actiware-io-docker](https://github.com/actiware-partner/actiware-io-docker).

Die Umgebung besteht aus zwei getrennten Stacks, die nacheinander gestartet werden:

1. **io-backend**: Infrastruktur (PostgreSQL, Redis, Solr, S3, Qdrant, Weaviate)
2. **io3**: Applikation (alle ACTIWARE.IO Services, Clients und Module)

## Schnelleinstieg

1. Repository klonen:

   ```bash
   git clone https://github.com/actiware-partner/actiware-io-docker.git
   cd actiware-io-docker
   ```

2. Geführte Einrichtung starten. Das Skript fragt die Eckdaten ab, schlägt Kennwörter vor und erzeugt beide `.env`-Dateien:

   ```bash
   ./setup.sh
   ```

3. Zertifikate bereitstellen, siehe [HTTPS-Konfiguration](./https-umstellung.md).
4. Erst `io-backend`, dann `io3` starten, siehe [Administratoren-Dokumentation](./administratoren-doku.md).

Die vollständige Schritt-für-Schritt-Anleitung mit allen Variablen, Zertifikatspfaden und dem Port-Schema steht in der [README des Repositorys](https://github.com/actiware-partner/actiware-io-docker#readme).

## Inhalte

- [Administratoren-Dokumentation](./administratoren-doku.md)
  - Verzeichnisstruktur und Compose-Dateien
  - Startreihenfolge und Abhängigkeiten
  - Image-Versionierung über ENV-Variablen
  - Update-Prozess

- [Passwortverwaltung](./passwortverwaltung.md)
  - Alle sicherheitsrelevanten Variablen beider Stacks
  - Pflichtfelder vor dem ersten Start
  - Empfehlungen zur Passwortsicherheit

- [HTTPS-Konfiguration](./https-umstellung.md)
  - Zertifikatserstellung mit OpenSSL (selbstsigniert oder CA-basiert)
  - Korrekte Ablage der Zertifikatsdateien auf dem Host
  - Einbindung in io-backend und io3
  - System als vertrauenswürdig einrichten

- [Anmelde-Adressen](./anmelde-adressen.md)
  - Welche Rücksprungadressen die Vorlage für die Anmeldung einträgt
  - Edge-Sidebar und weitere Adressen ergänzen
  - Warum man die Prüfung nicht abschalten sollte

## Weiterführend

- [Speichermangel und unerwartete Neustarts](/handbuch/troubleshooting/out-of-memory): Speicher der Docker-VM, Speicherlimits je Container, Aufräumen von Images und Logs.
- [Betrieb in Kubernetes](/handbuch/admin-guides/kubernetes): dieselbe Plattform ohne Docker Compose.

> [!IMPORTANT]
> Lesen Sie vor dem ersten Start alle Anleitungen vollständig durch und passen Sie alle sicherheitsrelevanten Einstellungen an, bevor Sie die Umgebung starten.

Diese Seiten werden aus dem Ordner `docs/` des Repositorys automatisch in die zentrale Dokumentation übernommen. Änderungen bitte dort vornehmen.
