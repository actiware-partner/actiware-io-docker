# Verwaltung von Passwörtern und sicherheitsrelevanten Einstellungen

Diese Anleitung beschreibt, welche Passwörter und sicherheitsrelevanten Einstellungen du vor dem ersten Start des Systems in der `.env` Datei anpassen musst.

## 1. Übersicht der sicherheitsrelevanten Variablen

Vor dem ersten Start musst du folgende Werte in der `.env` Datei prüfen und anpassen:

### Externe Adresse

- **EXTERNALADDRESS**: Trage hier den DNS-Namen oder die IP-Adresse ein, unter der das System von außen erreichbar ist.

### Interne Service-Sicherheit

- **CLIENT_ID**: Lege die Client-ID für die OAuth2 Authentifizierung fest.
- **CLIENT_SECRET**: Erstelle ein sicheres Passwort für die OAuth2 Authentifizierung der Clients und Services.
- **SHARED_SECRET**: Erstelle ein sicheres, 32-stelliges Token im HEX-Format für die interne Kommunikation zwischen den Services. Du kannst z.B. https://www.browserling.com/tools/random-hex nutzen.
- **ENCRYPTION_KEY**: Erstelle einen sicheren Schlüssel für die Verschlüsselung gespeicherter Daten.

### Datenbank-Zugangsdaten

- **DATABASE_USER**: Lege einen Benutzernamen für die Datenbank fest.
- **DATABASE_PASS**: Setze ein sicheres Passwort für die Datenbank. Ändere unbedingt den Standardwert!

### S3 Zugangsdaten

- **S3_ACCESS_KEY**: Erstelle eine GUID als Benutzernamen (z.B. https://www.guidgenerator.com/online-guid-generator.aspx). Alternativ einen sprechenden Benutzernamen wie admin o.ä.
- **S3_SECRET_KEY**: Erstelle eine GUID als Passwort oder erstelle ein sicheres, 32-stelliges Token im HEX-Format. Du kannst z.B. https://www.browserling.com/tools/random-hex nutzen.

### Standard-Admin-Zugang

- **DEFAULT_USER**: Lege den Benutzernamen für den Standard-Admin fest.
- **DEFAULT_PASS**: Setze hier unbedingt ein sicheres Passwort!
- **DEFAULT_VALIDITY_PERIOD**: Lege die Gültigkeitsdauer der Anmeldung in Sekunden fest. Standardmäßig sind 86400 Sekunden eingestellt.

### Solr Zugangsdaten

- **SOLR_TOKEN**: Erstelle ein sicheres Token für den Zugriff der Services auf Solr.
- **SOLR_USER**: Lege einen Benutzernamen für Solr fest.
- **SOLR_PASS**: Setze ein sicheres Passwort für Solr.

### Vektorspeicher Zugangsdaten

- **QDRANT_API_KEY**: Erstelle einen sicheren API-Schlüssel für Qdrant.
- **WEAVIATE_API_KEY**: Erstelle einen sicheren API-Schlüssel für Weaviate.

### SMTP Einstellungen

- **SMTP_PROFILE_FROM_ADDRESS**: Trage die E-Mail-Adresse ein, die als Absender verwendet wird.
- **SMTP_PROFILE_FROM_NAME**: Lege den Namen des Absenderprofils fest. Standardmäßig ist "service-default" eingestellt.
- **SMTP_PROFILE_FROM_DISPLAYNAME**: Trage den Anzeigenamen des Absenders ein. Standardmäßig ist "ACTIWARE.IO" eingestellt.
- **SMTP_PROFILE_FROM_TRANSPORT**: Lege die Versandart fest. Für den Versand über Microsoft Graph trägst du "MicrosoftGraph" ein.
- **SMTP_GRAPH_TENANT_ID**: Trage die Tenant-ID deiner Microsoft Entra ID Anwendung ein.
- **SMTP_GRAPH_CLIENT_ID**: Trage die Client-ID deiner Microsoft Entra ID Anwendung ein.
- **SMTP_GRAPH_CLIENT_SECRET**: Trage den geheimen Clientschlüssel deiner Microsoft Entra ID Anwendung ein.
- **SMTP_BLOCKED_REPORT_RECIPIENTS**: Trage die E-Mail-Adresse ein, an die Berichte über blockierte Nachrichten gesendet werden.

### Optionale API-Schlüssel

- **AI_API_KEY**: Trage den API-Schlüssel für den eingestellten AI Provider ein, wenn du den AI Assistant verwendest.
- **MISTRAL_API_KEY**: Trage den API-Schlüssel für Mistral ein, wenn du Mistral OCR verwendest.

> [!IMPORTANT]
> Ersetze alle Platzhalter wie "<PASSWORD>", "<KEY>" oder "<CLIENT_SECRET>" vor dem ersten Start. Verwende sichere, zufällige Werte.

## 2. Vorgehen vor dem ersten Start

1. Öffne die `.env` Datei im Editor.
2. Gehe alle oben genannten Variablen durch und passe sie an.
3. Speichere die Datei.
4. Starte das System wie in der Administratoren-Dokumentation beschrieben.

## 3. Hinweise zur Passwortsicherheit

- Verwende für alle Passwörter und Tokens mindestens 12 Zeichen, besser mehr.
- Nutze Groß- und Kleinbuchstaben, Zahlen und Sonderzeichen.
- Speichere Passwörter und Tokens sicher, z.B. in einem Passwortmanager.
- Teile Passwörter und Tokens niemals unverschlüsselt oder per E-Mail.

---

Weitere Hinweise zur Konfiguration findest du in der Administratoren-Dokumentation und in den Guidelines.
