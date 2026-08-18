import SwiftUI

struct AlarmRingingView: View {
    @EnvironmentObject var alarmManager: AlarmManager

    var body: some View {
        Group {
            switch alarmManager.currentlyRingingAlarm?.challenge ?? .dance {
            case .dance:
                DanceChallengeView(onCompleted: complete)
            case .toiletCamera:
                ToiletCameraChallengeView(onCompleted: complete)
            case .shake:
                ShakeChallengeView(onCompleted: complete)
            case .math:
                MathChallengeView(onCompleted: complete)
            case .qrScan:
                QRScanChallengeView(onCompleted: complete)
            case .steps:
                StepsChallengeView(onCompleted: complete)
            case .simonSays:
                SimonSaysChallengeView(onCompleted: complete)
            case .typing:
                TypingChallengeView(onCompleted: complete)
            }
        }
        .interactiveDismissDisabled(true) // нельзя свайпом закрыть будильник
    }

    private func complete() {
        alarmManager.dismissRinging()
    }
}

/// Общий "каркас" для экрана задания: заголовок, описание, прогресс
struct ChallengeScaffold<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, .red.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                Text(title)
                    .font(.title.bold())
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                content
                    .padding(.top, 12)
            }
            .padding()
        }
    }
}
