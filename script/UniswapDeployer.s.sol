// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "../lib/forge-std/src/Script.sol";

import {IUniswapV3Factory} from "../lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "../lib/v3-periphery-fixed/contracts/interfaces/INonfungiblePositionManager.sol";
import {ISwapRouter} from "../lib/v3-periphery-fixed/contracts/interfaces/ISwapRouter.sol";
import {ERC20Mintable} from "../src/ERC20Mintable.sol";
import {TickMath} from "../lib/v3-core/contracts/libraries/TickMath.sol";

/**
 * @title UniswapBase
 * @author lilyjjo
 * @notice Code for setting up  uniswap v3 pool
 */
contract UniswapDeployer is Script {
    // (uniswap): code realted to uniV3 initialization and use
    struct DeploymentInfo {
        address token0;
        address token1;
        address pool;
        address nftPositionManager;
        address factory;
        address swapRouter;
        address admin;
        uint256 adminPk;
    }

    uint24 constant POOL_FEE = 3000;

    function _deployUniswapConracts(
        address admin,
        uint256 adminPk
    ) internal returns (DeploymentInfo memory newDInfo) {
        newDInfo.admin = admin;
        newDInfo.adminPk = adminPk;

        vm.startBroadcast(adminPk);

        // initialize token0/token1/WETH
        ERC20Mintable token0;
        ERC20Mintable token1;

        {
            address tokenA = address(new ERC20Mintable("A", "A"));
            address tokenB = address(new ERC20Mintable("B", "B"));
            if (tokenA < tokenB) {
                token0 = ERC20Mintable(tokenA);
                token1 = ERC20Mintable(tokenB);
            } else {
                token0 = ERC20Mintable(tokenB);
                token1 = ERC20Mintable(tokenA);
            }
        }
        ERC20Mintable WETH = new ERC20Mintable("WETH", "WETH");

        newDInfo.token0 = address(token0);
        newDInfo.token1 = address(token1);

        console2.log("token0: ");
        console2.log(address(token0));
        console2.log("token1: ");
        console2.log(address(token1));
        console2.log("WETH: ");
        console2.log(address(WETH));

        // initialize Factory
        IUniswapV3Factory uniswapV3Factory = IUniswapV3Factory(
            deployCode("UniswapV3Factory.sol")
        );

        newDInfo.factory = address(uniswapV3Factory);
        console2.log("uniswapV3Factory: ");
        console2.log(address(uniswapV3Factory));

        // initialize Pool
        IUniswapV3Pool pool = IUniswapV3Pool(
            uniswapV3Factory.createPool(
                address(token0),
                address(token1),
                POOL_FEE
            )
        );

        newDInfo.pool = address(pool);
        console2.log("pool: ");
        console2.log(address(pool));

        int24 tickSpacing = pool.tickSpacing();
        int24 targetStartTick = 0;
        targetStartTick = targetStartTick < 0
            ? -((-targetStartTick / tickSpacing) * tickSpacing)
            : (targetStartTick / tickSpacing) * tickSpacing;

        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(targetStartTick);
        pool.initialize(sqrtPriceX96);

        // grow available observations in pool
        pool.increaseObservationCardinalityNext(10);

        // initialize PositionManager
        INonfungiblePositionManager positionManager = INonfungiblePositionManager(
                deployCode(
                    "NonfungiblePositionManager.sol",
                    abi.encode(
                        address(uniswapV3Factory),
                        address(WETH),
                        "Test token descriptor",
                        address(pool)
                    )
                )
            );

        newDInfo.nftPositionManager = address(positionManager);
        console2.log("positionManager: ");
        console2.log(address(positionManager));

        // initialize swapRouter
        ISwapRouter swapRouter = ISwapRouter(
            deployCode(
                "SwapRouter.sol",
                abi.encode(
                    address(uniswapV3Factory),
                    address(WETH),
                    address(pool)
                )
            )
        );

        newDInfo.swapRouter = address(swapRouter);
        console2.log("swapRouter: ");
        console2.log(address(swapRouter));

        vm.stopBroadcast();
    }

    /**
     * @notice adds liquidity to contracts
     * @dev command: forge script script/Interactions.s.sol:Interactions --sig "addLiquidity()" --broadcast --legacy -vv --verify
     */
    function _addLiquidity(
        address liquidityProvider,
        uint256 liquidityProviderPrivateKey,
        DeploymentInfo memory dInfo
    ) internal {
        _addLiquidityInternal(
            liquidityProvider,
            liquidityProviderPrivateKey,
            10 ether,
            10 ether,
            true,
            dInfo
        );
    }

    function _swap(
        address swapper,
        uint256 swapperPk,
        address router,
        address token0,
        address token1,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut
    ) internal {
        // scoping for stack too deep errors
        address tokenOut = tokenIn == token0 ? token1 : token0;

        ISwapRouter.ExactInputSingleParams memory swapParams;
        swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: POOL_FEE,
            recipient: swapper,
            deadline: block.timestamp + 10000,
            amountIn: amountIn,
            amountOutMinimum: amountOut,
            sqrtPriceLimitX96: 0
        });

        vm.startBroadcast(swapperPk);
        ISwapRouter(router).exactInputSingle(swapParams);
        vm.stopBroadcast();
    }

    function _fundSwapperApproveSwapRouter(
        address user,
        uint256 userPrivateKey,
        DeploymentInfo memory dInfo
    ) internal {
        _fundAndApprove(
            user,
            userPrivateKey,
            dInfo.swapRouter,
            dInfo.token0,
            10 ether,
            dInfo
        );
        _fundAndApprove(
            user,
            userPrivateKey,
            dInfo.swapRouter,
            dInfo.token1,
            10 ether,
            dInfo
        );
    }

    /**
     * @notice Helper function to give funds and approve a third
     * party to spend those funds.
     */
    function _fundAndApprove(
        address user,
        uint256 userPrivateKey,
        address approved,
        address token,
        uint256 amount,
        DeploymentInfo memory dInfo
    ) internal {
        vm.startBroadcast(dInfo.adminPk);
        ERC20Mintable(token).mint(user, amount);
        vm.stopBroadcast();
        vm.startBroadcast(userPrivateKey);
        ERC20Mintable(token).approve(approved, type(uint256).max);
        vm.stopBroadcast();
    }

    /**
     * @notice Adds liquidity.
     */
    function _addLiquidityInternal(
        address liquidityProvider,
        uint256 liquidtyProviderPrivateKey,
        uint256 token0Amount,
        uint256 token1Amount,
        bool mintTokens,
        DeploymentInfo memory dInfo
    ) internal returns (uint256, uint256) {
        if (mintTokens) {
            // mint liquidity provider tokens
            _fundAndApprove(
                liquidityProvider,
                liquidtyProviderPrivateKey,
                dInfo.nftPositionManager,
                dInfo.token0,
                token0Amount,
                dInfo
            );
            _fundAndApprove(
                liquidityProvider,
                liquidtyProviderPrivateKey,
                dInfo.nftPositionManager,
                dInfo.token1,
                token1Amount,
                dInfo
            );
        }
        vm.startBroadcast(liquidtyProviderPrivateKey);

        // supply liquidty across whole range, adjusted for tick spacing needs
        int24 tickSpacing = IUniswapV3Pool(dInfo.pool).tickSpacing();
        int24 tickLower = -887272;
        int24 tickUpper = -tickLower;
        tickLower = tickLower < 0
            ? -((-tickLower / tickSpacing) * tickSpacing)
            : (tickLower / tickSpacing) * tickSpacing;
        tickUpper = tickUpper < 0
            ? -((-tickUpper / tickSpacing) * tickSpacing)
            : (tickUpper / tickSpacing) * tickSpacing;

        INonfungiblePositionManager.MintParams
            memory mintParams = INonfungiblePositionManager.MintParams({
                token0: address(dInfo.token0),
                token1: address(dInfo.token1),
                fee: POOL_FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: token0Amount,
                amount1Desired: token1Amount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: liquidityProvider,
                deadline: 1903732493
            });

        (
            ,
            /*uint256 tokenId*/
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        ) = INonfungiblePositionManager(dInfo.nftPositionManager).mint(
                mintParams
            );

        console2.log("Liquidity added: %d", liquidity);
        console2.log("amount0: %d", amount0);
        console2.log("amount1: %d", amount1);

        vm.stopBroadcast();

        return (amount0, amount1);
    }
}
