#!/bin/sh

op run --env-file="./.env-kinto-prod" -- ./script/kinto/cancelrequest-cmd.sh
