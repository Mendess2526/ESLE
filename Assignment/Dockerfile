FROM postgres:latest

RUN mkdir -p /docker-entrypoint-initdb.d/

COPY "./pagila.sql" "/docker-entrypoint-initdb.d/"
