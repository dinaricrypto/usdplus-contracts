import { createPublicClient, http } from 'viem';
import {arbitrum} from 'viem/chains';

const publicClient = createPublicClient({
    chain: arbitrum,
    transport: http()
});


async function main() {

    const blockNumber = await publicClient.getBlockNumber();
    console.log(`Block number: ${blockNumber}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
