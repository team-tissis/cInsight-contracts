// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "./../../src/sbt/Sbt.sol";
import "./../../src/sbt/SbtImp.sol";
import "./../../src/skinnft/SkinNft.sol";

contract SbtTest is Test {
    address admin = address(0xad000); //TODO: executor に変更
    string baseURL = "https://thechaininsight.github.io/";
    Sbt internal sbt;
    SbtImp internal sbtImp;
    SkinNft internal skinNft;

    function setUp() public {
        sbt = new Sbt();
        sbtImp = new SbtImp();
        skinNft = new SkinNft(string.concat(baseURL, "skinnft/"));

        sbt.init(
            admin,
            "ChainInsight",
            "SBT",
            string.concat(baseURL, "sbt/"),
            address(skinNft),
            address(sbtImp)
        );
        skinNft.init(address(sbt));
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
        assertEq(address(sbt).balance, 20 ether);

        // test referral mint
        payable(beef).call{value: 20 ether}("");

        vm.prank(thisContract);
        address(sbt).call(abi.encodeWithSignature("refer(address)", beef));
        vm.prank(beef);
        address(sbt).call{value: 20 ether}(
            abi.encodeWithSignature("mintWithReferral(address)", thisContract)
        );
        assertEq(address(sbt).balance, 25 ether);
        assertEq(address(beef).balance, 5 ether);
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
    receive() external payable {}
}
