#!/bin/sh

op run --env-file="./.env-sepolia" -- ./script/upgrade028-cmd.sh

op run --env-file="./.env-arbitrum-sepolia" -- ./script/upgrade028-cmd.sh

op run --env-file="./.env-base-sepolia" -- ./script/upgrade028-cmd.sh

op run --env-file="./.env-sandbox" -- ./script/upgrade028-cmd.sh

op run --env-file="./.env-arbitrum" -- ./script/upgrade028-cmd.sh

op run --env-file="./.env-ethereum" -- ./script/upgrade028-cmd.sh

op run --env-file="./.env-base" -- ./script/upgrade028-cmd.sh

op run --env-file="./.env-kinto-prod" -- ./script/upgrade028-kinto-cmd.sh
