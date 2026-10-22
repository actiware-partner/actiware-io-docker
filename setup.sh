#!/usr/bin/env bash
#
# ACTIWARE.IO - interaktives Einrichtungsskript
#
# Fragt die Eckdaten der Installation ab, schlägt für alle Kennwörter und
# Schlüssel zufällige Werte vor (vom Anwender bestätigbar), erzeugt daraus
#   - io-backend/.env
#   - io3/.env
#   - INSTALLATIONSNACHWEIS.md  (Kennwörter im Klartext, nach dem Sichern löschen!)
#
# Aufruf:  ./setup.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT/io-backend"
IO3_DIR="$ROOT/io3"
PROOF_FILE="$ROOT/INSTALLATIONSNACHWEIS.md"
STAMP="$(date +%Y%m%d-%H%M%S)"

umask 077

# -----------------------------------------------------------------------------
# Ausgabe
# -----------------------------------------------------------------------------
if [ -t 1 ]; then
  C_B=$'\033[1m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_0=$'\033[0m'
else
  C_B=''; C_G=''; C_Y=''; C_R=''; C_0=''
fi

info()    { printf '%s\n' "$*"; }
ok()      { printf '%s✔%s %s\n' "$C_G" "$C_0" "$*"; }
warn()    { printf '%s!%s %s\n' "$C_Y" "$C_0" "$*" >&2; }
die()     { printf '%s✘ %s%s\n' "$C_R" "$*" "$C_0" >&2; exit 1; }
section() { printf '\n%s== %s ==%s\n' "$C_B" "$*" "$C_0"; }

usage() {
  cat <<'EOF'
Verwendung: ./setup.sh

Interaktive Einrichtung von ACTIWARE.IO. Erzeugt io-backend/.env, io3/.env und
INSTALLATIONSNACHWEIS.md aus den .env.example-Vorlagen.

Bei jedem Kennwort/Schlüssel wird ein zufälliger Wert vorgeschlagen:
  Enter / j   Vorschlag übernehmen
  n           neuen Vorschlag erzeugen
  e           eigenen Wert eingeben
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) usage >&2; exit 2 ;;
esac

# -----------------------------------------------------------------------------
# Zufallswerte (nur /dev/urandom, keine zusätzlichen Abhängigkeiten)
# -----------------------------------------------------------------------------
rand_hex() { # $1 = Länge in Zeichen (gerade)
  head -c "$(($1 / 2))" /dev/urandom | od -An -tx1 | tr -d ' \n'
}

rand_alnum() { # $1 = Länge in Zeichen
  local s=''
  while [ "${#s}" -lt "$1" ]; do
    s="$s$(head -c 96 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')"
  done
  printf '%s' "${s:0:$1}"
}

rand_guid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  elif [ -r /proc/sys/kernel/random/uuid ]; then
    cat /proc/sys/kernel/random/uuid
  else
    local h; h="$(rand_hex 32)"
    printf '%s-%s-%s-%s-%s' "${h:0:8}" "${h:8:4}" "${h:12:4}" "${h:16:4}" "${h:20:12}"
  fi
}

generate() { # $1 = Art (alnum32 | hex32 | guid | alnum24)
  case "$1" in
    alnum32) rand_alnum 32 ;;
    alnum24) rand_alnum 24 ;;
    hex32)   rand_hex 32 ;;
    guid)    rand_guid ;;
    *) die "Interner Fehler: unbekannte Generator-Art '$1'" ;;
  esac
}

# -----------------------------------------------------------------------------
# Werte-Speicher (bash 3.2 kompatibel: V_<KEY> als Variablen)
# -----------------------------------------------------------------------------
setv() { printf -v "V_$1" '%s' "$2"; }
getv() { local n="V_$1"; printf '%s' "${!n-}"; }

# Reihenfolge der Kennwörter für den Installationsnachweis: KEY|Datei(en)|Verwendung
PROOF_SECRETS=()
register_secret() { PROOF_SECRETS+=("$1|$2|$3"); }

# Offene Punkte für den Installationsnachweis
OPEN_ITEMS=()

# -----------------------------------------------------------------------------
# Eingabe
# -----------------------------------------------------------------------------
INTERACTIVE=0
[ -t 0 ] && INTERACTIVE=1

read_line() { # $1 = Prompt, Ergebnis in REPLY
  if ! IFS= read -r -p "$1" REPLY; then
    printf '\n'
    die "Eingabe beendet, nichts wurde geschrieben."
  fi
}

read_hidden() { # $1 = Prompt, Ergebnis in REPLY
  if [ "$INTERACTIVE" -eq 1 ]; then
    if ! IFS= read -r -s -p "$1" REPLY; then
      printf '\n'
      die "Eingabe beendet, nichts wurde geschrieben."
    fi
    printf '\n'
  else
    read_line "$1"
  fi
}

# Werte landen unquotiert in einer docker-compose-.env: diese Zeichen würden
# interpoliert, als Kommentar gewertet oder trennen den Wert auf.
valid_value() {
  case "$1" in
    *[[:space:]]* | *'$'* | *'#'* | *'"'* | *"'"* | *'\'* | *'`'*) return 1 ;;
  esac
  return 0
}

VALUE_RULE="Leerzeichen sowie \$ # \" ' \\ \` sind nicht erlaubt."

ask() { # KEY, Frage, Default, [required|optional]
  local key=$1 question=$2 def=${3-} mode=${4:-required} shown
  while :; do
    shown=''
    [ -n "$def" ] && shown=" [$def]"
    read_line "$question$shown: "
    REPLY="${REPLY:-$def}"
    if [ -z "$REPLY" ] && [ "$mode" = required ]; then
      warn "Pflichtangabe."
      continue
    fi
    if ! valid_value "$REPLY"; then
      warn "$VALUE_RULE"
      continue
    fi
    setv "$key" "$REPLY"
    return
  done
}

ask_yes_no() { # Frage, Default (j|n)
  local def=${2:-j} hint
  [ "$def" = j ] && hint='J/n' || hint='j/N'
  while :; do
    read_line "$1 [$hint]: "
    case "${REPLY:-$def}" in
      j|J|y|Y|ja|Ja|JA) return 0 ;;
      n|N|nein|Nein|NEIN) return 1 ;;
      *) warn "Bitte j oder n eingeben." ;;
    esac
  done
}

ask_hidden_value() { # Label, Ergebnis in REPLY; Eingabe wird wiederholt
  local first
  while :; do
    read_hidden "$1 (Eingabe unsichtbar): "
    first=$REPLY
    if [ -z "$first" ]; then warn "Leere Eingabe."; continue; fi
    if ! valid_value "$first"; then warn "$VALUE_RULE"; continue; fi
    read_hidden "Zur Kontrolle wiederholen: "
    if [ "$REPLY" = "$first" ]; then REPLY=$first; return; fi
    warn "Die Eingaben stimmen nicht überein."
  done
}

# Generierter Schlüssel mit Bestätigung durch den Anwender.
# KEY, Anzeigename, Generator-Art, Dateien (backend|io3|backend+io3), Verwendung
ask_generated() {
  local key=$1 label=$2 kind=$3 files=$4 usage=$5 candidate
  candidate="$(generate "$kind")"
  while :; do
    printf '\n%s%s%s (%s)\n' "$C_B" "$label" "$C_0" "$key"
    printf '  Vorschlag: %s%s%s\n' "$C_G" "$candidate" "$C_0"
    read_line "  [J] übernehmen  [N] neu erzeugen  [E] eigenen Wert eingeben: "
    case "${REPLY:-j}" in
      j|J|y|Y|ja|Ja) setv "$key" "$candidate"; break ;;
      n|N) candidate="$(generate "$kind")" ;;
      e|E) ask_hidden_value "  Eigener Wert für $key"; setv "$key" "$REPLY"; break ;;
      *) warn "Bitte J, N oder E eingeben." ;;
    esac
  done
  register_secret "$key" "$files" "$usage"
}

# Zugangsdaten, die identisch zum io-backend sein müssen, wenn nur io3
# eingerichtet wird: es gibt keinen sinnvollen Vorschlag, der Wert muss
# aus der .env des Backends kommen.
ask_shared_from_backend() { # KEY, Anzeigename, Verwendung
  printf '\n%s%s%s (%s)\n' "$C_B" "$2" "$C_0" "$1"
  info "  Muss identisch zur io-backend/.env sein."
  ask_hidden_value "  Wert für $1"
  setv "$1" "$REPLY"
  register_secret "$1" "io3" "$3"
}

# -----------------------------------------------------------------------------
# .env schreiben
# -----------------------------------------------------------------------------
set_env() { # Datei, KEY, Wert  (ersetzt "KEY=..." der Vorlage; bricht bei fehlendem KEY ab)
  local file=$1 key=$2 val=$3 tmp
  tmp="$(mktemp)"
  if ! K="$key" V="$val" awk '
        BEGIN { k = ENVIRON["K"]; v = ENVIRON["V"]; found = 0 }
        index($0, k "=") == 1 { print k "=" v; found = 1; next }
        { print }
        END { if (!found) exit 3 }
      ' "$file" > "$tmp"; then
    rm -f "$tmp"
    die "Schlüssel $key fehlt in der Vorlage von $file"
  fi
  mv "$tmp" "$file"
}

build_env() { # Zielverzeichnis, KEY...
  local dir=$1; shift
  local target="$dir/.env" key
  [ -f "$dir/.env.example" ] || die "Vorlage fehlt: $dir/.env.example"

  if [ -f "$target" ]; then
    local backup="$target.bak-$STAMP"
    cp -p "$target" "$backup"
    warn "Bestehende ${target#"$ROOT"/} gesichert als ${backup#"$ROOT"/} (enthält Kennwörter, nach Prüfung löschen)."
  fi

  local tmp; tmp="$(mktemp)"
  cp "$dir/.env.example" "$tmp"
  for key in "$@"; do
    set_env "$tmp" "$key" "$(getv "$key")"
  done
  mv "$tmp" "$target"
  chmod 600 "$target"
  ok "${target#"$ROOT"/} geschrieben"
}

check_placeholders() { # Datei: übrig gebliebene <PLATZHALTER> melden
  local file=$1 hit
  while IFS= read -r hit; do
    OPEN_ITEMS+=("\`${file#"$ROOT"/}\`: Platzhalter nicht ersetzt: \`$hit\`")
  done < <(grep -E '^[A-Za-z0-9_]+=<[^>]+>' "$file" || true)
}

# -----------------------------------------------------------------------------
# Start
# -----------------------------------------------------------------------------
cat <<EOF
${C_B}ACTIWARE.IO - Einrichtung${C_0}

Das Skript fragt die Eckdaten ab, schlägt Kennwörter und Schlüssel vor und
erzeugt anschließend die .env-Dateien sowie einen Installationsnachweis.
Bis zur Bestätigung am Ende wird nichts geschrieben (Abbruch mit Strg+C).
EOF

[ -f "$BACKEND_DIR/.env.example" ] && [ -f "$IO3_DIR/.env.example" ] ||
  die "Vorlagen nicht gefunden. Das Skript muss im Repository-Wurzelverzeichnis liegen."

section "Umfang"
info "  1) io-backend und io3 (Standard, gemeinsame Zugangsdaten werden einmal erzeugt)"
info "  2) nur io-backend"
info "  3) nur io3 (Backend läuft bereits, gemeinsame Zugangsdaten werden eingegeben)"
SCOPE=''
while [ -z "$SCOPE" ]; do
  read_line "Auswahl [1]: "
  case "${REPLY:-1}" in
    1) SCOPE=both ;;
    2) SCOPE=backend ;;
    3) SCOPE=io3 ;;
    *) warn "Bitte 1, 2 oder 3 eingeben." ;;
  esac
done
WITH_BACKEND=0; WITH_IO3=0
[ "$SCOPE" != io3 ] && WITH_BACKEND=1
[ "$SCOPE" != backend ] && WITH_IO3=1

# -----------------------------------------------------------------------------
section "Instanz"
DEFAULT_HOST="$(hostname -f 2>/dev/null || hostname)"
info "Der Name muss dem CN/SAN des TLS-Zertifikats entsprechen."
ask EXTERNALADDRESS "Extern erreichbarer Hostname oder IP" "$DEFAULT_HOST"
while :; do
  ask INSTANCE_PORT_PREFIX "Port-Präfix (Produktion=30, Test=40)" "30"
  case "$(getv INSTANCE_PORT_PREFIX)" in
    [0-9][0-9]) break ;;
    *) warn "Das Port-Präfix besteht aus genau zwei Ziffern." ;;
  esac
done
ask TIMEZONE "Zeitzone" "Europe/Berlin"

# -----------------------------------------------------------------------------
section "Infrastruktur-Zugänge (Datenbank, Solr, S3, Vektorspeicher)"
ask SOL_BASE_INDEXNAME "Name des Solr-Cores" "io3-objects"
ask DATABASE_USER "Datenbank-Benutzer" "ioadmin"
ask SOLR_USER "Solr-Benutzer" "iosolr"

if [ "$WITH_BACKEND" -eq 1 ]; then
  ask_generated DATABASE_PASS     "Datenbank-Kennwort"   alnum32 "backend+io3" "PostgreSQL-Kennwort von $(getv DATABASE_USER)"
  ask_generated S3_ACCESS_KEY     "S3/MinIO Access Key"  guid     "backend+io3" "S3/MinIO Root-Benutzer"
  ask_generated S3_SECRET_KEY     "S3/MinIO Secret Key"  alnum32  "backend+io3" "S3/MinIO Root-Kennwort"
  ask_generated SOLR_TOKEN        "Solr API-Token"       alnum32  "backend+io3" "Zugriff der Services auf Solr"
  ask_generated SOLR_PASS         "Solr-Kennwort"        alnum32  "backend+io3" "Solr Basic-Auth, Benutzer $(getv SOLR_USER)"
  ask_generated QDRANT_API_KEY    "Qdrant API-Key"       alnum32  "backend+io3" "Vektorspeicher Qdrant"
  ask_generated WEAVIATE_API_KEY  "Weaviate API-Key"     alnum32  "backend+io3" "Vektorspeicher Weaviate"
else
  warn "Die folgenden Werte müssen exakt der io-backend/.env entsprechen."
  ask_shared_from_backend DATABASE_PASS    "Datenbank-Kennwort"  "PostgreSQL-Kennwort von $(getv DATABASE_USER)"
  ask_shared_from_backend S3_ACCESS_KEY    "S3/MinIO Access Key" "S3/MinIO Root-Benutzer"
  ask_shared_from_backend S3_SECRET_KEY    "S3/MinIO Secret Key" "S3/MinIO Root-Kennwort"
  ask_shared_from_backend SOLR_TOKEN       "Solr API-Token"      "Zugriff der Services auf Solr"
  ask_shared_from_backend SOLR_PASS        "Solr-Kennwort"       "Solr Basic-Auth, Benutzer $(getv SOLR_USER)"
  ask_shared_from_backend QDRANT_API_KEY   "Qdrant API-Key"      "Vektorspeicher Qdrant"
  ask_shared_from_backend WEAVIATE_API_KEY "Weaviate API-Key"    "Vektorspeicher Weaviate"
fi

# -----------------------------------------------------------------------------
if [ "$WITH_IO3" -eq 1 ]; then
  section "Anwendung (io3)"
  ask S3_BUCKET_NAME_PREFIX "Präfix der S3-Buckets (instanzweit eindeutig)" "io3"
  ask DATABASE_PREFIX "Präfix der Datenbanknamen" "io3"
  ask DATABASE_SERVER "Hostname/IP des PostgreSQL-Servers" "$(getv EXTERNALADDRESS)"
  setv DATABASE_PORT "$(getv INSTANCE_PORT_PREFIX)432"
  ask DEFAULT_USER "Initialer Admin-Benutzer" "admin"

  ask_generated DEFAULT_PASS    "Kennwort des initialen Admins"          alnum24 "io3" "Anmeldung als $(getv DEFAULT_USER), nach dem ersten Login ändern"
  ask_generated CLIENT_SECRET   "OAuth2 Client-Secret"                   alnum32 "io3" "Authentifizierung zwischen den Services"
  ask_generated SHARED_SECRET   "Shared Secret (32 Zeichen HEX)"         hex32   "io3" "interne Service-zu-Service-Kommunikation"
  ask_generated ENCRYPTION_KEY  "Verschlüsselungsschlüssel (32 Zeichen HEX)" hex32 "io3" "Datenverschlüsselung at rest, nach Inbetriebnahme nicht mehr ändern"

  # --- E-Mail ---------------------------------------------------------------
  section "E-Mail-Versand (Microsoft Graph)"
  if ask_yes_no "E-Mail-Versand jetzt konfigurieren?" j; then
    ask SMTP_PROFILE_FROM_ADDRESS "Absenderadresse"
    ask SMTP_BLOCKED_REPORT_RECIPIENTS "Empfänger für Blocked-Reports" "$(getv SMTP_PROFILE_FROM_ADDRESS)"
    ask SMTP_GRAPH_TENANT_ID "Tenant-ID (Microsoft Entra ID)"
    ask SMTP_GRAPH_CLIENT_ID "Client-ID der Anwendung"
    ask_hidden_value "Client-Secret der Anwendung"
    setv SMTP_GRAPH_CLIENT_SECRET "$REPLY"
  else
    for k in SMTP_PROFILE_FROM_ADDRESS SMTP_BLOCKED_REPORT_RECIPIENTS SMTP_GRAPH_TENANT_ID SMTP_GRAPH_CLIENT_ID SMTP_GRAPH_CLIENT_SECRET; do setv "$k" ''; done
    OPEN_ITEMS+=("E-Mail-Versand nicht konfiguriert: \`SMTP_*\` in \`io3/.env\` nachtragen (Pflicht laut Dokumentation).")
  fi

  # --- KI -------------------------------------------------------------------
  section "KI-Assistent (optional)"
  if ask_yes_no "KI-Provider jetzt konfigurieren?" n; then
    ask AI_PROVIDER "Provider (OpenAI, AzureOpenAI, Anthropic, Google, Mistral, Ollama, Custom)" "openai"
    ask AI_MODEL "Modell"
    ask_hidden_value "API-Key des KI-Providers"
    setv AI_API_KEY "$REPLY"
  else
    setv AI_PROVIDER openai; setv AI_MODEL ''; setv AI_API_KEY ''
  fi

  # --- OCR ------------------------------------------------------------------
  section "OCR (optional)"
  if ask_yes_no "Mistral OCR jetzt konfigurieren?" n; then
    ask_hidden_value "Mistral API-Key"
    setv MISTRAL_API_KEY "$REPLY"
  else
    setv MISTRAL_API_KEY ''
  fi
fi

# -----------------------------------------------------------------------------
# Bestätigung und Schreiben
# -----------------------------------------------------------------------------
section "Zusammenfassung"
info "Instanz:        $(getv EXTERNALADDRESS), Port-Präfix $(getv INSTANCE_PORT_PREFIX)"
[ "$WITH_BACKEND" -eq 1 ] && info "Schreibe:       io-backend/.env"
[ "$WITH_IO3" -eq 1 ]     && info "Schreibe:       io3/.env"
info "Schreibe:       INSTALLATIONSNACHWEIS.md"
for f in "$BACKEND_DIR/.env" "$IO3_DIR/.env" "$PROOF_FILE"; do
  { [ "$f" = "$BACKEND_DIR/.env" ] && [ "$WITH_BACKEND" -eq 0 ]; } && continue
  { [ "$f" = "$IO3_DIR/.env" ] && [ "$WITH_IO3" -eq 0 ]; } && continue
  if [ -e "$f" ]; then
    if [ "$f" = "$PROOF_FILE" ]; then
      warn "${f#"$ROOT"/} existiert bereits und wird ersetzt."
    else
      warn "${f#"$ROOT"/} existiert bereits und wird ersetzt (Sicherung als .bak-$STAMP)."
    fi
  fi
done
if [ -f "$BACKEND_DIR/.env" ] && [ "$WITH_BACKEND" -eq 1 ]; then
  warn "Wurde die Datenbank mit der bisherigen .env bereits initialisiert, passen neue Kennwörter nicht mehr zu ihr."
fi
ask_yes_no "Dateien jetzt schreiben?" j || die "Abgebrochen, nichts wurde geschrieben."

section "Schreibe Dateien"
if [ "$WITH_BACKEND" -eq 1 ]; then
  build_env "$BACKEND_DIR" \
    EXTERNALADDRESS INSTANCE_PORT_PREFIX TIMEZONE \
    SOLR_TOKEN SOLR_USER SOLR_PASS SOL_BASE_INDEXNAME \
    QDRANT_API_KEY WEAVIATE_API_KEY \
    S3_ACCESS_KEY S3_SECRET_KEY \
    DATABASE_USER DATABASE_PASS
  check_placeholders "$BACKEND_DIR/.env"
fi
if [ "$WITH_IO3" -eq 1 ]; then
  build_env "$IO3_DIR" \
    EXTERNALADDRESS INSTANCE_PORT_PREFIX TIMEZONE \
    DEFAULT_USER DEFAULT_PASS CLIENT_SECRET SHARED_SECRET ENCRYPTION_KEY \
    AI_PROVIDER AI_MODEL AI_API_KEY \
    SOLR_TOKEN SOLR_USER SOLR_PASS SOL_BASE_INDEXNAME \
    S3_BUCKET_NAME_PREFIX S3_ACCESS_KEY S3_SECRET_KEY \
    DATABASE_USER DATABASE_PASS DATABASE_SERVER DATABASE_PORT DATABASE_PREFIX \
    SMTP_PROFILE_FROM_ADDRESS SMTP_GRAPH_TENANT_ID SMTP_GRAPH_CLIENT_ID SMTP_GRAPH_CLIENT_SECRET \
    SMTP_BLOCKED_REPORT_RECIPIENTS \
    QDRANT_API_KEY WEAVIATE_API_KEY \
    MISTRAL_API_KEY
  check_placeholders "$IO3_DIR/.env"
fi

# -----------------------------------------------------------------------------
# Installationsnachweis
# -----------------------------------------------------------------------------
shared_label() { # "io-backend, io3" | "io-backend" | "io3" je nach Umfang
  if [ "$WITH_BACKEND" -eq 1 ] && [ "$WITH_IO3" -eq 1 ]; then printf 'io-backend, io3'
  elif [ "$WITH_BACKEND" -eq 1 ]; then printf 'io-backend'
  else printf 'io3'; fi
}

write_proof() {
  local host http prefix entry key files usage val scope_text shared
  shared="$(shared_label)"
  case "$SCOPE" in
    both)    scope_text='io-backend und io3' ;;
    backend) scope_text='nur io-backend' ;;
    *)       scope_text='nur io3' ;;
  esac
  host="$(getv EXTERNALADDRESS)"; prefix="$(getv INSTANCE_PORT_PREFIX)"
  http="https"
  if [ "$WITH_IO3" -eq 1 ] && [ -f "$IO3_DIR/.env" ]; then
    http="$(sed -n 's/^INSTANCE_HTTP_TYPE=//p' "$IO3_DIR/.env" | head -n 1)"
    http="${http:-https}"
  fi

  {
    cat <<EOF
# Installationsnachweis ACTIWARE.IO

> [!CAUTION]
> **Dieses Dokument enthält Kennwörter und Schlüssel im Klartext.**
>
> - Alle Kennwörter **jetzt sichern**, z. B. in einem Passwortmanager oder Secret Manager.
> - Das Dokument dient **ausschließlich als Installationsnachweis** und ist keine Ablage für Kennwörter.
> - Nach dem Sichern **diese Datei löschen** (\`rm INSTALLATIONSNACHWEIS.md\`).
> - Nicht per E-Mail versenden und nicht in Git einchecken.
> - Den \`ENCRYPTION_KEY\` nach der Inbetriebnahme nicht mehr ändern: bereits verschlüsselte Daten wären sonst nicht mehr lesbar.

## Installation

| | |
|---|---|
| Erstellt am | $(date '+%d.%m.%Y %H:%M:%S %Z') |
| Erstellt von | $(id -un)@$(hostname) |
| Hostname der Instanz | \`$host\` |
| Port-Präfix | \`$prefix\` |
| Zeitzone | \`$(getv TIMEZONE)\` |
| Umfang | $scope_text |
EOF

    if [ "$WITH_IO3" -eq 1 ]; then
      cat <<EOF

## Anmeldung

| | |
|---|---|
| Web-Client | $http://$host:${prefix}202 |
| Designer | $http://$host:${prefix}201 |
| Benutzer | \`$(getv DEFAULT_USER)\` |
| Kennwort | \`$(getv DEFAULT_PASS)\` |

Das Kennwort des initialen Admins ist **sofort nach dem ersten Login zu ändern**.
EOF
    fi

    cat <<EOF

## Kennwörter und Schlüssel

| Variable | Wert | Gilt in | Verwendung |
|---|---|---|---|
EOF
    # Benutzernamen gehören zu den Zugangsdaten und stehen vor den Kennwörtern.
    printf '| `DATABASE_USER` | `%s` | %s | PostgreSQL-Benutzer |\n' "$(getv DATABASE_USER)" "$shared"
    printf '| `SOLR_USER` | `%s` | %s | Solr Basic-Auth Benutzer |\n' "$(getv SOLR_USER)" "$shared"
    for entry in "${PROOF_SECRETS[@]}"; do
      key="${entry%%|*}"; entry="${entry#*|}"
      files="${entry%%|*}"; usage="${entry#*|}"
      [ "$files" = "backend+io3" ] && files="$shared"
      val="$(getv "$key")"
      printf '| `%s` | `%s` | %s | %s |\n' "$key" "$val" "$files" "$usage"
    done

    if [ "$WITH_IO3" -eq 1 ]; then
      cat <<'EOF'

Zugangsdaten externer Dienste (SMTP-Client-Secret, KI- und Mistral-API-Key) stehen
bewusst nicht in diesem Dokument. Sie liegen nur in `io3/.env` und stammen aus dem
jeweiligen Anbieter-Portal.
EOF
    fi

    if [ "${#OPEN_ITEMS[@]}" -gt 0 ]; then
      printf '\n## Offene Punkte\n\n'
      for entry in "${OPEN_ITEMS[@]}"; do printf -- '- %s\n' "$entry"; done
    fi

    cat <<EOF

## Nächste Schritte

1. Kennwörter sichern, danach \`INSTALLATIONSNACHWEIS.md\` löschen.
2. Zertifikate bereitstellen, siehe [docs/https-umstellung.md](docs/https-umstellung.md).
3. Zuerst \`io-backend\`, danach \`io3\` starten: \`docker compose up -d\` im jeweiligen Verzeichnis.
4. Erste Anmeldung und Kennwort des Admins ändern.

Die Konfigurationsdateien \`io-backend/.env\` und \`io3/.env\` liegen nur auf diesem Server und sind für Git ausgeschlossen.
EOF
  } > "$PROOF_FILE"
  chmod 600 "$PROOF_FILE"
}

write_proof
ok "INSTALLATIONSNACHWEIS.md geschrieben"

# -----------------------------------------------------------------------------
section "Fertig"
if [ "${#OPEN_ITEMS[@]}" -gt 0 ]; then
  warn "Offene Punkte:"
  for item in "${OPEN_ITEMS[@]}"; do printf '    - %s\n' "$item" >&2; done
fi
cat <<EOF
${C_B}Wichtig:${C_0}
  1. Kennwörter aus ${C_B}INSTALLATIONSNACHWEIS.md${C_0} sichern (Passwortmanager).
  2. Danach die Datei löschen: rm INSTALLATIONSNACHWEIS.md
  3. Zertifikate bereitstellen, dann io-backend und anschließend io3 starten.
EOF
