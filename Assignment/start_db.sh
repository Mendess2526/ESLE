#!/bin/sh

/etc/init.d/postgresql start
psql --file ./pagila-schema.sql
psql --file ./pagila-data.sql
read -r
