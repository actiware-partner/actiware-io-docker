# Administratoren-Dokumentation

## Übersicht

Dieses Repository enthält die notwendigen Konfigurationsdateien und Anleitungen, um die ACTIWARE IO Umgebung mit Docker bereitzustellen und zu verwalten. Diese Dokumentation richtet sich an Administratoren und beschreibt die wichtigsten Einstellungen und Abläufe.

## 1. Die `.env` Datei

Die `.env` Datei enthält Umgebungsvariablen, die für den Betrieb der Docker-Umgebung benötigt werden. Typische Einstellungen sind:

- **EXTERNALADDRESS**: Hier muss der DNS-Name des Hostsystems eingetragen werden, unter dem das System von außen erreichbar ist. Alternativ kann auch die öffentliche IP-Adresse verwendet werden. Wichtig: Es muss der Name oder die IP eingetragen werden, mit dem/der das System von außen erreichbar ist.
- Weitere Variablen können projektspezifisch sein und werden in den jeweiligen Compose-Dateien referenziert.

> [!TIP]
> Nach Änderungen an der `.env` Datei sollten die betroffenen Docker-Container neu gestartet werden, damit die Änderungen wirksam werden.

## 2. Docker-Compose Dateien

Im Repository befinden sich mehrere `docker-compose` Dateien:

- **docker-compose.yml**: Setup für die Umgebung. Inkludiert das Backend, die Services und Module.
- **backend.docker-compose.yml**: Erweiterung für Backend-Dienste.
- **services.docker-compose.yml**: ACTIWARE.IO Services und Clients, die für den Betrieb benötigt werden.
- **module.docker-compose.yml**: Zusätzliche Module und optionale Komponenten.

### Environments starten

1. Stelle sicher, dass die `.env` Datei korrekt konfiguriert ist.
2. Starte die Umgebung mit:
   ```sh
   docker compose up -d
   ```
   oder für spezifische Dateien:
   ```sh
   docker compose -f <compose-datei> up -d
   ```

### Environments stoppen

Um die Umgebung zu stoppen, verwende:
```sh
docker compose down
```
oder für spezifische Dateien:
```sh
docker compose -f <compose-datei> down
```

### Environments aktualisieren

Um die Container zu aktualisieren (z.B. nach Änderungen an Images oder der `.env` Datei):

1. Ziehe neue Images (optional):
   ```sh
   docker compose pull
   ```
2. Starte die Umgebung neu:
   ```sh
   docker compose up -d
   ```

> [!IMPORTANT]
> Nach Änderungen an der `.env` Datei oder an den Compose-Dateien müssen die betroffenen Container neu gestartet werden.

## 3. Hinweise zur EXTERNALADDRESS Variable

Die Variable `EXTERNALADDRESS` ist essenziell für die korrekte Erreichbarkeit des Systems von außen. Trage hier den DNS-Namen oder die IP-Adresse des Hostsystems ein, unter dem die Umgebung erreichbar sein soll. Dies ist besonders wichtig für Reverse Proxies, Zertifikate und externe Integrationen.

> [!CAUTION]
> Wird hier ein falscher Wert eingetragen, sind Dienste ggf. nicht von außen erreichbar oder Zertifikate funktionieren nicht korrekt.

---

Weitere Details zu einzelnen Diensten und Modulen findest du in den jeweiligen Unterordnern oder in der README.md.
