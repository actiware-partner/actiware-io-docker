---
title: Große Dateien und Upload-Grenzen
---

# Große Dateien und Upload-Grenzen

Wie groß eine Datei sein darf, die Anwender in einen Inbox-Kanal oder als Anhang an ein Objekt hochladen, legen zwei
Stufen fest: die Einstellung im Designer und die technische Obergrenze der Installation. Diese Seite beschreibt beides,
was die Docker-Vorlage dafür vorsieht und was Sie einstellen müssen, wenn Sie einen eigenen Reverse Proxy vor die
Plattform setzen.

## Wer die Grenze prüft

- **Inbox Service und Object Storage Service** zählen die Bytes, die tatsächlich ankommen. Beim ersten Byte über der
  Grenze brechen sie ab und entfernen, was schon im S3-Speicher liegt. Diese Prüfung ist maßgeblich.
- **BFF Client Service** fragt die Grenze beim jeweiligen Dienst ab und reicht die Datei ohne Zwischenspeicher durch. Er
  hat dafür keine eigene Einstellung. Eine zu große Datei beantwortet er mit HTTP 413 und dem Code
  `UPLOAD_SIZE_LIMIT_EXCEEDED`, statt die Verbindung abzubrechen.
- **Clients** prüfen die Größe schon vor dem Hochladen und zeigen eine verständliche Meldung. Das ist nur Komfort, die
  Dienste prüfen trotzdem.

Ohne Berechtigung schreibt der Object Storage Service kein einziges Byte in den S3-Speicher. Er prüft Recht und
Transaktion, bevor er die Datei annimmt.

## Die Einstellung im Designer

| Bereich        | Ort im Designer                                                        | Feld                                | Standard |
| -------------- | ---------------------------------------------------------------------- | ----------------------------------- | -------- |
| Inbox          | _Maintenance_ → _Services_ → _Inbox Service_, Reiter _Content & upload_ | `content.max_file_size_megabytes`     | 100 MB   |
| Objekt-Anhänge | _Maintenance_ → _Services_ → _Object Storage Service_, Reiter _Attachments_ | `attachments.max_file_size_megabytes` | 100 MB   |

- Erlaubt sind Werte von **0 bis 2048 MB**. 1 MB sind hier 1 MiB (1.048.576 Bytes).
- **0 heißt unbegrenzt.** Dann gilt die technische Obergrenze aus dem nächsten Abschnitt, ohne eigene Angabe 50 GiB je
  Datei.
- Die Inbox-Grenze gilt für jeden Weg in die Inbox: Upload, Quelle, Verschieben und Kopieren, Ergebnisse der
  Vorverarbeitung. Die Anhang-Grenze gilt nur für Uploads über den Client: für Anhänge und für Dateien, die beim Anlegen eines
  Objekts mitkommen. Legen Dienste selbst Dokumente in einem Objekt ab (Inbox, Integration Flows, Worker Queues), prüft
  sie diese Grenze nicht. Dort gelten die Grenzen der jeweiligen Dienste, bei der Inbox die Inbox-Grenze. Es muss deshalb
  keine der beiden Grenzen höher stehen als die andere.
- Sollen Dateien über 2048 MB erlaubt sein, aber nicht bis 50 GiB, stellen Sie im Designer 0 ein und senken die
  technische Obergrenze auf den gewünschten Wert.

Die Bedienung beschreibt das Designer-Handbuch unter
[Die größte erlaubte Datei festlegen](/handbuch/user-guides/apps/app-designer/inbox/kanaele/uebersicht#die-größte-erlaubte-datei-festlegen)
(Inbox) und
[Die größte erlaubte Datei eines Anhangs festlegen](/handbuch/user-guides/apps/app-designer/storage/dokumenttypen#die-größte-erlaubte-datei-eines-anhangs-festlegen)
(Objekt-Anhänge).

Die Umgebungsvariablen `SERVICE__CONTENT__MAXFILESIZEMEGABYTES` (Inbox) und `SERVICE__ATTACHMENTS__MAXFILESIZEMEGABYTES`
(Object Storage) liefern nur den Ausgangswert. Ein im Designer gespeicherter Wert ersetzt sie. Die Vorlage setzt keine
der beiden.

## Die technische Obergrenze

„Unbegrenzt“ ist aus Sicherheitsgründen nie wirklich offen: Jeder Benutzer mit Upload-Recht könnte sonst beliebig viel
S3-Speicher belegen. Die Obergrenze kommt nur aus der Umgebung des Containers, im Designer lässt sie sich nicht ändern.
Inbox Service und Object Storage Service verwenden dieselben Namen:

| Variable                             | Bedeutung                                                                                                                                    | Standard                    |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- |
| `SERVICE__UPLOAD__MAXFILESIZEBYTES`  | Größte Datei in Bytes. Gilt bei der Einstellung 0 und begrenzt jeden höheren Wert aus dem Designer.                                            | `53687091200` (50 GiB)      |
| `SERVICE__UPLOAD__PARTSIZEMEGABYTES` | Größe eines Teils beim Schreiben in den S3-Speicher, in MiB, mindestens 5. Wird automatisch so angehoben, dass die Obergrenze in 10.000 Teile passt. | `16`                        |
| `SERVICE__UPLOAD__MAXCONCURRENCY`    | Teile, die ein Upload gleichzeitig schreibt.                                                                                                  | `4`                         |

Die Vorlage setzt keine dieser Variablen, es gelten die Standardwerte. Ändern Sie sie, ohne
`io3/services.docker-compose.yml` anzufassen, mit einer eigenen Datei `io3/docker-compose.override.yml`. Docker Compose
liest sie im Verzeichnis `io3` automatisch mit:

```yaml
# io3/docker-compose.override.yml: Obergrenze 100 GiB je Datei
services:
  io-inbox-service:
    environment:
      SERVICE__UPLOAD__MAXFILESIZEBYTES: "107374182400"
  io-object-storage-service:
    environment:
      SERVICE__UPLOAD__MAXFILESIZEBYTES: "107374182400"
```

Prüfen und übernehmen:

```bash
cd io3
docker compose config | grep SERVICE__UPLOAD__
docker compose up -d io-inbox-service io-object-storage-service
```

Setzen Sie den Wert in beiden Diensten gleich, sonst gelten für Inbox und Anhänge unterschiedliche Obergrenzen. Wählen
Sie die Obergrenze so niedrig, wie es Ihre Anwender erlauben.

## Arbeitsspeicher und Plattenplatz

- **Arbeitsspeicher:** Ein laufender Upload braucht im Inbox Service bzw. Object Storage Service etwa
  `MAXCONCURRENCY × PARTSIZEMEGABYTES`, mit den Standardwerten 64 MiB, unabhängig von der Dateigröße. Planen Sie den
  Speicher der Container für die Zahl gleichzeitiger Uploads. Wer die Obergrenze anhebt, bekommt größere Teile: Bei
  500 GiB sind es 52 MiB je Teil. Der BFF Client Service reicht die Datei in kleinen Stücken durch und braucht dafür
  keinen nennenswerten Speicher.
- **Plattenplatz im Inbox Service:** Dateien, die ein externes Modul liefert (Quelle, Ergebnis der Vorverarbeitung),
  legt der Inbox Service in einer temporären Datei im Container ab und löscht sie danach wieder. Diese Dateien liegen im
  Speicherbereich von Docker auf dem Host. Planen Sie dort Platz für das größte Modulergebnis mal die Zahl paralleler
  Läufe. Normale Uploads gehen direkt in den S3-Speicher und brauchen keine Platte.
- **S3-Speicher:** Das Volume `s3-data` des `io-backend` muss die Dateien aufnehmen können. Der S3-Dienst der Vorlage
  braucht keine eigene Einstellung.

## Reverse Proxy

Die Vorlage hat keinen Reverse Proxy. Browser und Clients laden Dateien direkt beim BFF Client Service hoch, Port
`…012` (bei `INSTANCE_PORT_PREFIX=30` also `30012`). Für eine Standardinstallation müssen Sie nichts tun.

Setzen Sie einen eigenen Reverse Proxy oder Load Balancer davor, muss er drei Dinge zulassen. Sonst bricht er große
Uploads ab, bevor die Dienste sie sehen, und Anwender erhalten nur „Network Error“:

1. **Größe:** Der Proxy muss Anfragen annehmen, die mindestens so groß sind wie die größte Grenze, plus etwas Reserve
   für den Rahmen der Anfrage. Die Dienste prüfen ohnehin selbst, darum dürfen Sie die Prüfung im Proxy auch abschalten.
2. **Kein Zwischenspeichern:** Der Proxy soll die Datei sofort weiterreichen. Speichert er sie erst komplett auf seiner
   Platte, braucht er dort Platz für jeden laufenden Upload, und die Zeit verdoppelt sich.
3. **Zeit:** Die Zeitgrenzen müssen die Dauer eines Uploads abdecken. 2 GB brauchen bei 50 Mbit/s gut 5 Minuten,
   50 GiB bei 100 Mbit/s rund 72 Minuten.

Öffnen Anwender die Programme über den Proxy unter einem anderen Namen, tragen Sie die Adressen außerdem für die
Anmeldung ein, siehe [Anmelde-Adressen](./anmelde-adressen.md).

### nginx

```nginx
location / {
    proxy_pass https://<EXTERNALADDRESS>:30012;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    client_max_body_size 51g;     # mindestens die größte Grenze; 0 schaltet die Prüfung im Proxy ab
    proxy_request_buffering off;  # Datei nicht im Proxy zwischenspeichern
    proxy_send_timeout 3600s;     # Upload an den BFF
    proxy_read_timeout 3600s;     # Warten auf die Antwort des BFF
}
```

Ohne `client_max_body_size` gilt bei nginx 1 MB. Eine abgelehnte Anfrage steht im Fehlerprotokoll von nginx als
`client intended to send too large body`.

### Kubernetes mit ingress-nginx

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "51g"
    nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
```

Siehe auch [Betrieb in Kubernetes](/handbuch/admin-guides/kubernetes).

### Traefik

Traefik reicht Anfragen ohne Zwischenspeicher durch und begrenzt die Größe nicht. Ab Traefik v3 bricht der Einstiegspunkt
Anfragen aber standardmäßig nach 60 Sekunden ab:

```yaml
entryPoints:
  websecure:
    address: ":443"
    transport:
      respondingTimeouts:
        readTimeout: 0  # oder eine Dauer, die den längsten Upload abdeckt, zum Beispiel 2h
```

Verwenden Sie die Middleware `buffering` nicht für den BFF, oder setzen Sie dort `maxRequestBodyBytes` passend.

### Caddy

`reverse_proxy` reicht Anfragen ohne Zwischenspeicher durch und hat keine Größengrenze. Setzen Sie `request_body` mit
`max_size` nur, wenn der Wert mindestens die größte Grenze erreicht.

### IIS mit Application Request Routing (ARR)

- `requestFiltering` → `requestLimits` → `maxAllowedContentLength` liegt standardmäßig bei 30.000.000 Bytes (rund
  28,6 MiB). Der größte mögliche Wert ist 4.294.967.295 Bytes. Über IIS sind deshalb keine Dateien über 4 GiB möglich.
- Die Zeitgrenze des Proxys (Serverfarm → _Proxy_ → _Time-out_, Standard 120 Sekunden) auf die Dauer des längsten
  Uploads anheben.

### Andere Load Balancer

Load Balancer in der Cloud haben oft eine Leerlauf- oder Anfrage-Zeitgrenze und teils eine eigene Größengrenze. Stellen
Sie beide nach denselben drei Regeln ein.

## Wenn etwas nicht funktioniert

| Was Anwender sehen                                                    | Ursache                                                                                              | Was Sie tun können                                                                                  |
| --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Meldung, dass die Datei zu groß ist                                   | Die Datei liegt über der Grenze aus dem Designer.                                                    | Grenze im Designer anheben oder 0 einstellen.                                                        |
| Bei „unbegrenzt“ trotzdem Ablehnung                                   | Die Datei liegt über der technischen Obergrenze.                                                     | `SERVICE__UPLOAD__MAXFILESIZEBYTES` anheben, siehe oben.                                            |
| „Network Error“ oder Abbruch, im Protokoll des BFF steht nichts       | Ein Reverse Proxy lehnt die Anfrage ab oder bricht nach seiner Zeitgrenze ab.                        | Größe, Zwischenspeichern und Zeitgrenzen im Proxy einstellen, siehe [Reverse Proxy](#reverse-proxy). |
| Anhänge brechen ab rund 28 MB ab, Inbox-Uploads ab 100 MB             | Der BFF Client Service läuft noch in einer Version ohne durchgereichten Upload.                     | BFF Client Service aktualisieren, siehe nächster Abschnitt.                                          |

## Beim Update

Die Upload-Grenzen brauchen neue Versionen mehrerer Dienste. Aktualisieren Sie in dieser Reihenfolge:

1. **Project Service** (kennt die Einstellung 0 und den Reiter _Attachments_), danach den **Designer**.
2. **Inbox Service** und **Object Storage Service** (setzen die Grenze durch und melden sie).
3. **BFF Client Service** (reicht die Datei durch und übernimmt die Grenze der Dienste).
4. **Clients** (Prüfung vor dem Hochladen, verständliche Meldung).

Solange der BFF Client Service noch die alte Version hat, bleiben seine festen Grenzen bestehen: rund 28,6 MiB für
Anhänge und 100 MiB für die Inbox, auch wenn im Designer mehr eingestellt ist.

Zwischen Schritt 1 und 2 gilt: Speichern Sie im Designer noch **nicht** den Wert 0 für die Inbox und noch keine
Einstellungen im Reiter _Attachments_. Der Project Service nimmt sie schon an, die alte Version des Inbox Service
lehnt den Wert 0 (erlaubt waren 1 bis 2048) beziehungsweise den neuen Abschnitt noch ab. Warten Sie mit diesen
Einstellungen, bis Inbox und Object Storage aktualisiert sind.

**Vor dem Update prüfen:** Die Anhang-Grenze gilt nur für Uploads über den Client (Anhänge, Dateien beim Anlegen eines
Objekts). Die Ablage durch Dienste, etwa aus der Inbox, aus Integration Flows oder der Worker Queue, ist davon nicht
betroffen. Brauchen Ihre Anwender größere Objektanhänge, als der Standard von 100 MB erlaubt, setzen Sie vor dem Update
des Object Storage Service die Umgebungsvariable `SERVICE__ATTACHMENTS__MAXFILESIZEMEGABYTES` (zum Beispiel
`"2048"`, oder `"0"` für unbegrenzt) als Ausgangswert, am besten in `io3/docker-compose.override.yml`. Ein im Designer
gespeicherter Wert ersetzt sie später. So gilt gleich nach dem Update die gewünschte Grenze und nicht kurz der Standard.

```yaml
# io3/docker-compose.override.yml
services:
  io-object-storage-service:
    environment:
      SERVICE__ATTACHMENTS__MAXFILESIZEMEGABYTES: "2048"
```

Weitere Einstellungen der beiden Dienste beschreiben
[Inbox Service: Umgebungsvariablen](/handbuch/platform-services/inbox-service/env/docker) und
[Object Storage Service: Umgebungsvariablen](/handbuch/platform-services/object-storage-service/env/docker).
