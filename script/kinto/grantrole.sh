#!/bin/sh

op run --env-file="./.env-kinto-prod" -- ./script/kinto/grantrole-cmd.sh
