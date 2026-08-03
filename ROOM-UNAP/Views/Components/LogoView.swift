import SwiftUI

struct LogoView: View {
    /// Cuando es compacto, el logo se adapta mejor a la barra superior y espacios reducidos.
    var isCompact: Bool = false

    var body: some View {
        Group {
            if isCompact {
                Image("RoomUnapMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .padding(4)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(red: 0.82, green: 0.89, blue: 0.95), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image("RoomUnapLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 176, height: 176)
                    .padding(8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(Color(red: 0.82, green: 0.89, blue: 0.95), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("RoomUnap")
    }
}

#Preview("Light Mode") {
    VStack(spacing: 40) {
        LogoView(isCompact: false)
        LogoView(isCompact: true)
    }
    .padding()
}

#Preview("Dark Mode") {
    VStack(spacing: 40) {
        LogoView(isCompact: false)
        LogoView(isCompact: true)
    }
    .padding()
    .preferredColorScheme(.dark)
}
