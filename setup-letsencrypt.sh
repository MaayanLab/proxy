#!/usr/bin/env bash

rsa_key_size=4096

if [ -d "/etc/letsencrypt/live/${nginx_server_name}" ]; then

echo "Reusing existing letsencrypt data..." >> $log
nginx -g "daemon off;" &
export NGINX_PID="$!"

else

echo "Setting up letsencrypt..." >> $log

if [ -z "${letsencrypt_staging}" ]; then
  export letsencrypt_staging="0"
fi

mkdir -p /etc/letsencrypt

if [ ! -e /etc/letsencrypt/options-ssl-nginx.conf ] || [ ! -e /etc/letsencrypt/ssl-dhparams.pem ]; then
  echo "Downloading recommended TLS parameters ..." >> $log
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > /etc/letsencrypt/options-ssl-nginx.conf
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > /etc/letsencrypt/ssl-dhparams.pem
fi

echo "Creating dummy certificate for ${nginx_server_name} ..." >> $log
path="/etc/letsencrypt/live/${nginx_server_name}"
mkdir -p "/etc/letsencrypt/live/${nginx_server_name}"
openssl req -x509 -nodes -newkey rsa:${rsa_key_size} -days 1 \
  -keyout "$path/privkey.pem" \
  -out "$path/fullchain.pem" \
  -subj "/CN=localhost"


echo "Starting nginx ..." >> $log
nginx -g "daemon off;" &
export NGINX_PID="$!"

sleep 2
echo "Deleting dummy certificate for ${nginx_server_name} ..." >> $log
rm -Rf /etc/letsencrypt/live/${nginx_server_name}
rm -Rf /etc/letsencrypt/archive/${nginx_server_name}
rm -Rf /etc/letsencrypt/renewal/${nginx_server_name}.conf


echo "Requesting Let's Encrypt certificate for $nginx_server_name ..." >> $log

server_name_args="-d ${nginx_server_name}"

if [ ! -z "${letsencrypt_email}" ]; then
  email_arg="--email ${letsencrypt_email}"
else
  email_arg="--register-unsafely-without-email"
fi

if [ "${letsencrypt_staging}" -ne "0" ]; then
  staging_arg="--staging"
fi

mkdir -p /etc/letsencrypt/certbot
certbot certonly --webroot --webroot-path /etc/letsencrypt/certbot \
  $staging_arg \
  $email_arg \
  $server_name_args \
  --rsa-key-size $rsa_key_size \
  --agree-tos \
  --force-renewal

echo "Reloading nginx ..." >> $log
nginx -s reload

fi
