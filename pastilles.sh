#!/usr/bin/env bash
# Pastilles d'état des agents IA — status-line tmux.
# MIT — Yannick Goalen (https://github.com/yg0a1n/tmux-agents-statusline)
#
# Deux dimensions :
#   - ACTIVITÉ (posée par un watcher : le transcript de l'agent bouge) → 🟢 il bosse MAINTENANT
#   - REPOS (posée par l'orchestrateur ou l'agent lui-même) :
#       waiting (🟡) = a livré qqch qui attend une action de l'orchestrateur (gate à valider, PR à merger)
#       blocked (🔴) = INTERVENTION HUMAINE REQUISE (décision irréversible / blocage)
#       idle    (⚪) = en veille, rien attendu
# render : prompt de permission → 🔴 (prioritaire) ; sinon actif → 🟢 ; sinon glyph(repos).
# Lecture : 🟢 = ça code · 🟡 = l'orchestrateur s'en occupe · ⚪ = ça dort · 🔴 = TU REVIENS.
# Tu ne reviens QUE sur 🔴.
#
# Usage :
#   pastilles.sh rest   <agent> <waiting|blocked|idle>
#   pastilles.sh active <agent> <0|1>
#   pastilles.sh prompt <agent> <0|1>   (menu de permission visible → 🔴 prioritaire)
#   pastilles.sh render
#
# Config :
#   PASTILLE_AGENTS : liste des agents affichés (défaut : "agent-1 agent-2 agent-3")
#   PASTILLE_DIR    : répertoire d'état (défaut : /tmp/pastilles)
#   PASTILLE_STALE  : fraîcheur max en secondes d'un signal actif/prompt (défaut : 30)

DIR="${PASTILLE_DIR:-/tmp/pastilles}"
AGENTS="${PASTILLE_AGENTS:-agent-1 agent-2 agent-3}"
mkdir -p "$DIR" 2>/dev/null

glyph() {
  case "$1" in
    waiting) printf '🟡' ;;
    blocked) printf '🔴' ;;
    *)       printf '⚪' ;;
  esac
}

case "$1" in
  rest)
    [ -n "$2" ] && [ -n "$3" ] && printf '%s' "$3" > "$DIR/$2.rest"
    ;;
  active)
    [ -n "$2" ] && [ -n "$3" ] && printf '%s' "$3" > "$DIR/$2.active"
    ;;
  prompt)
    [ -n "$2" ] && [ -n "$3" ] && printf '%s' "$3" > "$DIR/$2.prompt"
    ;;
  render)
    out=""
    now=$(date +%s)
    fresh() {  # $1=fichier : contenu "1" ET mtime < PASTILLE_STALE (heartbeat)
      [ "$(cat "$1" 2>/dev/null)" = "1" ] || return 1
      local mt; mt=$(stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0)
      [ $((now - mt)) -le "${PASTILLE_STALE:-30}" ]
    }
    for a in $AGENTS; do
      if fresh "$DIR/$a.prompt"; then
        g='🔴'   # prompt de permission en attente → l'humain doit répondre (prioritaire sur tout)
      elif fresh "$DIR/$a.active"; then
        g='🟢'
      else
        r=$(cat "$DIR/$a.rest" 2>/dev/null); [ -z "$r" ] && r=idle
        g=$(glyph "$r")
      fi
      out="$out $g$a"
    done
    printf '%s' "${out# }"
    ;;
  *)
    echo "usage: pastilles.sh rest|active|prompt <agent> <val> | render" >&2; exit 1
    ;;
esac
