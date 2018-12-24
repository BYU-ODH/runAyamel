FROM httpd:latest

COPY httpd.conf /usr/local/apache2/conf/
COPY $sites_available /usr/local/apache2/conf/extra/$sites_available
COPY *.key /user/local/apache2/conf/
COPY *.crt /user/local/apache2/conf/

ADD production /usr/local/apache2/htdocs/production
ADD beta /usr/local/apache2/htdocs/beta
