import Foundation
import PDFKit
import Vision
import ImageIO
import ZIPFoundation

enum DocumentReader {
    static let maximumBytes = 25_000_000

    static func readFile(_ url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= maximumBytes else { throw StudyError.invalid(String(localized: "The file is too large. Choose a file under 25 MB.")) }
            let data = try Data(contentsOf: url)
            guard data.count <= maximumBytes else { throw StudyError.invalid(String(localized: "The file is too large. Choose a file under 25 MB.")) }
            let text: String
            switch url.pathExtension.lowercased() {
            case "pdf": text = try readPDF(data)
            case "docx": text = try readDOCX(data)
            default: throw StudyError.invalid(String(localized: "Use Word .docx or PDF. For old Word .doc files, export to PDF before importing."))
            }
            return try checked(text)
        }.value
    }

    static func readImages(_ images: [Data]) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            guard !images.isEmpty, images.count <= 12 else { throw StudyError.invalid(String(localized: "Select 1 to 12 pages at a time.")) }
            var pages: [String] = []
            for (index, data) in images.enumerated() {
                try Task.checkCancellation()
                guard data.count <= maximumBytes else { throw StudyError.invalid(String(localized: "An image exceeds 25 MB.")) }
                let text = try recognize(data)
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw StudyError.invalid(String(localized: "Couldn't read the text on page \(index + 1). Retake the photo sharper, well lit and straight."))
                }
                pages.append(String(localized: "[Page \(index + 1)]\n\(text)"))
            }
            return try checked(pages.joined(separator: "\n\n"))
        }.value
    }

    private static func checked(_ text: String) throws -> String {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw StudyError.invalid(String(localized: "No text found. A Word file with only images should be exported to PDF for text recognition.")) }
        guard text.count <= 100_000 else { throw StudyError.invalid(String(localized: "The document is too long. Split it into lessons under 100,000 characters.")) }
        return text
    }

    private static func recognize(_ data: Data) throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 3000
              ] as CFDictionary) else { throw StudyError.invalid(String(localized: "Couldn't open this image.")) }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let supported = try request.supportedRecognitionLanguages()
        let preferred = ["vi-VN", "en-US", "zh-Hans", "fr-FR", "de-DE", "ru-RU"].filter { supported.contains($0) }
        if !preferred.isEmpty { request.recognitionLanguages = preferred }
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    private static func readPDF(_ data: Data) throws -> String {
        guard let document = PDFDocument(data: data), !document.isLocked else {
            throw StudyError.invalid(String(localized: "The PDF is locked or unreadable. Export a PDF without a password."))
        }
        guard (1...40).contains(document.pageCount) else { throw StudyError.invalid(String(localized: "Each lesson supports up to 40 PDF pages. Split the document before importing.")) }
        var pages: [String] = []
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { throw StudyError.invalid(String(localized: "Couldn't open page \(index + 1).")) }
            var text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty {
                let thumbnail = page.thumbnail(of: CGSize(width: 1800, height: 2400), for: .mediaBox)
                if let imageData = thumbnail.pngData() { text = try recognize(imageData) }
            }
            let pageText = text.isEmpty ? String(localized: "[No text recognized — check the original]") : text
            pages.append(String(localized: "[Page \(index + 1)]\n\(pageText)"))
        }
        return pages.joined(separator: "\n\n")
    }

    static func readDOCX(_ data: Data) throws -> String {
        let archive = try Archive(data: data, accessMode: .read)
        guard let entry = archive["word/document.xml"], entry.type == .file, entry.uncompressedSize <= 10_000_000 else {
            throw StudyError.invalid(String(localized: "The Word file is invalid or its text part is too large."))
        }
        var xml = Data()
        let crc = try archive.extract(entry) { chunk in
            guard xml.count + chunk.count <= 10_000_000 else { throw StudyError.invalid(String(localized: "The Word content is too large.")) }
            xml.append(chunk)
        }
        guard crc == entry.checksum else { throw StudyError.invalid(String(localized: "The Word file has corrupted data.")) }
        return try WordTextParser.read(xml)
    }
}

final class WordTextParser: NSObject, XMLParserDelegate {
    private var readingText = false
    private var deletedDepth = 0
    private var output = ""

    static func read(_ data: Data) throws -> String {
        let delegate = WordTextParser()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse() else { throw StudyError.invalid(String(localized: "Couldn't read the Word text structure.")) }
        return delegate.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "del" { deletedDepth += 1 }
        guard deletedDepth == 0 else { return }
        if elementName == "t" { readingText = true }
        if elementName == "tab" { output += "\t" }
        if elementName == "br" { output += "\n" }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if readingText && deletedDepth == 0 { output += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "del" { deletedDepth = max(0, deletedDepth - 1) }
        if elementName == "t" { readingText = false }
        if elementName == "p" { output += "\n" }
        if elementName == "tc" { output += "\t" }
    }
}
