import { expect, use } from 'chai'
import { solidity } from 'ethereum-waffle'
import { jestSnapshotPlugin } from 'mocha-chai-jest-snapshot'
import { ethers } from 'hardhat'

import ImageData from '../assets/image-data.json';


use(solidity)
use(jestSnapshotPlugin())

describe('PFP Contract', () => {
  it('should deploy the contract', async () => {
    const [owner] = await ethers.getSigners()
    const PFP = await ethers.getContractFactory('PFP')
    await PFP.deploy(owner.address, 'PFPNative', 'PFP')
  })

  it('should mint with a valid invite signature', async () => {
    const [owner] = await ethers.getSigners()
    const inviteCode = "invite-code"
    const messageHash = ethers.utils.solidityKeccak256(['string'], [inviteCode]);
    const signature = await owner.signMessage(ethers.utils.arrayify(messageHash))

    const PFP = await ethers.getContractFactory('PFP')
    const pfp = await PFP.deploy(owner.address, 'PFPNative', 'PFP')

    const { bgcolors, palette, images } = ImageData;
    const { bodies, heads } = images;

    await pfp.addManyBackgrounds(bgcolors)
    await pfp.addManyColorsToPalette(0, palette);
    await pfp.addManyBodies(bodies.map(({ data }) => data));
    await pfp.addManyHeads(heads.map(({ data }) => data));

    await expect(pfp.safeMint(inviteCode, signature)).to.emit(pfp, 'Transfer')

    const tokenSeed = await pfp.tokenSeed(0)
    expect(tokenSeed.body).to.be.at.least(0)
    expect(tokenSeed.head).to.be.at.least(0)
  })

  it('should not mint with an invalid invite signature', async () => {
    const [owner, someoneElse] = await ethers.getSigners()
    const inviteCode = "invite-code"
    const messageHash = ethers.utils.solidityKeccak256(['string'], [inviteCode]);
    const signature = await someoneElse.signMessage(ethers.utils.arrayify(messageHash))

    const PFP = await ethers.getContractFactory('PFP')
    const pfp = await PFP.deploy(owner.address, 'PFPNative', 'PFP')

    const { bgcolors, palette, images } = ImageData;
    const { bodies, heads } = images;

    await pfp.addManyBackgrounds(bgcolors)
    await pfp.addManyColorsToPalette(0, palette);
    await pfp.addManyBodies(bodies.map(({ data }) => data));
    await pfp.addManyHeads(heads.map(({ data }) => data));

    await expect(pfp.safeMint(inviteCode, signature)).to.be.revertedWith('Invalid signature')
  })


  it('should have generated an image', async () => {
    const [owner] = await ethers.getSigners()
    const inviteCode = "invite-code"
    const messageHash = ethers.utils.solidityKeccak256(['string'], [inviteCode]);
    const signature = await owner.signMessage(ethers.utils.arrayify(messageHash))

    const PFP = await ethers.getContractFactory('PFP')
    const pfp = await PFP.deploy(owner.address, 'PFPNative', 'PFP')

    const { bgcolors, palette, images } = ImageData;
    const { bodies, heads } = images;
    await pfp.addManyBackgrounds(bgcolors)
    await pfp.addManyColorsToPalette(0, palette);
    await pfp.addManyBodies(bodies.map(({ data }) => data));
    await pfp.addManyHeads(heads.map(({ data }) => data));

    await expect(pfp.safeMint(inviteCode, signature)).to.emit(pfp, 'Transfer')
    expect(await pfp.tokenURI(0)).to.be.a('string').and.satisfy((msg: String) => msg.startsWith('data:application/json;base64,'));
  })
})