import Foundation
import SwiftUI

extension View {
    func concertCard() -> some View {
        self.padding(.vertical)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.btsCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
