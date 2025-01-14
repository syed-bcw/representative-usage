// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

import {Applications} from "./Applications.s.sol";

// Open Zeppelin contracts
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
// Slightly hacked Open Zeppelin contracts
import {EIP712WithChanges} from "./EIP712WithChanges.sol";

// Immutable Contracts repo
import {ImmutableERC20MinterBurnerPermit} from "../src/im-contracts/token/erc20/preset/ImmutableERC20MinterBurnerPermit.sol";
import {ImmutableERC1155} from '../src/im-contracts/token/erc1155/preset/ImmutableERC1155.sol';

// Gem Game
import {GemGame} from "../src/im-contracts/games/gems/GemGame.sol";

// Hunters on Chain
import {Relayer} from "../src/hunters-on-chain/Relayer.sol";
import {Shards} from "../src/hunters-on-chain/Shards.sol";
import {BgemClaim, IBgem} from "../src/hunters-on-chain/Claim.sol";
import {HuntersOnChainClaimGame} from "../src/hunters-on-chain/HuntersOnChainClaimGame.sol";
import {Equipments} from "../src/hunters-on-chain/Equipments.sol";
import {Artifacts} from "../src/hunters-on-chain/Artifacts.sol";
import {Recipe, IBoom, IBgem as IBgem2, IMintable1155} from "../src/hunters-on-chain/Recipe.sol";
import {Fund} from "../src/hunters-on-chain/Fund.sol";

// Guild of Guardians
import {GuildOfGuardiansClaimGame} from "../src/guild-of-guardians/GuildOfGuardiansClaimGame.sol";

contract DeployAll is Applications {
    function run() public virtual {
        deployAll();
    }

    function deployAll() public {
        uint256 treasuryPKey = 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6;
        // Have this different for each run.
        string memory runName = RUN_NAME;
        if (vm.exists(path)) {
            vm.removeFile(path);
        }
        vm.writeLine(path, ("Execution Start *********************************"));
        console.logString(string(abi.encodePacked("Deployment address Information logged to: ", path)));

        setUpAccounts(treasuryPKey, runName);
        distributeNativeTokenToGamePlayers(runName);

        installCreate3Deployer();
        installPassportWallet();
        installSeaport();
        installGemGame();
        installRoyaltyAllowlist(); // Must be installed after Passport.
        installHuntersOnChain();
        installGuildOfGuardians();

        vm.closeFile(path);
    }

    function setUpAccounts(uint256 _treasuryPKey, string memory _runName) internal {
        vm.writeLine(path, "Run Name");
        vm.writeLine(path, _runName);
        console.logString(string(abi.encodePacked("Run Name: ", _runName)));

        address treasury = vm.addr(_treasuryPKey);
        vm.label(treasury, "treasury");
        if (treasury.balance == 0) {
            console.logString("ERROR: Treasury has 0 native gas token");
            revert("Treasury has 0 native gas token");
        }

        (root, rootPKey) = makeAddrAndKey(string(abi.encodePacked(_runName, "root")));
        vm.writeLine(path, "Root Address");
        vm.writeLine(path, Strings.toHexString(root));
        vm.writeLine(path, "Root PKey");
        vm.writeLine(path, Strings.toHexString(rootPKey));
        vm.startBroadcast(_treasuryPKey);
        payable(root).transfer(30 ether);
        if (root.balance == 0) {
            console.logString("ERROR: Root has 0 native gas token");
            revert("Root has 0 native gas token");
        }
        vm.stopBroadcast();

        (deployer, deployerPKey) = makeAddrAndKey(string(abi.encodePacked(_runName, "deployer")));
        vm.writeLine(path, "Deployer Address");
        vm.writeLine(path, Strings.toHexString(deployer));
        vm.writeLine(path, "Deployer PKey");
        vm.writeLine(path, Strings.toHexString(deployerPKey));
        vm.startBroadcast(rootPKey);
        payable(deployer).transfer(2 ether);
        if (deployer.balance == 0) {
            console.logString("ERROR: Deployer has 0 native gas token");
            revert("Deployer has 0 native gas token");
        }
        vm.stopBroadcast();

        (admin, adminPKey) = makeAddrAndKey(string(abi.encodePacked(_runName, "admin")));
        vm.writeLine(path, "Admin Address");
        vm.writeLine(path, Strings.toHexString(admin));
        vm.writeLine(path, "Admin PKey");
        vm.writeLine(path, Strings.toHexString(adminPKey));
        vm.startBroadcast(rootPKey);
        payable(admin).transfer(2 ether);
        if (admin.balance == 0) {
            console.logString("ERROR: Admin has 0 native gas token");
            revert("Admin has 0 native gas token");
        }
        vm.stopBroadcast();

        (relayer, relayerPKey) = makeAddrAndKey(string(abi.encodePacked(_runName, "relayer")));
        vm.writeLine(path, "Relayer Address");
        vm.writeLine(path, Strings.toHexString(relayer));
        vm.writeLine(path, "Relayer PKey");
        vm.writeLine(path, Strings.toHexString(relayerPKey));
        vm.startBroadcast(rootPKey);
        payable(relayer).transfer(5 ether);
        vm.stopBroadcast();

        // Off-chain signing, so no native tokens needed.
        (passportSigner, passportSignerPKey) = makeAddrAndKey(string(abi.encodePacked(_runName, "passportSigner")));
        vm.writeLine(path, "PassportSigner Address");
        vm.writeLine(path, Strings.toHexString(passportSigner));
        vm.writeLine(path, "PassportSigner PKey");
        vm.writeLine(path, Strings.toHexString(passportSignerPKey));

        (huntersOnChainMinter, huntersOnChainMinterPKey) = makeAddrAndKey(string(abi.encodePacked(_runName, "huntersOnChainMinter")));
        vm.writeLine(path, "HuntersOnChainMinter Address");
        vm.writeLine(path, Strings.toHexString(huntersOnChainMinter));
        vm.writeLine(path, "HuntersOnChainMinter PKey");
        vm.writeLine(path, Strings.toHexString(huntersOnChainMinterPKey));
        vm.startBroadcast(rootPKey);
        payable(huntersOnChainMinter).transfer(10 ether);
        vm.stopBroadcast();

        // Off-chain signing, so no native tokens needed.
        (huntersOnChainOffchainSigner, huntersOnChainOffchainSignerPKey) = makeAddrAndKey(string(abi.encodePacked(_runName, "huntersOnChainOffchainSigner")));
        vm.writeLine(path, "HuntersOnChainOffchainSigner Address");
        vm.writeLine(path, Strings.toHexString(huntersOnChainOffchainSigner));
        vm.writeLine(path, "HuntersOnChainOffchainSigner PKey");
        vm.writeLine(path, Strings.toHexString(huntersOnChainOffchainSignerPKey));
    }

    function installGemGame() private {
        vm.startBroadcast(deployerPKey);
        gemGame = new GemGame(admin, admin, admin);
        vm.writeLine(path, "GemGame deployed to address");
        vm.writeLine(path, Strings.toHexString(address(gemGame)));
        vm.stopBroadcast();
    }

    function installHuntersOnChain() private {
        address[] memory whiteListedMinters = new address[](1);
        whiteListedMinters[0] = huntersOnChainMinter;
        vm.startBroadcast(deployerPKey);
        huntersOnChainRelayer = new Relayer(whiteListedMinters);
        vm.stopBroadcast();
        vm.writeLine(path, "HuntersOnChainRelayer deployed to address");
        vm.writeLine(path, Strings.toHexString(address(huntersOnChainRelayer)));

        name = "BitGem";
        symbol = "BGEM";
        maxSupply = 1000000000000000000 ether;
        vm.startBroadcast(deployerPKey);
        bgemErc20 = new ImmutableERC20MinterBurnerPermit(admin, address(huntersOnChainRelayer), admin, name, symbol, maxSupply);
        vm.stopBroadcast();
        vm.startBroadcast(adminPKey);
        bgemErc20.grantMinterRole(huntersOnChainMinter);
        vm.stopBroadcast();
        vm.writeLine(path, "bgemErc20 deployed to address");
        vm.writeLine(path, Strings.toHexString(address(bgemErc20)));

        string memory baseURIe = "https://api-imx.boomland.io/api/e/";
        string memory contractURIe = "https://api-imx.boomland.io";
        vm.startBroadcast(deployerPKey);
        huntersOnChainEquipments = new Equipments(admin, admin, admin, admin, 1000, baseURIe, contractURIe, address(royaltyAllowlist));
        vm.stopBroadcast();
        vm.writeLine(path, "huntersOnChainEquipments deployed to address");
        vm.writeLine(path, Strings.toHexString(address(huntersOnChainEquipments)));

        string memory baseURIa = "https://api-imx.boomland.io/api/s/";
        string memory contractURIa = "https://api-imx.boomland.io";
        vm.startBroadcast(deployerPKey);
        huntersOnChainArtifacts = new Artifacts(admin, admin, admin, admin, 1000, baseURIa, contractURIa, address(royaltyAllowlist));
        vm.stopBroadcast();
        vm.writeLine(path, "huntersOnChainArtifacts deployed to address");
        vm.writeLine(path, Strings.toHexString(address(huntersOnChainArtifacts)));

        string memory baseURIs = "https://api-imx.boomland.io/api/s/{id}";
        string memory contractURIs = "https://api-imx.boomland.io/api/v1/shard";
        vm.startBroadcast(deployerPKey);
        huntersOnChainShards = new Shards(admin, address(huntersOnChainRelayer), admin, admin, 1000, baseURIs, contractURIs, address(royaltyAllowlist));
        vm.stopBroadcast();
        vm.writeLine(path, "huntersOnChainShards deployed to address");
        vm.writeLine(path, Strings.toHexString(address(huntersOnChainShards)));

        vm.startBroadcast(deployerPKey);
        huntersOnChainClaim = new BgemClaim(admin, IBgem(address(bgemErc20)), huntersOnChainOffchainSigner);
        huntersOnChainEIP712 = new EIP712WithChanges("Boomland Claim", "1", address(huntersOnChainClaim));
        vm.stopBroadcast();
        vm.startBroadcast(huntersOnChainMinterPKey);
        bgemErc20.mint(address(huntersOnChainClaim), 1000000 ether);
        vm.stopBroadcast();
        vm.writeLine(path, "huntersOnChainClaim deployed to address");
        vm.writeLine(path, Strings.toHexString(address(huntersOnChainClaim)));
        vm.writeLine(path, "huntersOnChainEIP712 deployed to address");
        vm.writeLine(path, Strings.toHexString(address(huntersOnChainEIP712)));

        vm.startBroadcast(deployerPKey);
        huntersOnChainClaimGame = new HuntersOnChainClaimGame(admin, admin, admin);
        vm.writeLine(path, "huntersOnChainClaimGame deployed to address");
        vm.writeLine(path, Strings.toHexString(address(huntersOnChainClaimGame)));
        vm.stopBroadcast();

        Recipe.IChestConfig memory chestOneConfig = Recipe.IChestConfig(170000, 0, HUNTERS_ON_CHAIN_COST, true);
        vm.startBroadcast(deployerPKey);
        huntersOnChainRecipe = new Recipe(
            uint32(block.chainid), huntersOnChainOffchainSigner, admin, 
            IBgem2(address(bgemErc20)), IBoom(address(0)),  
            IMintable1155(address(huntersOnChainArtifacts)), 
            IMintable1155(address(huntersOnChainEquipments)), 
            IMintable1155(address(huntersOnChainShards)));
        huntersOnChainRecipe.setChestConfig(HUNTERS_ON_CHAIN_CHEST1, chestOneConfig);
        vm.stopBroadcast();
        vm.writeLine(path, "huntersOnChainRecipe deployed to address");
        vm.writeLine(path, Strings.toHexString(address(huntersOnChainRecipe)));

        vm.startBroadcast(deployerPKey);
        huntersOnChainFund = new Fund(huntersOnChainMinter);
        vm.stopBroadcast();
        vm.writeLine(path, "huntersOnChainFund deployed to address");
        vm.writeLine(path, Strings.toHexString(address(huntersOnChainFund)));
    }


    function installGuildOfGuardians() private {
        vm.startBroadcast(deployerPKey);
        guildOfGuardiansClaimGame = new GuildOfGuardiansClaimGame(admin, admin, admin);
        vm.writeLine(path, "guildOfGuardiansClaimGame deployed to address");
        vm.writeLine(path, Strings.toHexString(address(guildOfGuardiansClaimGame)));
        vm.stopBroadcast();
    }

}
