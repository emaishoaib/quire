//
//  NameExtractor.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/24/26.
//

import Foundation
import FoundationModels

/// Reads the values a name pattern needs out of a document's text.
///
/// Only `SystemLanguageModel`, the model stored on the Mac, is used. macOS 27 also lets
/// apps send prompts to Apple's cloud model, and that is deliberately left alone here, so
/// a document's text never leaves the Mac.
///
/// The model only reads. Writing the values in the pattern's own formats is left to
/// `NamePattern`, so a date always comes out exactly as the other names write it.
enum NameExtractor {

    enum Failure: LocalizedError {
        case noText

        var errorDescription: String? {
            "This PDF has no text to read. If it is a scan, use Recognize Text first."
        }
    }

    /// What the model is asked for, as typed fields rather than free-form prose.
    @Generable
    struct Values {
        @Guide(description: "The document's main date, such as the date of purchase, issue or invoice, written as YYYY-MM-DD.")
        var date: String?

        @Guide(description: "The total amount paid or due, written as digits with a decimal point, such as 42.10, with no currency.")
        var amount: String?

        @Guide(description: "The words for the <text> part of the file name: the everyday name of the shop, company or sender, as short as in the example names, in normal capitalisation, without words like Ltd, Stores or UK.")
        var text: String?
    }

    /// Why the on-device model cannot be used right now, or nil when it can.
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            nil
        case .unavailable(.deviceNotEligible):
            "Renaming from the document needs a Mac that can run Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            "Renaming from the document needs Apple Intelligence, which is turned off in System Settings"
        case .unavailable(.modelNotReady):
            "Renaming from the document will work once Apple Intelligence finishes downloading"
        case .unavailable:
            "Apple Intelligence is not available right now"
        }
    }

    /// A name for the document with `text`, following `pattern`.
    ///
    /// A slot the model cannot fill keeps its placeholder, such as `<date>`, for the user
    /// to fill in by hand.
    static func suggestName(following pattern: NamePattern, for text: String) async throws -> String {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw Failure.noText }

        let model = SystemLanguageModel.default
        let session = LanguageModelSession(model: model, instructions: instructions)
        let prompt = try await prompt(for: pattern, text: text, fitting: model)
        let values = try await session.respond(
            to: prompt,
            generating: Values.self,
            options: GenerationOptions(samplingMode: .greedy)
        ).content

        return pattern.name(day: day(values.date), period: nil, amount: amount(values.amount), text: words(values.text))
    }

    private static let instructions = """
        You pick out the details used to name a document, such as a receipt, invoice or \
        letter. Take every detail from the document's text, never from the example names. \
        Leave a detail out when the document does not state it.
        """

    /// The prompt, holding as much of the start of the document as fits in half the model's context.
    ///
    /// The other half is left for the instructions, the description of the answer's
    /// fields, and the answer. The start is kept because that is where receipts and
    /// invoices put their dates, totals and senders.
    private static func prompt(for pattern: NamePattern, text: String, fitting model: SystemLanguageModel) async throws -> String {
        var excerpt = text.prefix(model.contextSize * 4)
        while !excerpt.isEmpty {
            let prompt = prompt(for: pattern, excerpt: excerpt)
            if try await model.tokenCount(for: prompt) <= model.contextSize / 2 {
                return prompt
            }
            excerpt = excerpt.prefix(excerpt.count * 3 / 4)
        }
        return prompt(for: pattern, excerpt: excerpt)
    }

    private static func prompt(for pattern: NamePattern, excerpt: Substring) -> String {
        let examples = pattern.examples.prefix(5).map { "- \($0)" }.joined(separator: "\n")
        return """
            Other files in the same folder are named like this:
            \(examples)

            Their pattern is: \(pattern)

            Here is the start of the document to name:
            \(excerpt)
            """
    }

    /// The day in a `YYYY-MM-DD` answer, or nil if the answer is not a real date.
    private static func day(_ answer: String?) -> DateComponents? {
        let numbers = answer?.split(separator: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard let numbers, numbers.count == 3 else { return nil }
        let day = DateComponents(year: numbers[0], month: numbers[1], day: numbers[2])
        return day.isValidDate(in: Calendar(identifier: .gregorian)) ? day : nil
    }

    private static func amount(_ answer: String?) -> Decimal? {
        guard let digits = answer?.filter({ $0.isASCII && ($0.isNumber || $0 == ".") }), !digits.isEmpty else {
            return nil
        }
        return Decimal(string: digits, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// The answer's words, with the characters a file name cannot hold swapped for dashes.
    private static func words(_ answer: String?) -> String? {
        let words = answer?
            .components(separatedBy: CharacterSet(charactersIn: "/:"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return words?.isEmpty == false ? words : nil
    }
}
