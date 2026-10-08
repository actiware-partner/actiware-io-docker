# Dokumentationsübersicht

Willkommen zur Dokumentation der ACTIWARE.IO Docker-Umgebung.

Die Umgebung besteht aus zwei getrennten Stacks, die nacheinander gestartet werden:

1. **io-backend** — Infrastruktur (PostgreSQL, Redis, Solr, S3, Qdrant, Weaviate)
2. **io3** — Applikation (alle ACTIWARE.IO Services, Clients und Module)

---

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

- [HTTPS-Umstellung](./https-umstellung.md)
  - Zertifikatserstellung mit OpenSSL (selbstsigniert oder CA-basiert)
  - Korrekte Ablage der Zertifikatsdateien auf dem Host
  - Einbindung in io-backend und io3
  - System als vertrauenswürdig einrichten

---

## Schnelleinstieg

Für den kompletten Start-Ablauf inkl. aller Variablen und Zertifikatspfade lies die **[README.md](../README.md)** — sie ist der primäre Einstiegspunkt für IT-Techniker.

---

> Lies vor dem ersten Start alle Anleitungen vollständig durch.
> Passe alle sicherheitsrelevanten Einstellungen an, bevor du die Umgebung startest.
