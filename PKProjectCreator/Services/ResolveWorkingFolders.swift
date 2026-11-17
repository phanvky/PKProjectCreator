import Foundation
import libzstd

/// Points a `.drp`'s Working Folders at a new folder. Resolve keeps them in `project.xml`, inside the hex
/// `<FieldsBlob>` that holds the "SetupBA" setting: a Qt byte-array variant holding `[u32][u32 length][flag byte][zstd frame]`, whose
/// frame is a protobuf message. Field 36 of that message is `[u32][u32 length][message]`, and inside it
/// 39 = cache files, 40 = proxy generation, 124 = project media location + "/" + project name (Resolve shows only
/// the folder). Learned from a Resolve export and confirmed by importing rewritten files (2026-11-18).
/// Gallery stills (38) and every other setting are left as they are.
nonisolated enum ResolveWorkingFolders {
    static let cacheField = 39, proxyField = 40, mediaField = 124
    private static let workingFoldersField = 36
    private static let setupKey: [UInt8] = [0, 0, 0, 14] + Array("SetupBA".data(using: .utf16BigEndian)!)
    private static let byteArrayType: UInt32 = 0x0c

    /// Returns `xml` with media, proxy and cache pointing at `folder`. Throws if the settings aren't laid out as expected.
    static func apply(folder: URL, projectName: String, to xml: String) throws -> String {
        // Resolve writes paths precomposed (NFC); file URLs on macOS may come back decomposed.
        let path = folder.plainPath.precomposedStringWithCanonicalMapping
        let paths: [Int: String] = [cacheField: path, proxyField: path, mediaField: path + "/" + projectName]

        let blobs = xml.matches(of: /<FieldsBlob>([0-9a-fA-F]+)<\/FieldsBlob>/).compactMap { match -> (Range<String.Index>, [UInt8], Int)? in
            guard let bytes = bytes(hex: match.output.1), let key = bytes.firstRange(of: setupKey) else { return nil }
            return (match.output.1.startIndex..<match.output.1.endIndex, bytes, key.upperBound)
        }
        guard blobs.count == 1, let first = blobs.first else { throw failure("the Working Folders settings weren’t found.") }
        let (range, blob, keyEnd) = first

        var reader = Reader(blob, at: keyEnd)
        // A Qt variant: type, then an "is null" byte, then the byte array.
        guard try reader.u32() == byteArrayType, try reader.take(1) == [0] else { throw failure("the Working Folders settings have an unknown type.") }
        let lengthAt = reader.at, arrayLength = Int(try reader.u32())
        let array = try reader.take(arrayLength)
        var inner = Reader(array, at: 0)
        let version = try inner.take(4)
        guard Int(try inner.u32()) == arrayLength - 8, let flag = try inner.take(1).first else { throw failure("the settings’ length doesn’t match.") }
        let settings = try decompress(Array(array[inner.at...]))

        var found = 0
        let rewritten = try rewrite(settings) { number, value in
            guard number == workingFoldersField else { return value }
            found += 1
            var header = Reader(value, at: 0)
            let prefix = try header.take(4)
            guard Int(try header.u32()) == value.count - 8 else { throw failure("the Working Folders length doesn’t match.") }
            var seen = Set<Int>()
            var message = try rewrite(Array(value[8...])) { number, value in
                guard let path = paths[number] else { return value }
                seen.insert(number)
                return Array(path.utf8)
            }
            for (number, path) in paths.sorted(by: { $0.key < $1.key }) where !seen.contains(number) {
                message += field(number, Array(path.utf8))
            }
            return prefix + u32(message.count) + message
        }
        guard found == 1 else { throw failure("the Working Folders settings weren’t found.") }

        let payload = [flag] + (try compress(rewritten))
        let newArray = version + u32(payload.count) + payload
        let newBlob = Array(blob[..<lengthAt]) + u32(newArray.count) + newArray + Array(blob[reader.at...])
        var result = xml
        result.replaceSubrange(range, with: newBlob.map { String(format: "%02x", $0) }.joined())
        return result
    }

    // MARK: zstd

    static func decompress(_ frame: [UInt8]) throws -> [UInt8] {
        let size = ZSTD_getFrameContentSize(frame, frame.count)
        guard size < 64 << 20, ZSTD_findFrameCompressedSize(frame, frame.count) == frame.count else {
            throw failure("the settings couldn’t be read.")
        }
        var output = [UInt8](repeating: 0, count: Int(size))
        let written = ZSTD_decompress(&output, output.count, frame, frame.count)
        guard ZSTD_isError(written) == 0, written == output.count else { throw failure("the settings couldn’t be read.") }
        return output
    }

    static func compress(_ data: [UInt8]) throws -> [UInt8] {
        var output = [UInt8](repeating: 0, count: ZSTD_compressBound(data.count))
        let written = ZSTD_compress(&output, output.count, data, data.count, 3)
        guard ZSTD_isError(written) == 0 else { throw failure("the settings couldn’t be written.") }
        return Array(output[..<written])
    }

    // MARK: Protobuf

    /// Copies a protobuf message, passing each length-delimited field through `change`.
    static func rewrite(_ message: [UInt8], _ change: (Int, [UInt8]) throws -> [UInt8]) throws -> [UInt8] {
        var reader = Reader(message, at: 0), output: [UInt8] = []
        while reader.at < message.count {
            let start = reader.at
            let key = try reader.varint()
            switch key & 7 {
            case 0: _ = try reader.varint(); output += message[start..<reader.at]
            case 1: _ = try reader.take(8); output += message[start..<reader.at]
            case 5: _ = try reader.take(4); output += message[start..<reader.at]
            case 2: output += field(Int(key >> 3), try change(Int(key >> 3), try reader.take(Int(try reader.varint()))))
            default: throw failure("the settings use an unknown format.")
            }
        }
        return output
    }

    /// One length-delimited protobuf field.
    static func field(_ number: Int, _ value: [UInt8]) -> [UInt8] {
        varint(UInt64(number << 3 | 2)) + varint(UInt64(value.count)) + value
    }

    private static func varint(_ value: UInt64) -> [UInt8] {
        var value = value, output: [UInt8] = []
        while value >= 0x80 {
            output.append(UInt8(value & 0x7f) | 0x80)
            value >>= 7
        }
        return output + [UInt8(value)]
    }

    private static func u32(_ value: Int) -> [UInt8] { withUnsafeBytes(of: UInt32(value).bigEndian, Array.init) }

    private static func bytes(hex: Substring) -> [UInt8]? {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var output: [UInt8] = [], index = hex.startIndex
        output.reserveCapacity(hex.count / 2)
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            output.append(byte)
            index = next
        }
        return output
    }

    private static func failure(_ reason: String) -> PremiereTemplateError { .resolveFileFailed(reason) }

    /// Reads big-endian integers, varints and byte runs, refusing to read past the end.
    private struct Reader {
        let bytes: [UInt8]
        var at: Int
        init(_ bytes: [UInt8], at: Int) { self.bytes = bytes; self.at = at }

        mutating func take(_ count: Int) throws -> [UInt8] {
            guard count >= 0, at + count <= bytes.count else { throw ResolveWorkingFolders.failure("the settings are cut short.") }
            defer { at += count }
            return Array(bytes[at..<at + count])
        }

        mutating func u32() throws -> UInt32 { try take(4).reduce(0) { $0 << 8 | UInt32($1) } }

        mutating func varint() throws -> UInt64 {
            var value: UInt64 = 0
            for shift in stride(from: 0, to: 64, by: 7) {
                let byte = try take(1)[0]
                value |= UInt64(byte & 0x7f) << shift
                if byte < 0x80 { return value }
            }
            throw ResolveWorkingFolders.failure("the settings use an unknown format.")
        }
    }
}
