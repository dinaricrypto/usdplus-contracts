import "dotenv/config";
import fs from 'fs';
import path from 'path';
import { parseAbi, createPublicClient, createWalletClient, publicActions, http, Hex, getContract, encodeEventTopics, parseEventLogs, decodeEventLog, formatUnits } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import * as chains from 'viem/chains';

const usdplusDataPath = path.resolve(__dirname, '../../lib/usdplus-deployments/src/v0.2.0/usdplus.json');
const usdplusData = JSON.parse(fs.readFileSync(usdplusDataPath, 'utf8'));
const usdplusAbi = usdplusData.abi;
const minterDataPath = path.resolve(__dirname, '../../lib/usdplus-deployments/src/v0.2.0/usdplusminter.json');
const minterData = JSON.parse(fs.readFileSync(minterDataPath, 'utf8'));
const minterAbi = minterData.abi;
const redeemerDataPath = path.resolve(__dirname, '../../lib/usdplus-deployments/src/v0.2.0/usdplusredeemer.json');
const redeemerData = JSON.parse(fs.readFileSync(redeemerDataPath, 'utf8'));
const redeemerAbi = redeemerData.abi;

// token abi
const tokenAbi = parseAbi([
    "function approve(address spender, uint256 value) external returns (bool)",
    "function decimals() external view returns (uint8)",
]);

function getChain(chainId: number) {
    for (const chain of Object.values(chains)) {
        if (chain.id === chainId) return chain;
    }

    throw new Error("Chain with id ${chainId} not found");
}

async function main() {

    // ------------------ Setup ------------------

    // setup values
    const privateKey = process.env.PRIVATE_KEY as Hex;
    if (!privateKey) throw new Error("empty key");
    const CHAINID_STR = process.env.CHAINID;
    if (!CHAINID_STR) throw new Error("empty chain id");
    const chainId = parseInt(CHAINID_STR);
    const RPC_URL = process.env.RPC_URL;
    if (!RPC_URL) throw new Error("empty rpc url");

    const usdcAddress = process.env.USDC as Hex;
    if (!usdcAddress) throw new Error("empty usdc address");

    // setup provider and signer
    const chain = getChain(chainId);
    const publicClient = createPublicClient({
        chain: chain,
        transport: http(RPC_URL)
    });
    const account = privateKeyToAccount(privateKey);
    console.log(`Account: ${account.address}`);
    const client = createWalletClient({ 
        account,
        chain: chain, 
        transport: http(RPC_URL)
      }).extend(publicActions);
    const usdplusAddress = usdplusData.networkAddresses[chainId];
    console.log(`USD+ Address: ${usdplusAddress}`);
    const minterAddress = minterData.networkAddresses[chainId];
    console.log(`Minter Address: ${minterAddress}`);
    const redeemerAddress = redeemerData.networkAddresses[chainId];
    console.log(`Redeemer Address: ${redeemerAddress}`);

    // connect to USD+ contract
    const usdplus = getContract({
        address: usdplusAddress,
        abi: usdplusAbi,
        client
    });

    // connect to USD+ Minter contract
    const minter = getContract({
        address: minterAddress,
        abi: minterAbi,
        client
    });

    // connect to USD+ Redeemer contract
    const redeemer = getContract({
        address: redeemerAddress,
        abi: redeemerAbi,
        client
    });

    // usdc token contract
    const usdc = getContract({
        address: usdcAddress,
        abi: tokenAbi,
        client
    });

    // mint amount
    const usdcDecimals = await publicClient.readContract({
        address: usdcAddress,
        abi: tokenAbi,
        functionName: 'decimals',
    })
    // const usdcDecimals = await usdc.read.decimals();
    const usdcAmount = 1 * 10 ** usdcDecimals as unknown as bigint; // 1 USDC

    // ------------------ Mint ------------------

    // approve USDC
    const usdcApproveTx = await usdc.write.approve([minterAddress, usdcAmount]);
    console.log(`Approve USDC tx hash: ${usdcApproveTx}`);

    // mint USD+
    const mintTx = await minter.write.deposit([usdc, usdcAmount, account.address]);
    console.log(`Mint USD+ tx hash: ${mintTx}`);

    // get USD+ amount from event
    const mintTxReceipt = await publicClient.waitForTransactionReceipt({ hash: mintTx});
    // const mintLogs =  parseEventLogs({ abi: minterAbi, eventName: 'Issued', logs: mintTxReceipt.logs });
    // const mintLog = decodeEventLog({ abi: minterAbi, data: mintLogs[0].data, topics: mintLogs[0].topics });
    const issuedTopic = encodeEventTopics({ abi: minterAbi, eventName: 'Issued' })[0];
    const mintLog = mintTxReceipt.logs.filter(log => log.topics[0] === issuedTopic)[0];
    const usdplusAmount = (decodeEventLog({ abi: minterAbi, data: mintLog.data, topics: mintLog.topics }) as any).usdPlusAmount;
    console.log(`Minted USD+: ${formatUnits(usdplusAmount, 6)}`);

    // ------------------ Redeem ------------------

    // redeem USD+
    // const redeemTx = await redeemer.write.redeem(amount);
    // console.log(`Redeem USD+ tx hash: ${redeemTx.hash}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
