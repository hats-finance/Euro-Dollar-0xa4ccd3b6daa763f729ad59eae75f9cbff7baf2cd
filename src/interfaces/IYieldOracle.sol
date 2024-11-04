// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface IYieldOracle {
    function assetsToShares(uint256 assets) external view returns (uint256);
    function sharesToAssets(uint256 shares) external view returns (uint256);
}
