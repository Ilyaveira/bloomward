#!/usr/bin/env bash
# Test automatique de bout en bout (sans fenêtre) :
#  1) partie solo jouée automatiquement ;
#  2) partie à deux en réseau local (hôte + client sur la même machine),
#     où chaque joueur ne connaît que ses propres indices.
# Usage : GODOT=/chemin/vers/godot tools/test_auto.sh
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
LOG="$(mktemp -d)"
fail=0

"$GODOT" --headless --import >/dev/null 2>&1 || true

echo "== Test solo"
timeout 90 "$GODOT" --headless -- --solo --autotest --quit-after 60 >"$LOG/solo.log" 2>&1
grep -q "AUTOTEST OK" "$LOG/solo.log" && echo "OK" || { echo "ÉCHEC"; cat "$LOG/solo.log"; fail=1; }

echo "== Test à deux en réseau local"
timeout 90 "$GODOT" --headless -- --host --autotest --quit-after 60 >"$LOG/host.log" 2>&1 &
HOST=$!
sleep 3
timeout 90 "$GODOT" --headless -- --join 127.0.0.1 --autotest --quit-after 60 >"$LOG/client.log" 2>&1
wait $HOST
for f in host client; do
  if grep -q "AUTOTEST OK" "$LOG/$f.log" && ! grep -q "SCRIPT ERROR" "$LOG/$f.log"; then echo "$f : OK"; else echo "$f : ÉCHEC"; cat "$LOG/$f.log"; fail=1; fi
done
grep -q "demande refusée" "$LOG/host.log" && echo "refus des pierres non attribuées : OK" || { echo "refus non vérifié : ÉCHEC"; fail=1; }
exit $fail
