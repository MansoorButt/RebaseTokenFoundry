// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {Vault} from "src/Vault.sol";
import {IRebaseToken} from "src/interface/IRebase.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintandBurnRole(address(vault));
        vm.deal(owner, 1e18);
        (bool success,) = payable(address(vault)).call{value: 1e18}("");
        vm.stopPrank();
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, 1e18);

        // Deal ETH to user
        vm.deal(user, amount);

        // Switch to user for deposit
        vm.startPrank(user);

        // User deposits ETH to get rebase tokens
        vault.deposit{value: amount}();

        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("startBalance", startBalance);
        assertEq(startBalance, amount);

        // Let's log the user's interest rate to understand what's happening
        uint256 userRate = rebaseToken.getUserInterestRate(user);
        console.log("User interest rate:", userRate);

        uint256 preciseStartBalance = rebaseToken.principleBalanceOf(user);
        console.log("Principle balance:", preciseStartBalance);

        // Advance time by 1 hour
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        console.log("Middle balance after 1 hour:", middleBalance);
        assertGt(middleBalance, startBalance);

        // Advance time by another hour
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        console.log("End balance after 2 hours:", endBalance);
        assertGt(endBalance, middleBalance);

        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 2);

        vm.stopPrank();
    }

    function testRedeemStraight(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);

        vault.deposit{value: amount}();
        uint256 initialBalance = rebaseToken.balanceOf(user);
        assertEq(initialBalance, amount);

        // Use the actual balance from balanceOf instead of type(uint96).max
        uint256 actualBalance = rebaseToken.balanceOf(user);
        vault.redeem(actualBalance);

        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);

        vm.stopPrank();
    }

    function testRedeemAfterSomeTime(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        console.log("Bound result", amount);

        vm.startPrank(user);
        vm.deal(user, amount);

        vault.deposit{value: amount}();
        uint256 initialBalance = rebaseToken.balanceOf(user);
        assertEq(initialBalance, amount);
        console.log("Initial balance:", initialBalance);

        // Advance time by 5 days
        vm.warp(block.timestamp + 5 days);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        console.log("Middle balance after 5 days:", middleBalance);
        assertGt(middleBalance, initialBalance);

        // Calculate the interest amount
        uint256 interestAmount = middleBalance - initialBalance;

        // Add more ETH to the vault to cover the interest payout
        vm.stopPrank();
        vm.startPrank(owner);
        vm.deal(owner, interestAmount);
        (bool success,) = payable(address(vault)).call{value: interestAmount}("");
        require(success, "Failed to add interest to vault");
        vm.stopPrank();

        vm.startPrank(user);
        // Use the actual balance from balanceOf
        uint256 actualBalance = rebaseToken.balanceOf(user);
        vault.redeem(actualBalance);

        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, middleBalance);

        vm.stopPrank();
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5+1e5, 1e18);
        amountToSend = bound(amountToSend, 1e5, amount-1e5);

        vm.startPrank(owner);
        rebaseToken.setInterestRate(4e10);
        vm.stopPrank();

        vm.startPrank(user);
        vm.deal(user, amount);

        vault.deposit{value: amount}();
        uint256 initialBalance = rebaseToken.balanceOf(user);
        assertEq(initialBalance, amount);

        // Transfer some tokens to another user
        address otherUser = makeAddr("otherUser");
        console.log("Amount To Send", amountToSend);
        console.log("Other user Balance:", rebaseToken.balanceOf(otherUser));
        vm.deal(otherUser, 0);
        rebaseToken.transfer(otherUser, amountToSend);
        console.log("User Balance after transfer:", rebaseToken.balanceOf(user));
        console.log("Other user Balance after transfer:", rebaseToken.balanceOf(otherUser));
        assertEq(rebaseToken.balanceOf(user), initialBalance - amountToSend);
        assertEq(rebaseToken.balanceOf(otherUser), amountToSend);
        assertEq(rebaseToken.getUserInterestRate(otherUser), 4e10);

        vm.stopPrank();

        
    }
}
