import "claim-types"
import "messages"

contract Claim {
    author: "CYBER"
    version: "0.1.0"
    description: "NFT escrow claim receiver"
    storage: ClaimStorage
    incomingMessages: AllowedMessageToClaim
}

type AllowedMessageToClaim =
    | NotificationForNewOwner

fun onInternalMessage(in: InMessage) {
    var storage = ClaimStorage.fromCell(contract.getData());
    var extra = storage.extra.load();
    val msg = lazy AllowedMessageToClaim.fromSlice(in.body);

    match (msg) {
        NotificationForNewOwner => {
            assert (in.senderAddress == storage.nftItemAddress) throw 401;
            assert (msg.queryId == extra.queryId) throw 402;
            assert (msg.oldOwnerAddress == extra.sellerAddress) throw 403;
            assert (!extra.received) throw 404;

            extra.received = true;
            storage.extra = extra.toCell();
            storage.save();

            val confirmation = createMessage({
                bounce: BounceMode.RichBounce,
                dest: storage.saleAddress,
                value: 0,
                body: ClaimConfirmed {
                    queryId: extra.queryId,
                    nftItemAddress: storage.nftItemAddress,
                    buyerAddress: extra.buyerAddress,
                },
            });
            confirmation.send(SEND_MODE_CARRY_ALL_REMAINING_MESSAGE_VALUE);
        }

        else => {
            assert (in.body.isEmpty()) throw 0xFFFF;
        }
    }
}

fun onBouncedMessage(in: InMessageBounced) {
    var storage = ClaimStorage.fromCell(contract.getData());
    var extra = storage.extra.load();

    if (in.senderAddress != storage.saleAddress) {
        return;
    }

    val rich = lazy RichBounceBody.fromSlice(in.bouncedBody);
    var originalBody = rich.originalBody.beginParse();
    val opcode = originalBody.loadUint(32);

    if (opcode != 0x434c4d31) {
        return;
    }

    val bounced = lazy ClaimConfirmed.fromSlice(rich.originalBody.beginParse());

    if (!extra.received) {
        return;
    }
    if (extra.confirmationBounced) {
        return;
    }
    if (bounced.queryId != extra.queryId) {
        return;
    }
    if (bounced.nftItemAddress != storage.nftItemAddress) {
        return;
    }
    if (bounced.buyerAddress != extra.buyerAddress) {
        return;
    }

    extra.confirmationBounced = true;
    storage.extra = extra.toCell();
    storage.save();
}
