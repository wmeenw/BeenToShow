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
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Исполнитель")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Например, Charli XCX", text: $artist)
                            .font(.title2)
                    }
                    .inputCard()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Город")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Например, Париж", text: $city)
                            .font(.title2)
                    }
                    .inputCard()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Когда")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        DatePicker("Дата", selection: $date, in: Date()..., displayedComponents: .date)
                            .labelsHidden()
                    }
                    .inputCard()
                }
                .padding(.horizontal)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    store.add(artist: artist, city: city, date: date, rating: 0, comment: "")
                    dismiss()
                } label: {
                    Text("Добавить в ожидаемые")
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
            .navigationTitle("Ждём концерт")
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
    NewWaitingView()
        .environment(ConcertStore())
}
