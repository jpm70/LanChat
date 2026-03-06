=====================================================
  Lan_Chat — by www.unfantasmaenelsistema.com v1
  Simple TCP LAN Chat
=====================================================

REQUISITOS
----------
- Sistema operativo: Kali Linux / Parrot / Ubuntu / Debian
- Dependencias: ncat, python3
  Instalar con: sudo apt install -y ncat python3

PRIMEROS PASOS
--------------
1. Dale permisos de ejecución al script:

chmod +x lan_chat.sh

2. Ejecútalo:
   
./lan_chat.sh


MODO SERVIDOR (HOST)
--------------------
- Selecciona la opción 1 "Hostear"
- El puerto por defecto es 4444 (pulsa ENTER para usarlo)
- Pon tu nombre de usuario
- El servidor quedará escuchando y mostrará los mensajes
- Los clientes deben conectarse a tu IP y puerto
- Puedes escribir mensajes y se enviarán a todos los clientes


MODO CLIENTE
------------
- Selecciona la opción 2 "Unirse"
- El puerto debe ser el mismo que el del servidor (por defecto 4444)
- Pon tu nombre de usuario
- Introduce la IP del servidor cuando te la pida
- Escribe mensajes y pulsa ENTER para enviar
- Verás los mensajes de los demás en pantalla


ENCONTRAR TU IP
---------------
Ejecuta en la terminal:
   ip a

Busca una línea como:
   inet 192.168.x.x  o  inet 10.0.x.x

Esa es tu IP local. Compártela con los demás para que se conecten.


NOTAS IMPORTANTES
-----------------
- El servidor y los clientes deben estar en la MISMA red local (LAN)
- El puerto 4444 debe estar libre (no usado por otra app)
- Si el firewall bloquea la conexión:
    sudo ufw allow 4444/tcp
- Para salir: Ctrl+C


EJEMPLO DE USO
--------------
Equipo A (servidor):
  ./lan_chat.sh → opción 1 → puerto 4444 → usuario: servidor

Equipo B (cliente):
  ./lan_chat.sh → opción 2 → puerto 4444 → usuario: cliente1 → IP: 192.168.1.100

Equipo C (cliente):
  ./lan_chat.sh → opción 2 → puerto 4444 → usuario: cliente2 → IP: 192.168.1.100

=====================================================
