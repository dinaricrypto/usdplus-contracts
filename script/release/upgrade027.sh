#!/bin/sh

op run --env-file="./.env-sepolia" -- ./script/upgrade027-cmd.sh

op run --env-file="./.env-arbitrum-sepolia" -- ./script/upgrade027-cmd.sh

op run --env-file="./.env-base-sepolia" -- ./script/upgrade027-cmd.sh

op run --env-file="./.env-sandbox" -- ./script/upgrade027-cmd.sh

op run --env-file="./.env-arbitrum" -- ./script/upgrade027-cmd.sh

op run --env-file="./.env-ethereum" -- ./script/upgrade027-cmd.sh

op run --env-file="./.env-base" -- ./script/upgrade027-cmd.sh

op run --env-file="./.env-kinto-prod" -- ./script/upgrade027-kinto-cmd.sh
