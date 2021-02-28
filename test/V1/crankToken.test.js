const CrankCoin = artifacts.require('CrankCoin');
const { expectEvent } = require("@openzeppelin/test-helpers");
const { ZERO_ADDRESS } = require("@openzeppelin/test-helpers/src/constants");
const ether = require("@openzeppelin/test-helpers/src/ether");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");
const { assert, expect } = require("chai");


const _data = [{ address: "", value: "" }];

contract("CrankCoin", async ([deployer, user1, user2]) => {
    beforeEach(async () => {
        this.token = await CrankCoin.new({ from: deployer });

        _data[0].address = web3.utils.toChecksumAddress(user1);
        _data[0].value = web3.utils.toWei("2", "ether");
    })

    describe("deployment", () => {
        it("should deploy token properly", async () => {
            assert.notEqual(this.token.address, null);
            assert.notEqual(this.token.address, undefined);
            assert.notEqual(this.token.address, "");
        });

        it("should set token name properly", async () => {
            const name = await this.token.name();
            assert.equal(name, "CrankCoin");
        });

        it("should set token symbol properly", async () => {
            const symbol = await this.token.symbol();
            assert.equal(symbol, "CKN");
        });

        it("should return token decimal", async () => {
            const decimals = await this.token.decimals();
            assert.equal(decimals, "18");
        })

        it("should return total supply", async () => {
            const totalSupply = await this.token.totalSupply();
            assert.equal(totalSupply, web3.utils.toWei("10000"));
        })

        it("should set token decimal properly", async () => {
            const decimals = await this.token.decimals();
            assert.equal(decimals, "18");
        })

        it("should mint new tokens on deployment", async () => {
            const totalSupply = await this.token.totalSupply();
            const ownerBalance = await this.token.balanceOf(deployer);
            assert.equal(totalSupply.toString(),ownerBalance.toString());
        })
    })

    describe("Approval", () => {
        let reciept;
        let _amount;
        beforeEach(async () => {
            _amount = web3.utils.toWei("100");
            reciept = await this.token.approve(user1, _amount, { from: deployer });
        })

        it("should approve token properly", async () => {
            const allowance = await this.token.allowance(deployer, user1);
            assert.equal(allowance, _amount);
        })

        it("should emit approval event", async () => {
            expectEvent(reciept, "Approval", {
                owner: deployer,
                spender: user1,
                value: _amount
            })
        })
    })

    describe("TransferFrom", () => {
        let reciept;
        let _amount;
        beforeEach(async () => {
            _amount = web3.utils.toWei("100");
            await this.token.approve(user1, _amount, { from: deployer });
            reciept = await this.token.transferFrom(deployer, user1, _amount, { from: user1 });
        })

        it("should transfer token to user1 account properly", async () => {
            const balance = await this.token.balanceOf(user1);
            const _tax = (Number(web3.utils.fromWei(_amount)) * 5) / 100;
            let _availableBalance = Number(web3.utils.fromWei(_amount)) - _tax;
            _availableBalance = web3.utils.toWei(_availableBalance.toString(), "ether");
            assert.equal(balance.toString(), _availableBalance.toString());
        })

        it("should burn 5% per transfer", async () => {
            const _tax = (Number(web3.utils.fromWei(_amount, "ether")) * 5) / 100;

            let totalSupply = await this.token.totalSupply();
            totalSupply = web3.utils.fromWei(totalSupply, "ether");
            const _circulatingSupply = (10000 - _tax).toString();
            assert.equal(totalSupply.toString(), _circulatingSupply);
        })

        it("should emit transfer event", async () => {
            expectEvent(reciept, "Transfer", {
                from: deployer,
                to: user1,
                value: _amount
            })
        })

        it("should fail if amount is greater than allowance", async () => {
            try {
                await this.token.transferFrom(user1, user2, _amount, { from: user2 });
            } catch (error) {
                assert(error.message.includes("ERC20: transfer amount exceeds balance"));
                return;
            }
            assert(false);
        })
    })

    describe("Transfer", async () => {
        let reciept;
        let _amount;
        beforeEach(async () => {
            _amount = web3.utils.toWei("100");
            await this.token.approve(user1, _amount, { from: deployer });
            reciept = await this.token.transfer(user1, _amount, { from: deployer });
        })

        it("should transfer token from deployer", async () => {

            const _tax = (Number(web3.utils.fromWei(_amount, "ether")) * 5) / 100;
            const _senderBalance = await this.token.balanceOf(deployer);
            const _recipientBalance = await this.token.balanceOf(user1);


            let totalSupply = await this.token.totalSupply();
            totalSupply = web3.utils.fromWei(totalSupply, "ether");
            const _circulatingSupply = (10000 - _tax).toString();

            assert.equal(_senderBalance.toString(), web3.utils.toWei("9900"));
            assert.equal(_recipientBalance.toString(), web3.utils.toWei("95"));
            assert.equal(totalSupply.toString(), _circulatingSupply);
        })

        it("should emit transfer event", async () => {
            expectEvent(reciept, "Transfer", {
                from: deployer,
                to: user1,
                value: _amount
            })
        })

        it("should fail is sender balance is greater than amount", async () => {
            try {
                await this.token.transfer(user1, _amount, { from: user2 });
            } catch (error) {
                assert(error.message.includes("ERC20: transfer amount exceeds balance"));
                return;
            }
            assert(false);
        })
    })

    describe("calculateLockGains", () => {
        it("should calculate lock gains", async () => {
            const _amount = web3.utils.toWei("100", "ether");
            const _result = await this.token.calculateLockGains(_amount);
            assert.equal(_result.toString(), web3.utils.toWei("20", "ether"));
        })
    })

    describe("lock", () => {
        let reciept;
        let _amount;

        beforeEach(async () => {
            await this.token.transfer(user1, web3.utils.toWei("50", "ether"), { from: deployer });

            _amount = web3.utils.toWei("47.5", "ether");
            reciept = await this.token.lock(_amount, { from: user1 });
        })

        it("should lock token properly", async () => {
            const userBalance = await this.token.balanceOf(user1);
            const { user, amount } = await this.token.locks(user1);

            assert.equal(user, user1);
            assert.equal(amount.toString(), _amount.toString());
            assert.equal(userBalance.toString(), web3.utils.toWei("0", "ether"));
        })

        it("should emit NewLock event", async () => {
            const { unlockTime } = await this.token.locks(user1);
            expectEvent(reciept, "NewLock", {
                user: user1,
                amount: _amount,
                unlockTime
            })
        })

        it("should reject dulicate lock", async () => {
            try {
                _amount = web3.utils.toWei("10", "ether");
                await this.token.lock(_amount, { from: user1 });
            } catch (error) {
                assert(error.message.includes("CrankCoin: active lock found. Wait for the current lock time to exceed"));
                return;
            }
            assert(false);
        })

        it("should reject if lock amount is <= zero", async () => {
            try {
                await this.token.transfer(user2, web3.utils.toWei("20", "ether"), { from: deployer });
                await this.token.lock("0", { from: user2 });
            } catch (error) {
                assert(error.message.includes("CrankCoin: lock amount must be greater than zero"));
                return;
            }
            assert(false);
        })
    })

    describe("unlock", () => {
        let _amount;

        beforeEach(async () => {
            await this.token.transfer(user1, web3.utils.toWei("50", "ether"), { from: deployer });

            _amount = web3.utils.toWei("47.5", "ether");
            await this.token.lock(_amount, { from: user1 });
        })

        it("should reject if lock amount is zero", async () => {
            try {
                await this.token.unlock({ from: user2 });
            } catch (error) {
                assert(error.message.includes("CrankCoin: no active lock found"));
                return;
            }
            assert(false);
        })

        it("should add stake to contract balance", async () => {
            const contractBalance = await this.token.balanceOf(this.token.address);
            const totalLockedToken = await this.token.getTotallockedToken();
        
            assert.equal(contractBalance.toString(), web3.utils.toWei("45.125"));
            assert.equal(totalLockedToken.toString(), web3.utils.toWei("47.5"));
        })

        it("should unlock tokens properly", async () => {
            const balanceBefore = await this.token.balanceOf(user1);
            await this.token.unlock({ from: user1 });
            const balanceAfter = await this.token.balanceOf(user1);
            const { amount } = await this.token.locks(user1);
            const totalLockedToken = await this.token.getTotallockedToken();
            const contractBalance = await this.token.balanceOf(this.token.address);

            assert.equal(amount.toString(), "0");
            assert.equal(balanceBefore.toString(), "0");
            assert.equal(balanceAfter.toString(), web3.utils.toWei("54.15"), "ether");
            assert.equal(totalLockedToken.toString(), "0");
            assert.equal(contractBalance.toString(), "0")
        })

        it("should emit NewUnlock event", async () => {
            const { amount } = await this.token.locks(user1);
            const _rewards = (Number(web3.utils.fromWei(amount, "ether")) * 20) / 100;
            const _reciept = await this.token.unlock({ from: user1 });
            expectEvent(_reciept, "NewUnlock", {
                user: user1,
                initialStake: amount.toString(),
                rewards: web3.utils.toWei(_rewards.toString(), "ether")
            });
        })

        // it("should reject if unlock time has not exceed", async () => {
        //     try {
        //         await this.token.unlock({ from: user1 });
        //     } catch (error) {
        //         assert(error.message.includes("CrankCoin: wait till lock time exceeds"));
        //         return;
        //     }
        //     assert(false);
        // })
    })

    describe("getContractBalance", () => {
        let _amount;

        beforeEach(async () => {
            _amount = web3.utils.toWei("10", "ether");
            await this.token.transfer(this.token.address, _amount);
        })
        it("should return contract balance", async () => {
            const contractBalance = await this.token.getContractBalance();
            assert.equal(contractBalance.toString(), web3.utils.toWei("9.5", "ether"));
        })
    })

    describe("getTotallockedToken", () => {
        let _amount;

        beforeEach(async () => {
            await this.token.transfer(user1, web3.utils.toWei("50", "ether"), { from: deployer });
            _amount = web3.utils.toWei("47.5", "ether");
            await this.token.lock(_amount, { from: user1 });
        })

        it("should return total locked tokens", async () => {
            const totalLockedToken = await this.token.getTotallockedToken();
            assert.equal(totalLockedToken.toString(), _amount);
        })
    })

    describe("shareReward", () => {
        beforeEach(async () => {
            const { address, value } = _data[0];
            await this.token.shareReward([address], [value], { from: deployer });
        })

        it("should distribute rewards properly", async () => {
            const _rewards = await this.token.checkRewards(user1);
            assert.equal(_rewards.toString(), web3.utils.toWei("1.8", "ether"));
        })
    })

    describe("claimRewards", () => {
        beforeEach(async () => {
            const { address, value } = _data[0];
            await this.token.shareReward([address], [value], { from: deployer });

            await this.token.claimRewards({ from:  user1 });
        })

        it("should credit user address with the claimed rewards", async () => {
            const userBalance = await this.token.balanceOf(user1);
            const _userRewards = await this.token.checkRewards(user1);

            assert.equal(userBalance.toString(), web3.utils.toWei("1.805", "ether"));
            assert.equal(_userRewards.toString(), "0");
        })

        it("should fail if user claim rewards is zero", async () => {
            try {
                await this.token.claimRewards({ from:  user2 });
            } catch (error) {
                assert(error.message.includes("CrankCoin: You have zero rewards to claim"));
                return;
            }
            assert(false);
        })
    })

    describe("calculateLockGains", () => {
        it("should calculate lock gains properly", async () => {
            const _amount = web3.utils.toWei("1");
            const result = await this.token.calculateLockGains(_amount);
            assert.equal(result.toString(), web3.utils.toWei("0.2", "ether"));
        })
    })

    describe("checkRewards", () => {
        beforeEach(async () => {
            const { address, value } = _data[0];
            await this.token.shareReward([address], [value], { from: deployer });
        })

        it("should return user reward", async () => {
            const _balance1 = await this.token.checkRewards(user1);
            const _balance2 = await this.token.checkRewards(user2);

            assert.equal(_balance1.toString(), web3.utils.toWei("1.8", "ether"));
            assert.equal(_balance2.toString(), 0);
        })
    })
})