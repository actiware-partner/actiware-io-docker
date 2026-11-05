---
title: Skill Runner einschalten
---

# Skill Runner einschalten

Der Skill Runner ist der Ausführungs-Container für Agent-Skills. Darin laufen die Skripte, die ein Skill mitbringt (zum Beispiel die Skills für Word, Excel, PowerPoint und PDF), und der Code, den ein Agent selbst schreibt. Jedes Gespräch bekommt einen eigenen Arbeitsbereich und einen eigenen Linux-Benutzer. Die Läufe haben keinen Netzzugang.

Der Runner ist **optional**. Ohne ihn funktionieren Skills weiter, nur ihre Skripte werden nicht ausgeführt, und der Designer zeigt am Agenten den Hinweis „Skripte dieses Skills werden nicht ausgeführt“.

In der Vorlage steht der Runner vollständig, aber auskommentiert in `io3/services.docker-compose.yml`. Diese Seite beschreibt, wie Sie ihn einschalten.

> [!NOTE]
> Die Images `actiwareio/io3-skill-runner` und `actiwareio/io3-skill-runner-office` stehen auf Docker Hub ab dem ersten Release des Skill Runners bereit.

## Voraussetzungen

- Linux-Host mit Docker Engine und Compose v2 (wie für die übrige Umgebung).
- Ein Docker-Volume mit Unix-Rechten für `/workspaces`. Das lokale Volume der Vorlage passt. NFS mit `root_squash` ist ungeeignet, weil der Runner jedem Arbeitsbereich eine eigene Benutzer-ID gibt.
- Genug Arbeitsspeicher: Standard ist ein Limit von 4 GB und 2 CPUs für alle Läufe zusammen.

## Welches Image?

| Image | Wofür |
| --- | --- |
| `actiwareio/io3-skill-runner` | Python 3.12, Node 22, Bibliotheken für Word, Excel, PowerPoint und PDF, pandoc, Poppler, qpdf. Reicht für die meisten Skills. |
| `actiwareio/io3-skill-runner-office` | Wie oben, zusätzlich LibreOffice. Nötig, wenn Skills Dokumente umwandeln, Formeln neu berechnen oder PDFs aus Office-Dateien erzeugen. Deutlich größer. |

Das Image legen Sie über `VERSION_IO_SKILL_RUNNER` in `io3/.env` fest. Der Sidecar für die Netzsperre nutzt dasselbe Image.

## Einschalten

1. **Geheimnis erzeugen** und in `io3/.env` eintragen. Die Zeile steht auskommentiert im Abschnitt `SKILL RUNNER` der `.env.example`:

   ```bash
   openssl rand -hex 32
   ```

   ```text
   SKILL_RUNNER_SHARED_SECRET=<erzeugter Wert>
   ```

   Optional im selben Abschnitt: `SKILL_RUNNER_MEM_LIMIT`, `SKILL_RUNNER_CPUS` und `VERSION_IO_SKILL_RUNNER` für die Office-Variante.

2. **Runner einkommentieren** in `io3/services.docker-compose.yml`, ganz am Ende der Datei:
   - die beiden Dienste `io-skill-runner` und `io-skill-runner-netguard`,
   - den Abschnitt `networks:` mit `skill_runner_net` und den Abschnitt `volumes:` mit `skill-runner-workspaces`.

3. **AiChat anbinden** in derselben Datei beim Dienst `io-ai-chat-service`. Einkommentieren:
   - unter `environment:` die beiden Zeilen `SKILLRUNNER__ENDPOINTS__0` und `SKILLRUNNER__SHAREDSECRET`,
   - den Abschnitt `networks:` mit `default` und `skill_runner_net`,
   - unter `depends_on:` den Eintrag `io-skill-runner`.

   Danach sieht der Dienst so aus (gekürzt):

   ```yaml
   io-ai-chat-service:
     environment:
       SKILLRUNNER__ENDPOINTS__0: "http://io-skill-runner:30024"
       SKILLRUNNER__SHAREDSECRET: "${SKILL_RUNNER_SHARED_SECRET}"
     networks:
       - default
       - skill_runner_net
     depends_on:
       io-identity-service:
         condition: service_started
       io-skill-runner:
         condition: service_healthy
   ```

   > [!IMPORTANT]
   > `default` muss in der Liste bleiben. Sobald ein Dienst `networks:` nennt, hängt er nur noch an den genannten Netzen; ohne `default` erreicht der AiChat die übrigen Dienste nicht mehr.

4. **Prüfen und starten:**

   ```bash
   cd io3
   docker compose config -q
   docker compose up -d io-skill-runner io-skill-runner-netguard io-ai-chat-service
   ```

## Prüfen

1. Der Runner ist gesund:

   ```bash
   docker compose ps io-skill-runner
   docker compose logs io-skill-runner | grep -E "Isolation ON|Egress guard"
   ```

   Erwartet: Status `healthy`, im Log `Isolation ON` und `Egress guard is in place`.

2. Im Designer: Bei einem Agenten mit einem Skill, der Skripte enthält, verschwindet am Reiter „Skills“ der Hinweis „Skripte dieses Skills werden nicht ausgeführt“. Der Status wird bis zu 30 Sekunden zwischengespeichert. Der Schalter „Skripte ausführen“ am Agenten muss an sein (Standard), danach das Projekt publizieren.

3. Im Client: In einem Gespräch mit diesem Agenten zum Beispiel schreiben „Erzeuge mit Python die Datei outputs/test.txt mit dem Text Hallo“. Die Antwort enthält die Datei als Anhang.

## Gut zu wissen

- **Keine Ports am Host.** Der Runner hat in der Vorlage bewusst kein `ports:`. Nur der AiChat erreicht ihn über das interne Netz (gRPC `30024`, Health `30025`).
- **Netzsperre.** Der Sidecar `io-skill-runner-netguard` sperrt allen Läufen den Netzzugang. Fehlt die Sperre, nimmt der Runner keine Läufe an. Nach einem Neustart des Runners den Sidecar neu erzeugen: `docker compose up -d io-skill-runner-netguard`.
- **Mehr Durchsatz.** Weitere Runner als eigene Dienste anlegen (zum Beispiel `io-skill-runner-2` mit eigenem Volume und eigenem Sidecar) und beim AiChat `SKILLRUNNER__ENDPOINTS__1` ergänzen. Der AiChat verteilt neue Gespräche auf den Runner mit den wenigsten Arbeitsbereichen.
- **Plattenplatz.** Der Runner prüft die Quota je Arbeitsbereich (Standard 500 MB) nach jedem Lauf. Für Installationen mit vielen Anwendern ein eigenes Dateisystem für das Volume mit Größengrenze vorsehen.
- **Aufräumen.** Arbeitsbereiche ohne Lauf seit 24 Stunden löscht der Runner selbst, beim Löschen eines Gesprächs löscht der AiChat den Arbeitsbereich mit.
- **Abschalten.** Die Zeilen wieder auskommentieren oder nur `SKILLRUNNER__ENDPOINTS__0` beim AiChat entfernen. Ohne Adresse bieten Agenten keine Skriptläufe mehr an.

## Weiterführend

- [Skill Runner Service: Installation, Konfiguration, Abschottung und Restrisiko](/handbuch/admin-guides/services/skill-runner-service/)
- [AI Chat Service: Konfiguration](/handbuch/admin-guides/services/ai-chat-service/configuration)
