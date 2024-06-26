import BigInt
import EvmKit

class Eip20TransactionDecorator {
    private let userAddress: Address

    init(userAddress: Address) {
        self.userAddress = userAddress
    }
}

extension Eip20TransactionDecorator: ITransactionDecorator {
    
    public func decoration(from: Address?, to: Address?, value: BigUInt?, contractMethod: ContractMethod?, internalTransactions _: [InternalTransaction], eventInstances: [ContractEventInstance], isLock: Bool) -> TransactionDecoration? {
        guard let from, let to, let value, let contractMethod else {
            return nil
        }

        if let transferMethod = contractMethod as? TransferMethod {
            if from == userAddress {
                return OutgoingEip20Decoration(
                    contractAddress: to,
                    to: transferMethod.to,
                    value: transferMethod.value,
                    sentToSelf: transferMethod.to == userAddress,
                    tokenInfo: eventInstances.compactMap { $0 as? TransferEventInstance }.first { $0.contractAddress == to }?.tokenInfo
                )
            }
        }

        if let approveMethod = contractMethod as? ApproveMethod {
            return ApproveEip20Decoration(
                contractAddress: to,
                spender: approveMethod.spender,
                value: approveMethod.value
            )
        }

        return nil
    }
}
