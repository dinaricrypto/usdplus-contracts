#!/bin/sh

op run --env-file="./.env-sepolia" -- ./script/upgrade029-cmd.sh

op run --env-file="./.env-arbitrum-sepolia" -- ./script/upgrade029-cmd.sh

op run --env-file="./.env-base-sepolia" -- ./script/upgrade029-cmd.sh

op run --env-file="./.env-sandbox" -- ./script/upgrade029-cmd.sh

op run --env-file="./.env-arbitrum" -- ./script/upgrade029-cmd.sh

op run --env-file="./.env-ethereum" -- ./script/upgrade029-cmd.sh

op run --env-file="./.env-base" -- ./script/upgrade029-cmd.sh

op run --env-file="./.env-kinto-prod" -- ./script/upgrade029-orbit-cmd.sh
