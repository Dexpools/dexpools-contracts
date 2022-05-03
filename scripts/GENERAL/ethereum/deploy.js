const { deployContract } = require("../../shared/helpers")

async function main() {
    // ++++++++++++++++++++++++++++++++ deployment +++++++++++++++++++++++++++++++
    const dxpToken = await deployContract('DexPoolsToken', [])
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
