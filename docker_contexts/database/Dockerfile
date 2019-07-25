FROM mysql:5.7.24

RUN echo '\n[client]\ndefault-character-set = utf8mb4\n\n[mysqld]\ncharacter-set-server = utf8mb4\ncollation-server = utf8mb4_unicode_ci\n\n[mysql]\ndefault-character-set = utf8mb4' >> /etc/mysql/my.cnf

COPY *.sql /tmp/
COPY database_init.sh /docker-entrypoint-initdb.d/
