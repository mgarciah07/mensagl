#!/bin/bash
apt update
apt install haproxy certbot -y
certbot certonly --standalone --agree-tos --non-interactive -m mgarciah07@educantabria.es -d marcosmatrix.duckdns.org --preferred-challenges http --renew-with-new-domains --keep-until-expiring

# Resultado del certbot al dar el certificado
# Successfully received certificate.
# Certificate is saved at: /etc/letsencrypt/live/marcosmatrix.duckdns.org/fullchain.pem
# Key is saved at:         /etc/letsencrypt/live/marcosmatrix.duckdns.org/privkey.pem
# This certificate expires on 2025-05-11.
# These files will be updated when the certificate renews.
# Certbot has set up a scheduled task to automatically renew this certificate in the background.

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# If you like Certbot, please consider supporting our work by:
#  * Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
#  * Donating to EFF:                    https://eff.org/donate-le
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Configuración de HAProxy
# Combinamos la clave y la llave en una sola para HAProxy
cat /etc/letsencrypt/live/marcosmatrix.duckdns.org/fullchain.pem /etc/letsencrypt/live/marcosmatrix.duckdns.org/privkey.pem | sudo tee /etc/letsencrypt/live/marcosmatrix.duckdns.org/haproxy.pem

# Fichero de configuración de HAProxy /etc/haproxy/haproxy.cfg
cat <<EOF > /etc/haproxy/haproxy.cfg
global
	log /dev/log	local0
	log /dev/log	local1 notice
	chroot /var/lib/haproxy
	stats socket /run/haproxy/admin.sock mode 660 level admin
	stats timeout 30s
	user haproxy
	group haproxy
	daemon

	# Default SSL material locations
	ca-base /etc/ssl/certs
	crt-base /etc/ssl/private

	# See: https://ssl-config.mozilla.org/#server=haproxy&server-version=2.0.3&config=intermediate
        ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
        ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
	log	global
	mode	http
	option	httplog
	option	dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
	errorfile 400 /etc/haproxy/errors/400.http
	errorfile 403 /etc/haproxy/errors/403.http
	errorfile 408 /etc/haproxy/errors/408.http
	errorfile 500 /etc/haproxy/errors/500.http
	errorfile 502 /etc/haproxy/errors/502.http
	errorfile 503 /etc/haproxy/errors/503.http
	errorfile 504 /etc/haproxy/errors/504.http

frontend http_front
    bind *:80
    mode http
    redirect scheme https code 301 if !{ ssl_fc }

frontend https_front
    bind *:443 ssl crt /etc/letsencrypt/live/marcosmatrix.duckdns.org/haproxy.pem
    mode http
    acl letsencrypt-req path_beg /.well-known/acme-challenge/
    use_backend letsencrypt-backend if letsencrypt-req
    default_backend app_back

# frontend matrix_federation
#     bind *:8448 ssl crt /etc/letsencrypt/live/marcosmatrix.duckdns.org/haproxy.pem
#     mode tcp
#     default_backend federation_back

backend app_back
    balance roundrobin
    server server1 10.210.3.20:8008 check
    server server2 10.210.3.21:8008 check

# backend federation_back
#     balance roundrobin
#     server server1 10.210.3.20:8448 check
#     server server2 10.210.3.21:8448 check

backend letsencrypt-backend
    server letsencrypt 127.0.0.1:80 check
EOF