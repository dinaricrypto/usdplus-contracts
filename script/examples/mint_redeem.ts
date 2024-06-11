import "dotenv/config";
import fs from 'fs';
import path from 'path';
import { createWalletClient, http, Hex, getContract, formatUnits } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import * as all from 'viem/chains';

const orderProcessorDataPath = path.resolve(__dirname, '../../lib/sbt-deployments/src/v0.4.0/order_processor.json');
const orderProcessorData = JSON.parse(fs.readFileSync(orderProcessorDataPath, 'utf8'));
const orderProcessorAbi = orderProcessorData.abi;

// token abi
const tokenAbi = [
    "function approve(address spender, uint256 value) external returns (bool)",
    "function decimals() external view returns (uint8)",
];

function getChain(chainId: number) {
    for (const chain of Object.values(all)) {
        if (chain.id === chainId) return chain;
    }

    throw new Error("Chain with id ${chainId} not found");
}
