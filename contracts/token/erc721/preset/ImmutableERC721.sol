// Copyright Immutable Pty Ltd 2018 - 2023
// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.19;

import {ImmutableERC721HybridBase} from "../abstract/ImmutableERC721HybridBase.sol";

contract ImmutableERC721 is ImmutableERC721HybridBase {
    ///     =====   Constructor  =====

    /**
     * @notice Grants `DEFAULT_ADMIN_ROLE` to the supplied `owner` address
     * @param owner_ The address to grant the `DEFAULT_ADMIN_ROLE` to
     * @param name_ The name of the collection
     * @param symbol_ The symbol of the collection
     * @param baseURI_ The base URI for the collection
     * @param contractURI_ The contract URI for the collection
     * @param operatorAllowlist_ The address of the operator allowlist
     * @param royaltyReceiver_ The address of the royalty receiver
     * @param feeNumerator_ The royalty fee numerator
     * @dev the royalty receiver and amount (this can not be changed once set)
     */
    uint256 public maxTotalSupplyByID; // Maximum supply for mintByID operations
    uint256 public maxTotalSupplyByBatch; // Maximum supply for mintByBatchQuantity operations
    uint256 public totalIDMinted; // Counter for total minted tokens (combined for simplicity)
    uint256 public totalBatchMinted; // Counter for total minted tokens (combined for simplicity)
    // Custom error for exceeding the maximum supply

    error ExceedsMaximumIDBasedSupply(uint256 attempted, uint256 maximum);
    error ExceedsMaximumBatchSupply(uint256 attempted, uint256 maximum);

    constructor(
        address owner_,
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        string memory contractURI_,
        address operatorAllowlist_,
        address royaltyReceiver_,
        uint96 feeNumerator_,
        uint256 maxTotalSupplyByID_, // Maximum supply for ID-based minting
        uint256 maxTotalSupplyByBatch_ // Maximum supply for batch minting
    )
        ImmutableERC721HybridBase(
            owner_,
            name_,
            symbol_,
            baseURI_,
            contractURI_,
            operatorAllowlist_,
            royaltyReceiver_,
            feeNumerator_
        )
    {
        maxTotalSupplyByID = maxTotalSupplyByID_;
        maxTotalSupplyByBatch = maxTotalSupplyByBatch_;
    }

    /**
     * @notice Allows minter to mint a token by ID to a specified address
     *  @param to the address to mint the token to
     *  @param tokenId the ID of the token to mint
     */
    function mint(address to, uint256 tokenId) external onlyRole(MINTER_ROLE) {
        if (maxTotalSupplyByID > 0 && totalIDMinted + 1 > maxTotalSupplyByID) {
            revert ExceedsMaximumIDBasedSupply(totalIDMinted + 1, maxTotalSupplyByID);
        }
        _mintByID(to, tokenId);
        totalIDMinted += 1;
    }

    /**
     * @notice Allows minter to mint a token by ID to a specified address with hooks and checks
     *  @param to the address to mint the token to
     *  @param tokenId the ID of the token to mint
     */
    function safeMint(address to, uint256 tokenId) external onlyRole(MINTER_ROLE) {
        if (maxTotalSupplyByID > 0 && totalIDMinted + 1 > maxTotalSupplyByID) {
            revert ExceedsMaximumIDBasedSupply(totalIDMinted + 1, maxTotalSupplyByID);
        }
        _safeMintByID(to, tokenId);
        totalIDMinted += 1;
    }

    /**
     * @notice Allows minter to mint a number of tokens sequentially to a specified address
     *  @param to the address to mint the token to
     *  @param quantity the number of tokens to mint
     */
    function mintByQuantity(address to, uint256 quantity) external onlyRole(MINTER_ROLE) {
        if (maxTotalSupplyByBatch > 0 && totalBatchMinted + quantity > maxTotalSupplyByBatch) {
            revert ExceedsMaximumBatchSupply(totalBatchMinted + 1, maxTotalSupplyByBatch);
        }
        _mintByQuantity(to, quantity);
        totalBatchMinted += quantity;
    }

    /**
     * @notice Allows minter to mint a number of tokens sequentially to a specified address with hooks
     *  and checks
     *  @param to the address to mint the token to
     *  @param quantity the number of tokens to mint
     */
    function safeMintByQuantity(address to, uint256 quantity) external onlyRole(MINTER_ROLE) {
        if (maxTotalSupplyByBatch > 0 && totalBatchMinted + quantity > maxTotalSupplyByBatch) {
            revert ExceedsMaximumBatchSupply(totalBatchMinted + 1, maxTotalSupplyByBatch);
        }
        _safeMintByQuantity(to, quantity);
        totalBatchMinted += quantity;
    }

    /**
     * @notice Allows minter to mint a number of tokens sequentially to a number of specified addresses
     *  @param mints the list of Mint struct containing the to, and the number of tokens to mint
     */
    function mintBatchByQuantity(Mint[] calldata mints) external onlyRole(MINTER_ROLE) {
        // Only calculate total quantity if a max supply is set
        if (maxTotalSupplyByBatch > 0) {
            uint256 totalQuantity = 0;
            for (uint256 i = 0; i < mints.length; i++) {
                totalQuantity += mints[i].quantity;
            }

            // Check if the total quantity to be minted exceeds the max supply
            if (totalBatchMinted + totalQuantity > maxTotalSupplyByBatch) {
                revert ExceedsMaximumBatchSupply({
                    attempted: totalBatchMinted + totalQuantity,
                    maximum: maxTotalSupplyByBatch
                });
            }
        }

        // Proceed with minting directly if no max supply is enforced
        _mintBatchByQuantity(mints);
    }

    /**
     * @notice Allows minter to safe mint a number of tokens by ID to a number of specified
     *  addresses with hooks and checks. Check ERC721Hybrid for details on _mintBatchByIDToMultiple
     *  @param mints the list of IDMint struct containing the to, and tokenIds
     */
    function safeMintBatchByQuantity(Mint[] calldata mints) external onlyRole(MINTER_ROLE) {
        // If maxTotalSupplyByBatch is set, calculate total quantity and perform the supply check
        if (maxTotalSupplyByBatch > 0) {
            uint256 totalQuantity = 0;
            for (uint256 i = 0; i < mints.length; i++) {
                totalQuantity += mints[i].quantity;
            }

            if (totalBatchMinted + totalQuantity > maxTotalSupplyByBatch) {
                revert ExceedsMaximumBatchSupply(totalBatchMinted + totalQuantity, maxTotalSupplyByBatch);
            }

            // Perform the minting operation if supply checks pass
            for (uint256 i = 0; i < mints.length; i++) {
                _safeMintByQuantity(mints[i].to, mints[i].quantity); // Ensure this is a safe minting operation
            }
            totalBatchMinted += totalQuantity;
        } else {
            // Directly proceed with minting if no max supply is enforced
            for (uint256 i = 0; i < mints.length; i++) {
                _safeMintByQuantity(mints[i].to, mints[i].quantity);
                // Update totalBatchMinted for each mint operation
                totalBatchMinted += mints[i].quantity;
            }
        }
    }

    /**
     * @notice Allows minter to safe mint a number of tokens by ID to a number of specified
     *  addresses with hooks and checks. Check ERC721Hybrid for details on _safeMintBatchByIDToMultiple
     *  @param mints the list of IDMint struct containing the to, and tokenIds
     */
    function safeMintBatch(IDMint[] calldata mints) external onlyRole(MINTER_ROLE) {
        // Only calculate total tokens and perform the supply check if maxTotalSupplyByID is set
        if (maxTotalSupplyByID > 0) {
            uint256 totalTokens = 0;
            for (uint256 i = 0; i < mints.length; i++) {
                totalTokens += mints[i].tokenIds.length;
            }

            if (totalIDMinted + totalTokens > maxTotalSupplyByID) {
                revert ExceedsMaximumIDBasedSupply(totalIDMinted + totalTokens, maxTotalSupplyByID);
            }

            // Proceed with minting only if the supply check passes
            for (uint256 i = 0; i < mints.length; i++) {
                IDMint calldata mint = mints[i];
                for (uint256 j = 0; j < mint.tokenIds.length; j++) {
                    _safeMint(mint.to, mint.tokenIds[j], ""); // Implement your ERC721-compliant safe minting here
                }
            }
            totalIDMinted += totalTokens;
        } else {
            // Directly proceed with minting if no max supply is enforced
            for (uint256 i = 0; i < mints.length; i++) {
                IDMint calldata mint = mints[i];
                for (uint256 j = 0; j < mint.tokenIds.length; j++) {
                    _safeMint(mint.to, mint.tokenIds[j], "");
                    totalIDMinted++; // Increment for each minted token
                }
            }
        }
    }

    /**
     * @notice Allows caller to a burn a number of tokens by ID from a specified address
     *  @param burns the IDBurn struct containing the to, and tokenIds
     */
    function safeBurnBatch(IDBurn[] calldata burns) external {
        _safeBurnBatch(burns);
    }

    /**
     * @notice Allows caller to a transfer a number of tokens by ID from a specified
     *  address to a number of specified addresses
     *  @param tr the TransferRequest struct containing the from, tos, and tokenIds
     */
    function safeTransferFromBatch(TransferRequest calldata tr) external {
        if (tr.tokenIds.length != tr.tos.length) {
            revert IImmutableERC721MismatchedTransferLengths();
        }

        for (uint256 i = 0; i < tr.tokenIds.length; i++) {
            safeTransferFrom(tr.from, tr.tos[i], tr.tokenIds[i]);
        }
    }
}
