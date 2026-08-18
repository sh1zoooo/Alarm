import SwiftUI

struct ContentView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @State private var showingAddSheet = false

    var body: some View {
        NavigationView {
            List {
                ForEach(alarmManager.alarms) { alarm in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(alarm.time, style: .time)
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                            Label(alarm.challenge.rawValue, systemImage: alarm.challenge.icon)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { alarm.isEnabled },
                            set: { _ in alarmManager.toggle(alarm) }
                        ))
                    }
                    .padding(.vertical, 6)
                }
                .onDelete(perform: alarmManager.removeAlarm)
            }
            .navigationTitle("Будильники")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddAlarmView()
                    .environmentObject(alarmManager)
            }
        }
    }
}

struct AddAlarmView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @Environment(\.dismiss) var dismiss

    @State private var time = Date()
    @State private var selectedChallenge: ChallengeType = .dance
    @State private var label = "Будильник"

    var body: some View {
        NavigationView {
            Form {
                Section("Время") {
                    DatePicker("Время", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                }
                Section("Название") {
                    TextField("Будильник", text: $label)
                }
                Section("Задание для выключения") {
                    ForEach(ChallengeType.allCases) { challenge in
                        Button {
                            selectedChallenge = challenge
                        } label: {
                            HStack {
                                Label(challenge.rawValue, systemImage: challenge.icon)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedChallenge == challenge {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Новый будильник")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let alarm = Alarm(time: time, challenge: selectedChallenge, label: label)
                        alarmManager.addAlarm(alarm)
                        dismiss()
                    }
                }
            }
        }
    }
}
