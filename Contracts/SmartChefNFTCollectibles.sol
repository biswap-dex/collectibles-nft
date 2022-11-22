//SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './interfaces/IBiswapCollectiblesNFT.sol';

contract SmartChefNFTCollectibles is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint public totalStakedSupply;
    uint public lastRewardBlock;
    address[] public listRewardTokens;
    IERC20 public stakeToken;
    uint256 public stakingEndBlock;
    IBiswapCollectiblesNFT public biswapCollectiblesNFT;

    struct RewardToken {
        uint rewardPerBlock;
        uint startBlock;
        uint accTokenPerShare; // Accumulated Tokens per share, times 1e12.
        uint rewardsForWithdrawal;
        bool enabled; // true - enable; false - disable
    }

    struct UserInfo {
        RewardToken[] rewardTokens;
        uint[] pendingReward;
        uint totalStakedSupply;
        IERC20 stakeToken;
        uint stakingEndBlock;
        uint stakedAmount;
        uint maxLimitPerUser;
    }

    mapping (address => uint) public stakedAmount; // Info of user staked amount
    mapping (address => mapping(address => uint)) public rewardDebt; //user => (rewardToken => rewardDebt);
    mapping (address => RewardToken) public rewardTokens;
    uint[] public nftLimitByLVL;

    event AddNewTokenReward(address token);
    event DisableTokenReward(address token);
    event ChangeTokenReward(address indexed token, uint rewardPerBlock, uint startBlock);
    event StakeToken(address indexed user, uint amount);
    event UnstakeToken(address indexed user, uint amount);
    event EmergencyWithdraw(address indexed user, uint amount);
    event SetNewNftLimits(uint[] nftLimits);

    constructor(IERC20 _stakeToken, uint _stakingEndBlock, IBiswapCollectiblesNFT _biswapCollectiblesNFT, uint[] memory _limits) {
        require(address(_stakeToken) != address(0), "address cant be zero");
        require(_stakingEndBlock > block.number, "bad end block");
        stakeToken = _stakeToken;
        stakingEndBlock = _stakingEndBlock;
        biswapCollectiblesNFT = _biswapCollectiblesNFT;
        setNftLimitsByLVL(_limits);
    }

    function setNftLimitsByLVL(uint[] memory _limits) public onlyOwner{
        require(_limits.length == biswapCollectiblesNFT.MAX_LEVEL(), "Bad _limits length");
        delete nftLimitByLVL;
        for(uint i = 0; i < _limits.length; i++){
            nftLimitByLVL.push(_limits[i]);
        }
        emit SetNewNftLimits(_limits);
    }

    function getUserlimit(address user) public view returns(uint limit){
        uint[] memory levels = biswapCollectiblesNFT.getTokenLevelsByUser(user);
        if(levels.length == 0){
            limit = 0;
        } else {
            for(uint i = 0; i < levels.length; i++) limit += nftLimitByLVL[levels[i] - 1];
        }
    }

    function isTokenInList(address _token) internal view returns(bool){
        address[] memory _listRewardTokens = listRewardTokens;
        for(uint i = 0; i < _listRewardTokens.length; i++){
            if(_listRewardTokens[i] == _token){
                return true;
            }
        }
        return false;
    }

    function getUserStakedAmount(address _user) public view returns(uint){
        return stakedAmount[_user];
    }

    function getListRewardTokens() public view returns(address[] memory list){
        list = new address[](listRewardTokens.length);
        list = listRewardTokens;
        return list;
    }

    function addNewTokenReward(address _newToken, uint _startBlock, uint _rewardPerBlock) public onlyOwner {
        require(_newToken != address(0), "Address shouldn't be 0");
        require(isTokenInList(_newToken) == false, "Token is already in the list");
        listRewardTokens.push(_newToken);
        if(_startBlock == 0){
            rewardTokens[_newToken].startBlock = block.number + 1;
        } else {
            rewardTokens[_newToken].startBlock = _startBlock;
        }
        rewardTokens[_newToken].rewardPerBlock = _rewardPerBlock;
        rewardTokens[_newToken].enabled = true;

        emit AddNewTokenReward(_newToken);
    }

    function disableTokenReward(address _token) public onlyOwner {
        require(isTokenInList(_token), "Token not in the list");
        require(rewardTokens[_token].enabled, "Taken already disabled");
        updatePool();
        rewardTokens[_token].enabled = false;
        emit DisableTokenReward(_token);
    }

    function enableTokenReward(address _token, uint _startBlock, uint _rewardPerBlock) public onlyOwner {
        require(isTokenInList(_token), "Token not in the list");
        require(!rewardTokens[_token].enabled, "Reward token is enabled");
        if(_startBlock == 0){
            _startBlock = block.number + 1;
        }
        require(_startBlock >= block.number, "Start block Must be later than current");
        rewardTokens[_token].enabled = true;
        rewardTokens[_token].startBlock = _startBlock;
        rewardTokens[_token].rewardPerBlock = _rewardPerBlock;
        updatePool();

        emit ChangeTokenReward(_token, _rewardPerBlock, _startBlock);
    }

    function changeRewardPerBlock(address _token, uint _newRewardPerBlock) public onlyOwner {
        require(isTokenInList(_token), "Token not in the list");
        require(rewardTokens[_token].enabled, "Reward token not enabled");
        updatePool();
        rewardTokens[_token].rewardPerBlock = _newRewardPerBlock;
        emit ChangeTokenReward(_token, _newRewardPerBlock, block.timestamp);
    }

    function changeStakingEndBlock(uint _newStakingEndBlock) public onlyOwner {
        require(_newStakingEndBlock >= block.number, "Must be greater than current block number");
        stakingEndBlock = _newStakingEndBlock;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint _from, uint _to) public view returns (uint) {
        if(_to <= stakingEndBlock){
            return _to - _from;
        } else if(_from >= stakingEndBlock) {
            return 0;
        } else {
            return stakingEndBlock - _from;
        }
    }
    // View function to see user info on frontend
    function getUserInfo(address _user) external view returns(UserInfo memory info){
        uint tokensLength = listRewardTokens.length;
        info.rewardTokens = new RewardToken[](tokensLength);
        for(uint i = 0; i < tokensLength; i++){
            info.rewardTokens[i] = rewardTokens[listRewardTokens[i]];
        }
        (, info.pendingReward) = this.pendingReward(_user);
        info.totalStakedSupply = totalStakedSupply;
        info.stakeToken = stakeToken;
        info.stakingEndBlock = stakingEndBlock;
        info.stakedAmount = stakedAmount[_user];
        info.maxLimitPerUser = getUserlimit(_user);
        return info;
    }

    // View function to see pending Reward on frontend
    function pendingReward(address _user) external view returns (address[] memory, uint[] memory) {
        uint _stakedAmount = stakedAmount[_user];
        uint[] memory rewards = new uint[](listRewardTokens.length);
        if(_stakedAmount == 0){
            return (listRewardTokens, rewards);
        }
        uint _totalSupply = totalStakedSupply;
        uint _multiplier = getMultiplier(lastRewardBlock, block.number);
        uint _accTokenPerShare = 0;
        for(uint i = 0; i < listRewardTokens.length; i++){
            address curToken = listRewardTokens[i];
            RewardToken memory curRewardToken = rewardTokens[curToken];
            if (_multiplier != 0 && _totalSupply != 0 && curRewardToken.enabled == true) {
                uint curMultiplier;
                if(getMultiplier(curRewardToken.startBlock, block.number) < _multiplier){
                    curMultiplier = getMultiplier(curRewardToken.startBlock, block.number);
                } else {
                    curMultiplier = _multiplier;
                }
                _accTokenPerShare = curRewardToken.accTokenPerShare +
                (curMultiplier * curRewardToken.rewardPerBlock * 1e12 / _totalSupply);
            } else {
                _accTokenPerShare = curRewardToken.accTokenPerShare;
            }
            rewards[i] = (_stakedAmount * _accTokenPerShare / 1e12) - rewardDebt[_user][curToken];
        }
        return (listRewardTokens, rewards);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public {
        uint multiplier = getMultiplier(lastRewardBlock, block.number);
        uint _totalSupply = totalStakedSupply; //Gas safe

        lastRewardBlock = block.number;

        if(multiplier == 0){
            return;
        }
        if(_totalSupply == 0){
            return;
        }
        for(uint i = 0; i < listRewardTokens.length; i++){
            address curToken = listRewardTokens[i];
            RewardToken memory curRewardToken = rewardTokens[curToken];
            if(curRewardToken.enabled == false || curRewardToken.startBlock >= block.number){
                continue;
            } else {
                uint curMultiplier;
                if(getMultiplier(curRewardToken.startBlock, block.number) < multiplier){
                    curMultiplier = getMultiplier(curRewardToken.startBlock, block.number);
                } else {
                    curMultiplier = multiplier;
                }
                uint tokenReward = curRewardToken.rewardPerBlock * curMultiplier;
                rewardTokens[curToken].rewardsForWithdrawal += tokenReward;
                rewardTokens[curToken].accTokenPerShare += (tokenReward * 1e12) / _totalSupply;
            }
        }
    }

    function withdrawReward() external {
        _withdrawReward(msg.sender);
    }

    function _updateRewardDebt(address _user) internal {
        for(uint i = 0; i < listRewardTokens.length; i++){
            rewardDebt[_user][listRewardTokens[i]] = stakedAmount[_user] * rewardTokens[listRewardTokens[i]].accTokenPerShare / 1e12;
        }
    }

    //SCN-01, SFR-02
    function _withdrawReward(address user) internal { //todo check limit and withdraw overlimit amount
        updatePool();
        uint _stakedAmount = stakedAmount[user];
        if(_stakedAmount == 0){
            return;
        }
        address[] memory _listRewardTokens = listRewardTokens;
        for(uint i = 0; i < _listRewardTokens.length; i++){
            RewardToken storage curRewardToken = rewardTokens[_listRewardTokens[i]];
            uint pending = _stakedAmount * curRewardToken.accTokenPerShare / 1e12 - rewardDebt[user][_listRewardTokens[i]];
            if(pending > 0){
                curRewardToken.rewardsForWithdrawal -= pending;
                rewardDebt[user][_listRewardTokens[i]] = _stakedAmount * curRewardToken.accTokenPerShare / 1e12;
                IERC20(_listRewardTokens[i]).safeTransfer(user, pending);
            }
        }
    }

    //stake tokens to the pool
    function stake(uint _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");
        _withdrawReward(msg.sender);
        stakeToken.safeTransferFrom(msg.sender, address(this), _amount);
        stakedAmount[msg.sender] += _amount;
        require(getUserlimit(msg.sender) >= stakedAmount[msg.sender], "Amount over limit");
        totalStakedSupply += _amount;
        _updateRewardDebt(msg.sender);
        emit StakeToken(msg.sender, _amount);
    }

    // Withdraw tokens from pool
    function unstake(uint _amount) external nonReentrant {
        _unstake(msg.sender, _amount);
    }

    function _unstake(address _user, uint _amount) private {
        require(stakedAmount[_user] >= _amount && _amount > 0, "Wrong token amount given");
        _withdrawReward(_user);
        stakedAmount[_user] -= _amount;
        totalStakedSupply -= _amount;
        _updateRewardDebt(_user);
        stakeToken.safeTransfer(_user, _amount);
        emit UnstakeToken(_user, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyUnstake() external {
        uint _stakedAmount = stakedAmount[msg.sender];
        totalStakedSupply -= _stakedAmount;
        delete stakedAmount[msg.sender];
        for(uint i = 0; i < listRewardTokens.length; i++){
            delete rewardDebt[msg.sender][listRewardTokens[i]];
        }
        stakeToken.safeTransfer(msg.sender, _stakedAmount);
        emit EmergencyWithdraw(msg.sender, _stakedAmount);
    }

    // Withdraw reward token. EMERGENCY ONLY.
    function emergencyRewardTokenWithdraw() external onlyOwner {
//        require(address(stakeToken) != _token, "Cant withdraw stake token");
//        require(IERC20(_token).balanceOf(address(this)) >= _amount, "Not enough balance");
        for(uint i = 0; i < listRewardTokens.length; i++){
            address _token = listRewardTokens[i];
            uint _amount = address(stakeToken) != _token ?
                IERC20(_token).balanceOf(address(this)) :
                IERC20(_token).balanceOf(address(this)) - totalStakedSupply;
            if(_amount > 0) IERC20(_token).safeTransfer(msg.sender, _amount);
        }
    }

    function transferNFTHookReceive(address user, uint tokenId, uint256 level) external {
        require(msg.sender == address(biswapCollectiblesNFT), "only biswapCollectiblesNFT allowed");
        uint newUserLimit = getUserlimit(user) - nftLimitByLVL[level - 1];
        uint currentUserStake = stakedAmount[user];
        uint tokensToUnstake = newUserLimit < currentUserStake ? currentUserStake - newUserLimit : 0;
        if(tokensToUnstake > 0) _unstake(user, tokensToUnstake);
    }
}
