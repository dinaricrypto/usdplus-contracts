#!/bin/sh

op run --env-file="./.env-kinto-prod" -- ./script/kinto/burnrequest-cmd.sh
