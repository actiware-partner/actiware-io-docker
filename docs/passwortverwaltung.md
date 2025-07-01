# Verwaltung von Passwörtern und sicherheitsrelevanten Einstellungen

Diese Anleitung beschreibt, welche Passwörter und sicherheitsrelevanten Einstellungen du vor dem ersten Start des Systems in der `.env` Datei anpassen musst.

## 1. Übersicht der sicherheitsrelevanten Variablen

Vor dem ersten Start musst du folgende Werte in der `.env` Datei prüfen und anpassen:

### Externe Adresse
- **EXTERNALADDRESS**: Trage hier den DNS-Namen oder die IP-Adresse ein, unter der das System von außen erreichbar ist.

### Master Token
- **TOKEN_MASTER**: Erstelle ein sicheres, 32-stelliges Token im HEX-Format. Du kannst z.B. https://www.browserling.com/tools/random-hex nutzen.

### Datenbank-Zugangsdaten
- **DATABASE_USER**: Lege einen Benutzernamen für die Datenbank fest (optional, aber empfohlen).
- **DATABASE_PASS**: Setze ein sicheres Passwort für die Datenbank. Ändere unbedingt den Standardwert!

### MinIO Zugangsdaten
- **MINIO_ACCESS_KEY**: Erstelle eine GUID als Benutzernamen (z.B. https://www.guidgenerator.com/online-guid-generator.aspx). Alternativ einen sprechenden Benutzernamen wie admin o.ä.
- **MINIO_SECRET_KEY**: Erstelle eine GUID als Passwort oder erstelle ein sicheres, 32-stelliges Token im HEX-Format. Du kannst z.B. https://www.browserling.com/tools/random-hex nutzen.

### Standard-Admin-Zugang
- **AUTH_DEFAULT_USER**: Standardmäßig "admin". Passe den Benutzernamen nach Bedarf an.
- **AUTH_DEFAULT_PASS**: Standardmäßig "admin". Setze hier unbedingt ein sicheres Passwort!
- **AUTH_DEFAULT_WEB_CLIENT_SECRET**: Passe diese Werte nach Bedarf an. Dieser wird für die OAuth2 Authentifizierung des Clients benötigt an dem ACTIWARE.IO System.

### Weitere sicherheitsrelevante Einstellungen
- **PROCESS_TRIGGER_TOKEN**: Setze ein sicheres Token für Trigger-Prozesse.
- **RABBITMQ_DEFAULT_USER**: Standardmäßig "rabbit". Passe den Benutzernamen nach Bedarf an.
- **RABBITMQ_DEFAULT_PASS**: Standardmäßig "carrot". Setze hier unbedingt ein sicheres Passwort!

> [!IMPORTANT]
> Ändere alle Passwörter und Tokens, die mit "admin", "default", "carrot" oder ähnlichen Standardwerten vorbelegt sind, vor dem ersten Start. Verwende sichere, zufällige Werte.

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
