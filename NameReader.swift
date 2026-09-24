//
//  NameReader.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/24/26.
//

import Foundation

/// Reads the values a name pattern needs out of a document's text, with plain code.
///
/// Every date, period and amount in the text is found, and the one to use is chosen by
/// the words just before it. A label that usually introduces the value wanted counts for
/// it, and one that usually introduces something else counts against it. Only the label
/// nearest the value is taken into account, so a line holding two labels is judged by
/// the one that actually introduces the value.
///
/// The free text is not read out of the document at all. It is picked from what the
/// folder's other names already have in that slot, by how many of its words the document
/// contains, and left as a placeholder when none of them fit.
///
/// Where a numeric date reads correctly either way round, the day is taken to come first.
enum NameReader {

    enum Failure: LocalizedError {
        case noText

        var errorDescription: String? {
            "This PDF has no text to read. If it is a scan, use Recognize Text first."
        }
    }

    /// A name for the document with `text`, following `pattern`.
    ///
    /// A slot that cannot be filled keeps its placeholder, for the user to fill in by hand.
    static func suggestName(following pattern: NamePattern, for text: String) throws -> String {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw Failure.noText }
        let document = text as NSString

        let dates = findDates(in: document)
        let periods = findPeriods(among: dates, in: document)
        let period = best(of: periods, labels: periodLabels, in: document)

        let inPeriods = periods.flatMap { [$0.first.location, $0.last.location] }
        let fullDates = dates.filter { $0.day.year != nil }
        let standalone = fullDates.filter { !inPeriods.contains($0.range.location) }
        let day = best(of: standalone.isEmpty ? fullDates : standalone, labels: dateLabels, in: document)

        let amounts = findAmounts(in: document).sorted { a, b in
            a.value != b.value ? a.value > b.value : a.range.location < b.range.location
        }
        let amount = best(of: amounts, labels: amountLabels, in: document)

        return pattern.name(
            day: day?.day,
            period: period?.period,
            amount: amount?.value,
            text: knownText(from: pattern.knownTexts, in: document)
        )
    }

    // MARK: Choosing by label

    /// Something found in the text, which a label before it can speak for or against.
    private protocol Found {
        var range: NSRange { get }
    }

    /// Words that introduce a value, and how strongly they speak for it.
    private struct Label {
        let regex: NSRegularExpression
        let length: Int
        let weight: Int

        init(_ words: String, _ weight: Int) {
            let pattern = #"(?<!\p{L})"# + NSRegularExpression.escapedPattern(for: words) + #"(?!\p{L})"#
            regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            length = words.count
            self.weight = weight
        }
    }

    /// How far before a value its label is looked for, in characters.
    private static let labelReach = 60

    /// The candidate whose nearest label speaks for it most, or the first when none has one.
    ///
    /// A candidate whose label speaks against it is never chosen, because a placeholder
    /// the user fills in is better than a confident wrong value.
    private static func best<T: Found>(of candidates: [T], labels: [Label], in text: NSString) -> T? {
        var best: (candidate: T, weight: Int)?
        for candidate in candidates {
            let weight = labelWeight(before: candidate.range.location, in: text, labels: labels)
            if weight >= 0 && weight > (best?.weight ?? -1) {
                best = (candidate, weight)
            }
        }
        return best?.candidate
    }

    /// The weight of the label ending nearest before `location`, or zero when there is none.
    ///
    /// Of two labels ending in the same place, the longer one wins, so a label that
    /// contains a shorter one is not mistaken for it.
    private static func labelWeight(before location: Int, in text: NSString, labels: [Label]) -> Int {
        let start = max(0, location - labelReach)
        let window = text.substring(with: NSRange(location: start, length: location - start))
        let range = NSRange(location: 0, length: (window as NSString).length)

        var nearest: (end: Int, length: Int, weight: Int)?
        for label in labels {
            guard let found = label.regex.matches(in: window, range: range).last else { continue }
            let end = NSMaxRange(found.range)
            if let current = nearest, end < current.end || (end == current.end && label.length <= current.length) {
                continue
            }
            nearest = (end, label.length, label.weight)
        }
        return nearest?.weight ?? 0
    }

    private static let dateLabels = [
        Label("statement date", 3), Label("invoice date", 3), Label("date of invoice", 3),
        Label("bill date", 3), Label("billing date", 3), Label("issue date", 3),
        Label("date of issue", 3), Label("date issued", 3), Label("issued on", 3),
        Label("issued", 2), Label("tax point", 3), Label("receipt date", 3),
        Label("document date", 3), Label("order date", 2), Label("date", 1),
        Label("due date", -3), Label("due", -3), Label("pay by", -3), Label("payment date", -2),
        Label("date of birth", -3), Label("expiry", -3), Label("expires", -3),
        Label("next", -2), Label("until", -2), Label("valid", -2),
    ]

    private static let periodLabels = [
        Label("billing period", 3), Label("statement period", 3), Label("period", 2),
        Label("covering", 2), Label("usage", 1), Label("from", 1),
        Label("contract", -2), Label("tariff", -1),
    ]

    private static let amountLabels = [
        Label("total amount due", 4), Label("amount due", 4), Label("total due", 4),
        Label("balance due", 4), Label("amount payable", 4), Label("total to pay", 4),
        Label("amount to pay", 4), Label("grand total", 4), Label("you owe", 4),
        Label("total amount", 3), Label("total charges", 3), Label("total cost", 3),
        Label("total", 2), Label("balance", 2), Label("to pay", 2), Label("amount", 1),
        Label("subtotal", -3), Label("sub total", -3), Label("sub-total", -3),
        Label("previous", -3), Label("last bill", -3),
        Label("discount", -3), Label("saving", -3), Label("per", -3), Label("rate", -2),
    ]

    // MARK: Dates

    private struct FoundDate: Found {
        let range: NSRange
        let day: DateComponents
    }

    private static let calendar = Calendar(identifier: .gregorian)

    private static let monthNames = [
        "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december",
    ]

    private static let monthPattern =
        "(january|february|march|april|may|june|july|august|september|october|november|december"
        + "|jan|feb|mar|apr|jun|jul|aug|sept|sep|oct|nov|dec)"

    private static let numericDate = try! NSRegularExpression(
        pattern: #"(?<![\d./-])(\d{1,2})([./-])(\d{1,2})\2(\d{4}|\d{2})(?![./-]?\d)"#
    )
    private static let yearFirstDate = try! NSRegularExpression(
        pattern: #"(?<![\d./-])((?:19|20)\d{2})([./-])(\d{1,2})\2(\d{1,2})(?![./-]?\d)"#
    )
    private static let dayMonthDate = try! NSRegularExpression(
        pattern: #"(?<![\p{L}\d])(\d{1,2})(?:st|nd|rd|th)?\s*(?:of\s+)?"# + monthPattern
            + #"(?!\p{L})\.?(?:,?\s+((?:19|20)\d{2})(?!\d))?"#,
        options: .caseInsensitive
    )
    private static let monthDayDate = try! NSRegularExpression(
        pattern: #"(?<!\p{L})"# + monthPattern + #"(?!\p{L})\.?\s+(\d{1,2})(?:st|nd|rd|th)?(?!\d)"#
            + #"(?:,?\s+((?:19|20)\d{2})(?!\d))?"#,
        options: .caseInsensitive
    )

    /// Every date in the text, in order, with overlapping readings of the same text removed.
    ///
    /// A date written with its month in words may leave out the year. Such a date is kept
    /// without one, because it can still start a period whose end gives the year.
    private static func findDates(in text: NSString) -> [FoundDate] {
        let whole = NSRange(location: 0, length: text.length)
        var found: [FoundDate] = []

        func add(_ match: NSTextCheckingResult, year: Int?, month: Int?, day: Int?) {
            guard let month, let day else { return }
            let components = DateComponents(year: year, month: month, day: day)
            var check = components
            check.year = year ?? 2000
            if check.isValidDate(in: calendar) {
                found.append(FoundDate(range: match.range, day: components))
            }
        }

        for match in numericDate.matches(in: text as String, range: whole) {
            let first = number(match, 1, in: text), second = number(match, 3, in: text)
            let year = number(match, 4, in: text).map { $0 < 100 ? 2000 + $0 : $0 }
            if let first, let second, first <= 12, second > 12 {
                add(match, year: year, month: first, day: second)
            } else {
                add(match, year: year, month: second, day: first)
            }
        }
        for match in yearFirstDate.matches(in: text as String, range: whole) {
            add(match, year: number(match, 1, in: text), month: number(match, 3, in: text), day: number(match, 4, in: text))
        }
        for match in dayMonthDate.matches(in: text as String, range: whole) {
            add(match, year: number(match, 3, in: text), month: month(match, 2, in: text), day: number(match, 1, in: text))
        }
        for match in monthDayDate.matches(in: text as String, range: whole) {
            add(match, year: number(match, 3, in: text), month: month(match, 1, in: text), day: number(match, 2, in: text))
        }

        var dates: [FoundDate] = []
        for date in found.sorted(by: { a, b in
            a.range.location != b.range.location ? a.range.location < b.range.location : a.range.length > b.range.length
        }) where date.range.location >= (dates.last.map { NSMaxRange($0.range) } ?? 0) {
            dates.append(date)
        }
        return dates
    }

    private static func number(_ match: NSTextCheckingResult, _ group: Int, in text: NSString) -> Int? {
        let range = match.range(at: group)
        return range.location == NSNotFound ? nil : Int(text.substring(with: range))
    }

    private static func month(_ match: NSTextCheckingResult, _ group: Int, in text: NSString) -> Int? {
        let range = match.range(at: group)
        guard range.location != NSNotFound else { return nil }
        let name = text.substring(with: range).lowercased()
        return monthNames.firstIndex { $0.hasPrefix(name) }.map { $0 + 1 }
    }

    // MARK: Periods

    private struct FoundPeriod: Found {
        let range: NSRange
        let first: NSRange
        let last: NSRange
        let period: NamePattern.Period
    }

    /// What may stand between the two ends of a period.
    private static let periodJoiners: Set<String> = ["to", "-", "–", "—", "until", "till", "through", "thru", "and"]

    /// Every pair of neighbouring dates joined as the two ends of a period.
    ///
    /// The last date must carry a year. A first date without one takes the same year, or
    /// the year before when its month comes later, as it does for a period across new year.
    private static func findPeriods(among dates: [FoundDate], in text: NSString) -> [FoundPeriod] {
        zip(dates, dates.dropFirst()).compactMap { first, last in
            guard let year = last.day.year else { return nil }
            let gapStart = NSMaxRange(first.range)
            let gap = text.substring(with: NSRange(location: gapStart, length: last.range.location - gapStart))
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard periodJoiners.contains(gap) else { return nil }

            var start = first.day
            if start.year == nil {
                start.year = (start.month ?? 0) > (last.day.month ?? 0) ? year - 1 : year
            }
            guard start.isValidDate(in: calendar),
                  let from = calendar.date(from: start),
                  let to = calendar.date(from: last.day),
                  from <= to
            else { return nil }

            return FoundPeriod(
                range: NSRange(location: first.range.location, length: NSMaxRange(last.range) - first.range.location),
                first: first.range,
                last: last.range,
                period: NamePattern.Period(start: start, end: last.day)
            )
        }
    }

    // MARK: Amounts

    private struct FoundAmount: Found {
        let range: NSRange
        let value: Decimal
    }

    /// Numbers with two decimal places, with or without separators between thousands,
    /// leaving out percentages and the parts of dates written with dots.
    private static let amountRegex = try! NSRegularExpression(
        pattern: #"(?<![\d.,])(?:\d{1,3}(?:[.,]\d{3})+|\d+)[.,]\d{2}(?![.,]?\d)(?!\s?%)"#
    )

    /// Every amount in the text.
    ///
    /// Each has exactly two decimal places, so whichever separators it uses, dropping them
    /// and dividing by a hundred gives its value.
    private static func findAmounts(in text: NSString) -> [FoundAmount] {
        amountRegex.matches(in: text as String, range: NSRange(location: 0, length: text.length)).compactMap { match in
            let digits = text.substring(with: match.range).filter(\.isNumber)
            guard let cents = Decimal(string: digits) else { return nil }
            return FoundAmount(range: match.range, value: cents / 100)
        }
    }

    // MARK: Free text

    /// The known text whose words the document contains the largest share of.
    ///
    /// Words that are only digits are left out of the count, because they change from one
    /// document to the next. A known text needs at least half its words in the document to
    /// be chosen. Between two with the same share, the one with more words found wins.
    private static func knownText(from known: [String], in text: NSString) -> String? {
        var best: (value: String, share: Double, found: Int)?
        for value in known {
            let words = value.split(whereSeparator: \.isWhitespace)
                .map { $0.trimmingCharacters(in: .punctuationCharacters.union(.symbols)) }
                .filter { $0.count >= 2 && !$0.allSatisfy(\.isNumber) }
            guard !words.isEmpty else { continue }

            let found = words.filter { contains($0, in: text) }.count
            let share = Double(found) / Double(words.count)
            guard share >= 0.5 else { continue }
            if let current = best, share < current.share || (share == current.share && found <= current.found) {
                continue
            }
            best = (value, share, found)
        }
        return best?.value
    }

    private static func contains(_ word: String, in text: NSString) -> Bool {
        let pattern = #"(?<![\p{L}\p{N}])"# + NSRegularExpression.escapedPattern(for: word) + #"(?![\p{L}\p{N}])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return false }
        return regex.firstMatch(in: text as String, range: NSRange(location: 0, length: text.length)) != nil
    }
}
