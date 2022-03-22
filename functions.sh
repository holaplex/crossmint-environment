# functions.sh: -*- Shell-script -*-  DESCRIPTIVE TEXT.
# 
# HOLA-BE - Generic API Server Backend for use in Web2 apps that connect to Web3.
# Derived from EVIXP
#
# EVIXP - Generic API Server Backend for use in health studies.
# Copyright (C) 2019 The EVIXP Authors (See AUTHORS)
# This software is licensed under the GNU Affero General Public License, Version 3.
# Please see the file 'LICENSE' for more detailed information.
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
#  Author: Brian J. Fox (bfox@opuslogica.com)
#  Birthdate: Fri Nov 22 08:51:09 2019.
source ./.env 2>/dev/null

setup-database() {
    database=${database:-postgresql}
    get-database-port
    eval setup-database-$database
}

get-database-port() {
    if [ "$database" = "mysql" ]; then
	app_dbport=${app_dbport:-3306}
    elif [ "$database" = "postgresql" ]; then
	app_dbport=${app_dbport:-5432}
    fi
}

get-database-command() {
    if [ "$database" = "postgresql" ]; then
	echo "psql -p ${app_dbport:-5432}"
    elif [ "$database" = "mysql" ]; then
	if [ "$db_password" = "" ]; then
	    if [ "$db_username" = "" ]; then
		echo "mysql mysql -P ${app_dbport}"
	    else
		echo "mysql mysql -P ${app_dbport} -u ${db_username}"
	    fi
	else
            echo "mysql mysql -P ${app_dbport} -u \"${db_username}\" -p\"${db_password}\""
	fi
    fi
}

setup-database-mysql() {
    app_dbuser="${app_dbuser:-${appname}_user}"
    app_dbpass="${app_dbpass:-${appname}_pass}"
    myapp_dbuser="'${app_dbuser}'@'localhost'"

    $(get-database-command) <<-EOF 2>/dev/null
	CREATE USER IF NOT EXISTS ${myapp_dbuser} identified by '${app_dbpass}';
EOF
    $(get-database-command) <<-EOF
	GRANT ALL PRIVILEGES ON ${appname}.* TO ${myapp_dbuser};
	GRANT ALL PRIVILEGES ON ${appname}_dev.* TO ${myapp_dbuser};
	GRANT ALL PRIVILEGES ON ${appname}_test.* TO ${myapp_dbuser};
EOF
}

setup-database-postgresql() {
    app_dbuser="${app_dbuser:-${appname}_user}"
    app_dbpass="${app_dbpass:-${appname}_pass}"
    db_username="${db_username:-${POSTGRES_USERNAME}}"
    db_password="${db_password:-${POSTGRES_PASSWORD}}"
    db_hostname="${db_hostname:-${RDS_ADDRESS:-localhost}}"

    postgres_url="postgresql://$db_username:$db_password@${db_hostname}:${app_dbport:-5432}/postgres"
    $(get-database-command) "${postgres_url}" <<-EOF #2>/dev/null
	CREATE USER ${app_dbuser} with encrypted password '${app_dbpass}';
	ALTER USER ${app_dbuser} CREATEDB CREATEROLE LOGIN;
EOF
    # In postgresql, the database has to exist before you can grant access to it.
    $(get-database-command) "${postgres_url}" <<-EOF #2>/dev/null
	CREATE DATABASE ${appname};
	CREATE DATABASE ${appname}_dev;
	CREATE DATABASE ${appname}_test;
	ALTER DATABASE ${appname} OWNER TO ${app_dbuser};
	ALTER DATABASE ${appname}_dev OWNER TO ${app_dbuser};
	ALTER DATABASE ${appname}_test OWNER TO ${app_dbuser};
EOF

    $(get-database-command) "${postgres_url}" <<-EOF #2>/dev/null
	GRANT ALL PRIVILEGES ON DATABASE ${appname} TO ${app_dbuser};
	GRANT ALL PRIVILEGES ON DATABASE ${appname}_dev TO ${app_dbuser};
	GRANT ALL PRIVILEGES ON DATABASE ${appname}_test TO ${app_dbuser};
	GRANT CONNECT ON DATABASE postgres TO ${app_dbuser};
EOF
    $(get-database-command) "${postgres_url}" <<-EOF #2>/dev/null
        \\c ${appname}

	CREATE EXTENSION IF NOT EXISTS "pgcrypto";
	CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EOF
}

create-database-config() {
    get-database-port
    if [ "$database" = "postgresql" ];then
	db_gem=pg
	db_adapter=postgresql
	db_scheme=postgresql
    elif [ "$database" = "mysql" ]; then
	db_gem=mysql2
	db_adapter=mysql2
	db_scheme=mysql2
    fi
    
    if [ ! -f config/database.yml ]; then
	app_dbhost="${app_dbhost:-${db_hostname:-${RDS_ADDRESS:-localhost}}}"
	
        cat ./config/database.yml-template |
	    sed -e "s/APPNAME/${appname}/g" -e "s/DB_ADAPTER/${db_adapter}/g" -e "s/DB_SCHEME/${db_scheme}/g" \
		-e "s/APP_DBUSER/${app_dbuser}/g" -e "s/APP_DBPASS/${app_dbpass}/g" \
		-e "s/APP_DBHOST/${app_dbhost:-localhost}/g" -e "s/APP_DBPORT/${app_dbport}/g" \
		> ./config/database.yml
    fi
}

rails-local-db-container() {
    database=postgresql
    app_dbport=7654
    app_dbhost=localhost
    rm -f config/database.yml
    create-database-config
}
