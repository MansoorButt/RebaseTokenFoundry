// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IRebaseToken} from "./interface/IRebase.sol";

contract Vault {

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    IRebaseToken private immutable i_rebaseToken;

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    function deposit() external payable{
         i_rebaseToken.mint(msg.sender, msg.value, i_rebaseToken.getInterestRate());
        emit Deposit(msg.sender, msg.value);
    }

    function redeem(uint256 _amount) external {
         if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        i_rebaseToken.burn(msg.sender, _amount);
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if(!success) {
            revert("Transfer failed.");
        }
        emit Redeem(msg.sender, _amount);
    }

    function getRebaseTokenAddress() public view returns (address) {
        return address(i_rebaseToken);
    }

}