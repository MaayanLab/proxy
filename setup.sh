#!/usr/bin/env bash

log=/error.log

if [ -z "${nginx_server_name}" ]; then
  export nginx_server_name="localhost"
fi

if [ -z "${nginx_http_port}" ]; then
  export nginx_http_port="80"
fi

if [ -z "${nginx_https_port}" ]; then
  export nginx_https_port="443"
fi

if [ -z "${nginx_ssl}" ]; then
  export nginx_ssl="0"
elif [ "${nginx_ssl}" -eq "1" ]; then
  if [ -z "${nginx_ssl_root}" ]; then
    if [ -z "${nginx_ssl_crt}" -a -z "${nginx_ssl_key}" ]; then
      echo "ERROR: `nginx_ssl_root` or `nginx_ssl_{crt,key}` must exist if `nginx_ssl` -eq 1 "
      exit 1
    fi
  fi

  if [ ! -z "${nginx_ssl_crt}" -a ! -z "${nginx_ssl_crt}" ]; then
    export nginx_ssl_root=/ssl
    mkdir -p "${nginx_ssl_root}"
    echo "${nginx_ssl_crt}" | sed -e 's/;/\n/g' | tee "${nginx_ssl_root}/tls.crt"
    echo "${nginx_ssl_key}" | sed -e 's/;/\n/g' | tee "${nginx_ssl_root}/tls.key"
  fi

  if [ ! -f "${nginx_ssl_root}/tls.key" ]; then
    echo "ERROR: `${nginx_ssl_root}/tls.key` must exist"
    exit 1
  elif [ ! -f "${nginx_ssl_root}/tls.crt" ]; then
    echo "ERROR: `${nginx_ssl_root}/tls.crt` must exist"
    exit 1
  fi
fi

if [ -z "${nginx_gzip}" ]; then
  export nginx_gzip="1"
fi

setup() {

# Setup base config
cat << EOF | tee /etc/nginx/nginx.conf >> $log
user  nginx;
worker_processes  1;

events {
  worker_connections  1024;
}

http {
  include       /etc/nginx/mime.types;
  default_type  application/octet-stream;

  access_log $log;
  error_log $log;

EOF

if [ "${nginx_gzip}" -ne "0" ]; then

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log

  gzip              on;
  gzip_http_version 1.0;
  gzip_proxied      any;
  gzip_min_length   500;
  gzip_disable      "MSIE [1-6]\.";
  gzip_types        text/plain text/xml text/css
                    text/comma-separated-values
                    text/javascript
                    application/x-javascript
                    application/atom+xml;

EOF

fi

if [ "${nginx_ssl}" -eq "1" ]; then

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
  server {
    listen          ${nginx_http_port};
    server_name     ${nginx_server_name};
    rewrite ^/(.*)  https://\$host/\$1 permanent;
  }

  server {
    listen          ${nginx_https_port} ssl;
    server_name     ${nginx_server_name};

    ssl_certificate ${nginx_ssl_root}/tls.crt;
    ssl_certificate_key ${nginx_ssl_root}/tls.key;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';

EOF

else

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
  server {
    listen          ${nginx_http_port};
    server_name     ${nginx_server_name};

EOF

fi

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
    charset utf-8;
    client_max_body_size 20M;
    sendfile on;
    keepalive_timeout  65;
    large_client_header_buffers 8 32k;

EOF

# Setup redirect configs
env | sort | grep "^nginx_redirect_" | while IFS="=" read key val; do

IFS=" " read path pass <<< "${val}"

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
    location ~ ^${path}$ {
      rewrite ^${path}$ ${pass};
      return 302;
    }
EOF

done

# Setup proxy configs
env | sort | grep "^nginx_proxy_" | while IFS="=" read key val; do

IFS=" " read path pass <<< "${val}"

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
    location ${path} {
      proxy_pass         ${pass};
      proxy_set_header   Host \$host;
      proxy_set_header   X-Real-IP \$remote_addr;
      proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header   X-Forwarded-Host \$server_name;
    }
EOF

done

# Finish config
cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
  }
}
EOF

}


if [ -f $log ]; then
  rm $log
fi

touch $log
tail -f $log &
setup && exec "$@"
