# database Dockerfile creator
FROM mysql:5.7.22
COPY *.sql /tmp/
COPY database_init.sh /docker-entrypoint-initdb.d/
