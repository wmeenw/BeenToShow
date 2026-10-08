import Foundation
import SwiftUI

struct WaitingCardView : View {
    let concert: Concert
    var parts: DateComponents {
        Calendar.current.dateComponents([.day, .hour, .minute], from: Date(), to: concert.date)
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
        let days = parts.day ?? 0
        let hours = parts.hour ?? 0
        let minutes = parts.minute ?? 0
        
        VStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("ДО КОНЦЕРТА")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.btsLime)
                Text(concert.artist)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)
                Text("\(concert.city) · \(concert.date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))")
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
        }
        .background(Color.btsBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

#Preview {
    WaitingCardView(concert: sampleConcerts[4])
}
