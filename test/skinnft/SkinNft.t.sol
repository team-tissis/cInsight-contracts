// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "./../../src/sbt/Sbt.sol";
import "./../../src/sbt/SbtImp.sol";
import "./../../src/skinnft/SkinNft.sol";

contract SkinNftTest is Test {
    address admin = address(0xad000);
    Sbt internal sbt;
    SbtImp internal imp;
    SkinNft internal skinNft;

    function setUp() public {
        // admin = vm.addr(admin);
        sbt = new Sbt();
        imp = new SbtImp();
        skinNft = new SkinNft("https://tissis.github.io/skinnft/");

        sbt.init(
            admin,
            "ChainInsight",
            "SBT",
            "https://tissis.github.io/sbt/metadata/",
            20 ether,
            address(skinNft),
            address(imp)
        );
        skinNft.init(address(sbt));
    }

    function testInit() public {
        assertEq(sbt.name(), "ChainInsight");
        assertEq(sbt.symbol(), "SBT");
        assertEq(sbt.executor(), admin);
    }

    function testSupportsInterface() public {
        assertEq(sbt.supportsInterface(0x01ffc9a7), true);
        assertEq(sbt.supportsInterface(0x5b5e139f), true);
    }

    function testSetBaseURI() public {
        assertEq(skinNft.baseURI(), "https://tissis.github.io/skinnft/");
        vm.prank(admin);
        sbt.setSkinnftBaseURI("https://newuri.github.io/skinnft/");
        assertEq(skinNft.baseURI(), "https://newuri.github.io/skinnft/");
    }

    function testMint() public {
        address beef = address(0xBEEF);
        address pork = address(409);
        address noki = address(0x0909);
        vm.deal(beef, 10000 ether);
        vm.deal(pork, 10000 ether);

        vm.prank(beef);
        address(sbt).call{value: 20 ether}(abi.encodeWithSignature("mint()"));
        vm.prank(pork);
        address(sbt).call{value: 20 ether}(abi.encodeWithSignature("mint()"));

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

        //TODO: these comment out should be executed when the nft airdrop is stopped

        // assertEq(skinNft.getFreemintQuantity(beef), 2);
        // assertEq(skinNft.getFreemintQuantity(address(1)), 0);
        // vm.prank(pork);
        // skinNft.freeMint();

        // vm.prank(noki);
        // vm.expectRevert(bytes("NOT FREEMINTABLE"));
        // skinNft.freeMint();

        // vm.startPrank(beef);
        // skinNft.freeMint();
        // assertEq(skinNft.ownerOf(1), pork);
        // skinNft.setIcon(3);
        // assertEq(skinNft.getIcon(beef), 3);

        // vm.expectRevert(bytes("THE TOKEN IS OWNED BY OTHER PERSON"));
        // skinNft.setIcon(1);
        // skinNft.tokenURI(1);

        uint256[] memory beefToken = new uint256[](2);
        beefToken[0] = 0;
        beefToken[1] = 1;
        assertEq(skinNft.tokensOfOwner(beef), beefToken);
        assertEq(
            sbt.tokenURI(1),
            "https://tissis.github.io/sbt/metadata/0/1/1"
        );
    }
}
