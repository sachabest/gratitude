import Foundation

/// Plain Codable mirrors of the SwiftData models, used only for JSON
/// serialization before encryption and CloudKit upload.
struct CheckInDTO: Codable {
    var id: UUID
    var date: Date
    var period: Period
    var timeBudget: TimeBudget
    var completedAt: Date
    var updatedAt: Date
    var moodRating: Int?
    var photoData: Data?
    var taggedPersonName: String?
    var taggedPersonPhoneNumber: String?
    var responses: [QuestionResponseDTO]

    init(from checkIn: CheckIn) {
        id = checkIn.id
        date = checkIn.date
        period = checkIn.period
        timeBudget = checkIn.timeBudget
        completedAt = checkIn.completedAt
        updatedAt = checkIn.updatedAt
        moodRating = checkIn.moodRating
        photoData = checkIn.photoData
        taggedPersonName = checkIn.taggedPersonName
        taggedPersonPhoneNumber = checkIn.taggedPersonPhoneNumber
        responses = checkIn.responses.map { QuestionResponseDTO(from: $0) }
    }

    func toModel() -> CheckIn {
        let model = CheckIn(
            id: id,
            date: date,
            period: period,
            timeBudget: timeBudget,
            completedAt: completedAt,
            moodRating: moodRating
        )
        model.updatedAt = updatedAt
        model.photoData = photoData
        model.taggedPersonName = taggedPersonName
        model.taggedPersonPhoneNumber = taggedPersonPhoneNumber
        model.responses = responses.map { $0.toModel() }
        return model
    }
}

struct QuestionResponseDTO: Codable {
    var id: UUID
    var questionId: String
    var questionText: String
    var order: Int
    var answerKindTag: AnswerKindTag
    var selectedOption: String?
    var freeText: String?

    init(from response: QuestionResponse) {
        id = response.id
        questionId = response.questionId
        questionText = response.questionText
        order = response.order
        answerKindTag = response.answerKindTag
        selectedOption = response.selectedOption
        freeText = response.freeText
    }

    func toModel() -> QuestionResponse {
        QuestionResponse(
            id: id,
            questionId: questionId,
            questionText: questionText,
            order: order,
            answerKindTag: answerKindTag,
            selectedOption: selectedOption,
            freeText: freeText
        )
    }
}

struct SmileDTO: Codable {
    var id: UUID
    var direction: SmileDirection
    var personName: String
    var message: String
    var date: Date
    var cloudRecordName: String?

    init(from smile: Smile) {
        id = smile.id
        direction = smile.direction
        personName = smile.personName
        message = smile.message
        date = smile.date
        cloudRecordName = smile.cloudRecordName
    }

    func toModel() -> Smile {
        Smile(id: id, direction: direction, personName: personName, message: message, date: date, cloudRecordName: cloudRecordName)
    }
}
