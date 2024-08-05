import {ethers, deployments, getUnnamedAccounts, getNamedAccounts} from 'hardhat';
import {
    BaseERC20, PoolFactory
} from '../typechain-types';
import {setupUsers} from './utils';
import {expect} from "chai";
import moment from "moment";
import {parseUnits} from "ethers/lib/utils";

//24cdf510
const setup = deployments.createFixture(async () => {
    const {PoolFactory, BaseERC20} = await deployments.fixture(["BaseERC20",'PoolFactory','Pool']);
    const contracts = {
        BaseERC20: <BaseERC20>(
            await ethers.getContractAt('BaseERC20', BaseERC20.address)
        ),
        PoolFactory: <PoolFactory>(
            await ethers.getContractAt('PoolFactory', PoolFactory.address)
        ),
    };
    const {deployer} = await getNamedAccounts();
    const users = await setupUsers([deployer], contracts);
    const decimals = await contracts.BaseERC20.decimals();
    await users[0].BaseERC20.increaseAllowance(users[0].PoolFactory.address, "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
    return {
        ...contracts,
        users,
        createSale: () => {
            const now = Date.now();
            return users[0].PoolFactory.createSale({
                emergencyWithdrawFees: 0,
                max_payment: Math.pow(10, 18).toString(),
                min_payment: (0.5 * Math.pow(10, 18)).toString(),
                nftAddress: '0x0000000000000000000000000000000000000000',
                payment_currency: '0x0000000000000000000000000000000000000000',
                salt: 1,
                publicStartTime: 0,
                tier1: {startTime: 0, endTime: 0},
                useWhitelist: false,
                cycle: "0",
                cycleBps: "0",
                endTime: now + 20000,
                governance: "0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82",
                hardCap: Math.pow(10, 18).toString(),
                rate: (10 * Math.pow(10, decimals)).toString(),
                softCap: (0.5 * Math.pow(10, 18)).toString(),
                startTime: now,
                tgeBps: "0"
            }, {value: "50000000000000000"})
        },
    };
});
describe('PoolFactory', function () {
    it('Create Sale', async function () {
        const {users, PoolFactory, createSale} = await setup();
        await expect(createSale())
            .to.emit(PoolFactory, 'PresalePoolCreated')
        ;
    });

    it('Create Sale Event', async function () {
        const {users, PoolFactory, createSale} = await setup();
        const sale = await createSale();
        const logs = await sale.wait();
        expect(!!logs.events?.find(event => {
            return event.topics.includes("0x11e1cae4d6b878316ebb48234cb6055d89bbd4656152049cd8881c3c2b4de791")
        })).to.be.false;
    });

    it('Should be admin one create sale and admin two cancel sale ',async ()=>{

        const {users, PoolFactory, createSale} = await setup();

        const address = await getUnnamedAccounts()
        const user =  await ethers.getSigner(address[3])

        await PoolFactory.addAdmin(address[3]);

        const sale = await createSale();
        const logs = await sale.wait();
        let poolAddress
        if(logs.events){
            for (const event of logs.events) {
                if (event.event ==='PresalePoolCreated' && event?.args) {
                    poolAddress = event.args[0];
                }
              }
        }

        const pool = await ethers.getContractAt('Pool', poolAddress)

        expect(await pool.poolState()).to.be.equal(0);

        await pool.connect(user).cancel()

        expect(await pool.poolState()).to.be.equal(2);

    })

    it("should create only admin", async() => {

        const {PoolFactory, BaseERC20} = await deployments.fixture(["BaseERC20",'PoolFactory','Pool']);

        const fakeDeployer = await getUnnamedAccounts()
        const contracts = {
            BaseERC20: <BaseERC20>(
                await ethers.getContractAt('BaseERC20', BaseERC20.address)
            ),
            PoolFactory: <PoolFactory>(
                await ethers.getContractAt('PoolFactory', PoolFactory.address)
            ),
        };
        const decimals = await contracts.BaseERC20.decimals();


        const now = Date.now();
        const users = await setupUsers([fakeDeployer[0]], contracts);

        await expect(users[0].PoolFactory.createSale({
            emergencyWithdrawFees: 0,
            max_payment: Math.pow(10, 18).toString(),
            min_payment: (0.5 * Math.pow(10, 18)).toString(),
            nftAddress: '0x0000000000000000000000000000000000000000',
            payment_currency: '0x0000000000000000000000000000000000000000',
            salt: 1,
            publicStartTime: 0,
            tier1: {startTime: 0, endTime: 0},
            useWhitelist: false,
            cycle: "0",
            cycleBps: "0",
            endTime: now + 20000,
            governance: "0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82",
            hardCap: Math.pow(10, 18).toString(),
            rate: (10 * Math.pow(10, decimals)).toString(),
            softCap: (0.5 * Math.pow(10, 18)).toString(),
            startTime: now,
            tgeBps: "0"
        })
        ).to.be.revertedWith('Ownable: caller is not the admin')

    })

    it('Contribute', async function () {
        const {users, PoolFactory, createSale} = await setup();
        const sale = await createSale();
        const logs = await sale.wait();
       const address = logs.events?.find(event => {
           return event.topics.includes("0x11e1cae4d6b878316ebb48234cb6055d89bbd4656152049cd8881c3c2b4de791")
       });
       if(!address) return;
       const pool = await ethers.getContractAt('CirclePresalePool', address?.address)
        const tx = await pool.contribute(((0.01) * Math.pow(10,18)).toString());
       await tx.wait();
    });
});
