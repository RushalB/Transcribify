import SwiftUI

struct WaveformView: View {
    var amplitudes: [Float]
    var maxPoints: Int = 100 // number of points to render

    @State private var cachedPath: Path = Path()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                cachedPath
                    .stroke(Color.white, lineWidth: 3)
            }
            .frame(height: 80)
            .background(Color.secondary)
            .onAppear {
                cachedPath = buildPath(from: amplitudes, in: geo.size)
            }
            .onChange(of: amplitudes) { newAmps, _ in // updated for iOS 17+
                cachedPath = buildPath(from: newAmps, in: geo.size)
            }
        }
        .frame(height: 80)
    }

    /// Builds a path with top+bottom mirroring and clamps Y within bounds.
    private func buildPath(from amplitudes: [Float], in size: CGSize) -> Path {
        var path = Path()

        // downsample
        let stride = max(1, amplitudes.count / maxPoints)
        let displayAmps = amplitudes.enumerated()
            .filter { $0.offset % stride == 0 }
            .map { abs($0.element) }

        let midY = size.height / 2
        let scaleFactor: CGFloat = 9.0 // increased sensitivity

        for (i, amp) in displayAmps.enumerated() {
            let x = size.width * CGFloat(i) / CGFloat(displayAmps.count)

            // scale & clamp
            let offset = CGFloat(amp) * midY * scaleFactor
            let clampedOffset = min(offset, midY)

            let yTop = midY - clampedOffset

            if i == 0 {
                path.move(to: CGPoint(x: x, y: yTop))
            } else {
                path.addLine(to: CGPoint(x: x, y: yTop))
            }
        }

        // Mirror the path at the bottom
        for (i, amp) in displayAmps.enumerated().reversed() {
            let x = size.width * CGFloat(i) / CGFloat(displayAmps.count)

            let offset = CGFloat(amp) * midY * scaleFactor
            let clampedOffset = min(offset, midY)

            let yBottom = midY + clampedOffset

            path.addLine(to: CGPoint(x: x, y: yBottom))
        }

        path.closeSubpath()

        return path
    }
}
