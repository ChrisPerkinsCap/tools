#!/bin/bash

set -e

## SET UP VARS
J_USER=${1:-admin}
J_PASSWD=${2:-password}
J_HOST=${3:-127.0.0.1}
J_PORT=${4:-8080}

J_FILENAME="plugins-${5:-standard}.txt"

### Generate the plugins.txt file

JENKINS_HOST=${J_USER}:${J_PASSWD}@${J_HOST}:${J_PORT}

echo "${JENKINS_HOST}"

J_PLUGINS=$( curl -sSL "http://$JENKINS_HOST/pluginManager/api/xml?depth=1&xpath=/*/*/shortName|/*/*/version&wrapper=plugins" | \
perl -pe 's/.*?<shortName>([\w-]+).*?<version>([^<]+)()(<\/\w+>)+/\1 \2\n/g'|sed 's/ /:/')

echo "${J_PLUGINS}" > "${J_FILENAME}"

exit 0
