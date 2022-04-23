// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import { Base64 } from "base64-sol/base64.sol";

library MultiPartRLEToSVG {
  struct SVGParams {
    bytes[] parts;
    string background;
  }

  struct ContentBounds {
    uint8 top;
    uint8 right;
    uint8 bottom;
    uint8 left;
  }

  struct Rect {
    uint8 length;
    uint8 colorIndex;
  }

  struct DecodedImage {
    uint8 paletteIndex;
    ContentBounds bounds;
    Rect[] rects;
  }

  /**
   * @notice Given RLE image parts and color palettes, merge to generate a single SVG image.
   */
  function generateSVG(
    SVGParams memory params,
    mapping(uint8 => string[]) storage palettes
  ) internal view returns (string memory svg) {
    // prettier-ignore
    return string(
            abi.encodePacked(
                '<svg width="320" height="320" viewBox="0 0 320 320" xmlns="http://www.w3.org/2000/svg" shape-rendering="crispEdges">',
                '<rect width="100%" height="100%" fill="#', params.background, '" />',
                _generateSVGRects(params, palettes),
                '</svg>'
            )
        );
  }

  /**
   * @notice Given RLE image parts and color palettes, generate SVG rects.
   */
  // prettier-ignore
  function _generateSVGRects(SVGParams memory params, mapping(uint8 => string[]) storage palettes)
        private
        view
        returns (string memory svg)
    {
        string[33] memory lookup = [
            '0', '10', '20', '30', '40', '50', '60', '70', 
            '80', '90', '100', '110', '120', '130', '140', '150', 
            '160', '170', '180', '190', '200', '210', '220', '230', 
            '240', '250', '260', '270', '280', '290', '300', '310',
            '320' 
        ];
        string memory rects;
        for (uint8 p = 0; p < params.parts.length; p++) {
            DecodedImage memory image = _decodeRLEImage(params.parts[p]);
            string[] storage palette = palettes[image.paletteIndex];
            uint256 currentX = image.bounds.left;
            uint256 currentY = image.bounds.top;
            uint256 cursor;
            string[16] memory buffer;

            string memory part;
            for (uint256 i = 0; i < image.rects.length; i++) {
                Rect memory rect = image.rects[i];
                if (rect.colorIndex != 0) {
                    buffer[cursor] = lookup[rect.length];          // width
                    buffer[cursor + 1] = lookup[currentX];         // x
                    buffer[cursor + 2] = lookup[currentY];         // y
                    buffer[cursor + 3] = palette[rect.colorIndex]; // color

                    cursor += 4;

                    if (cursor >= 16) {
                        part = string(abi.encodePacked(part, _getChunk(cursor, buffer)));
                        cursor = 0;
                    }
                }

                currentX += rect.length;
                if (currentX == image.bounds.right) {
                    currentX = image.bounds.left;
                    currentY++;
                }
            }

            if (cursor != 0) {
                part = string(abi.encodePacked(part, _getChunk(cursor, buffer)));
            }
            rects = string(abi.encodePacked(rects, part));
        }
        return rects;
    }

  /**
   * @notice Return a string that consists of all rects in the provided `buffer`.
   */
  // prettier-ignore
  function _getChunk(uint256 cursor, string[16] memory buffer) private pure returns (string memory) {
        string memory chunk;
        for (uint256 i = 0; i < cursor; i += 4) {
            chunk = string(
                abi.encodePacked(
                    chunk,
                    '<rect width="', buffer[i], '" height="10" x="', buffer[i + 1], '" y="', buffer[i + 2], '" fill="#', buffer[i + 3], '" />'
                )
            );
        }
        return chunk;
    }

  /**
   * @notice Decode a single RLE compressed image into a `DecodedImage`.
   */
  function _decodeRLEImage(bytes memory image)
    private
    pure
    returns (DecodedImage memory)
  {
    uint8 paletteIndex = uint8(image[0]);
    ContentBounds memory bounds = ContentBounds({
      top: uint8(image[1]),
      right: uint8(image[2]),
      bottom: uint8(image[3]),
      left: uint8(image[4])
    });

    uint256 cursor;
    Rect[] memory rects = new Rect[]((image.length - 5) / 2);
    for (uint256 i = 5; i < image.length; i += 2) {
      rects[cursor] = Rect({
        length: uint8(image[i]),
        colorIndex: uint8(image[i + 1])
      });
      cursor++;
    }
    return
      DecodedImage({
        paletteIndex: paletteIndex,
        bounds: bounds,
        rects: rects
      });
  }
}

contract PFP is ERC721, ERC721Enumerable, Ownable, ERC721Burnable {
  using Counters for Counters.Counter;
  using ECDSA for bytes32;

  struct Seed {
    uint48 body;
    uint48 head;
  }

  Counters.Counter private _tokenIdCounter;
  mapping(uint256 => Seed) public seeds;

  // Color Palettes (Index => Hex Colors)
  mapping(uint8 => string[]) public palettes;

  // Backgrounds (Hex Colors)
  string[] public backgrounds;

  // Parts RLE data
  bytes[] public bodies;
  bytes[] public heads;

  constructor(
    address _owner,
    string memory _name,
    string memory _symbol
  ) ERC721(_name, _symbol) {
    transferOwnership(_owner);
  }

  struct TokenURIParams {
    string name;
    string description;
    bytes[] parts;
    string background;
  }

  /**
   * @notice Construct an ERC721 token URI.
   */
  function constructTokenURI(
    TokenURIParams memory params,
    mapping(uint8 => string[]) storage _palettes
  ) internal view returns (string memory) {
    string memory image = generateSVGImage(
      MultiPartRLEToSVG.SVGParams({
        parts: params.parts,
        background: params.background
      }),
      _palettes
    );

    // prettier-ignore
    return string(
      abi.encodePacked(
        'data:application/json;base64,',
        Base64.encode(
          bytes(
            abi.encodePacked('{"name":"', params.name, '", "description":"', params.description, '", "image": "', 'data:image/svg+xml;base64,', image, '"}')
          )
        )
      )
    );
  }

  /**
   * @notice Generate an SVG image for use in the ERC721 token URI.
   */
  function generateSVGImage(
    MultiPartRLEToSVG.SVGParams memory params,
    mapping(uint8 => string[]) storage _palettes
  ) internal view returns (string memory svg) {
    return
      Base64.encode(bytes(MultiPartRLEToSVG.generateSVG(params, _palettes)));
  }

  function safeMint(string memory inviteCode, bytes memory signature) public {
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

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function bodyCount() public view returns (uint256) {
    return bodies.length;
  }

  function headCount() public view returns (uint256) {
    return bodies.length;
  }

  function addManyColorsToPalette(
    uint8 paletteIndex,
    string[] calldata newColors
  ) external onlyOwner {
    require(
      palettes[paletteIndex].length + newColors.length <= 256,
      "Palettes can only hold 256 colors"
    );
    for (uint256 i = 0; i < newColors.length; i++) {
      _addColorToPalette(paletteIndex, newColors[i]);
    }
  }

  function addManyBackgrounds(string[] calldata _backgrounds)
    external
    onlyOwner
  {
    for (uint256 i = 0; i < _backgrounds.length; i++) {
      _addBackground(_backgrounds[i]);
    }
  }

  function addManyBodies(bytes[] calldata _bodies) external onlyOwner {
    for (uint256 i = 0; i < _bodies.length; i++) {
      _addBody(_bodies[i]);
    }
  }

  function addManyHeads(bytes[] calldata _heads) external onlyOwner {
    for (uint256 i = 0; i < _heads.length; i++) {
      _addHead(_heads[i]);
    }
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override
    returns (string memory)
  {
    Seed memory seed = seeds[tokenId];
    string memory id = Strings.toString(tokenId);
    string memory tokenName = string(abi.encodePacked(symbol(), " ", id));
    string memory tokenDescription = string(abi.encodePacked(name()));

    return genericDataURI(tokenName, tokenDescription, seed);
  }

  function genericDataURI(
    string memory name,
    string memory description,
    Seed memory seed
  ) public view returns (string memory) {
    TokenURIParams memory params = TokenURIParams({
      name: name,
      description: description,
      parts: _getPartsForSeed(seed),
      background: backgrounds[0]
    });
    return constructTokenURI(params, palettes);
  }

  function _addColorToPalette(uint8 _paletteIndex, string calldata _color)
    internal
  {
    palettes[_paletteIndex].push(_color);
  }

  function _addBackground(string calldata _background) internal {
    backgrounds.push(_background);
  }

  function _addBody(bytes calldata _body) internal {
    bodies.push(_body);
  }

  function _addHead(bytes calldata _head) internal {
    heads.push(_head);
  }

  function _getPartsForSeed(Seed memory seed)
    internal
    view
    returns (bytes[] memory)
  {
    bytes[] memory _parts = new bytes[](2);
    _parts[0] = bodies[seed.body];
    _parts[1] = heads[seed.head];
    return _parts;
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function _generateSeed(uint256 tokenId) internal view returns (Seed memory) {
    uint256 pseudorandomness = uint256(
      keccak256(abi.encodePacked(blockhash(block.number - 1), tokenId))
    );

    return
      Seed({
        body: uint48(uint48(pseudorandomness) % bodyCount()),
        head: uint48(uint48(pseudorandomness >> 48) % headCount())
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
