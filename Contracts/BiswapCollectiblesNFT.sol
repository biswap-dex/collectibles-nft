// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

contract BiswapCollectiblesNFT is
    Initializable,
    ERC721EnumerableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    uint public constant MAX_LEVEL = 5;

    struct Token {
        uint8 level;
        uint32 createTimestamp;
    }

    struct TokenView {
        uint tokenId;
        uint8 level;
        uint32 createTimestamp;
        address tokenOwner;
        string uri;
        bool isSelected;
    }

    address[] public transferHookAddresses;

    mapping(uint => Token) private _tokens; //tokenId => Token

    mapping(address => uint) private selectedToken; //user address => tokenId

    bytes32 public constant TOKEN_MINTER_ROLE = keccak256("TOKEN_MINTER");

    string private _internalBaseURI;

    uint private _lastTokenId;

    //Events --------------------------------------------------------------------------------------------------------

    event Initialize(string baseURI, string name, string symbol);
    event TokenMint(address indexed to, uint tokenId, Token token, string uri);
    event TokenSelected(uint tokenId, address indexed owner);
    event TokenReselected(uint oldTokenId, uint newTokenId, address indexed owner);
    event HookError(address receiver,  bytes returndata);
    event NewTransferHookAddress(address newHookAddress);
    event DeleteTransferHookAddresses(address delHookAddress);

    //Initialize function --------------------------------------------------------------------------------------------

    function initialize(
        string memory baseURI,
        string memory name_,
        string memory symbol_
    ) public initializer {
        __ERC721_init(name_, symbol_);
        __ERC721Enumerable_init();
        __ReentrancyGuard_init();
        __AccessControl_init_unchained();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        _internalBaseURI = baseURI;

        emit Initialize(baseURI, name_, symbol_);
    }

    //External functions --------------------------------------------------------------------------------------------

    function selectToken(uint newTokenId) external {
        require(ownerOf(newTokenId) == msg.sender, "Not owner");
        require(msg.sender.code.length == 0 && tx.origin == msg.sender, "Contract not allowed");
        uint oldTokenId = selectedToken[msg.sender];
        selectedToken[msg.sender] = newTokenId;
        emit TokenReselected(oldTokenId, newTokenId, msg.sender);
    }

    function setTransferHookAddresses(address newHookAddress) external onlyRole(DEFAULT_ADMIN_ROLE){
        transferHookAddresses.push(newHookAddress);
        emit NewTransferHookAddress(newHookAddress);
    }

    function deleteTransferHookAddresses(address delHookAddress) external onlyRole(DEFAULT_ADMIN_ROLE) returns(bool){
        for(uint i; i < transferHookAddresses.length; i++){
            if(delHookAddress == transferHookAddresses[i]){
                transferHookAddresses[i] = transferHookAddresses[transferHookAddresses.length -1];
                transferHookAddresses.pop();
                emit DeleteTransferHookAddresses(delHookAddress);
                return true;
            }
        }
        return false;
    }

    function getTokenLevelsByUser(address user) external view returns(uint[] memory levels){
        uint tokensCount = balanceOf(user);
        levels = new uint[](tokensCount);
        for(uint i; i < tokensCount; i++){
            levels[i] = _tokens[tokenOfOwnerByIndex(user, i)].level;
        }
    }

    function getUserTokens(address user) external view returns (TokenView[] memory tokens) {
        if (user == address(0)) return tokens;
        tokens = new TokenView[](balanceOf(user));
        for (uint i = 0; i < tokens.length; i++) {
            tokens[i] = getToken(tokenOfOwnerByIndex(user, i));
        }
    }

    function getUserSelectedToken(address user) external view returns (TokenView memory token) {
        return getToken(selectedToken[user]);
    }

    function getUserSelectedTokenId(address user) external view returns (uint tokenId, uint8 level){
        tokenId = selectedToken[user];
        level = _tokens[tokenId].level;
    }

    function mint(address to, uint8 level) external onlyRole(TOKEN_MINTER_ROLE) {
        require(to != address(0), "Address can not be zero");
        require(level <= MAX_LEVEL, "Max level exceeded");
        require(level > 0, "Level cant be zero");
        _lastTokenId += 1; //5000
        uint tokenId = _lastTokenId; //5000 safe Gas
        _tokens[tokenId].level = level;
        _tokens[tokenId].createTimestamp = uint32(block.timestamp);
        _safeMint(to, tokenId);
    }

    function burn(uint _tokenId) external {
        require(_exists(_tokenId), "ERC721: token does not exist");
        require(ownerOf(_tokenId) == msg.sender, "Not token owner");
        _burn(_tokenId);
    }

    //Public functions ----------------------------------------------------------------------------------------------

    function getToken(uint tokenId) public view returns (TokenView memory tokenView) {
        if(!_exists(tokenId)) return tokenView;
        Token memory currentToken = _tokens[tokenId];
        tokenView.tokenId = tokenId;
        tokenView.level = currentToken.level;
        tokenView.createTimestamp = currentToken.createTimestamp;
        tokenView.tokenOwner = ownerOf(tokenId);
        tokenView.uri = tokenURI(tokenId);
        tokenView.isSelected = selectedToken[tokenView.tokenOwner] == tokenId;
        return tokenView;
    }

    function setBaseURI(string calldata newBaseUri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _internalBaseURI = newBaseUri;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IERC721EnumerableUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    //Internal functions --------------------------------------------------------------------------------------------

    function _baseURI() internal view override returns (string memory) {
        return _internalBaseURI;
    }

    function _burn(uint tokenId) internal override {
        super._burn(tokenId);
        delete _tokens[tokenId];
    }

    function _safeMint(address to, uint tokenId) internal override {
        super._safeMint(to, tokenId);
        emit TokenMint(to, tokenId, _tokens[tokenId], tokenURI(tokenId));
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint tokenId
    ) internal virtual override(ERC721EnumerableUpgradeable) {
        if (from != address(0) && from.code.length == 0 && selectedToken[from] == tokenId) reselectToken(from);
        if (to != address(0) && selectedToken[to] == 0 && to.code.length == 0) {
            selectedToken[to] = tokenId;
            emit TokenSelected(tokenId, to);
        }
        if(from != to && from != address(0)) transferHookHandler(from, tokenId, _tokens[tokenId].level);
        super._beforeTokenTransfer(from, to, tokenId);
    }

    //Private functions --------------------------------------------------------------------------------------------
    function reselectToken(address owner) private {
        uint oldTokenId = selectedToken[owner];
        uint newTokenId;
        uint _balance = balanceOf(owner);
        if ( _balance > 1) {
            for (uint i = 0; i < _balance; i++) {
                uint curToken = tokenOfOwnerByIndex(owner, i);
                if (curToken != oldTokenId) {
                    selectedToken[owner] = curToken;
                    newTokenId = curToken;
                    break;
                }
            }
        } else selectedToken[owner] = 0;
        emit TokenReselected(oldTokenId, newTokenId, owner);
    }

    function transferHookHandler(address user, uint tokenId, uint level) private {
        for (uint i = 0; i < transferHookAddresses.length; i++) {
            (bool success, bytes memory returndata ) = transferHookAddresses[i].call(
                abi.encodeWithSignature("transferNFTHookReceive(address,uint256,uint256)", user, tokenId, level)
            );
            if (!success) emit HookError(transferHookAddresses[i], returndata);
        }
    }
}
