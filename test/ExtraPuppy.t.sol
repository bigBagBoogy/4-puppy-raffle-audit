// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console2} from "lib/forge-std/src/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee_1e18 = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(entranceFee_1e18, feeAddress, duration);
    }

    function test_DenialOfService() public {
        vm.txGasPrice(1);
        // lets enter 100 players
        uint256 playersNum = 100;
        address[] memory players = new address[](playersNum);
        for (uint256 i; i < playersNum; i++) {
            players[i] = address(i); // this is a way to create an array of address with incrementing values (0 - 99
        }
        uint256 gasStart = gasleft(); // this is a checkpoint to check how much gas
        puppyRaffle.enterRaffle{value: entranceFee_1e18 * players.length}(players);
        uint256 gasEnd = gasleft();

        uint256 gasUsedFirst = (gasStart - gasEnd) * tx.gasprice;
        console2.log("Gas used first: ", gasUsedFirst);
    }
}
