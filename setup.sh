#!/usr/bin/env bash

export log=/log.fifo

if [ -z "${nginx_server_name}" ]; then
  export nginx_server_name="localhost"
fi

if [ -z "${nginx_http_port}" ]; then
  export nginx_http_port="80"
fi

if [ -z "${nginx_https_port}" ]; then
  export nginx_https_port="443"
fi

if [ -z "${nginx_timeout}" ]; then
  export nginx_timeout="60"
fi

if [ -z "${nginx_ssl}" ]; then
  export nginx_ssl="0"
elif [ "${nginx_ssl}" -eq "1" ]; then
  if [ "${nginx_ssl_letsencrypt}" -eq "1" ]; then
    export nginx_ssl_root="/etc/letsencrypt/live/${nginx_server_name}"
  else
    if [ -z "${nginx_ssl_root}" ]; then
      if [ -z "${nginx_ssl_crt}" -a -z "${nginx_ssl_key}" ]; then
        echo "ERROR: `nginx_ssl_root` or `nginx_ssl_{crt,key}` must exist if `nginx_ssl` -eq 1 "
        exit 1
      fi
    fi

    if [ ! -z "${nginx_ssl_crt}" -a ! -z "${nginx_ssl_key}" ]; then
      export nginx_ssl_root=/ssl
      mkdir -p "${nginx_ssl_root}"
      echo "${nginx_ssl_crt}" | sed -e 's/;/\n/g' | tee "${nginx_ssl_root}/tls.crt"
      echo "${nginx_ssl_key}" | sed -e 's/;/\n/g' | tee "${nginx_ssl_root}/tls.key"
    fi

    if [ ! -f "${nginx_ssl_root}/tls.key" ]; then
      echo "ERROR: ${nginx_ssl_root}/tls.key must exist"
      exit 1
    elif [ ! -f "${nginx_ssl_root}/tls.crt" ]; then
      echo "ERROR: ${nginx_ssl_root}/tls.crt must exist"
      exit 1
    fi
  fi
fi

if [ -z "${nginx_ssl_redirect}" ]; then
  export nginx_ssl_redirect="${nginx_ssl}"
fi

if [ -z "${nginx_gzip}" ]; then
  export nginx_gzip="1"
fi

if [ -z "${nginx_buffering}" ]; then
  export nginx_buffering="1"
fi

###

if [ -e $log ]; then
  rm $log
fi

mkfifo $log
tail -f $log &

source ./setup-nginx.sh
ret="$?"
if [ "${ret}" -ne "0" ]; then
  exit ${ret}
fi

if [ "${nginx_ssl_letsencrypt}" -eq "1" -a "$1" == "nginx" ]; then
  source ./setup-letsencrypt.sh
  ret="$?"
  if [ "${ret}" -ne "0" ]; then
    exit ${ret}
  fi
  echo "Starting letsencrypt renew loop..."
  trap exit TERM
  while :; do
    certbot renew
    nginx -s reload
    sleep 12h
  done &
  wait ${NGINX_PID}
elif [ "${nginx_ssl_letsencrypt}" -eq "1" ]; then
  echo "Warning: letsencrypt not setup"
  exec "$@"
else
  exec "$@"
fi
