// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "./../../src/sbt/Sbt.sol";
import "./../../src/sbt/SbtImp.sol";
import "./../../src/skinnft/SkinNft.sol";

contract SbtTest is Test {
    address admin = address(0xad000);
    address validator;
    Sbt internal sbt;
    SbtImp internal imp;
    SkinNft internal skinNft;

    function setUp() public {
        sbt = new Sbt();
        imp = new SbtImp();
        skinNft = new SkinNft("https://thechaininsight.github.io/skinnft/");

        sbt.init(
            admin,
            "ChainInsight",
            "SBT",
            "https://thechaininsight.github.io/sbt/",
            address(skinNft)
        );
        skinNft.init(address(sbt));
        bytes4[] memory sigs = new bytes4[](4);
        address[] memory impAddress = new address[](4);
        sigs[0] = bytes4(keccak256("mint()"));
        sigs[1] = bytes4(keccak256("mintWithReferral(address)"));
        sigs[2] = bytes4(keccak256("refer(address)"));
        sigs[3] = bytes4(keccak256("impInit()"));
        impAddress[0] = address(imp);
        impAddress[1] = address(imp);
        impAddress[2] = address(imp);
        impAddress[3] = address(imp);
        vm.prank(admin);
        sbt.setImplementation(sigs, impAddress);
        vm.prank(admin);
        address(sbt).call(abi.encodeWithSignature("impInit()"));
    }

    function testInit() public {
        assertEq(sbt.name(), "ChainInsight");
        assertEq(sbt.symbol(), "SBT");
        assertEq(sbt.admin(), admin);
    }

    function testSupportsInterface() public {
        assertEq(sbt.supportsInterface(0x01ffc9a7), true);
        assertEq(sbt.supportsInterface(0x5b5e139f), true);
    }

    function testMint() public {
        address beef = address(0xBEEF);
        address thisContract = address(this);
        address(sbt).call{value: 26 ether}(abi.encodeWithSignature("mint()"));
        assertEq(sbt.ownerOf(1), thisContract);
        vm.prank(beef);
        vm.expectRevert(bytes("Need to send more ETH"));
        address(sbt).call{value: 0 ether}(abi.encodeWithSignature("mint()"));

        // test referral mint
        payable(beef).transfer(20 ether);
        console.log(address(sbt).balance);

        vm.prank(thisContract);
        address(sbt).call(abi.encodeWithSignature("refer(address)", beef));
        vm.prank(beef);
        address(sbt).call{value: 15 ether}(
            abi.encodeWithSignature("mintWithReferral(address)", thisContract)
        );
    }

    // function testSetadmin() public {
    //     address newOwner = address(3);
    //     vm.prank(owner);
    //     (, bytes memory result) = address(sbt).call(
    //         abi.encodeWithSignature("setadmin(address)", newOwner)
    //     );
    //     assertEq(sbt.admin(), newOwner);

    //     vm.expectRevert(bytes("OWNER ONLY"));
    //     address(sbt).call(
    //         abi.encodeWithSignature("setadmin(address)", newOwner)
    //     );
    // }
}
