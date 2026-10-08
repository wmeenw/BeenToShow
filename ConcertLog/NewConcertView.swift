import Foundation
import SwiftUI

struct NewConcertView: View {
    @State private var artist = ""
    @State private var city = ""
    @State private var date = Date()
    @State private var rating = 0.0
    @State private var comment = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(ConcertStore.self) private var store
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Исполнитель")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Например, Billie Eilish", text: $artist)
                            .font(.title3)
                    }
                    .inputCard()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Город")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Например, Лондон", text: $city)
                            .font(.title3)
                    }
                    .inputCard()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Когда")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("Дата", selection: $date, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                    }
                    .inputCard()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Оценка")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(String(format: "%.1f", rating))
                                    .font(.title3)
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
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Как всё прошло?", text: $comment, axis: .vertical)
                            .font(.title3)
                            .lineLimit(3...6)
                    }
                    .inputCard()
                }
                .padding(.horizontal)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    store.add(artist: artist, city: city, date: date, rating: rating, comment: comment)
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
