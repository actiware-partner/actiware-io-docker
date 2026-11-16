---
title: Verschlüsselung und KI-Aufträge
---

# Verschlüsselung und KI-Aufträge

Diese Seite beschreibt die Schlüssel des Workflow Service und des AI Transcription Service sowie die KI- und Berichts-Aufträge des Workflow Service in der Docker-Vorlage. Die Werte stehen in `io3/.env`, die Compose-Datei `io3/services.docker-compose.yml` reicht sie an die Container weiter.

## Überblick

| Variable in `io3/.env` | Pflicht | Im Container | Zweck |
|---|---|---|---|
| `WORKFLOW_ENCRYPTION_KEY` | ✅ | `SERVICE__ENCRYPTION__KEYS__0__VALUE` (Workflow) | Hauptschlüssel für die Daten sensibler Workflows |
| `WORKFLOW_ENCRYPTION_KEY_ID` | ➖ | `SERVICE__ENCRYPTION__KEYS__0__ID` (Workflow) | Name dieses Schlüssels, Standard `kek-1` |
| `WORKFLOW_ENCRYPTION_ACTIVE_KEY_ID` | ➖ | `SERVICE__ENCRYPTION__ACTIVEKEYID` (Workflow) | Schlüssel für neue Vorgänge, leer: `WORKFLOW_ENCRYPTION_KEY_ID`. Nur bei einer Rotation setzen |
| `TRANSCRIPTION_ENCRYPTION_KEY` | ✅ | `SERVICE__ENCRYPTION__MASTERKEYS__1` (AI Transcription) | Hauptschlüssel für Aufträge mit der Verschlüsselungsrichtlinie `local` |
| `TRANSCRIPTION_ENCRYPTION_ACTIVE_KEY_ID` | ➖ | `SERVICE__ENCRYPTION__ACTIVEKEYID` (AI Transcription) | Schlüssel für neue Aufträge, Standard `1`. Nur bei einer Rotation setzen |
| `TRANSCRIPTION_AUDIT_PSEUDONYM_KEY` | ➖ | `SERVICE__AUDIT__PSEUDONYMKEY` (AI Transcription) | Pseudonyme der Benutzer im Audit; leer: alle Benutzer erscheinen als „Person“ |
| `WORKFLOW_AI_JOBS_ENABLED` | ➖ | `SERVICE__AIJOBS__ENABLED` (Workflow) | KI-Aufträge abarbeiten, Standard `true` |
| `WORKFLOW_REPORT_JOBS_ENABLED` | ➖ | `SERVICE__REPORTJOBS__ENABLED` (Workflow) | Berichts-Aufträge abarbeiten, Standard `true` |

`setup.sh` erzeugt die drei Schlüssel für neue Installationen (32 Zufallsbytes als Base64) und schreibt sie in `INSTALLATIONSNACHWEIS.md`. Von Hand: `openssl rand -base64 32`. Ein gültiger Schlüssel hat 44 Zeichen und endet auf `=`.

> [!WARNING]
> Workflow Service und AI Transcription Service starten nicht, wenn ihr Schlüssel leer oder ungültig ist. Bestehende Installationen tragen beide Schlüssel deshalb **vor** dem Update in `io3/.env` ein, siehe [Update einer bestehenden Installation](#update-einer-bestehenden-installation).

## Schlüssel des Workflow Service

Vorgänge eines Workflows, der als „enthält sensible Daten“ markiert ist, speichert der Workflow Service verschlüsselt: Feldwerte, Kommentare, Dateinamen, Variablen, Benachrichtigungen und die Eingaben und Ergebnisse der KI-Aufträge. Namen von Feldern, Ids, Status und Zeitpunkte bleiben lesbar. Jeder sensible Vorgang bekommt einen eigenen Datenschlüssel, den der Dienst mit dem Hauptschlüssel aus `WORKFLOW_ENCRYPTION_KEY` einwickelt (AES-256-GCM). Der Hauptschlüssel steht nie in der Datenbank.

Regeln:

- **Format:** Base64 von genau 32 Byte. Ein anderer Wert verhindert den Start.
- **Eigener Wert:** Nie gleich `SHARED_SECRET`, sonst startet der Dienst nicht.
- **Nie ändern oder entfernen:** Ohne den Schlüssel sind die Daten der sensiblen Vorgänge verloren. Es gibt keinen Notzugang. Für einen Wechsel gibt es die [Rotation](#rotation-des-workflow-schlüssels).
- **Getrennt sichern:** Den Schlüssel so aufbewahren, dass er zu jeder Datenbanksicherung auffindbar bleibt, aber nie im selben Backup wie die Datenbank. Wer beides hat, liest alles.
- **Gleicher Schlüsselring überall:** Laufen mehrere Instanzen des Workflow Service, bekommen alle dieselben Schlüssel.

Fehlt der Schlüssel eines Vorgangs, antwortet der Dienst mit dem Fehlercode `WORKFLOW_ENCRYPTION_UNAVAILABLE`. Listen und Hintergrundläufe lassen solche Vorgänge aus und schreiben eine Warnung ins Log. Wird ein Projekt gelöscht, überschreibt der Dienst die Datenschlüssel seiner sensiblen Vorgänge; die Werte sind danach auch in älteren Sicherungen nicht mehr lesbar.

Vorgänge, die vor der Verschlüsselung als sensibel gestartet wurden, bleiben unverschlüsselt.

### Rotation des Workflow-Schlüssels

Die Rotation braucht zwei Schritte. Beide in einem Schritt wären falsch: Eine Instanz mit dem alten Schlüsselring könnte Vorgänge nicht lesen, die eine schon umgestellte Instanz angelegt hat.

1. In `io3/services.docker-compose.yml` beim `io-workflow-service` die beiden Zeilen `SERVICE__ENCRYPTION__KEYS__1__…` einkommentieren und in `io3/.env` ergänzen:

   ```bash
   WORKFLOW_ENCRYPTION_KEY_2_ID=kek-2
   WORKFLOW_ENCRYPTION_KEY_2=<Ergebnis von openssl rand -base64 32>
   ```

   Danach `docker compose up -d io-workflow-service` und warten, bis alle Instanzen mit dem neuen Ring laufen.
2. `WORKFLOW_ENCRYPTION_ACTIVE_KEY_ID=kek-2` in `io3/.env` setzen und erneut `docker compose up -d io-workflow-service`. Neue sensible Vorgänge bekommen ab jetzt den neuen Schlüssel. Die vorhandenen Datenschlüssel wickelt der Dienst im Hintergrund neu ein (alle 300 Sekunden, Log: „Wrapped n data key(s) anew with the key …“).
3. Die Rotation ist fertig, wenn diese Abfrage in der Datenbank `io3-backend-workflow` 0 ergibt:

   ```sql
   SELECT count(*) FROM workflow_instance_keys WHERE kek_id <> 'kek-2' AND shredded_at IS NULL;
   ```

4. Den alten Schlüssel erst nach der Aufbewahrungsfrist der Datenbanksicherungen entfernen. Eine ältere Sicherung enthält Datenschlüssel, die nur der alte Schlüssel öffnet.

Gelangt ein Schlüssel nach außen, genügt die Rotation nicht: Mit dem alten Schlüssel und einer alten Sicherung lassen sich die Datenschlüssel darin öffnen. Ein Neuverschlüsseln aller Werte ist noch nicht automatisiert (IO3-3811).

## Schlüssel des AI Transcription Service

Der Hauptschlüssel `TRANSCRIPTION_ENCRYPTION_KEY` gilt für Transkriptionsprofile mit der Verschlüsselungsrichtlinie `local`. Dann verschlüsselt der Dienst Audio, Abschnitte und Transkript jedes Auftrags im S3-Speicher mit einem eigenen Auftragsschlüssel, den der Hauptschlüssel einwickelt.

- **Format:** Base64 von genau 32 Byte. Ein leerer oder fehlerhafter Wert verhindert den Start.
- **Nie ändern oder entfernen:** Ohne ihn sind alle damit verschlüsselten Aufträge unlesbar. Er gehört in die Sicherung der Secrets.

**Rotation:** In zwei Schritten wie beim Workflow Service. Erst die Zeile `SERVICE__ENCRYPTION__MASTERKEYS__2` beim `io-ai-transcription-service` einkommentieren, `TRANSCRIPTION_ENCRYPTION_KEY_2` in `io3/.env` setzen und den Dienst neu starten. Danach `TRANSCRIPTION_ENCRYPTION_ACTIVE_KEY_ID=2` setzen und erneut neu starten. Den alten Schlüssel erst entfernen, wenn diese Abfrage 0 ergibt (ein Werkzeug zum Neueinwickeln gibt es nicht; Aufträge ohne Höchstdauer halten den alten Schlüssel, bis sie gelöscht werden):

```sql
SELECT count(*) FROM content_keys WHERE master_key_id = '1';
```

**Pseudonym-Schlüssel:** `TRANSCRIPTION_AUDIT_PSEUDONYM_KEY` macht aus jedem Benutzer im Audit ein gleichbleibendes Pseudonym wie „Person 3F9A2C1B“. Ohne Wert erscheinen alle Benutzer nur als „Person“. Mindestens 32 Byte als Base64; ein neuer Wert gibt allen Benutzern neue Pseudonyme, Daten gehen dabei nicht verloren.

## KI-Aufträge und Berichts-Aufträge des Workflow Service

**KI-Aufträge:** Die Regel-Aktionen „KI ausführen“ und „KI-Transition“ warten nicht auf die KI. Sie legen einen Auftrag in der Tabelle `workflow_ai_jobs` an, ein Worker im Workflow Service führt ihn aus und schreibt das Ergebnis zurück. Agenten laufen im AiChat (Port `…007`, `SERVICE__ENDPOINTS__AICHATSERVICE__*`), Prompt Functions in den AI Agent Functions (Port `…016`, Anker `x-aiAgentFunctionsEnv`). Der Aufruf läuft im Namen des Benutzers, der die Regel ausgelöst hat.

**Berichts-Aufträge:** Am Ende eines Vorgangs kann der Workflow einen Bericht erzeugen: eine Seite in Docs, eine Mail mit der `.md`-Datei oder ein Dokument an einem Objekt. Diese Aufträge stehen in `workflow_report_jobs` und laufen über einen eigenen Worker.

Beide Worker sind im Dienst standardmäßig aus, die Vorlage schaltet sie ein (`WORKFLOW_AI_JOBS_ENABLED=true`, `WORKFLOW_REPORT_JOBS_ENABLED=true`), weil alle beteiligten Dienste zur Vorlage gehören. Voraussetzungen:

- AiChat, AI Agent Functions, Docs, SDK Service, Notification, Object Storage und Project Service laufen.
- Der KI-Provider ist im Vault Service eingerichtet (Designer > Maintenance > Services).
- Der Identity Service (ab 3.0.9) erlaubt dem Workflow Service Delegations-Tokens für `vault`, `docs` und `object-storage`. Die eingebaute Voreinstellung tut das. Wer `SERVICE__DELEGATION__REQUESTERS` am `io-identity-service` selbst setzt, ersetzt die Voreinstellung und muss `workflow=vault,object-storage,docs` aufnehmen.

Steht ein Worker auf `false`, reihen sich die Aufträge ein und warten, bis er wieder eingeschaltet ist; es geht nichts verloren. Nach einer Änderung in `io3/.env`: `docker compose up -d io-workflow-service`.

Feinsteuerung: Beim `io-workflow-service` stehen die übrigen Stellschrauben auskommentiert mit ihren Standardwerten (`SERVICE__AIJOBS__MAXPARALLEL`, `…__INTERVALSECONDS`, `…__LEASESECONDS`, `…__RETENTIONDAYS` und dieselben für `SERVICE__REPORTJOBS__`). Fertige Aufträge werden nach 90 Tagen gelöscht.

Häufige Fehlercodes im Auftrag (`last_error`) oder im Regel-Audit:

| Code | Bedeutung |
|---|---|
| `AI_NO_ACTING_USER` | Kein Benutzer hat die Regel ausgelöst (Lauf des Dienstes, App-Token): die Aktion tut nichts, die Regel läuft weiter |
| `DELEGATION_REFUSED` | Der Identity Service stellt kein Delegations-Token aus: `SERVICE__DELEGATION__REQUESTERS` prüfen |
| `AI_ATTEMPTS_EXHAUSTED` | Der Auftrag kam trotz Wiederholungen immer wieder zurück und wurde aufgegeben |
| `AI_RESULT_DISCARDED` | Der Vorgang hat den Status verlassen, bevor die Antwort kam; das Ergebnis wurde verworfen |

## Update einer bestehenden Installation

1. In `io3/.env` die neuen Variablen aus `io3/.env.example` ergänzen: `WORKFLOW_ENCRYPTION_KEY`, `WORKFLOW_ENCRYPTION_KEY_ID=kek-1`, `TRANSCRIPTION_ENCRYPTION_KEY`, optional `TRANSCRIPTION_AUDIT_PSEUDONYM_KEY`, `WORKFLOW_AI_JOBS_ENABLED` und `WORKFLOW_REPORT_JOBS_ENABLED`. Die Schlüssel mit `openssl rand -base64 32` erzeugen und sicher ablegen.
2. Lief der AI Transcription Service schon mit einem eigenen Hauptschlüssel (`SERVICE__ENCRYPTION__MASTERKEYS__1` aus einer eigenen Override-Datei), genau diesen Wert als `TRANSCRIPTION_ENCRYPTION_KEY` eintragen.
3. Dienste aktualisieren: `docker compose pull && docker compose up -d` im Verzeichnis `io3`.
4. Prüfen: `docker compose logs io-workflow-service | grep -i "key ring"` zeigt „Encryption key ring: 1 key(s), active key kek-1“.

Wer die KI-Aufträge noch nicht nutzen will, setzt vor Schritt 3 `WORKFLOW_AI_JOBS_ENABLED=false`.
