import Foundation

/// 掉落用的随机数，测试里换成固定种子的
protocol LootRandom {
    /// [0, 1) 之间均匀分布
    mutating func unit() -> Double
}

struct SystemLootRandom: LootRandom {
    private var generator = SystemRandomNumberGenerator()

    mutating func unit() -> Double {
        Double.random(in: 0..<1, using: &generator)
    }
}

/// 固定种子（SplitMix64），同一个种子每次抽出一样的序列
struct SeededLootRandom: LootRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func unit() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }
}

extension LootRandom {
    /// 按权重挑一个；权重全是 0 或者空时返回 nil
    mutating func pick<T>(_ weighted: [(T, Double)]) -> T? {
        let total = weighted.reduce(0) { $0 + max(0, $1.1) }
        guard total > 0 else { return nil }
        var roll = unit() * total
        for (value, weight) in weighted where weight > 0 {
            if roll < weight { return value }
            roll -= weight
        }
        return weighted.last { $0.1 > 0 }?.0
    }

    mutating func pick<T>(uniform values: [T]) -> T? {
        guard !values.isEmpty else { return nil }
        let index = min(values.count - 1, Int(unit() * Double(values.count)))
        return values[index]
    }
}
