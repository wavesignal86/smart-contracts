// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Launchpad.sol";
import "./interfaces/IWaveERC20.sol";

contract DeployLaunchpad is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IWaveERC20;

    address public signer;
    address public superAccount;
    address public waveLock;
    address payable public fundAddress;

    event NewLaunchpad(address indexed launchpad);

    uint256 public constant ZOOM = 10_000;

    constructor(address _signer, address _superAccount, address _waveLock, address payable _fundAddress){
        require(_signer != address(0) && _signer != address(this), 'signer');
        require(_waveLock != address(0) && _waveLock != address(this), 'waveLock');
        require(_superAccount != address(0) && _superAccount != address(this), 'superAccount');
        require(_fundAddress != address(0) && _fundAddress != address(this), 'fundAddress');
        signer = _signer;
        superAccount = _superAccount;
        fundAddress = _fundAddress;
        waveLock = _waveLock;
    }

    function setSigner(address _signer) public onlyOwner {
        signer = _signer;
    }

    function setSuperAccount(address _superAccount) public onlyOwner {
        superAccount = _superAccount;
    }

    function setWaveLock(address _waveLock) public onlyOwner {
        waveLock = _waveLock;
    }

    function setFundAddress(address payable _fundAddress) public onlyOwner {
        fundAddress = _fundAddress;
    }


    function calculateTokens(SharedStructs.CalculateTokenInput memory input) private view returns (uint256) {
        uint256 feeTokenDecimals = 18;
        if (input.feeToken != address(0)) {
            feeTokenDecimals = IWaveERC20(input.feeToken).decimals();
        }

        uint256 totalPresaleTokens = input.presaleRate.mul(input.hardCap).div(10 ** feeTokenDecimals);

        uint256 totalFeeTokens = totalPresaleTokens.mul(input.raisedTokenFeePercent).div(ZOOM);

        uint256 totalTeamTokens = input.teamTotalVestingTokens;

        uint256 totalRaisedFee = input.hardCap.mul(input.raisedFeePercent).div(ZOOM);
        uint256 netCap = input.hardCap.sub(totalRaisedFee);
        uint256 totalFeeTokensToAddLP = netCap.mul(input.listingPercent).div(ZOOM);

        uint256 totalLiquidityTokens = totalFeeTokensToAddLP.mul(input.listingPrice).div(10 ** feeTokenDecimals);

        uint256 result = totalPresaleTokens.add(totalTeamTokens).add(totalFeeTokens).add(totalLiquidityTokens);
        return result;
    }

    function deployLaunchpad(SharedStructs.LaunchpadInfo memory info, SharedStructs.ClaimInfo memory claimInfo, SharedStructs.TeamVestingInfo memory teamVestingInfo, SharedStructs.DexInfo memory dexInfo, SharedStructs.FeeSystem memory feeInfo) external payable {

        require(signer != address(0) && superAccount != address(0), 'Can not create launchpad now!');
        require(msg.value >= feeInfo.initFee, 'Not enough fee!');
        require(fundAddress != address(0), 'Invalid Fund Address');


        SharedStructs.SettingAccount memory settingAccount = SharedStructs.SettingAccount(
            _msgSender(),
            signer,
            superAccount,
            fundAddress,
            waveLock
        );

        Launchpad launchpad = new Launchpad(info, claimInfo, teamVestingInfo, dexInfo, feeInfo, settingAccount);

        IWaveERC20 icoToken = IWaveERC20(info.icoToken);
        uint256 feeTokenDecimals = 18;
        if (info.feeToken != address(0)) {
            feeTokenDecimals = IWaveERC20(info.feeToken).decimals();
        }

        SharedStructs.CalculateTokenInput memory input = SharedStructs.CalculateTokenInput(info.feeToken,
            info.presaleRate,
            info.hardCap,
            feeInfo.raisedTokenFeePercent,
            feeInfo.raisedFeePercent,
            teamVestingInfo.teamTotalVestingTokens,
            dexInfo.listingPercent,
            dexInfo.listingPrice);

        uint256 totalTokens = calculateTokens(input);

        if (msg.value > 0) {
            payable(fundAddress).transfer(msg.value);
        }

        if (totalTokens > 0) {
            IWaveERC20 icoTokenErc20 = IWaveERC20(info.icoToken);

            require(icoTokenErc20.balanceOf(_msgSender()) >= totalTokens, 'Insufficient Balance');
            require(icoTokenErc20.allowance(_msgSender(), address(this)) >= totalTokens, 'Insufficient Allowance');

            icoToken.safeTransferFrom(_msgSender(), address(launchpad), totalTokens);
        }
        emit NewLaunchpad(address(launchpad));
    }

}


