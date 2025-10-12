
import Foundation
import Combine

// Simple 1-layer linear model: score = clamp(1,100, 100 * (w·x + b))
// where x are normalized inputs in [0,1], equal-weight baseline.
final class MLLinearModel: ObservableObject {
    static let shared = MLLinearModel()

    @Published var weights: [Double] = Array(repeating: 0.2, count: 5) // equal weights
    @Published var bias: Double = 0.0

    private let defaults = UserDefaults.standard
    private let weightsKey = "MLLinearModel.weights.v1"
    private let biasKey = "MLLinearModel.bias.v1"

    private init() {
        load()
    }

    func load() {
        if let w = defaults.array(forKey: weightsKey) as? [Double], w.count == 5 {
            self.weights = w
        }
        let b = defaults.double(forKey: biasKey)
        if defaults.object(forKey: biasKey) != nil {
            self.bias = b
        }
    }

    func save() {
        defaults.set(weights, forKey: weightsKey)
        defaults.set(bias, forKey: biasKey)
    }

    // Normalize raw features to 0...1
    // sleepMin: minutes (target 8h), steps: ~0..20000, kcal ~0..2000,
    // stressLevel: 0..10 (lower is better -> invert),
    // screenMin: minutes (lower is better; 0..12h)
    func normalize(sleepMin: Int, steps: Int, kcal: Int, stress: Int, screenMin: Int) -> [Double] {
        let sleepHours = Double(sleepMin) / 60.0
        let sleepNorm = min(1.0, sleepHours / 8.0)

        let stepsNorm = min(1.0, Double(steps) / 10000.0)
        let kcalNorm = min(1.0, Double(kcal) / 1000.0)

        let stressNorm = max(0.0, min(1.0, (10.0 - Double(stress)) / 10.0)) // less stress is better

        let screenHours = Double(screenMin) / 60.0
        let screenNorm = max(0.0, min(1.0, (8.0 - screenHours) / 8.0)) // less is better, 0 at >=8h

        return [sleepNorm, stepsNorm, kcalNorm, stressNorm, screenNorm]
    }

    func predict(sleepMin: Int, steps: Int, kcal: Int, stress: Int, screenMin: Int) -> Int {
        let x = normalize(sleepMin: sleepMin, steps: steps, kcal: kcal, stress: stress, screenMin: screenMin)
        let dot = zip(weights, x).map(*).reduce(0.0, +) + bias
        let raw = max(0.0, min(1.0, dot))
        let score = Int((raw * 100.0).rounded())
        return min(100, max(1, score))
    }

    // SGD update on dataset to minimize MSE
    struct Sample {
        var sleepMin: Int
        var steps: Int
        var kcal: Int
        var stress: Int
        var screenMin: Int
        var targetScore: Int
    }

    func fit(samples: [Sample], epochs: Int = 200, lr: Double = 0.01) {
        guard !samples.isEmpty else { return }
        var w = weights
        var b = bias

        for _ in 0..<epochs {
            for s in samples.shuffled() {
                let x = normalize(sleepMin: s.sleepMin, steps: s.steps, kcal: s.kcal, stress: s.stress, screenMin: s.screenMin)
                let y = Double(s.targetScore) / 100.0
                let yhat = max(0.0, min(1.0, zip(w, x).map(*).reduce(0.0, +) + b))
                let err = yhat - y
                // gradient: dL/dw = 2*err*x, dL/db = 2*err
                for i in 0..<w.count {
                    w[i] -= lr * 2.0 * err * x[i]
                }
                b -= lr * 2.0 * err
            }
        }
        self.weights = w
        self.bias = b
        save()
    }
}
