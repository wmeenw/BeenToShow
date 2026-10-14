import Foundation
import SwiftUI
import PhotosUI

struct NewConcertView: View {
    @State private var artist = ""
    @State private var city = ""
    @State private var date = Date()
    @State private var rating = 0.0
    @State private var comment = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: Image?
    @State private var photoData: Data?
    @State private var tags: [String] = []
    @State private var availableTags = ["огонь", "до слёз", "танцевала"]
    @State private var showTagAlert = false
    @State private var showDeleteConfirm = false
    @State private var newTag = ""
    var concert: Concert? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(ConcertStore.self) private var store
    
    private var maxDate: Date {
        if let concert, !concert.isPast {
            return Date.distantFuture
        }
        return Date()
    }
    
    private func tagPill(_ tag: String) -> some View {
        let selected = tags.contains(tag)
        return Button {
            if selected {
                tags.removeAll { $0 == tag }
            } else {
                tags.append(tag)
            }
        } label: {
            Text(tag)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    LinearGradient(
                        colors: selected ? [Color.btsPink, Color.btsViolet] : [Color.clear, Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(selected ? 0 : 0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func addCustomTag() {
        let name = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        newTag = ""
        guard !name.isEmpty else { return }
        if !availableTags.contains(name) {
            availableTags.append(name)
        }
        if !tags.contains(name) {
            tags.append(name)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Фото и видео")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        Color.btsPink,
                                        style: StrokeStyle(lineWidth: 1.5, dash: [6])
                                    )
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .font(.title)
                                            .foregroundStyle(Color.btsPink)
                                    )
                            }
                            photo?
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: photoItem) {
                        Task {
                            if let data = try? await photoItem?.loadTransferable(type: Data.self),
                                let ui = UIImage(data: data) {
                                photo = Image(uiImage: ui)
                                photoData = ui.jpegData(compressionQuality: 0.7)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Исполнитель")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Например, Billie Eilish", text: $artist)
                            .font(.title2)
                    }
                    .inputCard()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Город")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Например, Лондон", text: $city)
                            .font(.title2)
                    }
                    .inputCard()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Когда")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        DatePicker("Дата", selection: $date, in: Date.distantPast...maxDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    .inputCard()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Оценка")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 4) {
                                    ForEach(1...5, id: \.self) { i in
                                        Image(systemName: Double(i) <= rating ? "star.fill" : "star")
                                            .foregroundStyle(Color.btsPink)
                                    }
                                }
                            }
                            Spacer()
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 40, weight: .heavy))
                        }
                        Slider(value: $rating, in: 0...5, step: 0.1)
                            .tint(Color.btsPink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Вайб")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TagFlowLayout(spacing: 8) {
                            ForEach(availableTags, id: \.self) { tag in
                                tagPill(tag)
                            }
                            Button {
                                showTagAlert = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.btsPink)
                                    .frame(width: 38, height: 38)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.btsPink, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Комментарий")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Как всё прошло?", text: $comment, axis: .vertical)
                            .font(.title2)
                            .lineLimit(3...6)
                    }
                    .inputCard()
                }
                .padding(.horizontal)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    Button {
                        if let concert {
                            store.update(concert, artist: artist, city: city, date: date, rating: rating, comment: comment, tags: tags, photoData: photoData, saleDate: concert.saleDate, reminders: concert.reminders, remindAfterConcert: concert.remindAfterConcert)
                        } else {
                            store.add(artist: artist, city: city, date: date, rating: rating, comment: comment, tags: tags, photoData: photoData)
                        }
                        dismiss()
                    } label: {
                        Text(concert == nil ? "Сохранить впечатление" : "Сохранить изменения")
                            .font(.headline)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.btsPink, Color.btsViolet],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                    .disabled(artist.isEmpty || city.isEmpty)
                    .opacity(artist.isEmpty || city.isEmpty ? 0.4 : 1)
                    
                    if concert != nil {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Text("Удалить")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.red.opacity(0.85))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle(concert == nil ? "Новое впечатление" : "Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            .background(Color.btsBackground.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
        .confirmationDialog("Удалить концерт?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                if let concert {
                    store.delete(concert)
                }
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Свой тег", isPresented: $showTagAlert) {
            TextField("Например, мурашки", text: $newTag)
                .textInputAutocapitalization(.never)
            Button("Добавить") {
                addCustomTag()
            }
            Button("Отмена", role: .cancel) {
                newTag = ""
            }
        }
        .onAppear() {
            if let concert {
                artist = concert.artist
                city = concert.city
                date = concert.date
                rating = concert.rating ?? 0
                comment = concert.comment ?? ""
                tags = concert.tags
                for tag in concert.tags where !availableTags.contains(tag) {
                    availableTags.append(tag)
                }
                if let name = concert.photoName,
                   let ui = UIImage(contentsOfFile: URL.documentsDirectory.appending(path: name).path) {
                    photo = Image(uiImage: ui)
                }
            }
        }
    }
}

struct TagFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            width = max(width, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
        NewConcertView()
            .environment(ConcertStore())
}
