// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Royalty.sol";

library Base64 {
    string internal constant TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';
        
        // load the table into memory
        string memory table = TABLE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)
            
            // prepare the lookup table
            let tablePtr := add(table, 1)
            
            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))
            
            // result ptr, jump over length
            let resultPtr := add(result, 32)
            
            // run over the input, 3 bytes at a time
            for {} lt(dataPtr, endPtr) {}
            {
               dataPtr := add(dataPtr, 3)
               
               // read 3 bytes
               let input := mload(dataPtr)
               
               // write 4 characters
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F)))))
               resultPtr := add(resultPtr, 1)
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F)))))
               resultPtr := add(resultPtr, 1)
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr( 6, input), 0x3F)))))
               resultPtr := add(resultPtr, 1)
               mstore(resultPtr, shl(248, mload(add(tablePtr, and(        input,  0x3F)))))
               resultPtr := add(resultPtr, 1)
            }
            
            // padding with '='
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }
        
        return result;
    }
}

abstract contract ContextMixin {
    function msgSender()
        internal
        view
        returns (address payable sender)
    {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
        } else {
            sender = payable(msg.sender);
        }
        return sender;
    }
}


contract StellarCapital is ERC721, ERC721Enumerable, ERC721URIStorage, ContextMixin, HasSecondarySaleFees, Ownable {
    using Strings for uint256;
    using SafeMath for uint256;
    using Math for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    
    address private constant _CREATOR = 0xF13c426Ae5Fd3381024b582f7BD31b681d571f48;
    string private constant _NAME = "StellarCapital";
    string private constant _Discription = 'Create by Nagi Fuyumi';
    string private myAddr;
    uint256 private startBlock;
    
    mapping(uint256 => uint256) private _tokenCounter;
    
    constructor()
    ERC721(_NAME, _NAME)
    HasSecondarySaleFees(new address payable[](0), new uint256[](0))
    {
        address payable[] memory thisAddressInArray = new address payable[](1);
        thisAddressInArray[0] = payable(address(this));
        uint256[] memory royaltyWithTwoDecimals = new uint256[](1);
        royaltyWithTwoDecimals[0] = 1000;

        _setCommonRoyalties(thisAddressInArray, royaltyWithTwoDecimals);
        
        bytes memory myAddress = abi.encodePacked(address(this));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + myAddress.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < myAddress.length; i++) {
            str[2+i*2] = alphabet[uint(uint8(myAddress[i] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(myAddress[i] & 0x0f))];
        }
        myAddr = string(str);
        
        uint256 currentNumber = _tokenIdCounter.current();
        _safeMint(_CREATOR, currentNumber);
        string memory ipfs = 'https://nagi-fuyumi.github.io/stellarcapital_contract/';
        string memory strBlock = block.number.toString();
        string memory json = string(abi.encodePacked('{"name": "Test", "description": "', _Discription, '", "external_url": "https://twitter.com/pote_pote_salad", "image": "', ipfs, 'main.png", "animation_url": "', ipfs, 'v.html?block=', strBlock, '&addr=', myAddr, '&tokenid=', currentNumber.toString()));
        
        _setTokenURI(currentNumber, json);
        _tokenCounter[currentNumber] = 0;
        _tokenIdCounter.increment();
        
        startBlock = block.number;
    }
    
    /**
     * This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
     */
    function _msgSender()
        internal
        override
        view
        returns (address sender)
    {
        return ContextMixin.msgSender();
    }
    
    function isApprovedForAll(
        address _owner,
        address _operator
    ) public override view returns (bool isOperator) {
      // if OpenSea's ERC721 Proxy Address is detected, auto-return true
        if (_operator == address(0x58807baD0B376efc12F5AD86aAc70E78ed67deaE)) {
            return true;
        }
        
        // otherwise, use the default ERC721.isApprovedForAll()
        return ERC721.isApprovedForAll(_owner, _operator);
    }
    
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721) {
        _tokenCounter[tokenId] += 1;
        super.safeTransferFrom(from, to, tokenId);
    }
    
    function getokenTransferCount(uint256 tokenId) public view returns(uint256) {
        return _tokenCounter[tokenId];
    }
    
    function make(string memory title, string memory cid, string memory img_cid) public onlyOwner {
        uint256 currentNumber = _tokenIdCounter.current();

        _safeMint(_msgSender(), currentNumber);
        _setTokenURI(currentNumber, title, cid, img_cid);
        _tokenCounter[currentNumber] = 0;
        _tokenIdCounter.increment();
    }
    
    function getStartBlock() public view returns(uint256){
        return startBlock;
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }
    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        string memory tokenURIBase = super.tokenURI(tokenId);
        string memory json = Base64.encode(abi.encodePacked(tokenURIBase, '&timestamp=', block.timestamp.toString(), '"}'));
        return string(abi.encodePacked('data:application/json;base64,', json));
    }

    function _setTokenURI(uint256 tokenId, string memory title, string memory cid, string memory img_cid)
        internal
    {
        string memory ipfs = string(abi.encodePacked('ipfs://', cid, '/'));
        string memory image_ipfs = string(abi.encodePacked('ipfs://', img_cid, '/'));
        string memory strBlock = block.number.toString();
        string memory json = string(abi.encodePacked('{"name": "', title, '", "description": "', _Discription, '", "external_url": "https://twitter.com/pote_pote_salad", "image": "', image_ipfs, 'main.png", "animation_url": "', ipfs, 'v.html?block=', strBlock, '&addr=', myAddr, '&tokenid=', tokenId.toString()));
        
        _setTokenURI(tokenId, json);
    }

    function withdrawETH() external {
        uint256 royalty = address(this).balance;

        Address.sendValue(payable(_CREATOR), royalty);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable, HasSecondarySaleFees)
        returns (bool)
    {
        return ERC721.supportsInterface(interfaceId) ||
        HasSecondarySaleFees.supportsInterface(interfaceId);
    }
    
    receive() external payable {}

}

