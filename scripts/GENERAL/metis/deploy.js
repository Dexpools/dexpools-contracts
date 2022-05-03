const { deployContract, } = require("../../shared/helpers")

async function main() {
    const trustedForwarder = "0xaD1628acd4a895efb1Ad94CC4471B3917CF90D91"
    const dexpoolsToken = await deployContract('DexpoolsToken', [trustedForwarder])
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
