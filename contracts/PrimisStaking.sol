// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "./interfaces/ISPrmToken.sol";
import "./interfaces/IPrimisTreasury.sol";
import "./interfaces/ISPrimisToken.sol";
import "./interfaces/IPrimisBond.sol";
import "hardhat/console.sol";

error ZeroAddress();
error InvalidAmount();
error NotKeeper();
error NotAllowed();

contract PrimisStaking is Initializable, EIP712Upgradeable, OwnableUpgradeable {
    string private constant SIGNING_DOMAIN = "stakingContract";
    string private constant SIGNATURE_VERSION = "1";
    uint public bondRewardPercentage;
    uint public rebasingIndex;
    address public signer;
    address public prmToken;
    address public sPrmToken;
    address public primisTreasury;
    address public primisBond;
    address public keeper;
    address public stEth;
    bool public isWhitelisted;
    bool public stakingEnable;  // status of staking-pause feature (enabled/disabled)
    bool public unstakeEnable;  // status of unstake-pause feature (enabled/disabled)
    bool public stakingContractPause; // status of stakingContract-pause feature (enabled/disabled)

    struct signData {
        address user;
        string key;
        bytes signature;
    }

    event AddressUpdated(address indexed addr, uint256 indexed addrType);
    event PercentUpdated(uint256 percent);
    event stakingEnableSet(bool indexed isEnable);
    event unstakeEnableSet(bool indexed isEnable);
    event stakingContractPauseSet(bool indexed isEnable);
    event Stake(address indexed staker, uint256 amount);
    event unStake(address indexed withdrawer, uint256 amount);
    event EpochStakingReward(address indexed asset, uint256 totalReward, uint256 rw2, uint256 sendTokens);
    event WhitelistChanged(bool indexed action);
    event newSigner(address _signer);
  
    function initialize(address _prm, address _sPrm, address _signer) external initializer {
        __Ownable_init();
        signer = _signer;
        // setAddress(_primisBond, 1);
        // setAddress(_primisTreasury, 2);
        stakingEnable = true; // for testing purpose
        unstakeEnable = true;   // for testing purpose
        stakingContractPause = true; // for testing purpose
        setAddress(_prm, 3);
        setAddress(_sPrm, 4);
        bondRewardPercentage = 10;
    }

    modifier stakingEnabled() {
        if (stakingEnable != true) revert NotAllowed();
        _;
    }

    modifier unstakeEnabled() {
        if (unstakeEnable != true) revert NotAllowed();
        _;
    }

    modifier stakingContractPaused() {
        if (stakingContractPause != true) revert NotAllowed();
        _; 
    }

    function setStakingEnable(bool _enable) external onlyOwner{
        stakingEnable = _enable;
        emit stakingEnableSet(_enable);
    }

    function setUnstakeEnable(bool _enable) external onlyOwner{
        unstakeEnable = _enable;
        emit unstakeEnableSet(_enable);
    }

    function setStakingPause(bool _enable) external onlyOwner{
        stakingContractPause = _enable;
        emit stakingContractPauseSet(_enable);
    }

    function setsigner(address _signer) external onlyOwner {
        require(_signer != address(0), "Address can't be zero");
        signer = _signer;
        emit newSigner(signer);
    }

    function setAddress(address _addr, uint256 _type) public onlyOwner {
        if (_addr == address(0)) revert ZeroAddress();

        if (_type == 1) primisBond = _addr;
        else if (_type == 2) primisTreasury = _addr;
        else if (_type == 3) prmToken = _addr;
        else if (_type == 4) sPrmToken = _addr;
        else if (_type == 5) keeper = _addr;
        else if (_type == 6) stEth = _addr;

         emit AddressUpdated(_addr, _type);

       
    }

    function setBondRewardPercentage(uint256 percent) external onlyOwner {
        if (percent == 0) revert InvalidAmount();

        bondRewardPercentage = percent;
          emit PercentUpdated(bondRewardPercentage);

        
    }

    function whitelist(bool _action) external onlyOwner{
        isWhitelisted = _action;
        emit WhitelistChanged(_action);
    }

    /**
     * @notice Users do stake
     * @param amount  stake amount
     */
    function stake(uint256 amount, signData memory userSign) external stakingEnabled stakingContractPaused{
        if (amount == 0) revert InvalidAmount();
        if(isWhitelisted){
            address signAddress = _verify(userSign);
            require(signAddress == signer && userSign.user == msg.sender, "user is not whitelisted");
        }
        console.log("\nPrm token deposit:- ", amount);
        if(ISPrmToken(prmToken).balanceOf(address(this)) == 0){
            uint256 sPrmAmount = calculateSPrmTokens(amount);
            console.log("Receipt token:- ", sPrmAmount);
            ISPrmToken(sPrmToken).mint(msg.sender, sPrmAmount);
            ISPrmToken(PrmToken).transferFrom(msg.sender, address(this), amount);
        } else {
            ISPrmToken(prmToken).transferFrom(msg.sender, address(this), amount);
            uint256 sPrmAmount = calculateSPrmTokens(amount);
            console.log("Receipt token:- ", sPrmAmount);
            ISPrmToken(sPrmToken).mint(msg.sender, sPrmAmount);
        }
        epochStakingReward(stEth);
        emit Stake(msg.sender, amount);
    }

    /**
     * @notice Users can unstake
     * @param amount  unstake amount
     */
    function unstake(uint256 amount) external unstakeEnabled stakingContractPaused{
        if (amount == 0) revert InvalidAmount();
        if (ISPrmToken(sPrmToken).balanceOf(msg.sender) < amount) revert InvalidAmount();
        // add reward
        epochStakingReward(stEth);
        uint256 reward = claimRebaseValue(amount);
        console.log("\nWithraw amount of staking contract:- ", reward);
        // transfer token
        ISPrmToken(prmToken).transfer(msg.sender, reward);
        ISPrmToken(sPrmToken).burn(msg.sender, amount);
        emit unStake(msg.sender, amount);


     
    }

    function epochStakingReward(address _asset) public  {
        // if (msg.sender != keeper) revert NotKeeper();
        uint256 totalReward = IPrimisTreasury(primisTreasury).stakeRebasingReward(_asset);
        uint256 rw2 = (totalReward * bondRewardPercentage) / 100;
        console.log("Rebase reward for bond holder's:- ", rw2);
        uint256 sprmTokens = calculateSPrmTokens(rw2);
        ISPrmToken(sPrmToken).mint(prmBond, sendTokens);
        ISPrmToken(prmToken).mint(address(this), totalReward);
        IPrimisBond(primisBond).epochRewardShareIndexForSend(sendTokens);
        calculateRebaseIndex();
         emit EpochStakingReward(_asset, totalReward, rw2, sendTokens);  
    }

    function calculateSPrmTokens(uint256 _prmAmount) public view returns (uint256 sPrmTokens) {
        if (rebasingIndex == 0) {
            sPrmTokens = _prmAmount;
            return sPrmTokens;
        } else{
            sPrmTokens = (_prmAmount/ rebasingIndex); 
            return sPrmTokens; 
        }
    }

    function calculateRebaseIndex() internal {
        uint256 prmBalStaking = ISPrmToken(prmToken).balanceOf(address(this));
        uint256 sPrmTotalSupply = ISPrmToken(sPrmToken).totalSupply();
        if (prmBalStaking == 0 || sPrmTotalSupply == 0) {
            rebasingIndex = 1;
        } else {
            rebasingIndex = prmBalStaking * 10e18/ sPrmTotalSupply;
        }
    }

    function claimRebaseValue(uint256 _sendAmount) internal view returns (uint256 reward) {
        console.log("rebasingIndex:- ", rebasingIndex);
        reward = (_sendAmount * rebasingIndex) / 10e18;
    }

    function _hash(signData memory userSign) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256("userSign(address user,string key)"),
                        userSign.user,
                        keccak256(bytes(userSign.key))
                    )
                )
            );
    }

    /**
     * @notice verifying the owner signature to check whether the user is whitelisted or not
     */
    function _verify(signData memory userSign) internal view returns (address) {
        bytes32 digest = _hash(userSign);
        return ECDSAUpgradeable.recover(digest, userSign.signature);
    }
}
