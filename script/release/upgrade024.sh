#!/bin/sh

op run --env-file="./.env-sepolia" -- ./script/upgrade024-cmd.sh

op run --env-file="./.env-arbitrum-sepolia" -- ./script/upgrade024-cmd.sh

op run --env-file="./.env-base-sepolia" -- ./script/upgrade024-cmd.sh

op run --env-file="./.env-sandbox" -- ./script/upgrade024-cmd.sh

op run --env-file="./.env-arbitrum" -- ./script/upgrade024-cmd.sh

op run --env-file="./.env-ethereum" -- ./script/upgrade024-cmd.sh

op run --env-file="./.env-base" -- ./script/upgrade024-cmd.sh

op run --env-file="./.env-kinto-prod" -- ./script/upgrade024-cmd.sh
