# System auf HTTPS umstellen

Diese Anleitung beschreibt, wie du das System auf HTTPS umstellst und die notwendigen Zertifikate auf einem Linux-System erstellst und einrichtest.

## 1. Zertifikate für HTTPS erstellen

Du kannst mit OpenSSL ein selbstsigniertes Zertifikat erstellen. Führe die folgenden Schritte auf deinem Linux-Host aus:

```sh
mkdir -p certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/server.key \
  -out certs/server.crt \
  -subj "/CN=<dein-dns-name>"
```

- Ersetze `<dein-dns-name>` durch den DNS-Namen, unter dem dein System erreichbar ist (dieser muss mit der EXTERNALADDRESS in der `.env` Datei übereinstimmen).
- Die Dateien `server.crt` und `server.key` werden im Ordner `certs` abgelegt. Das ist zwingend erforderlich.

## 2. Zertifikat als vertrauenswürdig einrichten (Linux)

Damit das Zertifikat auf dem Host-System als vertrauenswürdig gilt, führe folgende Schritte aus (Beispiel für Ubuntu/Debian):

1. Kopiere das Zertifikat in den Ordner für vertrauenswürdige Zertifikate:
   ```sh
   sudo cp certs/server.crt /usr/local/share/ca-certificates/server.crt
   ```
2. Aktualisiere die Zertifikatsdatenbank:
   ```sh
   sudo update-ca-certificates
   ```

> [!IMPORTANT]
> Nach Änderungen an Zertifikaten oder der Zertifikatsdatenbank solltest du betroffene Dienste oder das System neu starten.

## 3. .env Datei anpassen

Öffne die `.env` Datei und stelle folgende Werte ein:

```properties
INSTANCE_HTTP_TYPE=https
INSTANCE_WS_TYPE=wss
```

- Stelle sicher, dass die Variable `EXTERNALADDRESS` exakt dem DNS-Namen entspricht, der im Zertifikat verwendet wurde.

## 4. Hinweise zu DNS und EXTERNALADDRESS

- Das SSL-Zertifikat ist nur gültig, wenn der aufgerufene DNS-Name mit dem Wert in `EXTERNALADDRESS` und dem im Zertifikat (`CN`) übereinstimmt.
- Bei Abweichungen kommt es zu Zertifikatswarnungen oder Verbindungsproblemen.

## 5. Umgebung neu starten

Starte die Umgebung neu, damit die Änderungen wirksam werden:

```sh
docker compose down
docker compose up -d
```

---

Weitere Hinweise findest du in der Administratoren-Dokumentation und in den Guidelines.
