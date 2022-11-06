// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "./../../src/bonfire/BonfireProxy.sol";
import "./../../src/bonfire/BonfireLogic.sol";
import "./../../src/skinnft/SkinNft.sol";

contract BonfireTest is Test {
    address admin = address(0xad000); //TODO: executor に変更
    string baseURL = "https://thechaininsight.github.io/";
    Bonfire internal bonfire;
    BonfireLogic internal bonfireLogic;
    SkinNft internal skinNft;
    uint256 sbtPrice = 0.1 ether;

    function setUp() public {
        bonfire = new Bonfire();
        bonfireLogic = new BonfireLogic();
        skinNft = new SkinNft(string.concat(baseURL, "skinnft/"));

        bonfire.init(
            admin,
            "ChainInsight",
            "BONFIRE",
            string.concat(baseURL, "bonfire/metadata/"),
            sbtPrice,
            address(skinNft),
            address(bonfireLogic)
        );
        skinNft.init(address(bonfire));
    }

    function testInit() public {
        assertEq(bonfire.name(), "ChainInsight");
        assertEq(bonfire.symbol(), "BONFIRE");
        assertEq(bonfire.executor(), admin);
    }

    function testSupportsInterface() public {
        assertEq(bonfire.supportsInterface(0x01ffc9a7), true);
        assertEq(bonfire.supportsInterface(0x5b5e139f), true);
    }

    function testMint() public {
        uint256 init_balance = 40 ether;
        uint256 sbtPrice = 0.1 ether;
        address manA = address(0xa);
        payable(manA).call{value: init_balance}("");

        address manB = address(0xb);
        payable(manB).call{value: init_balance}("");

        address manC = address(0xc);
        payable(manC).call{value: init_balance}("");

        address manD = address(0xd);
        payable(manD).call{value: init_balance}("");

        address manE = address(0xe);
        payable(manE).call{value: init_balance}("");

        address manF = address(0xf);
        payable(manF).call{value: init_balance}("");

        address beef = address(0xbeef);
        payable(beef).call{value: init_balance}("");

        //mint
        vm.prank(manA);
        address(bonfire).call{value: 26 ether}(
            abi.encodeWithSignature("mint()")
        );
        assertEq(bonfire.ownerOf(1), manA);
        assertEq(bonfire.tokenIdOf(manA), 1);
        assertEq(init_balance - sbtPrice, manA.balance);
        assertEq(sbtPrice, address(bonfire).balance);

        vm.prank(manB);
        address(bonfire).call{value: 26 ether}(
            abi.encodeWithSignature("mint()")
        );
        assertEq(bonfire.ownerOf(2), manB);
        assertEq(bonfire.tokenIdOf(manB), 2);

        vm.prank(manC);
        address(bonfire).call{value: 26 ether}(
            abi.encodeWithSignature("mint()")
        );
        vm.prank(manD);
        address(bonfire).call{value: 26 ether}(
            abi.encodeWithSignature("mint()")
        );
        vm.prank(manE);
        bool zero;
        bytes memory retData;
        (zero, retData) = address(bonfire).call{value: 20 ether}(
            abi.encodeWithSignature("mint()")
        );
        assertEq(abi.decode(retData, (uint256)), 5);
        assertEq(bonfire.mintedTokenNumber(), 5);

        //tokenURI
        vm.expectRevert(
            bytes("ERC721URIStorage: URI query for nonexistent token")
        );
        bonfire.tokenURI(10);

        string memory tokenuri = bonfire.tokenURI(4);
        assertEq(
            tokenuri,
            "https://thechaininsight.github.io/bonfire/metadata/0/1/4"
        );

        // test add favo
        vm.prank(manA);
        address(bonfire).call(
            abi.encodeWithSignature("addFavos(address,uint8)", manB, 5)
        );
        assertEq(bonfire.favoOf(manA), 5);
        assertEq(bonfire.makiMemoryOf(manB), 25);

        vm.prank(manA);
        address(bonfire).call(
            abi.encodeWithSignature("addFavos(address,uint8)", manC, 4)
        );
        assertEq(bonfire.favoOf(manA), 9);
        assertEq(bonfire.makiMemoryOf(manC), 20);

        vm.prank(manA);
        address(bonfire).call(
            abi.encodeWithSignature("addFavos(address,uint8)", manD, 2)
        );
        assertEq(bonfire.favoOf(manA), 10);
        assertEq(bonfire.makiMemoryOf(manD), 5);

        vm.expectRevert(bytes("favo num must be bigger than 0"));
        vm.prank(manA);
        address(bonfire).call(
            abi.encodeWithSignature("addFavos(address,uint8)", manC, 0)
        );

        //month init
        address(bonfire).call(abi.encodeWithSignature("monthInit()"));
        assertEq(bonfire.makiOf(manA), 1);
        assertEq(bonfire.gradeOf(manA), 2);
        assertEq(bonfire.gradeOf(manB), 5);
        assertEq(bonfire.gradeOf(manC), 4);
        assertEq(bonfire.gradeOf(manD), 3);
        assertEq(bonfire.gradeOf(manE), 1);

        // // test referral mint

        vm.prank(manB);
        address(bonfire).call(abi.encodeWithSignature("refer(address)", beef));
        vm.prank(beef);
        address(bonfire).call{value: 20 ether}(
            abi.encodeWithSignature("mintWithReferral(address)", manB)
        );

        assertEq(bonfire.makiMemoryOf(manB), 10); // + 10
        assertEq(address(manB).balance, init_balance - sbtPrice + sbtPrice / 4);
        assertEq(address(beef).balance, init_balance - sbtPrice / 2);

        // check distance for addFavo is working.
        vm.prank(beef);
        address(bonfire).call(
            abi.encodeWithSignature("addFavos(address,uint8)", manB, 1)
        );
        assertEq(bonfire.makiMemoryOf(manB), 11); // + 10
    }

    // function testSetadmin() public {
    //     address newOwner = address(3);
    //     vm.prank(owner);
    //     (, bytes memory result) = address(bonfire).call(
    //         abi.encodeWithSignature("setadmin(address)", newOwner)
    //     );
    //     assertEq(bonfire.admin(), newOwner);

    //     vm.expectRevert(bytes("OWNER ONLY"));
    //     address(bonfire).call(
    //         abi.encodeWithSignature("setadmin(address)", newOwner)
    //     );
    // }
    receive() external payable {}
}
