#!/bin/bash

rootpassword="$(cat $MYSQL_ROOT_PASSWORD_FILE)"
userpassword="$(cat $MYSQL_PASSWORD_FILE)"

if [[ -z "$rootpassword" ]]; then
    echo "MYSQL_ROOT_PASSWORD_FILE var does not exist"
    if [[ -f /run/secrets/mysql_root_password ]]; then
        rootpassword="$(cat /run/secrets/mysql_root_password)"
    elif [[ -n "$MYSQL_ROOT_PASSWORD" ]]; then
        rootpassword="$MYSQL_ROOT_PASSWORD"
    else
        echo "mysql root password not set"
        exit 1
    fi
fi

if [[ -z "$userpassword" ]]; then
    echo "MYSQL_PASSWORD_FILE var does not exist"
    if [[ -f /run/secrets/mysql_password ]]; then
        userpassword="$(cat /run/secrets/mysql_password)"
    elif [[ -n "$MYSQL_PASSWORD" ]]; then
        userpassword="$MYSQL_PASSWORD"
    else
        echo "mysql password not set"
        exit 1
    fi
fi

databases=$(mysql -uroot -p$rootpassword -se "show databases")
mysql -uroot -p$rootpassword -e "CREATE USER IF NOT EXISTS \"$MYSQL_USER\"@'%' IDENTIFIED BY \"$userpassword\"";

for file in $(ls /tmp/*.sql 2>/dev/null); do
    filename=$(basename $file)
    if [[ -n $( printf '%s\n' "${databases[@]}" | grep -e "^${filename%.*}$" ) ]]; then
        echo "Database already exists: $file"
        continue
    fi
    mysql -uroot -p$rootpassword -e "create database ${filename%.*}"
    mysql -uroot -p$rootpassword "${filename%.*}" < "$file"
    mysql -uroot -p$rootpassword -e "GRANT ALL PRIVILEGES ON ${filename%.*}.* To \"$MYSQL_USER\"@'%'";
    echo "Added database: $file."
done

