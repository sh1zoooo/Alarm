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
                                .foregroundColor(Theme.coral)
                                .font(.headline)
                            Text("Будильники не будут срабатывать, пока ты не разрешишь уведомления в Настройках.")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                            Button("Открыть Настройки") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .tint(Theme.coral)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Theme.surface)
                }

                Section {
                    ForEach(alarmManager.alarms) { alarm in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(Theme.coral.opacity(0.18)).frame(width: 46, height: 46)
                                Image(systemName: alarm.challenge.icon)
                                    .foregroundColor(Theme.coral)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(alarm.time, style: .time)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Text(alarm.challenge.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { alarm.isEnabled },
                                set: { _ in alarmManager.toggle(alarm) }
                            ))
                            .tint(Theme.coral)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Theme.surface)
                    }
                    .onDelete(perform: alarmManager.removeAlarm)

                    if alarmManager.alarms.isEmpty {
                        VStack(spacing: 8) {
                            Text("Будильников пока нет")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Text("Нажми «+» вверху, чтобы поставить первый — и выбрать, чем его выключать.")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .listRowBackground(Theme.surface)
                    }
                }

                Section("Проверить задание сразу") {
                    ForEach(ChallengeType.allCases) { type in
                        Button {
                            alarmManager.testChallenge(type)
                        } label: {
                            Label(type.rawValue, systemImage: type.icon)
                                .foregroundColor(Theme.textPrimary)
                        }
                    }
                    .listRowBackground(Theme.surface)
                }

                Section {
                    Button {
                        AlarmScheduler.scheduleTestAlarm(seconds: 15, challenge: .dance)
                    } label: {
                        Label("Тест реального будильника через 15 сек", systemImage: "timer")
                            .foregroundColor(Theme.textPrimary)
                    }
                    .listRowBackground(Theme.surface)

                    if showPendingDebug {
                        if pendingDescriptions.isEmpty {
                            Text("Нет запланированных уведомлений")
                                .foregroundColor(Theme.textSecondary)
                                .font(.caption)
                                .listRowBackground(Theme.surface)
                        } else {
                            ForEach(pendingDescriptions, id: \.self) { line in
                                Text(line).font(.caption).foregroundColor(Theme.textSecondary)
                                    .listRowBackground(Theme.surface)
                            }
                        }
                        if let last = alarmManager.lastWatchdogCheck {
                            Text("Watchdog последний раз проверял: \(last.formatted(date: .omitted, time: .standard))")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                                .listRowBackground(Theme.surface)
                        } else {
                            Text("Watchdog ещё не запускался")
                                .font(.caption2)
                                .foregroundColor(Theme.coral)
                                .listRowBackground(Theme.surface)
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
                    .tint(Theme.coral)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Разбудильник")
            .onAppear {
                alarmManager.refreshAuthorizationStatus()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.coral)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddAlarmView()
                    .environmentObject(alarmManager)
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.coral)
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
                .listRowBackground(Theme.surface)

                Section("Название") {
                    TextField("Будильник", text: $label)
                }
                .listRowBackground(Theme.surface)

                Section("Задание для выключения") {
                    ForEach(ChallengeType.allCases) { challenge in
                        Button {
                            selectedChallenge = challenge
                        } label: {
                            HStack {
                                Label(challenge.rawValue, systemImage: challenge.icon)
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                if selectedChallenge == challenge {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.coral)
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Новый будильник")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .tint(Theme.coral)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let alarm = Alarm(time: time, challenge: selectedChallenge, label: label)
                        alarmManager.addAlarm(alarm)
                        dismiss()
                    }
                    .tint(Theme.coral)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
