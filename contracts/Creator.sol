// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import './PFP.sol';

contract Creator {
    PFP[] public allPFPCollections;
    event PFPCollectionCreated(address indexed newCollection);

    function createPFPCollection(
        string memory name,
        string memory symbol,
        uint price,
        string[] memory backgrounds,
        string[] memory palette,
        bytes[] memory heads,
        bytes[] memory bodies
    ) external returns (PFP) {
        PFP newPFPCollection = new PFP(name, symbol, price);

        newPFPCollection.addManyBackgrounds(backgrounds);
        newPFPCollection.addManyColorsToPalette(0, palette);
        newPFPCollection.addManyHeads(heads);
        newPFPCollection.addManyBodies(bodies);
        newPFPCollection.transferOwnership(msg.sender);

        allPFPCollections.push(newPFPCollection);

        emit PFPCollectionCreated(address(newPFPCollection));
        return newPFPCollection;
    }

    function getPFPCollections() external view returns (PFP[] memory) {
        return allPFPCollections;
    }
}