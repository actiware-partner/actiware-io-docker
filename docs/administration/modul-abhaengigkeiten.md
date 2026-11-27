---
title: Modul-Abhängigkeiten zur Laufzeit
---

# Modul-Abhängigkeiten zur Laufzeit

Ein Modul kann ein anderes Modul als Abhängigkeit deklarieren und es zur Laufzeit aufrufen. Aufrufen darf es nur, was der
Administrator freigegeben hat. Der SDK Service (`io-sdk-service`) vermittelt diese Aufrufe über den Rückkanal und prüft bei
jedem Aufruf die Freigabe.

Der Schalter `MODULE_DEPENDENCY_ENABLED` betrifft nur diese **Laufzeit**. Der Weg im Designer (Abhängigkeiten ansehen und
freigeben) läuft über den Project Service und braucht den Schalter nicht. Solange der Schalter aus ist, endet jede
Laufzeit-Anfrage mit `not_enabled`.

## Voraussetzungen

- SDK Service, Project Service und alle Fachdienste sind auf einem Stand mit Modul-Abhängigkeiten.
- Der SDK Service kennt den Endpunkt des Project Service. Ohne ihn startet der SDK Service bei eingeschaltetem Schalter
  nicht. Die Vorlage setzt den Endpunkt über den Anker `*projectEnv` (`SERVICE__ENDPOINTS__PROJECTSERVICE__URL` und
  `SERVICE__ENDPOINTS__PROJECTSERVICE__SHAREDSECRET`), Sie müssen dafür nichts eintragen. Betreiben Sie den SDK Service
  ohne diese Vorlage, tragen Sie beide Werte selbst ein.
- Nach dem Ausrollen des SDK Service mit dieser Funktion ist die Modul-Konfiguration (`module_config`) geleert. Veröffentlichen
  Sie jedes Projekt in jeder Solution neu, bevor Sie den Schalter setzen.

## Einschalten

| Schritt | Was |
| ------- | --- |
| `io3/.env` | `MODULE_DEPENDENCY_ENABLED=true` |
| Neustart | `docker compose up -d io-sdk-service` |

Die Vorlage setzt die Variable am `io-sdk-service` als `SERVICE__MODULEDEPENDENCY__ENABLED`. Fehlt die Zeile in der `.env`,
bleibt die Laufzeit aus.

Zwei Grenzwerte lassen sich bei Bedarf als Umgebungsvariablen am `io-sdk-service` ändern, in der Compose-Datei stehen sie
auskommentiert:

| Variable | Standard | Bedeutung |
| -------- | -------- | --------- |
| `SERVICE__MODULEDEPENDENCY__REFRESHSECONDS` | `60` | Wie oft der SDK Service die Freigaben beim Project Service abgleicht. |
| `SERVICE__MODULEDEPENDENCY__MAXAGESECONDS` | `300` | Wie alt ein Stand höchstens sein darf, bevor der SDK Service nicht mehr auf ihn vertraut. |

## Freigaben erteilen und entziehen

Freigaben gibt der Administrator im Designer unter Umgebung › Modules › Abhängigkeiten (Tab „Dependencies“). Ein Entzug wirkt
zur Laufzeit spätestens nach 300 Sekunden.

Die Freigaben liegen im Speicher jedes SDK-Service-Prozesses. Betreiben Sie mehrere Instanzen des SDK Service, erreicht eine
Änderung zunächst nur eine Instanz, die übrigen folgen nach `REFRESHSECONDS`, also standardmäßig nach 60 Sekunden.

Die Freigabe ordnet ehrliche Module und ersetzt nicht die Prüfung, ob Sie einem Modul vertrauen. Geben Sie nur Abhängigkeiten
frei, deren Herkunft Sie kennen.

## Prüfen

1. Die Variable steht am Container:

   ```bash
   docker compose exec io-sdk-service printenv SERVICE__MODULEDEPENDENCY__ENABLED
   ```

2. Der SDK Service ist nach dem Neustart gestartet. Bricht er sofort ab, prüfen Sie im Log den Endpunkt des Project Service:

   ```bash
   docker compose logs io-sdk-service | grep -i "ProjectService"
   ```
