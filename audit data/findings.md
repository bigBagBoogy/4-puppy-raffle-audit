### [M-1] Looping through players array to check for duplicates in `PuppyRaffle::enterRaffle` is a potential denial of service (DoS), incrementing gas costs for future entrants

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
  


**Recommended Mitigation**