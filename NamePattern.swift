//
//  NamePattern.swift
//  Quire
//
//  Created by Mustafa Shoaib on 9/24/26.
//

import Foundation

/// A way of naming files, worked out from the names already in a folder.
///
/// A name is read as fixed text with slots in it: dates, amounts, and at most one run of
/// free text, such as a shop's name.
///
/// Only numbers with two decimal places count as amounts, because a whole number in a
/// name is as likely to be a reference or a page count as a price.
struct NamePattern: CustomStringConvertible {

    enum Part: Hashable {
        case literal(String)
        case text
        case date(format: String)
        case amount(decimalSeparator: String)
    }

    let parts: [Part]

    /// The names that follow the pattern, as examples of it filled in.
    let examples: [String]

    var description: String {
        name(day: nil, amount: nil, text: nil)
    }

    /// The pattern filled in, keeping a slot's placeholder where its value is missing.
    ///
    /// Each value is written the way the example names write it: the date in their
    /// format, and the amount with two decimal places and their decimal separator.
    func name(day: DateComponents?, amount: Decimal?, text: String?) -> String {
        parts.map { part in
            switch part {
            case .literal(let literal):
                literal
            case .text:
                text ?? "<text>"
            case .date(let format):
                day.flatMap { Self.string(from: $0, format: format) } ?? "<date>"
            case .amount(let separator):
                amount.flatMap { Self.string(from: $0, decimalSeparator: separator) } ?? "<amount>"
            }
        }.joined()
    }

    /// Writes a day in `format`, in UTC throughout, so that no time zone can move it to the day before.
    private static func string(from day: DateComponents, format: String) -> String? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard let date = calendar.date(from: day) else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = .gmt
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    private static func string(from amount: Decimal, decimalSeparator: String) -> String? {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = decimalSeparator
        return formatter.string(from: amount as NSDecimalNumber)
    }

    /// The pattern shared by the most of `names`, or nil when no two names share one.
    ///
    /// Names are grouped by where their dates and amounts fall and how they are written.
    /// Within a group, fixed text that differs from name to name becomes the text slot. A
    /// group whose fixed text differs in more than one place has no single pattern, and a
    /// pattern that is nothing but free text says nothing, so neither counts.
    static func find(in names: [String]) -> NamePattern? {
        var groups: [[Member]] = []
        var groupIndex: [[Part]: Int] = [:]

        for name in names {
            let member = Member(name: name, parts: parts(of: name))
            let shape = member.parts.map(\.shape)
            if let index = groupIndex[shape] {
                groups[index].append(member)
            } else {
                groupIndex[shape] = groups.count
                groups.append([member])
            }
        }

        return groups.enumerated()
            .filter { $0.element.count >= 2 }
            .sorted { a, b in
                a.element.count != b.element.count
                    ? a.element.count > b.element.count
                    : a.offset < b.offset
            }
            .lazy
            .compactMap { merge($0.element) }
            .first
    }

    private struct Member {
        let name: String
        let parts: [Part]
    }

    /// Combines names with the same shape into one pattern.
    private static func merge(_ members: [Member]) -> NamePattern? {
        var parts: [Part] = []
        var hasText = false

        for (index, part) in members[0].parts.enumerated() {
            guard part.literalText != nil else {
                parts.append(part)
                continue
            }
            let literals = members.map { $0.parts[index].literalText ?? "" }
            if Set(literals).count == 1 {
                parts.append(part)
                continue
            }
            guard !hasText else { return nil }
            hasText = true
            parts += textSlot(across: literals)
        }

        guard parts != [.text] else { return nil }
        return NamePattern(parts: parts, examples: members.map(\.name))
    }

    /// Splits fixed text that differs between names into a text slot and the words around it.
    ///
    /// The shared text is trimmed back to whole words, so that `Tesco` and `Tiger` do not
    /// leave a fixed `T` in front of the slot.
    private static func textSlot(across literals: [String]) -> [Part] {
        var prefix = literals.dropFirst().reduce(literals[0]) { $0.sharedPrefix(with: $1) }
        while let last = prefix.last, last.isLetter || last.isNumber {
            prefix.removeLast()
        }

        let rests = literals.map { String($0.dropFirst(prefix.count).reversed()) }
        var suffix = String(rests.dropFirst().reduce(rests[0]) { $0.sharedPrefix(with: $1) }.reversed())
        while let first = suffix.first, first.isLetter || first.isNumber {
            suffix.removeFirst()
        }

        return [.literal(prefix), .text, .literal(suffix)].filter { $0 != .literal("") }
    }

    /// Reads a name as fixed text with dates and amounts in it.
    private static func parts(of name: String) -> [Part] {
        let text = name as NSString
        var parts: [Part] = []
        var location = 0

        while let (range, slot) = nextSlot(in: name, from: location) {
            if range.location > location {
                parts.append(.literal(text.substring(with: NSRange(location: location, length: range.location - location))))
            }
            parts.append(slot)
            location = NSMaxRange(range)
        }
        if location < text.length {
            parts.append(.literal(text.substring(from: location)))
        }
        return parts
    }

    /// The first date or amount at or after `location`.
    ///
    /// When two start at the same place the longer one wins, so `2026.09.01` is read as a
    /// date rather than as the amount `2026.09`.
    private static func nextSlot(in name: String, from location: Int) -> (NSRange, Part)? {
        let search = NSRange(location: location, length: (name as NSString).length - location)
        let found = finders.compactMap { finder -> (NSRange, Part)? in
            guard let match = finder.regex.firstMatch(in: name, options: .withTransparentBounds, range: search) else {
                return nil
            }
            return (match.range, finder.part((name as NSString).substring(with: match.range)))
        }
        return found.min { a, b in
            a.0.location != b.0.location ? a.0.location < b.0.location : a.0.length > b.0.length
        }
    }

    private struct Finder {
        let regex: NSRegularExpression
        let part: (String) -> Part
    }

    /// The date formats recognised in names, day before month where the year comes last.
    private static let dateFormats = ["yyyyMMdd"] + ["-", ".", "_"].flatMap { separator in
        ["yyyy\(separator)MM\(separator)dd", "dd\(separator)MM\(separator)yyyy"]
    }

    private static let finders: [Finder] = dateFormats.map { format in
        Finder(regex: regex(forDateFormat: format)) { _ in .date(format: format) }
    } + [
        Finder(regex: try! NSRegularExpression(pattern: #"(?<![\d.,])\d+[.,]\d{2}(?![\d.,])"#)) { match in
            .amount(decimalSeparator: match.contains(",") ? "," : ".")
        }
    ]

    /// A pattern matching dates written in `format`, with months and days kept in range so
    /// that an arbitrary eight-digit number is not taken for a date.
    private static func regex(forDateFormat format: String) -> NSRegularExpression {
        let pattern = NSRegularExpression.escapedPattern(for: format)
            .replacingOccurrences(of: "yyyy", with: #"(?:19|20)\d{2}"#)
            .replacingOccurrences(of: "MM", with: "(?:0[1-9]|1[0-2])")
            .replacingOccurrences(of: "dd", with: #"(?:0[1-9]|[12]\d|3[01])"#)
        return try! NSRegularExpression(pattern: #"(?<!\d)"# + pattern + #"(?!\d)"#)
    }
}

private extension NamePattern.Part {

    /// The fixed text, or nil for a slot.
    var literalText: String? {
        if case .literal(let text) = self { text } else { nil }
    }

    /// The part with any fixed text blanked out, so names can be grouped by their slots.
    var shape: Self {
        literalText == nil ? self : .literal("")
    }
}

private extension String {
    func sharedPrefix(with other: String) -> String {
        String(zip(self, other).prefix { $0 == $1 }.map(\.0))
    }
}
