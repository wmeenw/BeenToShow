import Foundation
import SwiftUI

struct WaitingCardView : View {
    let concert: Concert
    @State private var showEdit = false
    @Environment(\.dismiss) private var dismiss
    @Environment(ConcertStore.self) private var store
    
    private var current: Concert {
        store.concerts.first(where: { $0.id == concert.id }) ?? concert
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
    
    func tile(value: Int, title: String) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", value))
                .font(.system(size: 32, weight: .heavy))
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
                        .font(.system(size: 30, weight: .heavy))
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
                Spacer()
                
                Button {
                    showEdit = true
                } label: {
                    Text("Изменить")
                        .font(.system(size: 17, weight: .semibold))
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
