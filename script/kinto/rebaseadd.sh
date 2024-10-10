#!/bin/sh

op run --env-file="./.env-kinto-prod" -- ./script/kinto/rebaseadd-cmd.sh
