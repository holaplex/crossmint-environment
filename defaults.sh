# defaults.sh: -*- Shell-script -*-  DESCRIPTIVE TEXT.
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
#  Birthdate: Tue Nov 26 06:57:38 2019.
source ./.env
self=${BASH_SOURCE[0]}
dir=$(dirname $self)
appname=crossmint
database=postgresql
app_dbuser="${APP_DBUSER:-crossmint_user}"
app_dbpass="${APP_DBPASS:-crossmint_pass}"
app_dbhost="${app_dbhost:-${1:-${RDS_ADDRESS:-localhost}}}"
