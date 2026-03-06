#!/usr/bin/env bash
set -Eeuo pipefail

DEFAULT_PORT=4444

die() { echo "[-] $*" >&2; exit 1; }
info() { echo "[*] $*"; }
ok() { echo "[+] $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Falta '$1' en PATH."; }
is_int() { [[ "${1:-}" =~ ^[0-9]+$ ]]; }

cleanup() {
  echo -e "\n[*] Cerrando TELNET..."
  kill 0 2>/dev/null
}
trap cleanup EXIT
trap 'exit 130' INT

show_logo() {
  local BRIGHT_GREEN="\e[92m"
  local DIM_GREEN="\e[2;32m"
  local RESET="\e[0m"
  clear || true
  echo -e "${DIM_GREEN}"
  cat <<'EOF'
╔══════════════════════════════════════════════════════╗
║  ｱ ﾊ ﾐ ﾋ ｰ ｳ ｼ ﾅ ﾓ ﾆ ｻ ﾜ ﾂ ｵ ﾘ ｱ ﾎ ﾃ ﾏ ｹ  ║
║  ﾒ ｴ ｶ ｸ ﾁ ﾄ ﾉ ﾌ ﾔ ﾖ ﾙ ﾚ ﾛ ﾝ 0 1 0 1 1 0  ║
╠══════════════════════════════════════════════════════╣
EOF
  echo -e "${BRIGHT_GREEN}"
  cat <<'EOF'
║                                                      ║
 .----------------.  .----------------.  .-----------------.                    
| .--------------. || .--------------. || .--------------. |                    
| |   _____      | || |      __      | || | ____  _____  | |                    
| |  |_   _|     | || |     /  \     | || ||_   \|_   _| | |                    
| |    | |       | || |    / /\ \    | || |  |   \ | |   | |                    
| |    | |   _   | || |   / ____ \   | || |  | |\ \| |   | |                    
| |   _| |__/ |  | || | _/ /    \ \_ | || | _| |_\   |_  | |                    
| |  |________|  | || ||____|  |____|| || ||_____|\____| | |                    
| |              | || |              | || |              | |                    
| '--------------' || '--------------' || '--------------' |                    
 '----------------'  '----------------'  '----------------'                     
 .----------------.  .----------------.  .----------------.  .----------------. 
| .--------------. || .--------------. || .--------------. || .--------------. |
| |     ______   | || |  ____  ____  | || |      __      | || |  _________   | |
| |   .' ___  |  | || | |_   ||   _| | || |     /  \     | || | |  _   _  |  | |
| |  / .'   \_|  | || |   | |__| |   | || |    / /\ \    | || | |_/ | | \_|  | |
| |  | |         | || |   |  __  |   | || |   / ____ \   | || |     | |      | |
| |  \ `.___.'\  | || |  _| |  | |_  | || | _/ /    \ \_ | || |    _| |_     | |
| |   `._____.'  | || | |____||____| | || ||____|  |____|| || |   |_____|    | |
| |              | || |              | || |              | || |              | |
| '--------------' || '--------------' || '--------------' || '--------------' |
 '----------------'  '----------------'  '----------------'  '----------------' 
║              by www.unfantasmaenelsistema.com v1                      ║
EOF
  echo -e "${DIM_GREEN}"
  cat <<'EOF'
╠══════════════════════════════════════════════════════╣
║      Simple TCP LAN Chat · ncat · Idle: 10min        ║
╚══════════════════════════════════════════════════════╝
EOF
  echo -e "${RESET}"
}

is_valid_ip() {
  local ip="$1"
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  local IFS='.'
  read -ra octets <<< "$ip"
  for octet in "${octets[@]}"; do
    ((octet >= 0 && octet <= 255)) || return 1
  done
}

pick_ip() {
  mapfile -t ips < <(hostname -I 2>/dev/null | tr ' ' '\n' | sed '/^$/d')
  ((${#ips[@]})) || die "No se detectaron IPs."
  if ((${#ips[@]} == 1)); then echo "${ips[0]}"; return 0; fi
  echo "[!] Varias interfaces:"
  for i in "${!ips[@]}"; do printf "    %d) %s\n" "$((i+1))" "${ips[$i]}"; done
  local choice
  read -r -p "Selecciona [1-${#ips[@]}]: " choice
  is_int "$choice" || die "Selección inválida."
  ((choice >= 1 && choice <= ${#ips[@]})) || die "Fuera de rango."
  echo "${ips[$((choice-1))]}"
}

port_in_use() {
  command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -qE ":$1[[:space:]]"
}

run_server() {
  local port="$1"
  local user="$2"

  # Escribir el servidor Python en un archivo temporal
  local PYFILE
  PYFILE=$(mktemp /tmp/telnet_server_XXXXXX.py)

  cat > "$PYFILE" << PYEOF
import sys
import socket
import threading
import os

PORT = int(sys.argv[1])
SERVER_USER = sys.argv[2]
TTY = sys.argv[3]

clients = []
clients_lock = threading.Lock()

def broadcast(msg, sender=None):
    with clients_lock:
        dead = []
        for c in clients:
            if c is sender:
                continue
            try:
                c.sendall((msg + "\n").encode())
            except:
                dead.append(c)
        for c in dead:
            clients.remove(c)

def handle_client(conn, addr):
    with clients_lock:
        clients.append(conn)
    try:
        buf = b""
        while True:
            data = conn.recv(1024)
            if not data:
                break
            buf += data
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                msg = line.decode(errors="replace").strip()
                if msg:
                    print(msg, flush=True)
                    broadcast(msg, sender=conn)
    except:
        pass
    finally:
        with clients_lock:
            if conn in clients:
                clients.remove(conn)
        conn.close()

def read_server_input(user, tty):
    # Leer desde el TTY directamente para no interferir con heredoc
    with open(tty, "r") as f:
        for line in f:
            line = line.strip()
            if line:
                msg = f"[{user}] {line}"
                print(msg, flush=True)
                broadcast(msg)

srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("0.0.0.0", PORT))
srv.listen(10)

print(f"[*] Servidor escuchando en 0.0.0.0:{PORT}", flush=True)

t = threading.Thread(target=read_server_input, args=(SERVER_USER, TTY), daemon=True)
t.start()

try:
    while True:
        conn, addr = srv.accept()
        print(f"[+] Cliente conectado: {addr[0]}", flush=True)
        threading.Thread(target=handle_client, args=(conn, addr), daemon=True).start()
except KeyboardInterrupt:
    pass

srv.close()
PYEOF

  # Pasar el TTY como argumento para que Python lea desde ahí
  python3 "$PYFILE" "$port" "$user" "$(tty)"
  rm -f "$PYFILE"
}

run_client() {
  local server_ip="$1"
  local port="$2"
  local user="$3"

  # Recibir en background
  ncat "$server_ip" "$port" > /dev/tty &
  RECV_PID=$!

  # Enviar con nombre prefijado
  {
    echo ">>> '$user' SE HA CONECTADO <<<"
    while IFS= read -r line; do
      echo "[$user] $line"
    done
  } | ncat "$server_ip" "$port" 2>/dev/null

  kill $RECV_PID 2>/dev/null
}

main() {
  show_logo
  need_cmd hostname
  need_cmd python3

  local MY_IP
  MY_IP="$(pick_ip)"
  ok "Tu IP: $MY_IP"

  local PORT
  read -r -p "Puerto [ENTER = $DEFAULT_PORT]: " PORT
  PORT="${PORT:-$DEFAULT_PORT}"
  is_int "$PORT" || die "Puerto inválido."
  ((PORT >= 1 && PORT <= 65535)) || die "Puerto fuera de rango."

  echo "---------------------------------"
  echo "1) Hostear (Servidor)"
  echo "2) Unirse  (Cliente)"
  local MODE
  read -r -p "Opción: " MODE
  [[ "$MODE" == "1" || "$MODE" == "2" ]] || die "Opción inválida."

  local USER_NAME
  read -r -p "Nombre de usuario: " USER_NAME
  [[ -n "${USER_NAME// }" ]] || die "Nombre vacío."

  if [[ "$MODE" == "1" ]]; then
    echo
    ok "Modo SERVIDOR — $MY_IP:$PORT"
    port_in_use "$PORT" && die "Puerto $PORT ya en uso."
    echo "---------------------------------"
    echo "Clientes conectan a: $MY_IP:$PORT"
    echo "---------------------------------"
    info "Escribe y pulsa ENTER. Ctrl+C para salir."
    echo
    run_server "$PORT" "$USER_NAME"

  else
    local SERVER_IP
    read -r -p "IP del servidor: " SERVER_IP
    [[ -n "${SERVER_IP// }" ]] || die "IP vacía."
    is_valid_ip "$SERVER_IP" || die "IP inválida: $SERVER_IP"
    echo
    ok "Conectando a $SERVER_IP:$PORT como [$USER_NAME]..."
    echo "---------------------------------"
    info "Escribe y pulsa ENTER. Ctrl+C para salir."
    echo
    run_client "$SERVER_IP" "$PORT" "$USER_NAME"
  fi
}

main "$@"
