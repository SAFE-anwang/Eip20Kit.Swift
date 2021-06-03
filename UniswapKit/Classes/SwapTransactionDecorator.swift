import EthereumKit
import Erc20Kit
import BigInt

class SwapTransactionDecorator {
    private let userAddress: Address
    private let contractAddress: Address
    private let contractMethodFactories: SwapContractMethodFactories

    init(userAddress: Address, contractAddress: Address, contractMethodFactories: SwapContractMethodFactories) {
        self.userAddress = userAddress
        self.contractAddress = contractAddress
        self.contractMethodFactories = contractMethodFactories
    }

    private func totalTokenAmount(userAddress: Address, tokenAddress: Address, logs: [TransactionLog], collectIncomingAmounts: Bool) -> BigUInt {
        var amountIn: BigUInt = 0
        var amountOut: BigUInt = 0

        for log in logs {
            if log.address == tokenAddress,
               let erc20Event = log.erc20Event(),
               let transferEventDecoration = erc20Event as? TransferEventDecoration {
                if transferEventDecoration.from == userAddress {
                    amountIn += transferEventDecoration.value
                }

                if transferEventDecoration.to == userAddress {
                    amountOut += transferEventDecoration.value
                }
            }
        }

        return collectIncomingAmounts ? amountIn : amountOut
    }

    private func totalETHIncoming(userAddress: Address, transactions: [InternalTransaction]) -> BigUInt {
        var amountOut: BigUInt = 0

        for transaction in transactions {
            if transaction.to == userAddress {
                amountOut += transaction.value
            }
        }

        return amountOut
    }

}

extension SwapTransactionDecorator: IDecorator {

    func decorate(transactionData: TransactionData, fullTransaction: FullTransaction?) -> TransactionDecoration? {
        guard let contractMethod = contractMethodFactories.createMethod(input: transactionData.input) else {
            return nil
        }

        switch contractMethod {
        case let method as SwapETHForExactTokensMethod:
            guard let lastCoinInPath = method.path.last else {
                return nil
            }

            var amountIn: BigUInt? = nil
            if let fullTransaction = fullTransaction {
                let change = totalETHIncoming(userAddress: method.to, transactions: fullTransaction.internalTransactions)
                amountIn = fullTransaction.transaction.value - change
            }

            return .swap(
                    trade: .exactOut(amountOut: method.amountOut, amountInMax: transactionData.value, amountIn: amountIn),
                    tokenIn: .evmCoin,
                    tokenOut: .eip20Coin(address: lastCoinInPath),
                    to: method.to,
                    deadline: method.deadline
            )
//          3ff5e170e270c94f58e307857d41e8ebd7d078f25e6c8965344f0dbb6c0c62b8
//          exactOut(amountOut: 50000000000000000000, amountInMax: 5419440020395405, amountIn: Optional(5392477632234234)), tokenIn: evmCoin, tokenOut: eip20Coin(address: 0x101848d5c5bbca18e6b4431eedf6b95e9adf82fa), to: 0xda8086165e5b4fa1eb2ab27722339a6db8eb7fae, deadline: 1621926349)

        case let method as SwapExactETHForTokensMethod:
            guard let lastCoinInPath = method.path.last else {
                return nil
            }

            var amountOut: BigUInt? = nil
            if let logs = fullTransaction?.receiptWithLogs?.logs {
                amountOut = totalTokenAmount(userAddress: method.to, tokenAddress: lastCoinInPath, logs: logs, collectIncomingAmounts: false)
            }

            return .swap(
                    trade: .exactIn(amountIn: transactionData.value, amountOutMin: method.amountOutMin, amountOut: amountOut),
                    tokenIn: .evmCoin,
                    tokenOut: .eip20Coin(address: lastCoinInPath),
                    to: method.to,
                    deadline: method.deadline
            )
//          ea8f9962b56fb34e81657b34456668f873896be25b7fd6811406225e528403c5
//          exactIn(amountIn: 10000000000000000, amountOutMin: 730611499602306243853, amountOut: Optional(734264557100317775073)), tokenIn: evmCoin, tokenOut: eip20Coin(address: 0x101848d5c5bbca18e6b4431eedf6b95e9adf82fa), to: 0xda8086165e5b4fa1eb2ab27722339a6db8eb7fae, deadline: 1616490997)

        case let method as SwapExactTokensForETHMethod:
            guard let firstCoinInPath = method.path.first else {
                return nil
            }

            var amountOut: BigUInt? = nil
            if let internalTransactions = fullTransaction?.internalTransactions {
                amountOut = totalETHIncoming(userAddress: method.to, transactions: internalTransactions)
            }

            return .swap(
                    trade: .exactIn(amountIn: method.amountIn, amountOutMin: method.amountOutMin, amountOut: amountOut),
                    tokenIn: .eip20Coin(address: firstCoinInPath),
                    tokenOut: .evmCoin,
                    to: method.to,
                    deadline: method.deadline
            )
//          669ca8f254aae34808b35d8f72a72eb3bfb4c5d8ed4ddf13725d715560055bae
//          exactIn(amountIn: 2000000000000000000, amountOutMin: 30347404218793086, amountOut: Optional(30499141239887052)), tokenIn: eip20Coin(address: 0xad6d458402f60fd3bd25163575031acdce07538d), tokenOut: evmCoin, to: 0xda8086165e5b4fa1eb2ab27722339a6db8eb7fae, deadline: 1621423254)

        case let method as SwapExactTokensForTokensMethod:
            guard let firstCoinInPath = method.path.first, let lastCoinInPath = method.path.last else {
                return nil
            }

            var amountOut: BigUInt? = nil
            if let logs = fullTransaction?.receiptWithLogs?.logs {
                amountOut = totalTokenAmount(userAddress: method.to, tokenAddress: lastCoinInPath, logs: logs, collectIncomingAmounts: false)
            }

            return .swap(
                    trade: .exactIn(amountIn: method.amountIn, amountOutMin: method.amountOutMin, amountOut: amountOut),
                    tokenIn: .eip20Coin(address: firstCoinInPath),
                    tokenOut: .eip20Coin(address: lastCoinInPath),
                    to: method.to,
                    deadline: method.deadline
            )
//          5c63484eb0006697e59c62b4d187721efbc097b4515a3971767397f8f0b994a6
//          exactIn(amountIn: 100000000000000000000, amountOutMin: 724488982381145247, amountOut: Optional(728111427293050974)), tokenIn: eip20Coin(address: 0x101848d5c5bbca18e6b4431eedf6b95e9adf82fa), tokenOut: eip20Coin(address: 0xad6d458402f60fd3bd25163575031acdce07538d), to: 0xda8086165e5b4fa1eb2ab27722339a6db8eb7fae, deadline: 1621423423)

        case let method as SwapTokensForExactETHMethod:
            guard let firstCoinInPath = method.path.first else {
                return nil
            }

            var amountIn: BigUInt? = nil
            if let logs = fullTransaction?.receiptWithLogs?.logs {
                amountIn = totalTokenAmount(userAddress: method.to, tokenAddress: firstCoinInPath, logs: logs, collectIncomingAmounts: true)
            }

            return .swap(
                    trade: .exactOut(amountOut: method.amountOut, amountInMax: method.amountInMax, amountIn: amountIn),
                    tokenIn: .eip20Coin(address: firstCoinInPath),
                    tokenOut: .evmCoin,
                    to: method.to,
                    deadline: method.deadline
            )
//          2e3e316e86211adcd55b5ecd32b7f817a36e33a820c49bd573bf83f8f9b96195 0
//          exactOut(amountOut: 20000000000000000, amountInMax: 183195634466095495490, amountIn: Optional(182284213399099995513)), tokenIn: eip20Coin(address: 0x101848d5c5bbca18e6b4431eedf6b95e9adf82fa), tokenOut: evmCoin, to: 0xda8086165e5b4fa1eb2ab27722339a6db8eb7fae, deadline: 1621925802)

        case let method as SwapTokensForExactTokensMethod:
            guard let firstCoinInPath = method.path.first, let lastCoinInPath = method.path.last else {
                return nil
            }

            var amountIn: BigUInt? = nil
            if let logs = fullTransaction?.receiptWithLogs?.logs {
                amountIn = totalTokenAmount(userAddress: method.to, tokenAddress: firstCoinInPath, logs: logs, collectIncomingAmounts: true)
            }

            return .swap(
                    trade: .exactOut(amountOut: method.amountOut, amountInMax: method.amountInMax, amountIn: amountIn),
                    tokenIn: .eip20Coin(address: firstCoinInPath),
                    tokenOut: .eip20Coin(address: lastCoinInPath),
                    to: method.to,
                    deadline: method.deadline
            )
//          71df63502014e85c2e8237d6f642ab651d12b3a1b5b8f57b91d5a13607d0b278
//          exactOut(amountOut: 10000000000000000000, amountInMax: 62192169434897117, amountIn: Optional(61636710041690673)), tokenIn: eip20Coin(address: 0xad6d458402f60fd3bd25163575031acdce07538d), tokenOut: eip20Coin(address: 0x101848d5c5bbca18e6b4431eedf6b95e9adf82fa), to: 0xda8086165e5b4fa1eb2ab27722339a6db8eb7fae, deadline: 1621932961)

        default: return nil
        }
    }

    public func decorate(logs: [TransactionLog]) -> [EventDecoration] {
        logs.compactMap { log -> EventDecoration? in
            guard log.address == contractAddress, log.topics.count == 3, log.data.count == 128 else {
                return nil
            }

            let signature = log.topics[0]
            let firstParam = Address(raw: log.topics[1])
            let secondParam = Address(raw: log.topics[2])

            guard (firstParam == userAddress || secondParam == userAddress) && signature == SwapEventDecoration.signature else {
                return nil
            }

            let amount0In = BigUInt(Data(log.data[0..<32]))
            let amount1In = BigUInt(Data(log.data[32..<64]))
            let amount0Out = BigUInt(Data(log.data[64..<96]))
            let amount1Out = BigUInt(Data(log.data[96..<128]))

            return SwapEventDecoration(
                    contractAddress: contractAddress, sender: firstParam, amount0In: amount0In, amount1In: amount1In,
                    amount0Out: amount0Out, amount1Out: amount1Out, to: secondParam
            )
        }
    }

}
