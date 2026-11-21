---
title: Herkünfte der Clients (CORS)
---

# Herkünfte der Clients (CORS)

Drei Dienste werden direkt aus dem Browser aufgerufen: der **BFF Client** (Web-Client, Integration-Client,
Desktop-Anwendung), der **Project Service** (Designer) und der **Identity Service** (Anmeldung). Sie beantworten
Anfragen aus dem Browser nur noch, wenn die Seite unter einer bekannten Adresse läuft, der sogenannten Herkunft
(englisch *Origin*: Schema, Name und Port, etwa `https://io3.example.com:30202`). Alle übrigen Dienste ruft kein Browser
direkt auf, sie haben gar keine Browser-Freigabe mehr (IO3-4004).

Läuft eine Seite unter einer Herkunft, die nicht in der Liste steht, blockiert der Browser die Antworten. Die Anmeldung
oder das Laden bleibt dann hängen, in den Entwicklerwerkzeugen des Browsers (F12, Reiter *Konsole*) steht eine Meldung
wie `has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present`.

> ⚠️ **Wichtig beim Update:** Ab dieser Version müssen die Herkünfte aller Programme bekannt sein, sonst kann sich
> niemand mehr anmelden, weder im Web-Client noch im Designer noch im Integration-Client. Die Docker-Vorlage trägt die
> Adressen unter `EXTERNALADDRESS` selbst ein. **Nicht von selbst** erfasst werden:
>
> - Installationen mit eigener Domain, eigenem Reverse Proxy, IP-Adresse oder Kurznamen,
> - Installationen ohne diese Vorlage, etwa eigene Compose-Dateien, ältere awrun-Umgebungen oder Kubernetes,
> - die Edge-Sidebar und lokale Entwicklungs-Server.
>
> Gehen Sie vor dem Update die [Checkliste](#vor-dem-update-checkliste) durch und tragen Sie fehlende Herkünfte ein.
> Alle drei Dienste lesen `SERVICE__CORS__ALLOWEDORIGINS` nur beim Start, eine Änderung wirkt erst nach einem Neustart.
> Sofort wirken nur die im Designer gespeicherten SSO-Herkünfte des Identity Service.

## Vor dem Update: Checkliste

1. **Wie öffnen die Benutzer die Programme?** Notieren Sie für Designer, Web-Client und Integration-Client die Adresse
   aus der Adresszeile des Browsers, also Schema, Name und Port, ohne Pfad: `https://awrun.dt.local:30202`, nicht
   `https://awrun.dt.local:30202/#/inbox`. Jede abweichende Schreibweise ist eine eigene Herkunft: Name und IP-Adresse,
   Kurzname und vollständiger Name, `http` und `https`, mit und ohne Port.
2. **Vergleichen Sie mit der abgeleiteten Liste** aus `INSTANCE_HTTP_TYPE`, `EXTERNALADDRESS` und `INSTANCE_PORT_PREFIX`
   (Tabelle im nächsten Abschnitt). Alles, was dort nicht steht, gehört in `ADDITIONAL_CLIENT_ORIGINS`.
3. **Nutzen Sie die Vorlage nicht oder nur teilweise**, setzen Sie die Variablen selbst an allen drei Diensten, siehe
   [Ohne diese Vorlage](#ohne-diese-vorlage-eigene-compose-dateien-kubernetes).
4. **Edge-Sidebar im Einsatz?** Dann ihre Erweiterungs-Id eintragen, siehe [Edge-Sidebar](#edge-sidebar).
5. **Erst die Vorlage, dann die Dienste:** `.env` anpassen, Vorlage aktualisieren, danach Identity Service, Project
   Service und BFF Client neu erstellen.
6. **Nach dem Update prüfen:** einmal im Designer und im Web-Client anmelden und die Herkünfte mit einer Vorab-Anfrage
   prüfen, siehe [Prüfen](#prüfen).

## Was die Vorlage einträgt

`io3/services.docker-compose.yml` setzt die Liste aus `INSTANCE_HTTP_TYPE`, `EXTERNALADDRESS`, `INSTANCE_PORT_PREFIX`
und den Ports der Clients zusammen:

| Programm           | Herkunft (bei `INSTANCE_PORT_PREFIX=30`) |
| ------------------ | ---------------------------------------- |
| Designer           | `https://<EXTERNALADDRESS>:30201`         |
| Web-Client         | `https://<EXTERNALADDRESS>:30202`         |
| Integration-Client | `https://<EXTERNALADDRESS>:30203`         |

Dieselbe Liste geht an zwei Stellen:

| Variable im Container | Dienste | Wofür |
| --- | --- | --- |
| `SERVICE__CORS__ALLOWEDORIGINS` | BFF Client, Project Service, Identity Service | Browser-Freigabe (CORS) aller Routen |
| `SERVICE__ENDPOINTS__IDENTITYSERVICE__SSOALLOWEDORIGINS`, `SERVICE__SSO_ALLOWED_ORIGINS` | BFF Client, Project Service bzw. Identity Service | Anmeldung (Single Sign-on) |

Die Desktop-Anwendung läuft unter der festen Herkunft `app://bundle`. Die Dienste lassen sie immer zu, ebenso
`clientapp.actiware` und `clientapp.elo` der eingebetteten Clients früherer Versionen. Dafür ist nichts einzutragen.

Den Token-Abruf nach der Anmeldung schicken die Programme an BFF Client bzw. Project Service, die ihn an den Identity
Service weiterleiten. Nach dieser Weiterleitung meldet der Browser keine Herkunft mehr (`null`); der Identity Service
lässt das für den Token-Abruf zu.

Für eine Standardinstallation müssen Sie also nichts tun.

## Eigene Kunden-Domain eintragen

Öffnen Benutzer die Programme unter einem anderen Namen als `EXTERNALADDRESS`, etwa über einen Reverse Proxy, eine
zweite Domain, die IP-Adresse oder auf anderen Ports, tragen Sie diese Herkünfte in `io3/.env` ein. Mehrere Herkünfte
trennen Sie durch `;`. Eine Herkunft hat **keinen Pfad und keinen Schrägstrich am Ende**:

```shell
ADDITIONAL_CLIENT_ORIGINS=https://io3.ihre-firma.de;https://designer.ihre-firma.de
```

Die Vorlage hängt sie an die abgeleitete Liste an, die Adressen unter `EXTERNALADDRESS` bleiben erlaubt.

Zu einer eigenen Domain gehören meist noch diese Schritte:

1. **Anmelde-Rücksprungadressen** der Programme unter der neuen Domain in `ADDITIONAL_REDIRECT_URIS` eintragen, etwa
   `https://io3.ihre-firma.de/oauth-callback.html` für den Web-Client und `https://designer.ihre-firma.de/auth/callback`
   für den Designer, siehe [Anmelde-Adressen](./anmelde-adressen.md).
2. **Zertifikat:** Der Name muss im Zertifikat stehen, das der Reverse Proxy oder der Container ausliefert, siehe
   [HTTPS-Konfiguration](./https-umstellung.md).
3. **Modul-Oberflächen im Client:** Soll der Web-Client unter der neuen Domain Module einbetten, gehört seine Herkunft
   zusätzlich in `MODULE_PROXY_EXTRA_HOST_ORIGIN`, siehe [Modul-Oberflächen im Client](./modul-oberflaechen.md).
4. **Dienst-Einstellungen des Identity Service:** Wurden im Designer unter *Maintenance > Services > Identity Service*
   die SSO-Herkünfte schon einmal gespeichert, gilt für die Anmeldung die gespeicherte Liste und nicht mehr die aus der
   `.env`. Tragen Sie die neue Domain dann auch dort ein. Die Browser-Freigabe (`SERVICE__CORS__ALLOWEDORIGINS`) gilt
   unabhängig davon.

Danach die drei Dienste neu erstellen, damit sie die neuen Werte lesen:

```shell
docker compose up -d io-identity-service io-project-service io-bff-client-service
```

## Beispiele

Die Beispiele zeigen jeweils die Zeilen in `io3/.env`. Die drei Adressen unter `EXTERNALADDRESS` trägt die Vorlage
immer selbst ein, in `ADDITIONAL_CLIENT_ORIGINS` steht nur, was darüber hinausgeht.

### Lokale Entwicklung mit `host.docker.internal`

Auf einem Entwicklerrechner mit Docker Desktop erreichen sich die Container untereinander unter `host.docker.internal`.
Damit auch der Browser die Programme unter diesem Namen öffnet, muss der Rechner ihn auflösen; fehlt er, tragen Sie
`127.0.0.1 host.docker.internal` in die `hosts`-Datei ein. Dann reicht:

```shell
EXTERNALADDRESS=host.docker.internal
INSTANCE_PORT_PREFIX=30
INSTANCE_HTTP_TYPE=https
# Abgeleitet: https://host.docker.internal:30201 (Designer), :30202 (Web-Client), :30203 (Integration-Client)
```

Öffnen Sie die Programme im Browser zusätzlich unter `localhost`, ist das eine andere Herkunft. Tragen Sie sie dann ein:

```shell
ADDITIONAL_CLIENT_ORIGINS=https://localhost:30201;https://localhost:30202;https://localhost:30203
```

Startet jemand Designer oder Client als Entwicklungs-Server (`npm run dev`) gegen diese Container, laufen sie unter
`http://localhost:5173` (bzw. `:3000`, `:5000`). Diese Adressen lassen die Dienste nur in der Umgebung `Development`
zu. Laufen die Container nicht in `Development`, tragen Sie die Adresse ein, nur auf dem Entwicklerrechner:

```shell
ADDITIONAL_CLIENT_ORIGINS=http://localhost:5173
```

### Interne Instanz unter `awrun.dt.local`

Eine Test- oder Demo-Instanz im internen Netz, die Benutzer unter `awrun.dt.local` öffnen:

```shell
EXTERNALADDRESS=awrun.dt.local
INSTANCE_PORT_PREFIX=30
INSTANCE_HTTP_TYPE=https
# Abgeleitet: https://awrun.dt.local:30201, https://awrun.dt.local:30202, https://awrun.dt.local:30203
```

Erreichen einige Benutzer die Instanz auch über den Kurznamen oder die IP-Adresse, sind das weitere Herkünfte:

```shell
ADDITIONAL_CLIENT_ORIGINS=https://awrun:30201;https://awrun:30202;https://192.168.10.25:30201;https://192.168.10.25:30202
```

Läuft auf demselben Rechner eine zweite Instanz mit `INSTANCE_PORT_PREFIX=40`, leitet ihre Vorlage
`https://awrun.dt.local:40201` usw. selbst ab; jede Instanz kennt nur ihre eigenen Ports.

### Eigene Domain hinter einem Reverse Proxy

Der Reverse Proxy veröffentlicht die Programme unter eigenen Namen auf Port 443, intern bleiben die Container unter
`EXTERNALADDRESS`:

```shell
EXTERNALADDRESS=io3-host.intern.ihre-firma.de
ADDITIONAL_CLIENT_ORIGINS=https://designer.ihre-firma.de;https://io3.ihre-firma.de;https://integration.ihre-firma.de
```

Bei Port 443 steht kein Port in der Herkunft. Dazu gehören die Schritte aus
[Eigene Kunden-Domain eintragen](#eigene-kunden-domain-eintragen) (Rücksprungadressen, Zertifikat, Modul-Oberflächen).

### Ohne diese Vorlage (eigene Compose-Dateien, Kubernetes)

Wer die Dienste mit eigenen Compose-Dateien, älteren awrun-Umgebungen, Helm oder Kubernetes-Manifesten betreibt, bekommt
`ADDITIONAL_CLIENT_ORIGINS` nicht ausgewertet. Setzen Sie die Liste dann direkt an den drei Diensten, getrennt durch
`;` oder `,`, ohne Pfad und ohne Schrägstrich am Ende:

| Dienst | Variable |
| --- | --- |
| BFF Client | `SERVICE__CORS__ALLOWEDORIGINS` |
| Project Service | `SERVICE__CORS__ALLOWEDORIGINS` |
| Identity Service | `SERVICE__CORS__ALLOWEDORIGINS`, für die Anmeldung zusätzlich `SERVICE__SSO_ALLOWED_ORIGINS` |

Die Dienste lassen außerdem die SSO-Herkünfte zu (`SERVICE__ENDPOINTS__IDENTITYSERVICE__SSOALLOWEDORIGINS` an BFF Client
und Project Service). Fehlen beide Variablen an einem Dienst, beantwortet er **keine** Browser-Anfrage mehr, außer der
Desktop-Anwendung. Prüfen Sie deshalb gerade ältere Compose-Dateien, die die SSO-Herkünfte nur am Identity Service
setzen.

Beispiel für Kubernetes (Auszug aus dem `env` der drei Deployments):

```yaml
env:
  - name: SERVICE__CORS__ALLOWEDORIGINS
    value: "https://designer.ihre-firma.de;https://io3.ihre-firma.de;https://integration.ihre-firma.de"
```

Beim Identity Service zusätzlich:

```yaml
  - name: SERVICE__SSO_ALLOWED_ORIGINS
    value: "https://designer.ihre-firma.de;https://io3.ihre-firma.de;https://integration.ihre-firma.de"
```

`SERVICE__SSO_ALLOWED_ORIGINS` gilt für die Anmeldung nur, solange in den Dienst-Einstellungen des Identity Service
keine SSO-Herkünfte gespeichert sind; sonst gilt die gespeicherte Liste, siehe
[Eigene Kunden-Domain eintragen](#eigene-kunden-domain-eintragen), Schritt 4.

Nach der Änderung die Pods neu starten (`kubectl rollout restart deployment/<name>`), denn alle drei Dienste lesen
`SERVICE__CORS__ALLOWEDORIGINS` nur beim Start.

## Wenn sich niemand mehr anmelden kann

Bleibt nach dem Update die Anmeldung hängen und zeigt die Konsole des Browsers `blocked by CORS policy`:

1. In der Konsole steht die abgelehnte Herkunft (`from origin 'https://…'`). Genau diese Adresse in
   `ADDITIONAL_CLIENT_ORIGINS` (bzw. `SERVICE__CORS__ALLOWEDORIGINS`) eintragen.
2. Identity Service, Project Service und BFF Client neu erstellen bzw. neu starten:
   `docker compose up -d io-identity-service io-project-service io-bff-client-service`.
3. Mit der Vorab-Anfrage aus [Prüfen](#prüfen) bestätigen, dass die Herkunft zurückkommt.

Die Desktop-Anwendung (`app://bundle`) ist von fehlenden Einträgen nicht betroffen, sie ist immer zugelassen.

## Edge-Sidebar

Die Edge-Sidebar läuft als Browser-Erweiterung unter `chrome-extension://<erweiterungs-id>`. Die Id finden Sie in Edge
unter `edge://extensions` bei der Erweiterung. Tragen Sie sie wie eine eigene Domain ein:

```shell
ADDITIONAL_CLIENT_ORIGINS=chrome-extension://abcdefghijklmnop
ADDITIONAL_REDIRECT_URIS=chrome-extension://abcdefghijklmnop/oauth-callback.html
MODULE_PROXY_EXTRA_HOST_ORIGIN=chrome-extension://abcdefghijklmnop
```

## Prüfen

Ob ein Dienst eine Herkunft zulässt, zeigt eine Vorab-Anfrage (Preflight). Antwortet der Dienst mit
`access-control-allow-origin` und der angefragten Herkunft, ist sie freigegeben; fehlt die Zeile, nicht:

```shell
curl -sk -o /dev/null -D - -X OPTIONS "https://<EXTERNALADDRESS>:30012/api/v3/client/user/settings" \
     -H "Origin: https://io3.ihre-firma.de" -H "Access-Control-Request-Method: GET" \
     -H "Access-Control-Request-Headers: authorization" | grep -i access-control
```

Für den Project Service nehmen Sie Port `30002` und die Herkunft des Designers, für den Identity Service Port `30001`.

Lokale Entwicklungs-Server (`http://localhost:3000`, `:5000`, `:5173`) lassen die Dienste nur in der Umgebung
`Development` zu. Wer Designer oder Client lokal gegen eine Test-Installation startet, trägt die Adresse dort in
`ADDITIONAL_CLIENT_ORIGINS` ein, etwa `http://localhost:5173`; in einer produktiven Installation nicht.

## Hintergrund

Bisher erlaubten alle Dienste Anfragen aus dem Browser von **jeder** Herkunft. Jede fremde Webseite konnte damit im
Browser eines Benutzers die Antworten der Dienste lesen, etwa die öffentlichen Routen und Fehlertexte. Geschützte Daten
blieben durch das Anmelde-Token geschützt, das eine fremde Seite nicht kennt. Mit der Liste antworten die Dienste nur
noch den eigenen Programmen.
