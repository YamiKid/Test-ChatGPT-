import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

enum AttachmentProcessor {
    private nonisolated static let maximumDocumentBytes = 10 * 1_024 * 1_024
    private nonisolated static let maximumExtractedCharacters = 8_000

    nonisolated static func processImage(_ sourceData: Data) -> (data: Data, thumbnail: Data)? {
        guard let source = CGImageSourceCreateWithData(sourceData as CFData, nil) else { return nil }
        guard
            let fullImage = downsample(source, maximumPixelSize: 1_600),
            let thumbnailImage = downsample(source, maximumPixelSize: 520),
            let imageData = jpegData(from: fullImage, quality: 0.76),
            let thumbnailData = jpegData(from: thumbnailImage, quality: 0.64)
        else { return nil }
        return (imageData, thumbnailData)
    }

    nonisolated static func processDocument(at url: URL) -> ChatAttachment? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .nameKey, .contentTypeKey])
        guard (values?.fileSize ?? 0) <= maximumDocumentBytes else { return nil }

        let fileName = values?.name ?? url.lastPathComponent
        let contentType = values?.contentType ?? UTType(filenameExtension: url.pathExtension)
        let mimeType = contentType?.preferredMIMEType ?? "text/plain"

        let extracted: String?
        if contentType?.conforms(to: .pdf) == true || url.pathExtension.lowercased() == "pdf" {
            extracted = textFromPDF(at: url)
        } else {
            extracted = textFromPlainFile(at: url)
        }

        guard let extracted, !extracted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return ChatAttachment(
            data: Data(),
            mimeType: mimeType,
            fileName: fileName,
            extractedText: String(extracted.prefix(maximumExtractedCharacters))
        )
    }

    private nonisolated static func downsample(
        _ source: CGImageSource,
        maximumPixelSize: Int
    ) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private nonisolated static func jpegData(from image: CGImage, quality: Double) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    private nonisolated static func textFromPDF(at url: URL) -> String? {
        guard let document = PDFDocument(url: url) else { return nil }
        var result = ""
        for pageIndex in 0..<min(document.pageCount, 40) {
            guard let text = document.page(at: pageIndex)?.string else { continue }
            result += text + "\n\n"
            if result.count >= maximumExtractedCharacters { break }
        }
        return result
    }

    private nonisolated static func textFromPlainFile(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return nil }
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .utf16) {
            return text
        }
        return nil
    }
}
