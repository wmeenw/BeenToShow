import Foundation
import SwiftUI

struct WaitingCardView : View {
    let concert: Concert
    @State private var showEdit = false
    @State private var notes = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(ConcertStore.self) private var store

    private var current: Concert {
        store.concerts.first(where: { $0.id == concert.id }) ?? concert
    }

    private func saveNotes() {
        store.update(
            current,
            artist: current.artist,
            city: current.city,
            date: current.date,
            rating: current.rating ?? 0,
            comment: notes,
            tags: current.tags,
            saleDate: current.saleDate,
            reminders: current.reminders,
            remindAfterConcert: current.remindAfterConcert
        )
    }
    
    private var headline: String {
        if let sale = current.saleDate, sale > Date() {
            return "ПРОДАЖА БИЛЕТОВ СКОРО"
        }
        return "ДО КОНЦЕРТА"
    }
    
    func parts(from now: Date) -> DateComponents {
        Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: current.date)
    }
    
    private var showWhatsNext: Bool {
        current.saleDate != nil || !current.reminders.isEmpty || current.remindAfterConcert
    }

    private var reminderStatusText: String {
        if current.reminders.isEmpty {
            return "Напоминания не будет"
        }
        return "Напомним: " + current.reminders.map { $0.lowercased() }.joined(separator: ", ")
    }

    private var reminderStatusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: current.reminders.isEmpty ? "bell.slash" : "bell.fill")
                .foregroundStyle(current.reminders.isEmpty ? Color.white.opacity(0.4) : Color.btsLime)
            Text(reminderStatusText)
                .font(.onest(13, .medium))
                .foregroundStyle(current.reminders.isEmpty ? Color.white.opacity(0.4) : Color.white.opacity(0.8))
        }
        .padding(.horizontal)
    }

    private var notesBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ЗАМЕТКИ")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Место, ряд, с кем идёшь, что взять")
                        .font(.onest(15))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
                TextEditor(text: $notes)
                    .scrollContentBackground(.hidden)
                    .font(.onest(15))
                    .foregroundStyle(.white)
            }
            .frame(minHeight: 100)
        }
        .padding(.horizontal)
        .concertCard()
        .padding(.horizontal)
    }

    private var whatsNextBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ЧТО ДАЛЬШЕ")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
            if let sale = current.saleDate {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Старт продаж")
                        .font(.onest(13))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(sale.formatted(.dateTime.day().month(.wide).hour().minute()))
                        .font(.onest(17, .semibold))
                        .foregroundStyle(.white)
                    if sale > Date() {
                        let days = max(0, Calendar.current.dateComponents([.day], from: Date(), to: sale).day ?? 0)
                        Text(days > 0 ? "через \(days) \(daysWord(days))" : "уже сегодня")
                            .font(.onest(13, .semibold))
                            .foregroundStyle(Color.btsLime)
                    }
                }
            }
            if !current.reminders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Напомнить")
                        .font(.onest(13))
                        .foregroundStyle(.white.opacity(0.5))
                    TagFlowLayout(spacing: 8) {
                        ForEach(current.reminders, id: \.self) { reminder in
                            Text(reminder)
                                .font(.onest(14, .semibold))
                                .foregroundStyle(.black)
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.btsLime)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            if current.remindAfterConcert {
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(Color.btsLime)
                    Text("Напомню записать впечатление после концерта")
                        .font(.onest(14))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal)
        .concertCard()
        .padding(.horizontal)
    }

    func tile(value: Int, title: String) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", value))
                .font(.unbounded(32, .bold))
                .foregroundStyle(Color.btsLime)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.btsLime.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let p = parts(from: context.date)
            let days = p.day ?? 0
            let hours = p.hour ?? 0
            let minutes = p.minute ?? 0
            
            VStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(headline)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.btsLime)
                    Text(current.artist)
                        .font(.unbounded(30, .bold))
                        .foregroundStyle(.white)
                    Text("\(current.city) · \(current.date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))")
                        .foregroundStyle(.white.opacity(0.5))
                    
                    HStack(spacing: 12) {
                        tile(value: days, title: daysWord(days))
                        tile(value: hours, title: hoursWord(hours))
                        tile(value: minutes, title: minutesWord(minutes))
                    }
                }
                
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.btsCard)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(colors: [Color.btsPink, Color.btsViolet],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2))
                .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 16) {
                        reminderStatusRow
                        notesBlock
                        if showWhatsNext {
                            whatsNextBlock
                        }
                    }
                    .padding(.vertical, 16)
                }

                Button {
                    if notes != (current.comment ?? "") {
                        saveNotes()
                    }
                    showEdit = true
                } label: {
                    Text("Изменить")
                        .font(.onest(17, .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.btsCard)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .sheet(isPresented: $showEdit) { NewWaitingView(concert: current) }
            }
            .background(Color.btsBackground.ignoresSafeArea())
            .preferredColorScheme(.dark)
        }
        .onAppear {
            notes = current.comment ?? ""
        }
        .onDisappear {
            if notes != (current.comment ?? "") {
                saveNotes()
            }
        }
        .onChange(of: store.concerts.contains { $0.id == concert.id }) { _, exists in
            if !exists {
                dismiss()
            }
        }
    }
}

#Preview {
    WaitingCardView(concert: sampleConcerts[4])
        .environment(ConcertStore())
}
