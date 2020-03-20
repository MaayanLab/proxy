# proxy

`docker pull maayanlab/proxy`

A convenient and generic proxy image. It's useful for exposing multiple microservices on a single ingress and easily configurable via environment variables.

See docker-compose for more configuration information.

## Tutorial
I've extended this overtime to assist with different use-cases but the general idea is enabling hassle-free http proxying.

I.e. Consider an application with 2 backends (`/frontend`, `/api/v1`), a legacy redirect (`/api` => `/api/v1`), and a [fuzzy-proxy](https://github.com/maayanlab/fuzzy-proxy) fallback.
```yaml
version: '3'
services:
  proxy:
    image: maayanlab/proxy
    environment:
      - nginx_redirect_01=/api/(.*) /api/v1/$$1
      - nginx_proxy_02=/api/v1/(.*) http://api/$$1
      - nginx_proxy_03=/frontend/(.*) http://frontend/$$1
      - nginx_proxy_04=(.*) http://fuzzy-proxy/$$1
    port:
      - 80:80
  api:
    ...
  frontend:
    ...
  fuzzy-proxy:
    ...
```

We can expose our multi-container application at one place with the help of this proxy.

## Testing
To run the tests execute:
```sh
sh test.sh
```
