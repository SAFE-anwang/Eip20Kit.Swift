import BigInt
import EvmKit

class Eip20TransactionSyncer {
    private let provider: ITransactionProvider
    private let storage: Eip20Storage

    init(provider: ITransactionProvider, storage: Eip20Storage) {
        self.provider = provider
        self.storage = storage
    }

    private func handle(transactions: [ProviderTokenTransaction]) {
        guard !transactions.isEmpty else {
            return
        }

        let events = transactions.map { tx in
            Event(
                hash: tx.hash,
                blockNumber: tx.blockNumber,
                contractAddress: tx.contractAddress,
                from: tx.from,
                to: tx.to,
                value: tx.value,
                tokenName: tx.tokenName,
                tokenSymbol: tx.tokenSymbol,
                tokenDecimal: Int(tx.tokenDecimal.description) ?? -1
            )
        }

        storage.save(events: events)
    }
}

extension Eip20TransactionSyncer: ITransactionSyncer {
    func transactions() async throws -> ([Transaction], Bool) {
        let lastBlockNumber = storage.lastEvent()?.blockNumber ?? 0
        let initial = lastBlockNumber == 0

        do {
            let transactions = try await provider.tokenTransactions(startBlock: lastBlockNumber + 1)

            handle(transactions: transactions)

            let array = transactions.map { tx in
                Transaction(
                    hash: tx.hash,
                    timestamp: tx.timestamp,
                    isFailed: false,
                    blockNumber: tx.blockNumber,
                    transactionIndex: Int(tx.transactionIndex.description),
                    nonce: tx.nonce,
                    gasPrice: Int(tx.gasPrice.description),
                    gasLimit: Int(tx.gasLimit.description),
                    gasUsed: Int(tx.gasUsed.description)
                )
            }

            return (array, initial)
        } catch {
            return ([], initial)
        }
    }
}
