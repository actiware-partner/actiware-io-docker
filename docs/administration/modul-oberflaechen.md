---
title: Modul-Oberflächen im Client
---

# Modul-Oberflächen im Client

Module können eigene Oberflächen in den Client bringen: einen Bereich, einen Eintrag in der Seitenleiste, einen Tab oder
eine Einstellungskarte. Diese Oberflächen liefert der BFF Client (`io-bff-client-service`) über seinen **Modul-Proxy** aus.
Der Client kennt nur den BFF, die Adresse des Moduls verlässt die Plattform nie.

Solange der Modul-Proxy aus ist, öffnet sich keine Modul-Oberfläche. Der BFF antwortet dann auf die Ticket-Anfrage des
Clients mit `503 module_proxy_not_configured`.

## Warum jedes Modul eine eigene Adresse braucht

Jedes Modul läuft im Browser unter einer eigenen Herkunft, zum Beispiel
`https://3f2a1b4c5d6e4f708a9b0c1d2e3f4a5b.modules.example.com:30012`. Das erste Stück des Namens ist die Kennung des Moduls.
So trennt der Browser die Module voneinander und vom Client: Ein Modul kann weder auf ein anderes Modul noch auf die
Anmeldung des Benutzers im Client zugreifen.

Der BFF prüft das beim Start. Ergibt die Vorlage die Adresse eines Clients oder des BFF selbst, startet er nicht.

## Was Sie einrichten

| Schritt | Was |
| ------- | --- |
| DNS | Einen Wildcard-Eintrag `*.modules.<EXTERNALADDRESS>`, der auf denselben Host zeigt wie `EXTERNALADDRESS`. |
| Zertifikat | Ein Zertifikat, das `*.modules.<EXTERNALADDRESS>` abdeckt. Es kann dasselbe Server-Zertifikat sein, wenn Sie den Namen als weiteren SAN-Eintrag aufnehmen (siehe [HTTPS-Konfiguration](./https-umstellung.md)). HTTPS ist Pflicht, weil das Sitzungs-Cookie des Proxys `Secure` ist. |
| `io3/.env` | `MODULE_ORIGIN_TEMPLATE=https://{module}.modules.<EXTERNALADDRESS>:30012` |
| Neustart | `docker compose up -d io-bff-client-service` |

Für ein Zertifikat aus eigener CA ergänzen Sie den SAN-Eintrag in Schritt 3 der HTTPS-Anleitung so:

```bash
subjectAltName = DNS:<EXTERNALADDRESS>, DNS:*.modules.<EXTERNALADDRESS>, IP:<IP-ADRESSE>
```

Ein Wildcard-Zertifikat deckt genau eine Stufe ab. `*.modules.example.com` passt auf
`3f2a….modules.example.com`, aber nicht auf `example.com` selbst. Deshalb steht `EXTERNALADDRESS` weiterhin als eigener
Eintrag im Zertifikat.

Steht vor dem BFF ein eigener Reverse Proxy, leiten Sie `*.modules.<EXTERNALADDRESS>` an den BFF weiter und reichen den
ursprünglichen `Host`-Header unverändert durch. Der BFF liest die Kennung des Moduls aus dem Namen.

## Was die Vorlage einträgt

`io3/services.docker-compose.yml` setzt am `io-bff-client-service`:

| Variable | Wert |
| -------- | ---- |
| `MODULEPROXY__MODULEORIGINTEMPLATE` | `MODULE_ORIGIN_TEMPLATE` aus der `.env`; leer: Proxy aus |
| `MODULEPROXY__ALLOWEDHOSTORIGINS__0` | Web-Client, `https://<EXTERNALADDRESS>:30202` |
| `MODULEPROXY__ALLOWEDHOSTORIGINS__1` | Integration-Client, `https://<EXTERNALADDRESS>:30203` |
| `MODULEPROXY__ALLOWEDHOSTORIGINS__2` | `MODULE_PROXY_EXTRA_HOST_ORIGIN` aus der `.env`, etwa die Edge-Sidebar `chrome-extension://<erweiterungs-id>` |
| `SERVICE__ENDPOINTS__CLIENTSERVICE__SHAREDSECRET` | `SHARED_SECRET`; der Client Service gibt die Adresse eines Moduls nur damit heraus |

Die Desktop-Anwendung (`app://bundle`) ist immer zugelassen. Nur die eingetragenen Herkünfte dürfen ein Modul einbetten und
ein Ticket für die Oberfläche holen. Fehlt eine Herkunft, scheitert der Client schon an CORS. Im Log des BFF steht dann
`Request origin … does not have permission to access the resource.`

## Lokal auf einem Entwicklerrechner

Browser lösen `*.localhost` ohne DNS-Eintrag auf den eigenen Rechner auf. Mit einem Zertifikat, das
`*.modules.localhost` enthält (zum Beispiel aus `mkcert`), reicht:

```bash
MODULE_ORIGIN_TEMPLATE=https://{module}.modules.localhost:30012
```

Das gilt auch, wenn `EXTERNALADDRESS` `host.docker.internal` ist. Die Modul-Adressen müssen nicht zum Namen des Clients
passen, sie müssen sich nur von ihm unterscheiden.

## Prüfen

1. Im Log des BFF darf beim Start **nicht** `The module proxy is switched off.` stehen:

   ```bash
   docker compose logs io-bff-client-service | grep -i "module proxy"
   ```

2. Der Preflight der Ticket-Route muss den Web-Client zulassen (Projekt und Modul-ID sind hier beliebig):

   ```bash
   curl -sk -o /dev/null -D - -X OPTIONS \
     "https://<EXTERNALADDRESS>:30012/api/v3/client/test/modules/00000000-0000-0000-0000-000000000001/ticket" \
     -H "Origin: https://<EXTERNALADDRESS>:30202" -H "Access-Control-Request-Method: POST" \
     | grep -i access-control-allow-origin
   ```

3. Ein Modul-Host antwortet auf eine API-Route mit `404` und auf die Proxy-Route ohne Sitzung mit `401`. Antwortet er
   gar nicht oder mit einem Zertifikatsfehler, fehlt der DNS-Eintrag oder der SAN-Eintrag im Zertifikat.

Ausführlich, mit allen Schlüsseln und Grenzwerten, beschreibt die Dokumentation des BFF Client Service den Modul-Proxy
unter **Module Proxy Origin**.
