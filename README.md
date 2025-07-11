# actiware-io-docker

Dieses Repository stellt die zentrale Docker-Umgebung für ACTIWARE.IO bereit. Es enthält alle notwendigen Docker Compose Dateien, Beispielkonfigurationen und Anleitungen, um die Plattform lokal, für Entwicklung, Test oder im Produktivbetrieb zu betreiben.

## Wofür kann das Repository verwendet werden?

- Bereitstellung einer vollständigen ACTIWARE.IO Umgebung per Docker Compose
- Einfache Verwaltung und Skalierung von Backend, Services und Modulen
- Zentrale Konfiguration über eine `.env` Datei
- Sicherer Betrieb durch empfohlene Passwort- und Zertifikatsverwaltung

## Einstieg & Dokumentation

Vor dem ersten Start solltest du die Dokumentation unter `docs/` lesen und die Konfiguration an deine Umgebung anpassen:

- [index.md – Dokumentationsübersicht](docs/index.md)
- [Administratoren-Dokumentation](docs/administratoren-doku.md)
- [Passwortverwaltung](docs/passwortverwaltung.md)
- [HTTPS-Umstellung](docs/https-umstellung.md)

## Hinweise

- Passe alle sicherheitsrelevanten Einstellungen in der `.env` Datei an, bevor du das System startest.
- Folge den Empfehlungen zur Zertifikats- und Passwortverwaltung.
- Weitere Details findest du in den einzelnen Dokumentationsdateien im `docs/` Verzeichnis.
