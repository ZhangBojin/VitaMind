import Foundation
import HealthKit
import SwiftUI

/// All health metric types the app reads from HealthKit.
/// Each case maps to a HealthKit identifier, display label, SF Symbol, unit string, and tint color.
enum HealthMetricType: String, CaseIterable, Codable, Sendable {
    case heartRate
    case heartRateVariability       // SDNN
    case restingHeartRate
    case walkingHeartRateAverage
    case steps
    case activeEnergy
    case exerciseMinutes
    case standHours
    case sleepAnalysis
    case bloodOxygen
    case respiratoryRate

    // MARK: - Display Metadata

    var displayName: String {
        switch self {
        case .heartRate:               return "心率"
        case .heartRateVariability:    return "心率变异性"
        case .restingHeartRate:        return "静息心率"
        case .walkingHeartRateAverage: return "步行平均心率"
        case .steps:                   return "步数"
        case .activeEnergy:            return "活动能量"
        case .exerciseMinutes:         return "锻炼"
        case .standHours:              return "站立小时"
        case .sleepAnalysis:           return "睡眠"
        case .bloodOxygen:             return "血氧"
        case .respiratoryRate:         return "呼吸频率"
        }
    }

    var unit: String {
        switch self {
        case .heartRate:               return "次/分"
        case .heartRateVariability:    return "毫秒"
        case .restingHeartRate:        return "次/分"
        case .walkingHeartRateAverage: return "次/分"
        case .steps:                   return "步"
        case .activeEnergy:            return "千卡"
        case .exerciseMinutes:         return "分钟"
        case .standHours:              return "小时"
        case .sleepAnalysis:           return "小时"
        case .bloodOxygen:             return "%"
        case .respiratoryRate:         return "次/分"
        }
    }

    var systemImage: String {
        switch self {
        case .heartRate:               return "heart.fill"
        case .heartRateVariability:    return "waveform.path.ecg"
        case .restingHeartRate:        return "heart.circle"
        case .walkingHeartRateAverage: return "figure.walk"
        case .steps:                   return "shoeprints.fill"
        case .activeEnergy:            return "flame.fill"
        case .exerciseMinutes:         return "figure.run"
        case .standHours:              return "clock.arrow.circlepath"
        case .sleepAnalysis:           return "moon.zzz.fill"
        case .bloodOxygen:             return "lungs.fill"
        case .respiratoryRate:         return "wind"
        }
    }

    var tintColor: Color {
        switch self {
        case .heartRate:               return .red
        case .heartRateVariability:    return .purple
        case .restingHeartRate:        return .pink
        case .walkingHeartRateAverage: return .orange
        case .steps:                   return .green
        case .activeEnergy:            return .orange
        case .exerciseMinutes:         return .mint
        case .standHours:              return .teal
        case .sleepAnalysis:           return .indigo
        case .bloodOxygen:             return .red
        case .respiratoryRate:         return .cyan
        }
    }

    // MARK: - HealthKit Mapping

    /// The HKQuantityTypeIdentifier for quantity-based metrics, nil for category types.
    var hkQuantityTypeIdentifier: HKQuantityTypeIdentifier? {
        switch self {
        case .heartRate:               return .heartRate
        case .heartRateVariability:    return .heartRateVariabilitySDNN
        case .restingHeartRate:        return .restingHeartRate
        case .walkingHeartRateAverage: return .walkingHeartRateAverage
        case .steps:                   return .stepCount
        case .activeEnergy:            return .activeEnergyBurned
        case .exerciseMinutes:         return .appleExerciseTime
        case .bloodOxygen:             return .oxygenSaturation
        case .respiratoryRate:         return .respiratoryRate
        case .standHours, .sleepAnalysis:
            return nil
        }
    }

    /// The HKCategoryTypeIdentifier for category-based metrics, nil for quantity types.
    var hkCategoryTypeIdentifier: HKCategoryTypeIdentifier? {
        switch self {
        case .standHours:    return .appleStandHour
        case .sleepAnalysis: return .sleepAnalysis
        default:             return nil
        }
    }

    /// The HKUnit used to read this metric from HealthKit.
    var hkUnit: HKUnit {
        switch self {
        case .heartRate, .restingHeartRate, .walkingHeartRateAverage:
            return HKUnit(from: "count/min")
        case .heartRateVariability:
            return HKUnit(from: "ms")
        case .steps:
            return HKUnit.count()
        case .activeEnergy:
            return HKUnit.kilocalorie()
        case .exerciseMinutes:
            return HKUnit.minute()
        case .bloodOxygen:
            return HKUnit.percent()
        case .respiratoryRate:
            return HKUnit(from: "count/min")
        case .standHours, .sleepAnalysis:
            return HKUnit.count()
        }
    }

    /// Return the HKObjectType for this metric (quantity or category).
    var hkObjectType: HKObjectType? {
        if let qid = hkQuantityTypeIdentifier {
            return HKQuantityType.quantityType(forIdentifier: qid)
        }
        if let cid = hkCategoryTypeIdentifier {
            return HKCategoryType.categoryType(forIdentifier: cid)
        }
        return nil
    }

    // MARK: - Sleep Stage Names

    var sleepStageName: String? {
        // Only used for sleepAnalysis
        return nil
    }
}
