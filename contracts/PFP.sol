// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract PFP is ERC721, ERC721Enumerable, Ownable, ERC721Burnable {
  using Counters for Counters.Counter;
  using ECDSA for bytes32;

  struct Seed {
    uint48 body;
    uint48 head;
  }

  Counters.Counter private _tokenIdCounter;
  mapping(uint256 => Seed) public seeds;

  constructor(
    address _owner,
    string memory _name,
    string memory _symbol
  ) ERC721(_name, _symbol) {
    transferOwnership(_owner);
  }

  function safeMint(
    string memory inviteCode,
    bytes memory signature
  ) public {
    require(
      _verifySignature(inviteCode, signature, owner()) == true,
      "Invalid signature"
    );
    uint256 tokenId = _tokenIdCounter.current();
    _tokenIdCounter.increment();
    _safeMint(msg.sender, tokenId);
    seeds[tokenId] = _generateSeed(tokenId);
  }

  function tokenSeed(uint256 tokenId) external view returns (Seed memory) {
    return seeds[tokenId];
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function _generateSeed(uint256 tokenId) internal view returns (Seed memory) {
    uint256 pseudorandomness = uint256(
      keccak256(abi.encodePacked(blockhash(block.number - 1), tokenId))
    );

    return
      Seed({
        body: uint48(
          uint48(pseudorandomness) % 4 // max 4 bodies
        ),
        head: uint48(
          uint48(pseudorandomness >> 48) % 4 // max 4 heads
        )
      });
  }

  function _verifySignature(
    string memory inviteCode,
    bytes memory signature,
    address account
  ) internal pure returns (bool) {
    bytes32 msgHash = keccak256(abi.encodePacked(inviteCode));
    return msgHash.toEthSignedMessageHash().recover(signature) == account;
  }
}
