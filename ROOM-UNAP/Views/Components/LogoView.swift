import SwiftUI
struct LogoView: View {
    /// Determina si el logo se muestra en tamaño grande (Login) o pequeño (NavigationBar)
    var isCompact: Bool = false
    
    var body: some View {
        HStack(spacing: isCompact ? 8 : 16) {
            
            // ISOTIPO: alojamiento estudiantil sin repetir la inicial del logotipo
            ZStack {
                RoundedRectangle(cornerRadius: isCompact ? 8 : 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.8), Color.accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isCompact ? 32 : 64, height: isCompact ? 32 : 64)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: isCompact ? 4 : 12, x: 0, y: isCompact ? 2 : 6)
                
                Image(systemName: "house.fill")
                    .font(.system(size: isCompact ? 17 : 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // LOGOTIPO: "RoomUnap"
            HStack(spacing: 0) {
                Text("Room")
                    .font(.system(size: isCompact ? 22 : 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Unap")
                    .font(.system(size: isCompact ? 22 : 36, weight: .light, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }
}
// Vista previa para que Xcode la muestre en el Canvas
#Preview("Light Mode") {
    VStack(spacing: 50) {
        LogoView(isCompact: false)
        LogoView(isCompact: true)
    }
    .padding()
}
#Preview("Dark Mode") {
    VStack(spacing: 50) {
        LogoView(isCompact: false)
        LogoView(isCompact: true)
    }
    .padding()
    .preferredColorScheme(.dark)
}
