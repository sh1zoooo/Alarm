import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var alarmManager: AlarmManager
    @State private var showingAddSheet = false
    @State private var showPendingDebug = false
    @State private var pendingDescriptions: [String] = []

    var body: some View {
        NavigationView {
            List {
                if !alarmManager.notificationsAuthorized {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Уведомления запрещены", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.headline)
                            Text("Будильники не будут срабатывать, пока ты не разрешишь уведомления в Настройках.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button("Открыть Настройки") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Проверить задание сразу (без ожидания)") {
                    ForEach(ChallengeType.allCases) { type in
                        Button {
                            alarmManager.testChallenge(type)
                        } label: {
                            Label(type.rawValue, systemImage: type.icon)
                        }
                    }
                }

                Section {
                    Button {
                        AlarmScheduler.scheduleTestAlarm(seconds: 15, challenge: .dance)
                    } label: {
                        Label("Тест реального будильника через 15 сек", systemImage: "timer")
                    }
                    if showPendingDebug {
                        if pendingDescriptions.isEmpty {
                            Text("Нет запланированных уведомлений")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        } else {
                            ForEach(pendingDescriptions, id: \.self) { line in
                                Text(line).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        if let last = alarmManager.lastWatchdogCheck {
                            Text("Watchdog последний раз проверял: \(last.formatted(date: .omitted, time: .standard))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Watchdog ещё не запускался")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                } footer: {
                    Button(showPendingDebug ? "Скрыть отладку" : "Показать отладку (что реально запланировано)") {
                        showPendingDebug.toggle()
                        if showPendingDebug {
                            AlarmScheduler.fetchPendingDescriptions { pendingDescriptions = $0 }
                        }
                    }
                    .font(.caption)
                }

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
            .onAppear {
                alarmManager.refreshAuthorizationStatus()
            }
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
