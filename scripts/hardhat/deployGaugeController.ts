import { ethers } from "hardhat";
import readline from "readline";

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

const promptUser = (question: string) => {
  return new Promise((resolve, reject) => {
    rl.question(question, function (answer: string) {
      resolve(answer);
    });
  });
};

async function main() {
  console.log("Starting deploys....");
  
  // TODO: move this to hardhat tasks
  // https://ethereum.stackexchange.com/questions/114730/pass-command-line-args-to-scripts-run-by-hardhat-run-command
  const tokenAddr = await promptUser("Input address for the deployed token contract: ")
  const voteEscrowAddr = await promptUser("Input address for the deployed vote escrow contract: ")
  
  const GaugeController = await ethers.getContractFactory("GaugeController");
  const gaugeController = await GaugeController.deploy(tokenAddr, voteEscrowAddr);
  await gaugeController.deployed();

  console.log("GaugeController deployed to:", gaugeController.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
