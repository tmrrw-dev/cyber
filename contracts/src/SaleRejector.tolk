contract SaleRejector {
    author: "CYBER"
    version: "0.1.0"
    description: "Test-only contract that rejects incoming messages"
}

fun onInternalMessage(in: InMessage) {
    assert (false) throw 500;
}
