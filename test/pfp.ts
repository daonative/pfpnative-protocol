import { expect, use } from 'chai'
import { solidity } from 'ethereum-waffle'
import { jestSnapshotPlugin } from 'mocha-chai-jest-snapshot'
import { ethers, waffle } from 'hardhat'
import { parseEther } from '@ethersproject/units'

use(solidity)
use(jestSnapshotPlugin())

describe('PFP Contract', () => {
  it('should deploy the contract', async () => {
    const [owner] = await ethers.getSigners()
    const PFP = await ethers.getContractFactory('PFP')
    await PFP.deploy(owner.address, 'PFPNative', 'PFP')
  })
})