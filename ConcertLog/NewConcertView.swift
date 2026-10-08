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
            Form {
                TextField("Исполнитель", text: $artist)
                TextField("Город", text: $city)
                DatePicker("Дата", selection: $date,in: ...Date(), displayedComponents: .date)
                Stepper("Оценка: \(rating, specifier: "%.1f")", value: $rating, in: 0...5, step: 0.1)
                TextField("Комментарий", text: $comment, axis: .vertical)
                Button("Сохранить впечатление") {
                    store.add(artist: artist, city: city, date: date, rating: rating, comment: comment)
                    dismiss()
                }
                .disabled(artist.isEmpty || city.isEmpty)
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
        }
    }
}

#Preview {
    NewConcertView()
        .environment(ConcertStore())
}
