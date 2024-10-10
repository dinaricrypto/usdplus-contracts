#!/bin/sh

op run --env-file="./.env-kinto-prod" -- ./script/kinto/rebasesub-cmd.sh
