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
        // admin = vm.addr(admin);
        sbt = new Sbt();
        imp = new SbtImp();
        skinNft = new SkinNft("https://thechaininsight.github.io/skinnft/");

        sbt.init(admin, "ChainInsight", "SBT", "example://", address(skinNft));

        skinNft.init(address(sbt));
        bytes4[] memory sigs = new bytes4[](2);
        address[] memory impAddress = new address[](2);
        sigs[0] = bytes4(keccak256("mint(address,uint256,uint256,bytes)"));
        sigs[1] = bytes4(keccak256("setFreemintQuantity(address,uint256)"));
        impAddress[0] = address(imp);
        impAddress[1] = address(imp);
        vm.prank(admin);
        sbt.setImplementation(sigs, impAddress);
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

    function testSetFreemintQuantity() public {
        address beef = address(0xBEEF);
        address pork = address(409);
        address noki = address(0x0909);
        assertEq(skinNft.getFreemintQuantity(beef), 0);
        vm.prank(admin);
        address(sbt).call(
            abi.encodeWithSignature(
                "setFreemintQuantity(address,uint256)",
                address(beef),
                uint256(2)
            )
        );

        vm.prank(admin);
        address(sbt).call(
            abi.encodeWithSignature(
                "setFreemintQuantity(address,uint256)",
                address(pork),
                uint256(2)
            )
        );

        assertEq(skinNft.getFreemintQuantity(beef), 2);
        assertEq(skinNft.getFreemintQuantity(address(1)), 0);
        vm.prank(pork);
        skinNft.freeMint();

        vm.prank(noki);
        vm.expectRevert(bytes("NOT FREEMINTABLE"));
        skinNft.freeMint();

        vm.startPrank(beef);
        skinNft.freeMint();
        assertEq(skinNft.ownerOf(1), pork);
        skinNft.setIcon(3);
        assertEq(skinNft.getIcon(beef), 3);

        vm.expectRevert(bytes("THE TOKEN IS OWNED BY OTHER PERSON"));
        skinNft.setIcon(1);
        skinNft.tokenURI(1);
    }
}
