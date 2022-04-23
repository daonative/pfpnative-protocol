// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import './PFP.sol';

contract CollectionCreator {
    PFP[] public allPFPCollections;
    event PFPCollectionCreated(address indexed newCollection);

    function createPFPCollection(
        string memory name,
        string memory symbol
    ) external returns (PFP) {
        PFP newPFPCollection = new PFP(msg.sender, name, symbol);
        emit PFPCollectionCreated(address(newPFPCollection));
        allPFPCollections.push(newPFPCollection);
        return newPFPCollection;
    }

    function getPFPCollections() external view returns (PFP[] memory) {
        return allPFPCollections;
    }
}