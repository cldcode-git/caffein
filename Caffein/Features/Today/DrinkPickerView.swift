import CaffeineKit
import SwiftUI

/// Full drink list, grouped by kind, plus a custom entry. Picking a drink
/// opens the count-and-time form.
struct DrinkPickerView: View {
    let add: (_ drink: Drink, _ customName: String?, _ servings: Int, _ date: Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var customName = ""
    @State private var customMg = ""
    @State private var search = ""
    @State private var selected: DrinkChoice?

    var body: some View {
        NavigationStack {
            List {
                ForEach(DrinkCategory.allCases) { category in
                    let drinks = filtered(category)
                    if !drinks.isEmpty {
                        Section(DrinkText.category(category)) {
                            ForEach(drinks) { row($0) }
                        }
                    }
                }
                Section {
                    TextField("İçecek adı", text: $customName)
                    TextField("Kafein (mg)", text: $customMg)
                        .keyboardType(.numberPad)
                    Button("Ekle") {
                        guard let mg = Double(customMg), mg > 0 else { return }
                        let name = customName.trimmingCharacters(in: .whitespaces)
                        selected = DrinkChoice(drink: Drink(id: "custom", category: .other, caffeineMg: mg, symbol: "drop.fill"),
                                               customName: name.isEmpty ? L("Diğer içecek") : name)
                    }
                    .disabled(Double(customMg) == nil)
                } header: {
                    Text("Listede yok mu?")
                } footer: {
                    Text("Değerler bir porsiyon için yaklaşıktır; demleme süresi, fincan boyu ve markaya göre değişir.")
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("İçecek ara"))
            .navigationTitle("İçecek ekle")
            .navigationDestination(item: $selected) { choice in
                AddDrinkForm(choice: choice) { servings, date in
                    add(choice.drink, choice.customName, servings, date)
                    dismiss()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    private func filtered(_ category: DrinkCategory) -> [Drink] {
        let drinks = DrinkCatalog.drinks(in: category, language: AppLanguage.current.resolvedCode)
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return drinks }
        return drinks.filter { (DrinkText.name($0.id) ?? $0.id).localizedCaseInsensitiveContains(query) }
    }

    private func row(_ drink: Drink) -> some View {
        Button {
            selected = DrinkChoice(drink: drink, customName: nil)
        } label: {
            HStack {
                Image(systemName: drink.symbol)
                    .foregroundStyle(Theme.caffeine)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(DrinkText.name(drink.id) ?? drink.id).foregroundStyle(.primary)
                    Text(DrinkText.serving(drink.id)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(drink.caffeineMg.mgText).foregroundStyle(.secondary)
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .tint(.primary)
    }
}
