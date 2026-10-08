import Foundation
import SwiftUI

struct NewWaitingView: View {
    @State private var artist = ""
    @State private var city = ""
    @State private var date = Date()
    @Environment(\.dismiss) private var dismiss
    @Environment(ConcertStore.self) private var store
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Исполнитель", text: $artist)
                TextField("Город", text: $city)
                DatePicker("Дата", selection: $date,in: Date()..., displayedComponents: .date)
                Button("Добавить в ожидаемые") {
                    store.add(artist: artist, city: city, date: date, rating: 0, comment: "")
                    dismiss()
                }
                .disabled(artist.isEmpty || city.isEmpty)
            }
            .navigationTitle("Ждем концерт")
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
    NewWaitingView()
        .environment(ConcertStore())
}
