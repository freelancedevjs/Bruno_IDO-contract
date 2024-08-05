import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {ethers, upgrades} from "hardhat";
import { PoolFactory__factory } from '../typechain-types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, getNamedAccounts} = hre;
    const {deploy, get, save} = deployments;
    const useProxy = !hre.network.live;

    const {deployer} = await getNamedAccounts();

    const master = await get("Pool");

    const deployment = await deploy('PoolFactory', {
        from: deployer,
        args: [],
        log: true,
        gasLimit: 996189,
        // skipIfAlreadyDeployed: true,
        proxy: {
            proxyContract: "OptimizedTransparentProxy",
            execute: {
                init: {
                    methodName: "initialize",
                    args: [
                        master.address,
                        1,
                    ],
                },
            }
        },
    });

    let tx;

    const PoolFactory = new PoolFactory__factory(await ethers.getSigner(deployer));
    let factory = PoolFactory.attach(deployment.address);
    const owner = await factory.owner();
    const masterC = await factory.master();
    console.log('MASTER', masterC, master.address, owner)
    if(masterC !== master.address) {
        tx = await factory.setMasterAddress(master.address, {
            from: deployer,
        });
        await tx.wait();
    }

    const poolOwner = await factory.poolOwner();
    console.log('poolOwner', poolOwner, deployment.address, await factory.master())
    if (poolOwner !== deployment.address) {
        tx = await factory.setPoolOwner(deployment.address, {
            from: deployer,
        });
        await tx.wait();
    }
    const adminOwner = await factory.feeWallet();
    if (adminOwner !== "0xC755562543fb48683e51978C583485512528723A") {
        tx = await factory.setFeeWallet("0x45E94DF9Af3F81EbcAEcb230a3b575bF75E0aEB4", {
            from: deployer,
            // gasLimit: 35705,
        });
        await tx.wait();
    }
    tx = await factory.addMultiAdmins(["0x0fC392eD64a6f41B45B992099C501D6C2CEF5e06","0xDa9228849a76D56F2197E903131400ae1C0d6C13"], {
        from: deployer,
        // gasLimit: 35705,
    })
    await tx.wait();
    // return !useProxy;
};
export default func;
func.tags = ['PoolFactory'];
