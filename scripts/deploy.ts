import { ethers } from "hardhat";
import {config as CONFIG} from 'dotenv';
CONFIG();

async function main() {

  const vault:string = process.env.VAULT!;

  const community:string = process.env.COMMUNITY!;

  const token = await ethers.deployContract("EmmetToken", [vault, community]);

  await token.waitForDeployment();

  console.log(`Emmet.Bridge was deployed to ${token.target}`);

  process.exit(0);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
