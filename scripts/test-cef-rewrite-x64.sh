#!/bin/bash
# x86_64 : un processus nommé `steam` qui exécute le webhelper avec le port CEF figé 8080
# doit voir l'argument réécrit par la_symbind64 et le port publié pour Lumen.
# (Sur x86_64 le loader n'appelle que la_symbind64 : sans lui, le port reste 8080.)
set -u
cd "$(dirname "$0")/.."
LIB="$PWD/bin/SLSsteam.so"
[ -f "$LIB" ] || { echo "missing: $LIB" >&2; exit 2; }
T="$(mktemp -d /tmp/slsm-cef.XXXXXX)"; trap 'rm -rf "$T"' EXIT
cat > "$T/t.c" <<'C'
#include <unistd.h>
int main(void) {
	char *a[] = {"echo", "sh -c exec steamwebhelper.sh --remote-debugging-port=8080 -lang=en", 0};
	execv("/bin/echo", a);
	return 1;
}
C
gcc -O1 "$T/t.c" -o "$T/steam" || exit 2
mkdir -p "$T/home/.config/SLSsteam" "$T/home/.local/share" "$T/home/.cache"
printf 'Notifications: no\nNotifyInit: no\n' > "$T/home/.config/SLSsteam/config.yaml"
out="$(env -i PATH=/usr/bin:/bin HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" \
	XDG_DATA_HOME="$T/home/.local/share" XDG_CACHE_HOME="$T/home/.cache" \
	STEAM_STEAMRT_RECURSION_GUARD=1 LD_AUDIT="$LIB" "$T/steam")"
port="$(printf '%s' "$out" | sed -n 's/.*--remote-debugging-port=\([0-9]*\).*/\1/p')"
[ -n "$port" ] && [ "$port" != 8080 ] && [ "$port" -ge 1024 ] || { echo "FAIL: port=$port out='$out'"; exit 1; }
[ -s "$T/home/.local/share/Lumen/cef_port" ] || { echo "FAIL: cef_port not published"; exit 1; }
case "$(cat "$T/home/.SLSsteam.log")" in *"CEF: remote-debugging port"*) ;;
	*) echo "FAIL: setup() did not run in the guarded client"; exit 1;; esac

# With KeepDefaultCefPort: yes, port remains 8080 and no contract is published
mkdir -p "$T/home2/.config/SLSsteam" "$T/home2/.local/share" "$T/home2/.cache"
printf 'Notifications: no\nNotifyInit: no\nKeepDefaultCefPort: yes\n' > "$T/home2/.config/SLSsteam/config.yaml"
out2="$(env -i PATH=/usr/bin:/bin HOME="$T/home2" XDG_CONFIG_HOME="$T/home2/.config" \
	XDG_DATA_HOME="$T/home2/.local/share" XDG_CACHE_HOME="$T/home2/.cache" \
	STEAM_STEAMRT_RECURSION_GUARD=1 LD_AUDIT="$LIB" "$T/steam")"
port2="$(printf '%s' "$out2" | sed -n 's/.*--remote-debugging-port=\([0-9]*\).*/\1/p')"
[ "$port2" = 8080 ] || { echo "FAIL: KeepDefaultCefPort expected 8080, got $port2 out='$out2'"; exit 1; }
[ ! -e "$T/home2/.local/share/Lumen/cef_port" ] || { echo "FAIL: cef_port should not be published when keeping 8080"; exit 1; }

echo "PASS test-cef-rewrite-x64 (port $port, KeepDefaultCefPort 8080)"
