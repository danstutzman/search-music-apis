#!/bin/bash

/Applications/Postgres.app/Contents/MacOS/bin/pg_dump -U postgres postgres -t api_queries > api_queries.sql
