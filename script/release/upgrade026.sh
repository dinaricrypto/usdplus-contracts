#!/bin/sh

op run --env-file="./.env-sepolia" -- ./script/upgrade026-cmd.sh

op run --env-file="./.env-arbitrum-sepolia" -- ./script/upgrade026-cmd.sh

op run --env-file="./.env-base-sepolia" -- ./script/upgrade026-cmd.sh

op run --env-file="./.env-sandbox" -- ./script/upgrade026-cmd.sh

op run --env-file="./.env-arbitrum" -- ./script/upgrade026-cmd.sh

op run --env-file="./.env-ethereum" -- ./script/upgrade026-cmd.sh

op run --env-file="./.env-base" -- ./script/upgrade026-cmd.sh

op run --env-file="./.env-kinto-prod" -- ./script/upgrade026-kinto-cmd.sh
