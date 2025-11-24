#!/bin/bash
set -e

echo "Granting extra privileges to ${MYSQL_USER}..."

mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
  -- allow Rails user to create/drop databases
  GRANT CREATE, DROP ON *.* TO '${MYSQL_USER}'@'%';

  -- give full access to all app databases with this prefix
  -- change 'myapp\_%' to whatever prefix you actually use
  GRANT ALL PRIVILEGES ON \`myapp\_%\`.* TO '${MYSQL_USER}'@'%';

  FLUSH PRIVILEGES;
EOSQL
