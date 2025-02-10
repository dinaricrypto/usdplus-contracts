import { Command } from "commander";

const program = new Command();

program
  .name("scripts")
  .description("Complementary CLI for smart contract deployment");


program.command("combine").action(function() {
  console.log("this should do something :)");
})

async function main() {
  await program.parseAsync();
}

main();
