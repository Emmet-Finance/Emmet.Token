import {ethers} from 'ethers';
import {config as CONFIG} from 'dotenv';
import { log } from 'console';
CONFIG();

const phrase = process.env.SEED!

const mnemonic = ethers.Mnemonic.fromPhrase(phrase)

const SK = ethers.HDNodeWallet.fromMnemonic(mnemonic);
log("Secret Key:", SK.privateKey);
log("Public Key:", SK.address)
log("Full Account", SK)