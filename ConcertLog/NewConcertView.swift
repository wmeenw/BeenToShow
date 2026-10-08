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
    @Environment(\.dismiss) private var dismiss
    @Environment(ConcertStore.self) private var store
    
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
                        DatePicker("Дата", selection: $date, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                    }
                    .inputCard()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Оценка")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(String(format: "%.1f", rating))
                                    .font(.title2)
                            Spacer()
                            ForEach(1...5, id: \.self) { i in
                                Image(systemName: Double(i) <= rating ? "star.fill" : "star")
                                    .foregroundStyle(Color.btsPink)
                            }
                        }
                        Slider(value: $rating, in: 0...5, step: 0.1)
                            .tint(Color.btsPink)
                    }
                    .inputCard()
                    
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
                Button {
                    store.add(artist: artist, city: city, date: date, rating: rating, comment: comment, photoData: photoData)
                    dismiss()
                } label: {
                    Text("Сохранить впечатление")
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
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Новое впечатление")
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
    }
}

#Preview {
        NewConcertView()
            .environment(ConcertStore())
}
