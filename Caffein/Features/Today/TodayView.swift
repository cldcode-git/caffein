import CaffeineKit
import SwiftData
import SwiftUI

struct TodayView: View {
    @Query(sort: \CaffeineIntake.date, order: .reverse) private var intakes: [CaffeineIntake]
    @Query(sort: \PulseReading.date, order: .reverse) private var readings: [PulseReading]
    @Query(sort: \SleepLog.date, order: .reverse) private var sleepLogs: [SleepLog]
    @Query(sort: \TensionRating.day, order: .reverse) private var ratings: [TensionRating]
    @Environment(\.modelContext) private var context

    // Re-read on every change so the maths follows the settings screen.
    @AppStorage(SettingsKey.bedtimeMinutes) private var bedtimeMinutes = 23 * 60
    @AppStorage(SettingsKey.profileAge) private var profileAge = 0
    @AppStorage(SettingsKey.profileWeight) private var profileWeight = 0.0
    @AppStorage(SettingsKey.pregnant) private var pregnant = false
    @AppStorage(SettingsKey.sensitivity) private var sensitivityRaw = CaffeineSensitivity.normal.rawValue
    @AppStorage(AppLanguage.storageKey) private var languageRaw = AppLanguage.system.rawValue

    @State private var showMorning = false
    @State private var showTense = false
    @State private var showDrinkPicker = false
    /// A quick-add drink waiting for its count and time.
    @State private var choice: DrinkChoice?
    @State private var showGuide = false
    @State private var showProfile = false
    @State private var undo: UndoToast?

    private var prefs: CaffeinePreferences {
        CaffeinePreferences(bedtimeMinutes: bedtimeMinutes,
                            sensitivity: CaffeineSensitivity(rawValue: sensitivityRaw) ?? .normal,
                            profile: CaffeinePreferences.profile(age: profileAge, weight: profileWeight, pregnant: pregnant))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let now = timeline.date
            let status = Wellness.caffeineStatus(intakes, prefs: prefs, now: now)
            ScrollView {
                VStack(spacing: 16) {
                    MorningCard(reading: Wellness.todaysMorningReading(readings, now: now),
                                sleep: Wellness.todaysSleep(sleepLogs, now: now),
                                baseline: Wellness.baseline(readings, now: now),
                                start: { showMorning = true })

                    CaffeineCard(status: status, limit: prefs.limit, now: now,
                                 openGuide: { showGuide = true }, editProfile: { showProfile = true })

                    WaterCard(target: WaterGuide.target(weightKg: profileWeight > 0 ? profileWeight : nil,
                                                        caffeineTodayMg: status.todayTotalMg),
                              hasWeight: profileWeight > 0)

                    QuickAddCard(
                        drinks: DrinkCatalog.quickAdd(recentDrinkIDs: recentDrinkIDs(now: now),
                                                      defaults: DrinkText.defaultQuickAdd,
                                                      language: AppLanguage.current.resolvedCode),
                        todayIntakes: Wellness.todayIntakes(intakes, now: now),
                        add: { choice = DrinkChoice(drink: $0, customName: nil) },
                        changeServings: changeServings,
                        delete: delete,
                        more: { showDrinkPicker = true }
                    )

                    StressCard(assessment: Wellness.stress(readings: readings, ratings: ratings, now: now),
                               baselineProgress: Wellness.baselineProgress(readings, now: now),
                               tense: { showTense = true })

                    EveningCard(score: Wellness.todaysTension(ratings, now: now)?.score) { score in
                        rateTension(score, now: now)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle(greeting(now))
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Ayarlar")
            }
        }
        .overlay(alignment: .bottom) {
            if let undo {
                UndoToastView(toast: undo) {
                    switch undo.action {
                    case .removeAdded(let id):
                        if let intake = intakes.first(where: { $0.persistentModelID == id }) {
                            context.delete(intake)
                        }
                    case .restore(let copy):
                        context.insert(copy.makeIntake())
                    }
                    try? context.save()
                    self.undo = nil
                }
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: undo)
        .sheet(isPresented: $showMorning) { MorningCheckInView() }
        .sheet(isPresented: $showTense) { TenseFlowView() }
        .sheet(isPresented: $showDrinkPicker) {
            DrinkPickerView { drink, name, servings, date in
                add(drink, name: name, servings: servings, date: date)
            }
        }
        .sheet(item: $choice) { choice in
            NavigationStack {
                AddDrinkForm(choice: choice) { servings, date in
                    add(choice.drink, name: choice.customName, servings: servings, date: date)
                    self.choice = nil
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Kapat") { self.choice = nil }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack { ProfileView() }
        }
        .sheet(isPresented: $showGuide) {
            NavigationStack { PalpitationGuideView() }
        }
    }

    // MARK: - Actions

    private func add(_ drink: Drink, name: String? = nil, servings: Int = 1, date: Date = Date()) {
        let displayName = name ?? DrinkText.name(drink.id) ?? drink.id
        let intake = CaffeineIntake(date: date, drinkID: drink.id, name: displayName, caffeineMg: drink.caffeineMg,
                                    symbol: drink.symbol, servings: servings)
        context.insert(intake)
        try? context.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let label = servings > 1 ? "\(servings) × \(displayName)" : displayName
        show(UndoToast(text: L("\(label) eklendi · \(intake.totalMg.mgText)"),
                       action: .removeAdded(intake.persistentModelID)))
    }

    /// The − and + on a logged drink. Going below one removes it (with undo).
    private func changeServings(_ intake: CaffeineIntake, by delta: Int) {
        let newValue = intake.servings + delta
        if newValue < 1 {
            delete(intake)
        } else {
            intake.servings = min(newValue, 10)
            try? context.save()
        }
    }

    private func delete(_ intake: CaffeineIntake) {
        let toast = UndoToast(text: L("\(DrinkText.displayName(intake)) silindi"),
                              action: .restore(IntakeCopy(intake)))
        context.delete(intake)
        try? context.save()
        show(toast)
    }

    private func show(_ toast: UndoToast) {
        undo = toast
        Task {
            try? await Task.sleep(for: .seconds(4))
            if undo == toast { undo = nil }
        }
    }

    private func rateTension(_ score: Int, now: Date) {
        let day = DayClock.dayStart(for: now)
        if let existing = Wellness.todaysTension(ratings, now: now) {
            existing.score = score
        } else {
            context.insert(TensionRating(day: day, score: score))
        }
    }

    /// Favourites from the last 30 days, excluding today, so the buttons
    /// don't reorder under the user's finger while they log drinks.
    private func recentDrinkIDs(now: Date) -> [String] {
        let todayStart = DayClock.dayStart(for: now)
        return intakes.filter { $0.date > now.addingTimeInterval(-30 * 86_400) && $0.date < todayStart }
            .map(\.drinkID)
    }

    private func greeting(_ now: Date) -> String {
        switch DayClock.calendar.component(.hour, from: now) {
        case 4..<12: L("Günaydın")
        case 12..<18: L("İyi günler")
        default: L("İyi akşamlar")
        }
    }
}

struct UndoToast: Equatable {
    enum Action: Equatable {
        /// Undo an add: delete the new intake.
        case removeAdded(PersistentIdentifier)
        /// Undo a delete: insert the intake again.
        case restore(IntakeCopy)
    }

    /// Two toasts with the same text are still different toasts.
    let token = UUID()
    let text: String
    let action: Action
}

/// The fields of a deleted intake, kept so the delete can be undone.
struct IntakeCopy: Equatable {
    let date: Date
    let drinkID: String
    let name: String
    let caffeineMg: Double
    let symbol: String
    let servings: Int

    init(_ intake: CaffeineIntake) {
        date = intake.date
        drinkID = intake.drinkID
        name = intake.name
        caffeineMg = intake.caffeineMg
        symbol = intake.symbol
        servings = intake.servings
    }

    func makeIntake() -> CaffeineIntake {
        CaffeineIntake(date: date, drinkID: drinkID, name: name, caffeineMg: caffeineMg, symbol: symbol,
                       servings: servings)
    }
}

private struct UndoToastView: View {
    let toast: UndoToast
    let undo: () -> Void

    var body: some View {
        HStack {
            Text(toast.text).font(.subheadline).lineLimit(1)
            Spacer()
            Button("Geri al", action: undo).font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: Capsule())
        .padding(.horizontal, 16)
    }
}
