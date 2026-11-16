import CaffeineKit
import SwiftUI

/// Full drink list, grouped by kind, plus a custom entry.
struct DrinkPickerView: View {
    let add: (Drink, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var customName = ""
    @State private var customMg = ""
    @State private var search = ""

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
                        add(Drink(id: "custom", category: .other, caffeineMg: mg, symbol: "drop.fill"),
                            name.isEmpty ? L("Diğer içecek") : name)
                        dismiss()
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
            add(drink, nil)
            dismiss()
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
            }
        }
        .tint(.primary)
    }
}
