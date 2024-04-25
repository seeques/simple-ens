//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ENS} from "src/Ens.sol";

contract EnsTest is Test {
    error IncorrectAmount();
    error OutOfBounds();
    error AlreadyRegistered();
    error NotOwner();

    struct Info {
        address user;
        uint96 timestamp;
        uint128 price;
        uint128 subscriptionEndsAt;
    }

    ENS internal ens;
    address internal user;

    function setUp() public {
        ens = new ENS(msg.sender, 1e18);
        user = address(uint160(uint256(keccak256("user"))));
        vm.deal(user, 1000e18);
    }

    function testFuzz_RegDom_RevertIf_OOB(uint96 amount) public {
        vm.assume(amount > 10);
        vm.expectRevert(OutOfBounds.selector);
        ens.registerDomain("name", amount);
        vm.expectRevert(OutOfBounds.selector);
        ens.registerDomain("name", 0);
    }

    function testFuzz_RegDom_RevertIf_IncorrectPrice(
        uint96 price,
        uint96 time
    ) public {
        vm.assume(time > 0 && time < 10);
        vm.assume(price < 1e18 * time);
        vm.expectRevert(IncorrectAmount.selector);
        ens.registerDomain{value: price}("name", time);
    }

    function testRegisterUser() public {
        registerUser("name");

        address _addr = ens.getAddress("name");
        assertEq(_addr, address(this));
    }

    function testFuzz_Register_TheSameDomainNameAfterExpiration(
        uint96 amount
    ) public {
        vm.warp(1641070800);
        string memory name = "name";
        registerUser(name);
        console.log(ens.getAddress(name));

        vm.assume(amount > 10 && amount < 10000000);
        uint256 timeToSkip = block.timestamp + (31536000 * amount);
        vm.warp(timeToSkip);

        vm.prank(user);
        registerUser(name);
        console.log(ens.getAddress(name));
    }

    function registerUser(string memory name) public {
        ens.registerDomain{value: 1e18 * 10}(name, 10);
    }
}
