import SwiftUI

struct MarkdownMessageView: View {
    let text: String

    private var blocks: [MarkdownBlock] {
        MarkdownParser.parse(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(blocks) { block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case .heading(let level, let content):
            Text(inlineMarkdown(content))
                .font(headingFont(level))
                .foregroundStyle(.primary)
                .padding(.top, level == 1 ? 4 : 1)

        case .paragraph(let content):
            Text(inlineMarkdown(content))
                .font(.body)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 5, height: 5)
                        Text(inlineMarkdown(item))
                            .font(.body)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text("\(index + 1)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(AppTheme.accent.gradient, in: Circle())
                        Text(inlineMarkdown(item))
                            .font(.body)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .quote(let content):
            HStack(alignment: .top, spacing: 11) {
                Capsule()
                    .fill(AppTheme.accent.opacity(0.75))
                    .frame(width: 3)
                Text(inlineMarkdown(content))
                    .font(.body.italic())
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 3)

        case .code(let content):
            ScrollView(.horizontal) {
                Text(content)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(13)
                    .textSelection(.enabled)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.tertiaryBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            }

        case .table(let headers, let rows):
            MarkdownTableView(headers: headers, rows: rows)

        case .divider:
            Divider()
                .padding(.vertical, 2)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title2.bold()
        case 2: .title3.bold()
        default: .headline
        }
    }
}

private struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        if let first = value(at: 0, in: row), !first.isEmpty {
                            Text(first)
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.accent.opacity(0.1), in: Capsule())
                        }

                        if let title = value(at: 1, in: row), !title.isEmpty {
                            Text(inlineMarkdown(title))
                                .font(.subheadline.bold())
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("\(rowIndex + 1)")
                                .font(.subheadline.bold())
                        }
                    }

                    ForEach(Array(row.dropFirst(min(2, row.count)).enumerated()), id: \.offset) { offset, value in
                        VStack(alignment: .leading, spacing: 3) {
                            let columnIndex = offset + 2
                            if let header = header(at: columnIndex), !header.isEmpty {
                                Text(header.uppercased())
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Text(inlineMarkdown(value))
                                .font(.subheadline)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.tertiaryBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(.primary.opacity(0.06), lineWidth: 1)
                }
            }
        }
    }

    private func value(at index: Int, in row: [String]) -> String? {
        row.indices.contains(index) ? row[index] : nil
    }

    private func header(at index: Int) -> String? {
        headers.indices.contains(index) ? headers[index] : nil
    }
}

private struct MarkdownBlock: Identifiable {
    enum Kind {
        case heading(Int, String)
        case paragraph(String)
        case unorderedList([String])
        case orderedList([String])
        case quote(String)
        case code(String)
        case table(headers: [String], rows: [[String]])
        case divider
    }

    let id: Int
    let kind: Kind
}

private enum MarkdownParser {
    static func parse(_ source: String) -> [MarkdownBlock] {
        let lines = source.components(separatedBy: .newlines)
        var result: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                index += 1
                var codeLines: [String] = []
                while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                append(.code(codeLines.joined(separator: "\n")), to: &result)
                continue
            }

            if index + 1 < lines.count, isTableSeparator(lines[index + 1]), splitTableRow(line).count >= 2 {
                let headers = splitTableRow(line)
                index += 2
                var rows: [[String]] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard !candidate.isEmpty, candidate.contains("|") else { break }
                    let cells = splitTableRow(candidate)
                    guard !cells.isEmpty else { break }
                    rows.append(cells)
                    index += 1
                }
                append(.table(headers: headers, rows: rows), to: &result)
                continue
            }

            if let heading = heading(from: trimmed) {
                append(.heading(heading.level, heading.text), to: &result)
                index += 1
                continue
            }

            if isDivider(trimmed) {
                append(.divider, to: &result)
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                var parts: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard candidate.hasPrefix(">") else { break }
                    parts.append(String(candidate.dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                append(.quote(parts.joined(separator: " ")), to: &result)
                continue
            }

            if unorderedItem(from: trimmed) != nil {
                var items: [String] = []
                while index < lines.count, let item = unorderedItem(from: lines[index].trimmingCharacters(in: .whitespaces)) {
                    items.append(item)
                    index += 1
                }
                append(.unorderedList(items), to: &result)
                continue
            }

            if orderedItem(from: trimmed) != nil {
                var items: [String] = []
                while index < lines.count, let item = orderedItem(from: lines[index].trimmingCharacters(in: .whitespaces)) {
                    items.append(item)
                    index += 1
                }
                append(.orderedList(items), to: &result)
                continue
            }

            var paragraph: [String] = []
            while index < lines.count {
                let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                if candidate.isEmpty || (!paragraph.isEmpty && beginsBlock(lines, at: index)) { break }
                paragraph.append(candidate)
                index += 1
            }
            append(.paragraph(paragraph.joined(separator: " ")), to: &result)
        }

        return result
    }

    private static func append(_ kind: MarkdownBlock.Kind, to result: inout [MarkdownBlock]) {
        result.append(MarkdownBlock(id: result.count, kind: kind))
    }

    private static func beginsBlock(_ lines: [String], at index: Int) -> Bool {
        let value = lines[index].trimmingCharacters(in: .whitespaces)
        return value.hasPrefix("```") ||
            value.hasPrefix(">") ||
            heading(from: value) != nil ||
            isDivider(value) ||
            unorderedItem(from: value) != nil ||
            orderedItem(from: value) != nil ||
            (index + 1 < lines.count && isTableSeparator(lines[index + 1]))
    }

    private static func heading(from line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes) else { return nil }
        let remainder = line.dropFirst(hashes)
        guard remainder.first?.isWhitespace == true else { return nil }
        return (hashes, remainder.trimmingCharacters(in: .whitespaces))
    }

    private static func unorderedItem(from line: String) -> String? {
        for prefix in ["- ", "* ", "+ ", "• "] where line.hasPrefix(prefix) {
            return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func orderedItem(from line: String) -> String? {
        var cursor = line.startIndex
        while cursor < line.endIndex, line[cursor].isNumber {
            cursor = line.index(after: cursor)
        }
        guard cursor > line.startIndex, cursor < line.endIndex, line[cursor] == "." || line[cursor] == ")" else { return nil }
        cursor = line.index(after: cursor)
        guard cursor < line.endIndex, line[cursor].isWhitespace else { return nil }
        return String(line[cursor...]).trimmingCharacters(in: .whitespaces)
    }

    private static func isDivider(_ line: String) -> Bool {
        let compact = line.filter { !$0.isWhitespace }
        guard compact.count >= 3, let first = compact.first, ["-", "*", "_"].contains(first) else { return false }
        return compact.allSatisfy { $0 == first }
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let cells = splitTableRow(line)
        guard cells.count >= 2 else { return false }
        return cells.allSatisfy { cell in
            let compact = cell.filter { $0 != ":" && !$0.isWhitespace }
            return compact.count >= 3 && compact.allSatisfy { $0 == "-" }
        }
    }

    private static func splitTableRow(_ line: String) -> [String] {
        var value = line.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("|") { value.removeFirst() }
        if value.hasSuffix("|") { value.removeLast() }
        return value.split(separator: "|", omittingEmptySubsequences: false).map {
            String($0).trimmingCharacters(in: .whitespaces)
        }
    }
}

private func inlineMarkdown(_ source: String) -> AttributedString {
    (try? AttributedString(
        markdown: source,
        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(source)
}
