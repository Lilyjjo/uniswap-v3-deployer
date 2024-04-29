// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {UniswapDeployer} from "./UniswapDeployer.s.sol";

/**
 * @title Deployment code uniswap v3
 * @author lilyjjo
 */
contract Deployments is UniswapDeployer {
    address public admin;
    uint256 public adminPk;

    address public liquidityProvider;
    uint256 public liquidityProviderPk;

    address public swapper;
    uint256 public swapperPk;

    /**
     * @notice Pulls environment variables
     */
    function setUp() public {
        // grab address/pk pairs
        admin = vm.envAddress("ADMIN");
        adminPk = uint256(vm.envBytes32("ADMIN_PK"));

        liquidityProvider = vm.envAddress("LIQUIDITY_PROVIDER");
        liquidityProviderPk = uint256(vm.envBytes32("LIQUIDITY_PROVIDER_PK"));

        swapper = vm.envAddress("SWAPPER");
        swapperPk = uint256(vm.envBytes32("SWAPPER_PK"));
    }

    /**
     * @notice Deploys and sets up new L1 contracts for testing
     * @dev creates and submits ~12 transactions, will take ~10 minutes to deploy depending on the target blockchain's blocktime
     * @dev command: forge script script/Deployments.s.sol:Deployments  --broadcast --legacy -vv --verify --sig "deployUniswapV3(bool)" true --fork-url https://ethereum-holesky-rpc.publicnode.com
     */
    function deployUniswapV3(bool initPoolState) public {
        UniswapDeployer.DeploymentInfo
            memory deploymentInfo = _deployUniswapConracts(admin, adminPk);

        if (initPoolState) {
            // Add state to uniswap contracts
            // note: only does new contract liquidity provisioning, all addresses need to have funds on the target L1 already

            // add liquidty to the pool
            _addLiquidity(
                liquidityProvider, // liquidity provider
                liquidityProviderPk,
                deploymentInfo
            );
            // give swappers tokens to swap with router
            _fundSwapperApproveSwapRouter(swapper, swapperPk, deploymentInfo);
        }
    }

    /**
     * @notice Makes a swap on the deployed uniswap v3 pool
     * @dev Need to set some addresses in the .env for this to work
     * @dev command: forge script script/Deployments.s.sol:Deployments  --broadcast --legacy -vv --sig "performSwap()" --fork-url https://ethereum-holesky-rpc.publicnode.com
     */
    function performSwap() public {
        swapper = vm.envAddress("SWAPPER");
        swapperPk = uint256(vm.envBytes32("SWAPPER_PK"));
        address router = vm.envAddress("SWAP_ROUTER_DEPLOYED");
        address token_0 = vm.envAddress("TOKEN_0_DEPLOYED");
        address token_1 = vm.envAddress("TOKEN_1_DEPLOYED");

        _swap(swapper, swapperPk, router, token_0, token_1, token_0, 10, 0);
    }
}
