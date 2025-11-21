import Foundation

// MARK: - Onboarding Configuration
struct OnboardingConfiguration: Codable {
    let version: String
    let flow: OnboardingFlow

    static func loadLocal(named filename: String = "onboarding_config") -> OnboardingConfiguration? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(OnboardingConfiguration.self, from: data)
    }
}

struct OnboardingFlow: Codable {
    let name: String
    let steps: [OnboardingStep]
}

// MARK: - Onboarding Step Types
struct OnboardingStep: Codable {
    let id: String
    let type: StepType
    let config: StepConfiguration

    enum StepType: String, Codable {
        case survey = "survey"
        case bullet = "bullet"
        case image = "image"
        case missingInfo = "missing_info"
        case name = "name"
        case email = "email"
        case password = "password"
        case createNest = "create_nest"
        case referral = "referral"
        case paywall = "paywall"
        case finish = "finish"
    }
}

// MARK: - Step Configurations
enum StepConfiguration: Codable {
    case survey(SurveyStepConfig)
    case bullet(BulletStepConfig)
    case image(ImageStepConfig)
    case basic(BasicStepConfig)

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "survey":
            let config = try SurveyStepConfig(from: decoder)
            self = .survey(config)
        case "bullet":
            let config = try BulletStepConfig(from: decoder)
            self = .bullet(config)
        case "image":
            let config = try ImageStepConfig(from: decoder)
            self = .image(config)
        default:
            let config = try BasicStepConfig(from: decoder)
            self = .basic(config)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .survey(let config):
            try container.encode("survey", forKey: .type)
            try config.encode(to: encoder)
        case .bullet(let config):
            try container.encode("bullet", forKey: .type)
            try config.encode(to: encoder)
        case .image(let config):
            try container.encode("image", forKey: .type)
            try config.encode(to: encoder)
        case .basic(let config):
            try container.encode("basic", forKey: .type)
            try config.encode(to: encoder)
        }
    }
}

// MARK: - Survey Step Configuration
struct SurveyStepConfig: Codable {
    let questionId: String?
    let title: String
    let subtitle: String?
    let options: [SurveyOptionConfig]
    let isMultiSelect: Bool
    let ctaText: String?

    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case title
        case subtitle
        case options
        case isMultiSelect = "multi_select"
        case ctaText = "cta_text"
    }
}

struct SurveyOptionConfig: Codable {
    let title: String
    let subtitle: String?
    let value: String?
}

// MARK: - Bullet Step Configuration
struct BulletStepConfig: Codable {
    let title: String
    let subtitle: String?
    let bullets: [BulletItemConfig]
    let ctaText: String?

    enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case bullets
        case ctaText = "cta_text"
    }
}

struct BulletItemConfig: Codable {
    let title: String
    let description: String
    let iconName: String

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case iconName = "icon_name"
    }
}

// MARK: - Image Step Configuration
struct ImageStepConfig: Codable {
    let title: String
    let subtitle: String?
    let imageName: String
    let ctaText: String?

    enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case imageName = "image_name"
        case ctaText = "cta_text"
    }
}

// MARK: - Basic Step Configuration
struct BasicStepConfig: Codable {
    let title: String?
    let subtitle: String?
    let ctaText: String?

    enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case ctaText = "cta_text"
    }
}