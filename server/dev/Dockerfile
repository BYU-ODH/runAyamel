FROM httpd:latest

ARG sites_available
# Enable mods and include virtual host configuration
RUN sed -i \
        -e 's/^#\(LoadModule socache_shmcb_module modules\/mod_socache_shmcb.so\)/\1/' \
        -e 's/^#\(LoadModule proxy_module modules\/mod_proxy.so\)/\1/' \
        -e 's/^#\(LoadModule proxy_http_module modules\/mod_proxy_http.so\)/\1/' \
        -e 's/^#\(LoadModule rewrite_module modules\/mod_rewrite.so\)/\1/' \
        -e "s/^#\(Include\) conf\/extra\/httpd-vhosts.conf/\1 conf\/extra\/$sites_available\/*.conf/" \
        -e 's/\(ServerAdmin\) you@example.com/\1 santiago_verdu@byu.edu/' \
        conf/httpd.conf

COPY $sites_available /usr/local/apache2/conf/extra/$sites_available
