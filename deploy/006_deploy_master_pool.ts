import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {parseEther} from 'ethers/lib/utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, getNamedAccounts} = hre;
    const {deploy} = deployments;

    const {deployer} = await getNamedAccounts();

    await deploy('Pool', {
        from: deployer,
        args: [],
        log: true,
        gasLimit: 5468620,
        // skipIfAlreadyDeployed: true,
    });
};
export default func;
func.tags = ['Pool'];
