#!/usr/bin/env bash

uri_parse() {
  sed 's/^\(https\{0,1\}:\/\/\)\([^:/$]\{1,\}\)\(:[0-9]\{1,\}\)\{0,1\}\/\{0,1\}\(.*\)$/\1\2\3 \/\4/'
}

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

  log_format main '\$remote_addr:\$http_x_forwarded_for - \$remote_user [\$time_local] '
                  '"\$request" \$status \$body_bytes_sent "\$http_referer" '
                  '"\$http_user_agent"' ;

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

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log

  server {
    listen          ${nginx_http_port};
    server_name     ${nginx_server_name};

EOF

if [ "${nginx_ssl_letsencrypt}" -eq "1" ]; then

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
    location /.well-known/acme-challenge/ {
        root /etc/letsencrypt/certbot;
    }
EOF

fi

if [ "${nginx_ssl_redirect}" -eq "1" ]; then

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
    location / {
      rewrite ^/(.*)  https://\$host/\$1 permanent;
    }
EOF

fi

if [ "${nginx_ssl}" -eq "1" ]; then

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
  }

  server {
    listen          ${nginx_https_port} ssl;
    server_name     ${nginx_server_name};

    include /etc/letsencrypt/options-ssl-nginx.conf;
EOF

if [ "${nginx_ssl_letsencrypt}" -eq "1" ]; then

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    ssl_certificate ${nginx_ssl_root}/fullchain.pem;
    ssl_certificate_key ${nginx_ssl_root}/privkey.pem;
EOF

else

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
    ssl_certificate ${nginx_ssl_root}/tls.crt;
    ssl_certificate_key ${nginx_ssl_root}/tls.key;
EOF

fi

fi

if [ "${nginx_buffering}" -eq "0" ]; then

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
    charset utf-8;
    proxy_http_version 1.1;
    client_max_body_size 0;
    sendfile on;
    keepalive_timeout  ${nginx_timeout};
    proxy_request_buffering off;
EOF

else

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
    charset utf-8;
    client_max_body_size 20M;
    sendfile on;
    keepalive_timeout  ${nginx_timeout};
    large_client_header_buffers 8 32k;

EOF

fi

if [ "${nginx_basic_auth}" != "" ]; then

mkdir -p /etc/apache2/
echo "${nginx_basic_auth}" | while IFS=":" read user pass; do
  htpasswd -b -c /etc/apache2/.htpasswd "${user}" "${pass}"
done

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
  auth_basic "Authentication required";
  auth_basic_user_file /etc/apache2/.htpasswd;
EOF

fi

# Setup http redirect config
env | sort | grep "^nginx_html_redirect_" | while IFS="=" read key val; do

IFS=" " read path pass <<< "${val}"

mkdir -p /etc/nginx/html/
touch "/etc/nginx/html/${key}.html"

cat << EOF | tee "/etc/nginx/html/${key}.html" >> $log
<!DOCTYPE html>
<html>
   <head>
      <title>HTML Meta Tag</title>
   </head>
   <body>
      <p>This page has moved, you will be redirected momentarily.</p>
      <script>
        window.location.href = (window.location.pathname+'').replace(new RegExp("^${path}\$"), "${pass}");</script>
   </body>
</html>
EOF

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
    location ~ ^${path}$ {
      default_type text/html;
      try_files /${key}.html =404;
    }
EOF

done

# Setup redirect configs
env | sort | grep "^nginx_redirect_" | while IFS="=" read key val; do

IFS=" " read path pass <<< "${val}"

echo ${pass} | grep -q '^/'
if [ "$?" -eq "0" ]; then

pass="\$scheme://\$http_host$pass"

fi

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
    location ~ ^${path}$ {
      add_header 'Access-Control-Allow-Origin' '*';
      add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
      add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range';
      return 307 ${pass};
    }
EOF

done

# Setup proxy configs
env | sort | grep "^nginx_proxy_" | while IFS="=" read key val; do

IFS=" " read path pass <<< "${val}"

echo ${pass} | uri_parse | while IFS=" " read uri_front uri_back; do

cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
    location ~ ^${path}$ {
      rewrite ^${path}$ ${uri_back} break;

      proxy_pass         ${uri_front};
      proxy_set_header   Host \$host;
      proxy_set_header   Connection 'upgrade';
      proxy_set_header   Upgrade \$http_upgrade;
      proxy_set_header   X-Real-IP \$remote_addr;
      proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header   X-Forwarded-Host \$server_name;
      proxy_set_header   X-Forwarded-Proto \$scheme;

      proxy_connect_timeout ${nginx_timeout};
      proxy_send_timeout    ${nginx_timeout};
      proxy_read_timeout    ${nginx_timeout};
      send_timeout          ${nginx_timeout};
    }
EOF

done

done

# Finish config
cat << EOF | tee -a /etc/nginx/nginx.conf >> $log
  }
}
EOF
