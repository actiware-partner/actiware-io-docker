---
title: Anmelde-Adressen
---

# Anmelde-Adressen

Ab Version 3.0.9 schickt die Anmeldeseite von ACTIWARE.IO Benutzer nach der Anmeldung nur noch an Adressen zurück, die
der Identity Service kennt. Steht eine Adresse nicht in seiner Liste, erscheint **`Invalid redirect_uri`** und die
Anmeldung bricht ab. Diese Seite beschreibt, was die Docker-Vorlage dafür einträgt und was Sie selbst ergänzen müssen.

Ausführlich und ohne Fachbegriffe erklärt, warum das so ist und worauf Sie achten müssen, steht in der Dokumentation
des Identity Service unter **Administration → Anmelde-Adressen (Redirect-Adressen)**.

## Warum?

Ohne diese Liste konnte ein Angreifer einen Link bauen, der wie eine normale Anmeldung aussieht. Der Benutzer meldet sich
auf der echten Anmeldeseite an, der Anmeldenachweis landet aber beim Angreifer, der dann im Namen des Benutzers arbeiten
kann. Die Liste verhindert das: Der Nachweis geht nur noch an die eigenen Programme.

## Was die Vorlage einträgt

`io3/services.docker-compose.yml` setzt beim `io-identity-service` die Adressen aus `EXTERNALADDRESS`,
`INSTANCE_PORT_PREFIX` und `INSTANCE_HTTP_TYPE` zusammen:

| Programm           | Adresse (bei `INSTANCE_PORT_PREFIX=30`)                       |
| ------------------ | ------------------------------------------------------------- |
| Designer           | `https://<EXTERNALADDRESS>:30201/auth/callback`               |
| Web-Client         | `https://<EXTERNALADDRESS>:30202/oauth-callback.html`         |
| Integration-Client | `https://<EXTERNALADDRESS>:30203/oauth-callback.html`         |
| Desktop-Anwendung  | `io3://oauth/callback`                                        |

Für eine Standardinstallation müssen Sie also nichts tun.

## Was Sie selbst ergänzen müssen

Tragen Sie in `io3/.env` zusätzliche Adressen in `ADDITIONAL_REDIRECT_URIS` ein, mehrere durch `;` getrennt, wenn

- die **Edge-Sidebar** genutzt wird: `chrome-extension://<erweiterungs-id>/oauth-callback.html`. Die Id finden Sie in
  Edge unter `edge://extensions` bei der Erweiterung oder in der Fehlermeldung im Protokoll;
- Benutzer die Programme **unter einem anderen Namen** öffnen als `EXTERNALADDRESS`, etwa über einen Reverse Proxy,
  eine zweite Domain oder die IP-Adresse;
- die Programme **auf anderen Ports** laufen als in der Vorlage.

```shell
ADDITIONAL_REDIRECT_URIS=chrome-extension://abcdefghijklmnop/oauth-callback.html;https://io3.intern.ihre-firma.de/oauth-callback.html
```

Danach den Identity Service neu starten:

```shell
docker compose up -d io-identity-service
```

## Fehlende Adresse finden

Der Identity Service schreibt jede abgelehnte Adresse ins Protokoll:

```shell
docker compose logs io-identity-service | grep "Authorization refused"
```

Die Zeile nennt die Adresse genau so, wie sie eingetragen werden muss. Tragen Sie nur Adressen ein, die zu Ihrer
Installation gehören. Eine unbekannte Adresse kann ein Angriffsversuch sein.

## Prüfung abschalten: möglich, aber nicht empfohlen

Mit `REDIRECT_URI_CHECK=warn` in `io3/.env` lehnt der Identity Service unbekannte Adressen nicht mehr ab, sondern
protokolliert sie nur.

**Das sollten Sie nicht dauerhaft tun.** Damit ist die Sicherheitslücke wieder offen: Wer einem Benutzer einen
präparierten Anmeldelink schickt, kann dessen Zugang übernehmen, ohne das Passwort zu kennen, und der Benutzer merkt
davon nichts. Das gilt für alle Benutzer, auch für Administratoren.

Vertretbar ist `warn` nur **für kurze Zeit**, wenn sich nach einem Update niemand mehr anmelden kann und Sie
herausfinden müssen, welche Adressen fehlen:

1. `REDIRECT_URI_CHECK=warn` setzen, Identity Service neu starten.
2. Im Protokoll nach `is not registered for application` suchen und die eigenen Adressen in
   `ADDITIONAL_REDIRECT_URIS` übernehmen.
3. **Sofort** wieder `REDIRECT_URI_CHECK=enforce` setzen und neu starten.
