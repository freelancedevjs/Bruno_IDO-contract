import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {parseEther} from 'ethers/lib/utils';
const { ethers, upgrades } = require("hardhat");

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, getNamedAccounts} = hre;
    const {deploy,save} = deployments;
    const useProxy = !hre.network.live;

    const {deployer} = await getNamedAccounts();

    if(useProxy) {
        await deploy('BaseERC20', {
            from: deployer,
            args: ["test","test",7],
            log: true,
            // skipIfAlreadyDeployed: true,
        });
    }
    // return !useProxy;
};
export default func;
func.tags = ['BaseERC20'];
