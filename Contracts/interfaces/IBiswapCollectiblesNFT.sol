//SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IBiswapCollectiblesNFT {
  struct Token{
    uint8 level;
    uint32 createTimestamp;
  }

  struct TokenView{
    uint tokenId;
    uint8 level;
    uint32 createTimestamp;
    address tokenOwner;
    string uri;
    bool isSelected;
  }

  function DEFAULT_ADMIN_ROLE (  ) external view returns ( bytes32 );
  function TOKEN_MINTER_ROLE (  ) external view returns ( bytes32 );
  function MAX_LEVEL() external view returns (uint);
  function approve ( address to, uint256 tokenId ) external;
  function balanceOf ( address owner ) external view returns ( uint256 );
  function burn ( uint256 _tokenId ) external;
  function getApproved ( uint256 tokenId ) external view returns ( address );
  function getRoleAdmin ( bytes32 role ) external view returns ( bytes32 );
  function getToken ( uint256 tokenId ) external view returns ( TokenView calldata);
  function getUserTokens ( address user ) external view returns ( TokenView[] calldata);
  function getUserSelectedToken(address user) external view returns (TokenView memory token);
  function getUserSelectedTokenId(address user) external view returns (uint tokenId, uint8 level);
  function grantRole ( bytes32 role, address account ) external;
  function hasRole ( bytes32 role, address account ) external view returns ( bool );
  function initialize ( string calldata baseURI, string calldata name_, string calldata symbol_ ) external;
  function isApprovedForAll ( address owner, address operator ) external view returns ( bool );
  function mint ( address to, uint8 level ) external;
  function name (  ) external view returns ( string calldata);
  function ownerOf ( uint256 tokenId ) external view returns ( address );
  function renounceRole ( bytes32 role, address account ) external;
  function revokeRole ( bytes32 role, address account ) external;
  function safeTransferFrom ( address from, address to, uint256 tokenId ) external;
  function safeTransferFrom ( address from, address to, uint256 tokenId, bytes calldata data ) external;
  function setApprovalForAll ( address operator, bool approved ) external;
  function setBaseURI ( string calldata newBaseUri ) external;
  function supportsInterface ( bytes4 interfaceId ) external view returns ( bool );
  function symbol (  ) external view returns ( string calldata );
  function tokenByIndex ( uint256 index ) external view returns ( uint256 );
  function tokenOfOwnerByIndex ( address owner, uint256 index ) external view returns ( uint256 );
  function tokenURI ( uint256 tokenId ) external view returns ( string calldata );
  function totalSupply (  ) external view returns ( uint256 );
  function transferFrom ( address from, address to, uint256 tokenId ) external;
  function getTokenLevelsByUser(address user) external view returns(uint[] memory levels);

  event Initialize(string baseURI, string name, string symbol);
  event TokenMint(address indexed to, uint tokenId, Token token, string uri);
  event TokenSelected(uint tokenId, address indexed owner);
  event TokenReselected(uint oldTokenId, uint newTokenId, address indexed owner);
  event HookError(address receiver);


}
