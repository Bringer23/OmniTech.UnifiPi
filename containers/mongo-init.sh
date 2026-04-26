#!/bin/bash
set -e

mongosh --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin <<EOF
db.getSiblingDB("unifidb").createUser({
  user: "$MONGO_USER",
  pwd: "$MONGO_PASS",
  roles: [
    { role: "dbOwner", db: "unifidb" },
    { role: "dbOwner", db: "unifidb_stat" },
    { role: "dbOwner", db: "unifidb_audit" }
  ]
});
EOF
