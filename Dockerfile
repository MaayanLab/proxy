FROM nginx

RUN set -x \
  && apt-get -y update \
  && apt-get -y install certbot curl \
  && rm -rf /var/lib/apt/lists/*

RUN rm /etc/nginx/nginx.conf
ADD ./setup.sh /setup.sh
ADD ./setup-nginx.sh /setup-nginx.sh
ADD ./setup-letsencrypt.sh /setup-letsencrypt.sh
RUN chmod +x /setup.sh /setup-nginx.sh /setup-letsencrypt.sh

ENTRYPOINT [ "/bin/bash", "/setup.sh" ]
CMD [ "nginx", "-g", "daemon off;" ]
