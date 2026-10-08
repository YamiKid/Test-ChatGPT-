import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct ComposerView: View {
    private let actionButtonSize: CGFloat = 42
    private let maximumAttachmentCount = 3

    let isGenerating: Bool
    let onSend: (String, [ChatAttachment]) -> Void
    let onStop: () -> Void

    @State private var text = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var attachments: [ChatAttachment] = []
    @State private var isLoadingAttachments = false
    @State private var isShowingFileImporter = false
    @State private var attachmentErrorMessage = ""
    @State private var showsAttachmentError = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            if !attachments.isEmpty {
                attachmentPreview
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: 10) {
                Menu {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: max(1, maximumAttachmentCount - attachments.count),
                        matching: .images
                    ) {
                        Label(L10n.addPhoto, systemImage: "photo.on.rectangle.angled")
                    }

                    Button {
                        isShowingFileImporter = true
                    } label: {
                        Label(L10n.addFile, systemImage: "doc.badge.plus")
                    }
                } label: {
                    Group {
                        if isLoadingAttachments {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: actionButtonSize, height: actionButtonSize)
                    .background(AppTheme.accent.opacity(0.1), in: Circle())
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isGenerating || isLoadingAttachments || attachments.count >= maximumAttachmentCount)
                .accessibilityLabel(L10n.addAttachment)

                TextField(L10n.messagePlaceholder, text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .disabled(isGenerating)
                    .padding(.vertical, 11)

                Button {
                    if isGenerating {
                        SoundFeedback.button()
                        onStop()
                    } else {
                        send()
                    }
                } label: {
                    Image(systemName: isGenerating ? "stop.fill" : "arrow.up")
                        .font(.system(size: isGenerating ? 13 : 16, weight: .bold))
                        .foregroundStyle(canSend || isGenerating ? Color.white : Color.secondary)
                        .frame(width: actionButtonSize, height: actionButtonSize)
                        .background(
                            canSend || isGenerating ? AppTheme.accent : AppTheme.tertiaryBackground,
                            in: Circle()
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!isGenerating && !canSend)
                .accessibilityLabel(isGenerating ? L10n.stopGeneration : L10n.send)
            }
            .padding(.leading, 13)
            .padding(.trailing, 7)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .stroke(.primary.opacity(0.09), lineWidth: 1)
            }

            Text(L10n.disclaimer)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 5)
        .background(.ultraThinMaterial)
        .animation(.easeOut(duration: 0.2), value: attachments.count)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadImages(from: items) }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: allowedDocumentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await loadDocuments(from: urls) }
            case .failure:
                showAttachmentError(L10n.fileReadErrorMessage)
            }
        }
        .alert(L10n.attachmentErrorTitle, isPresented: $showsAttachmentError) {
            Button(L10n.done, role: .cancel) {}
        } message: {
            Text(attachmentErrorMessage)
        }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
    }

    private func send() {
        guard canSend, !isGenerating else { return }
        let prompt = text
        let sentAttachments = attachments
        isFocused = false
        text = ""
        attachments = []
        pickerItems = []
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        onSend(prompt, sentAttachments)
    }

    private var attachmentPreview: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(attachments) { attachment in
                    ZStack(alignment: .topTrailing) {
                        if attachment.isImage, let image = UIImage(data: attachment.previewData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 76, height: 76)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(.primary.opacity(0.1), lineWidth: 1)
                                }
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: fileIcon(for: attachment))
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(AppTheme.accent)
                                Text(attachment.displayName)
                                    .font(.caption2.weight(.medium))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.primary)
                            }
                            .padding(8)
                            .frame(width: 104, height: 76)
                            .background(AppTheme.secondaryBackground, in: RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.primary.opacity(0.08), lineWidth: 1)
                            }
                        }

                        Button {
                            SoundFeedback.button()
                            attachments.removeAll { $0.id == attachment.id }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(.black.opacity(0.68), in: Circle())
                        }
                        .offset(x: 5, y: -5)
                        .accessibilityLabel(L10n.removeAttachment)
                    }
                    .padding(.top, 5)
                    .padding(.trailing, 5)
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
        .frame(height: 86)
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        isLoadingAttachments = true
        defer {
            isLoadingAttachments = false
            pickerItems = []
        }

        var loaded: [ChatAttachment] = []
        for item in items.prefix(maximumAttachmentCount - attachments.count) {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            guard let processed = await Task.detached(priority: .userInitiated, operation: {
                AttachmentProcessor.processImage(data)
            }).value else { continue }
            loaded.append(ChatAttachment(data: processed.data, thumbnailData: processed.thumbnail))
        }
        attachments.append(contentsOf: loaded)
        if loaded.count < min(items.count, maximumAttachmentCount - attachments.count + loaded.count) {
            showAttachmentError(L10n.imageReadErrorMessage)
        }
    }

    private func loadDocuments(from urls: [URL]) async {
        let availableSlots = maximumAttachmentCount - attachments.count
        guard availableSlots > 0 else {
            showAttachmentError(L10n.attachmentLimitMessage)
            return
        }

        isLoadingAttachments = true
        defer { isLoadingAttachments = false }

        let selectedURLs = Array(urls.prefix(availableSlots))
        var loaded: [ChatAttachment] = []
        for url in selectedURLs {
            if let attachment = await Task.detached(priority: .userInitiated, operation: {
                AttachmentProcessor.processDocument(at: url)
            }).value {
                loaded.append(attachment)
            }
        }
        attachments.append(contentsOf: loaded)
        if loaded.count != selectedURLs.count {
            showAttachmentError(L10n.fileReadErrorMessage)
        } else if urls.count > availableSlots {
            showAttachmentError(L10n.attachmentLimitMessage)
        }
    }

    private var allowedDocumentTypes: [UTType] {
        [.pdf, .plainText, .commaSeparatedText, .json, .xml, .sourceCode]
    }

    private func fileIcon(for attachment: ChatAttachment) -> String {
        if attachment.mimeType == "application/pdf" { return "doc.richtext.fill" }
        if attachment.mimeType.contains("json") { return "curlybraces.square.fill" }
        if attachment.mimeType.contains("csv") { return "tablecells.fill" }
        return "doc.text.fill"
    }

    private func showAttachmentError(_ message: String) {
        attachmentErrorMessage = message
        showsAttachmentError = true
    }
}
