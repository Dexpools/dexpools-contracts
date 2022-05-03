const { deployContract, sendTxn} = require("../../shared/helpers")

async function main() {
    //================== Deploy Process =========================
    const commissionAddress = "0xe34668Be1A8D6Db6143C0DcCC564558bC84DF3e3"
    const dxpOwner = "0xEd8c1D2f12751dB7Ee414DA7f046DFee7A3F2C65"
    const transactionManager = await deployContract('TransactionManager', [])
    await sendTxn(transactionManager.setCommissionAddress(commissionAddress))
    await sendTxn(transactionManager.transferOwnership(dxpOwner), "transferOwnership")
}



main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

