import Foundation
import SwiftUI

struct NewWaitingView: View {
    @State private var artist = ""
    @State private var city = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @State private var saleEnabled = false
    @State private var saleDate = Date()
    @State private var reminders: [String] = []
    @State private var remindAfterConcert = false
    var concert: Concert? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(ConcertStore.self) private var store
    
    private var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }
    
    private let reminderOptions = ["За неделю", "За день", "За час"]
    
    private func reminderPill(_ title: String) -> some View {
        let selected = reminders.contains(title)
        return Button {
            if selected {
                reminders.removeAll { $0 == title }
            } else {
                reminders.append(title)
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selected ? Color.black : Color.white)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(selected ? Color.btsLime : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(selected ? 0 : 0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func save() {
        let sale = saleEnabled ? saleDate : nil
        if let concert {
            store.update(
                concert,
                artist: artist,
                city: city,
                date: date,
                rating: concert.rating ?? 0,
                comment: concert.comment ?? "",
                tags: concert.tags,
                saleDate: sale,
                reminders: reminders,
                remindAfterConcert: remindAfterConcert
            )
        } else {
            store.add(
                artist: artist,
                city: city,
                date: date,
                rating: 0,
                comment: "",
                saleDate: sale,
                reminders: reminders,
                remindAfterConcert: remindAfterConcert
            )
        }
    }
    
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
                        DatePicker("Дата", selection: $date, in: tomorrow..., displayedComponents: .date)
                            .labelsHidden()
                    }
                    .inputCard()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $saleEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Старт продажи билетов")
                                    .font(.headline)
                                Text("Указать")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(Color.btsPink)
                        if saleEnabled {
                            DatePicker("Дата и время", selection: $saleDate, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }
                    }
                    .inputCard()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Напомнить")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TagFlowLayout(spacing: 8) {
                            ForEach(reminderOptions, id: \.self) { title in
                                reminderPill(title)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Toggle("Напомнить записать впечатление после концерта", isOn: $remindAfterConcert)
                        .tint(Color.btsPink)
                        .inputCard()
                }
                .padding(.horizontal)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    save()
                    dismiss()
                } label: {
                    Text(concert == nil ? "Добавить в ожидаемые" : "Сохранить изменения")
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
            .navigationTitle(concert == nil ? "Ждём концерт" : "Редактирование")
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
        .onAppear {
            if let concert {
                artist = concert.artist
                city = concert.city
                date = concert.date
                if let sale = concert.saleDate {
                    saleEnabled = true
                    saleDate = sale
                }
                reminders = concert.reminders
                remindAfterConcert = concert.remindAfterConcert
            }
        }
    }
}

#Preview {
    NewWaitingView()
        .environment(ConcertStore())
}
