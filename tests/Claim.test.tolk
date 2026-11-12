import "@contracts/types"
import "@tests/nft-collection.test"
import "@wrappers/NftCollection.gen"
import "@wrappers/NftItem.gen"
import "@stdlib/gas-payments"
import "@acton/emulation/network"
import "@acton/emulation/testing"
import "@acton/testing/expect"
import "@contracts/messages"
import "@contracts/claim-types"
import "@wrappers/Claim.gen"

get fun `test claim rejects notification from wrong NFT item`() {
    val (contract, deployer, notDeployer) = setupClaimTest();

    val result = contract.sendNotificationForNewOwner(
        notDeployer.address,
        0,
        deployer.address,
        PayloadInline { value: createEmptySlice() },
        { value: grams("0.05"), bounce: true },
    );

    expect(result).toHaveFailedTx<NotificationForNewOwner>({
        from: notDeployer.address,
        to: contract.address,
        exitCode: 401,
    });
}

fun setupClaimTest(): (Claim, Treasury, Treasury) {
    val deployer = testing.treasury("deployer");
    val notDeployer = testing.treasury("notDeployer");

    val contract = Claim.fromStorage({
        saleAddress: notDeployer.address,
        nftItemAddress: deployer.address,
        extra: ClaimExtra {
            sellerAddress: deployer.address,
            buyerAddress: notDeployer.address,
            queryId: 0,
            received: false,
            confirmationBounced: false,
        }.toCell(),
    });

    val res = contract.deploy(deployer.address, { value: grams("1") });
    expect(res).toHaveSuccessfulDeploy({ to: contract.address });

    return (contract, deployer, notDeployer);
}

get fun `test claim rejects wrong query id`() {
    val (contract, deployer, _) = setupClaimTest();

    val result = contract.sendNotificationForNewOwner(
        deployer.address,
        1,
        deployer.address,
        PayloadInline { value: createEmptySlice() },
        { value: grams("0.05"), bounce: true },
    );

    expect(result).toHaveFailedTx<NotificationForNewOwner>({
        from: deployer.address,
        to: contract.address,
        exitCode: 402,
    });
}

get fun `test claim rejects wrong seller`() {
    val (contract, deployer, notDeployer) = setupClaimTest();

    val result = contract.sendNotificationForNewOwner(
        deployer.address,
        0,
        notDeployer.address,
        PayloadInline { value: createEmptySlice() },
        { value: grams("0.05"), bounce: true },
    );

    expect(result).toHaveFailedTx<NotificationForNewOwner>({
        from: deployer.address,
        to: contract.address,
        exitCode: 403,
    });
}

get fun `test claim rejects duplicate notification`() {
    val (contract, deployer, _) = setupClaimTest();

    val first = contract.sendNotificationForNewOwner(
        deployer.address,
        0,
        deployer.address,
        PayloadInline { value: createEmptySlice() },
        { value: grams("0.05"), bounce: true },
    );

    expect(first).toHaveSuccessfulTx<NotificationForNewOwner>({
        from: deployer.address,
        to: contract.address,
    });

    val second = contract.sendNotificationForNewOwner(
        deployer.address,
        0,
        deployer.address,
        PayloadInline { value: createEmptySlice() },
        { value: grams("0.05"), bounce: true },
    );

    expect(second).toHaveFailedTx<NotificationForNewOwner>({
        from: deployer.address,
        to: contract.address,
        exitCode: 404,
    });
}

get fun `test claim accepts real NFT item notification`() {
    val (collection, _, _) = setupTest();

    val seller = testing.treasury("integration-seller");
    val buyer = testing.treasury("integration-buyer");

    val nftItem = nftFixture(collection, seller.address);
    val queryId = 77;

    val claim = Claim.fromStorage({
        saleAddress: buyer.address,
        nftItemAddress: nftItem.address,
        extra: ClaimExtra {
            sellerAddress: seller.address,
            buyerAddress: buyer.address,
            queryId,
            received: false,
            confirmationBounced: false,
        }.toCell(),
    });

    val deployResult = claim.deploy(
        seller.address,
        { value: grams("1") },
    );

    expect(deployResult).toHaveSuccessfulDeploy({
        to: claim.address,
    });

    val transferResult = nftItem.sendAskToChangeOwnership(
        seller.address,
        queryId,
        claim.address,
        null,
        null,
        grams("0.01"),
        PayloadInline { value: createEmptySlice() },
        { value: grams("0.1"), bounce: true },
    );

    expect(transferResult).toHaveSuccessfulTx<AskToChangeOwnership>({
        from: seller.address,
        to: nftItem.address,
    });

    expect(transferResult).toHaveTx<NotificationForNewOwner>({
        from: nftItem.address,
        to: claim.address,
        bounce: false,
    });

    expect(transferResult).toHaveTx<ClaimConfirmed>({
        from: claim.address,
        to: buyer.address,
        body: ClaimConfirmed {
            queryId,
            nftItemAddress: nftItem.address,
            buyerAddress: buyer.address,
        }.toCell(),
    });

    val ownerAfterTransfer = nftItem.getNftData().ownerAddress;
    expect(ownerAfterTransfer!).toEqual(claim.address);
}
