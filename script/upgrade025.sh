#!/bin/sh

op run --env-file="./.env-sepolia" -- ./script/upgrade025-cmd.sh

op run --env-file="./.env-arbitrum-sepolia" -- ./script/upgrade025-cmd.sh

op run --env-file="./.env-base-sepolia" -- ./script/upgrade025-cmd.sh

op run --env-file="./.env-sandbox" -- ./script/upgrade025-cmd.sh

op run --env-file="./.env-arbitrum" -- ./script/upgrade025-cmd.sh

op run --env-file="./.env-ethereum" -- ./script/upgrade025-cmd.sh

op run --env-file="./.env-base" -- ./script/upgrade025-cmd.sh

op run --env-file="./.env-kinto-prod" -- ./script/upgrade025-kinto-cmd.sh
