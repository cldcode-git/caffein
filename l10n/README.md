# Çeviriler

Uygulama metinlerinin kaynağı Türkçedir (koddaki metinler). İngilizce `make_catalog.rb` içinde, diğer 11 dil `translations/<kod>.json` dosyalarında.

| Dosya | Ne işe yarar |
|---|---|
| `make_catalog.rb` | `Caffein/Localizable.xcstrings` ve `Caffein/InfoPlist.xcstrings` dosyalarını üretir |
| `validate_translation.rb` | Bir dil dosyasını kontrol eder: eksik metin, `%@`/`%lld` uyumu, `**` işaretleri |
| `translations-source.json` | Çevirmenlere verilen kaynak (Türkçe anahtar + İngilizce) |
| `translations/*.json` | `{ "strings": {...}, "infoplist": {...} }` |

## Metin ekleyince

1. Uygulamayı derle (Xcode metinleri `.stringsdata` olarak çıkarır).
2. Anahtar listesini çıkar ve İngilizcesini `make_catalog.rb` içindeki `EN` tablosuna ekle.
3. `DUMP_SOURCE=translations-source.json ruby -Eutf-8:utf-8 make_catalog.rb keys.txt ../Caffein/Localizable.xcstrings ../Caffein/InfoPlist.xcstrings translations` ile kaynağı güncelle, yeni metinleri her dil dosyasına çevir.
4. Her dili doğrula: `ruby -Eutf-8:utf-8 validate_translation.rb translations-source.json translations/de.json`
5. `STRICT=1` ile kataloğu yeniden üret ve derle.
