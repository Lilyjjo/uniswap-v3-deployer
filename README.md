# Uniswap V3 Deployer for Testing

This repo is setup to deploy a UniswapV3 pool setup for testing purposes. It deploys the following contracts:
- `UniswapV3Factory`
- `UniswapV3Pool`
- `UniswapV3NonfungiblePositionManager`
- `UniswapV3SwapRouter`
- `ERC20`s with admin minting priviledges

It additionally initializes the pool's tick square root spacing and initial observation cardinality capacity. It also optionally adds initial liquidity and sets up a swapper for swapping by giving them tokens and approving the SwapRouter. 

## How to Run
1. Clone the repo and initialize the submodules:
        ```
        git clone https://github.com/Lilyjjo/uniswap-v3-deployer
        git submodule update --recursive
        ```

2. Clone `.sample_env` to `.env` and fill out initial EOA private/public key pairs.
3. Deploy the setup:
    ```
    forge script script/Deployments.s.sol:Deployments  --broadcast --legacy -vvvv --sig "deployUniswapV3(bool)" true --fork-url {YOUR FORK URL}
    ```
    Setting the bool to `false` will skip adding liquidity and preparing a swapper. 

4. Put the outputted addresses into the `.env`

5. Run a swap:
        ```
        forge script script/Deployments.s.sol:Deployments --broadcast --legacy -vv --sig "performSwap()" --fork-url {YOUR FORK URL}
        ```

## Uniswap Code Notes
UniswapV3 is a PITA to modify and to launch. I created a [fork](https://github.com/Lilyjjo/univ3-0.8-periphery-codehash-fixed) of [uniswap/v3-periphery](https://github.com/Lilyjjo/univ3-0.8-periphery-codehash-fixed) with a version that has the `POOL_INIT_CODE_HASH` updated with the correct value.
