*Hydro Lottery*

This lottery contract uses Hydro Snowflake Ids (EINs) for creating unique lotteries with rewards setup in HYDRO tokens instead of ETH. It's made of an HydroEscrow contract that holds HYDRO for each unique lottery, a Randomizer contract that generates random numbers with Oraclize for creating unique, secure randomised numbers for selecting winners and a HydroLottery contract that takes care of the main logic. Since we can't generate fully randomised numbers on the blockchain without risking security, we have to use an external oracle which in this case is Oraclize. It charges a small amount of ETH everytime it generates a random number for finishing lotteries and selecting winners.

**How to use it**
***Deployment***
1. First deploy an Identity Registry contract if you haven't already, a Hydro Token contract and a Randomizer contract. On rinkeby, use the official contract addresses, you still need to deploy a new Randomizer:
    HydroToken: 0x2df33c334146d3f2d9e09383605af8e3e379e180
    IdentityRegistry: 0xa7ba71305bE9b2DFEad947dc0E5730BA2ABd28EA

2. Deploy a new Hydro Lottery contract by setting up the identity registry, hydro token and randomizer addresses in the constructor.

3. Set the Hydro Lottery address on the Randomizer contract by using the `setHydroLottery()` function so that it can call the `endLottery()` function from the main Lottery contract with the randomly generated lottery winner. You can find a complete description of the steps in the tests.

4. Get a Snowflake EIN for you account in order to create a participate in lotteries since it's the main way of interacting with the lotteries instead of addresses. The contract automatically detects if you have an EIN associated with your account.

5. That should be it. You now should be able to use the Hydro Lottery contract.

***Creating a lottery***
After setting up the contracts you'll want to create a lottery. The way it's done is simple: approve some HYDRO to the Lottery contract and execute the `createLottery()` function with your desired lottery name, description, hydro price per ticket, hydro reward for the winner (how many tokens the winner gets), the start timestamp, the end timestamp, the fee and the fee receiver address. A fee is optional for those that want to get a portion of the earnings from that lottery. The fee must be between 0 and 100, for instance if you set a fee of 20, the fee receiver address will get the 20% of all the earnings including the lottery reward and the lottery tickets sold. In that case the winner will get 80% of the set hydro reward + an 80% of the earnings from tickets sold to that lottery while the fee receiver gets a 20% from the same sources.

When you run the create lottery function, a new HydroEscrow contract will be created associated to that lottery to hold all the funds raised in a secure independent environment. The only way to extract those tokens is to end the lottery with the `raffle()` function. After the lottery is created, the function will return the lottery ID which you can use to identify that lottery.

***Buying a ticket***
Users that want to participate in the lottery will have to buy a ticket by paying the specified hydro price per ticket, they can only participate once per lottery and they must have an EIN associated with their accounts to do so.


**Hydro Escrow**
Whenever a user creates a lottery with the `createLottery()` function, a new instance of the HydroEscrow contract is created
