// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
/**
 * @title RebaseToken
 * @author Mansoor Butt
 * @dev Implementation of the RebaseToken
 * @notice This is a cross-chain Rebase token that incentivizes users to deposit WETH into a vault to earn rewards in the form of RWT which accumalates rewards on a interest rate.
 *  @notice The interest rate decreases relevant to time
 * @notice Each user will have their own interest rate set by the current global interest rate at the time of Minting RWT
 */

contract RebaseToken is ERC20, Ownable, AccessControl {
    uint256 private interestRate = 5e10; // 5% interest rate
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 private constant PRECISION_FACTOR = 1e18; // Precision factor to calculate interest
    mapping(address => uint256) public userInterestRate; // Mapping to store the interest rate of each user
    mapping(address => uint256) private last_Updated; // Mapping to store the last time the user's interest rate was updated

    event InterestRateChanged(uint256 newInterestRate);

    constructor() ERC20("Reward Token", "RWT") Ownable(msg.sender) {}

    function grantMintandBurnRole(address _account) public onlyOwner {
        _grantRole(MINTER_ROLE, _account);
    }

    /**
     *
     * @param _newInterestRate The new interest rate to be set
     * @notice This function sets the interest rate for the Rebase token
     * @notice The interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) public onlyOwner {
        if (_newInterestRate > interestRate) {
            revert("Interest rate can only decrease");
        }
        interestRate = _newInterestRate;
        emit InterestRateChanged(interestRate);
    }

    function mint(address _to, uint256 _amount,uint256 _userInterestRate) external onlyRole(MINTER_ROLE) {
        _mintAccruedInterest(_to);
        userInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINTER_ROLE) {
        _mintAccruedInterest(_from);
        userInterestRate[_from] = interestRate;
        _burn(_from, _amount);
    }

    function balanceOf(address account) public view override returns (uint256) {
        uint256 balance = super.balanceOf(account);
        return balance * calculateAccruedInterest(account) / PRECISION_FACTOR;
    }
    /**
     * @param recipient The address to transfer the tokens to
     * @param amount The amount of tokens to transfer
     * @notice This function transfers the tokens to the recipient
     * @notice It also mints the accrued interest to the sender and the recipient
     * @notice The interest is calculated using the formula:
     * @notice interest = principal * (1 + interestRate * timeElapsed)
     *
     */

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(recipient);
        if (amount == type(uint256).max) {
            amount = balanceOf(msg.sender);
        }
        userInterestRate[recipient] = interestRate;
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _mintAccruedInterest(sender);
        _mintAccruedInterest(recipient);
        if (amount == type(uint256).max) {
            amount = balanceOf(sender);
        }
        userInterestRate[recipient] = interestRate;
        return super.transferFrom(sender, recipient, amount);
    }

    function calculateAccruedInterest(address _user) public view returns (uint256 linearInterest) {
        uint256 timeElapsed = block.timestamp - last_Updated[_user];
        linearInterest = PRECISION_FACTOR + (timeElapsed * userInterestRate[_user] * PRECISION_FACTOR / (365 days));
    }
    /**
     *
     * @param _user The user to mint the accrued interest to
     * @notice This function mints the accrued interest to the user
     * @notice The interest is calculated using the formula:
     * @notice interest = principal * (1 + interestRate * timeElapsed)
     */

    function _mintAccruedInterest(address _user) internal {
        // find principal balance of rwt tokens that have been minted
        uint256 principleBalance = super.balanceOf(_user);
        // calculate their current balance including interest
        uint256 currentBalance = balanceOf(_user);
        // calculate number of tokens to be minted
        uint256 balanceIncreased = currentBalance - principleBalance;

        last_Updated[_user] = block.timestamp;
        _mint(_user, balanceIncreased);
    }

    function getUserInterestRate(address _user) public view returns (uint256) {
        return userInterestRate[_user];
    }

    function getInterestRate() public view returns (uint256) {
        return interestRate;
    }

    function principleBalanceOf(address _user) public view returns (uint256) {
        return super.balanceOf(_user);
    }
}
