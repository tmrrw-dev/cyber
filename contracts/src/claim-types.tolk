struct ClaimExtra {
    sellerAddress: address
    buyerAddress: address
    queryId: uint64
    received: bool
    confirmationBounced: bool
}

struct ClaimStorage {
    saleAddress: address
    nftItemAddress: address
    extra: Cell<ClaimExtra>
}

fun ClaimStorage.save(self) {
    contract.setData(self.toCell());
}

struct (0x434c4d31) ClaimConfirmed {
    queryId: uint64
    nftItemAddress: address
    buyerAddress: address
}
