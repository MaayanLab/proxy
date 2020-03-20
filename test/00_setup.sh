#!/bin/sh

docker-compose build || exit 1
docker-compose up -d || exit 1
docker-compose logs
