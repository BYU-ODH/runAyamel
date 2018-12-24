FROM httpd:latest

# Only copy the ssl keys if they exist
COPY httpd.conf server.cr[t] server.ke[y] ca.cr[t] /usr/local/apache2/conf/
# Copy apache/site configuration
COPY $sites_available /usr/local/apache2/conf/extra/$sites_available

ADD production /usr/local/apache2/htdocs/production
ADD beta /usr/local/apache2/htdocs/beta

