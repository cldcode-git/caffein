# Caffein

Kafeinin uykuna ve gerginliğine **sende** nasıl etki ettiğini gösteren sağlıklı yaşam uygulaması. Akıllı saat gerekmez, hesap gerekmez; tüm veriler telefonda kalır.

Amaç kafeini kötülemek değil: ne zaman, ne kadar içtiğini görüp sana iyi gelen dengeyi bulmak ve fazla kafeinle gelen çarpıntıda ne yapacağını bilmek.

> App Store'da: **Caffein - Caffeine Tracker** (ad) ve **Track Your Daily Consumption** (alt başlık). Ana ekran adı **Caffein - Track Your Daily Caffeine Consumption** (ana ekranda kısaltılarak görünür). Yalnızca Bundle ID (`com.secilgunay.vuru`) eski çalışma adını koruyor: kullanıcı onu görmez ve değişirse cihazdaki veriler kaybolur.

İkon: ölçü çizgili fincan. Kaynak SVG dosyaları `Design/icon/` altında; açık, koyu ve renklendirilmiş varyantlar `Caffein/Assets.xcassets/AppIcon.appiconset/` içinde (1024×1024, saydamlıksız). App Store bilgileri: [AppStore.md](AppStore.md).

## Günlük kullanım

| Ne zaman | Ne yapılır |
|---|---|
| Sabah | 60 sn kamerayla dinlenme nabzı + uyku kaydı (yatış, uyanış, nasıl uyudun) |
| Gün içinde | İçilen kahve, çay, enerji içeceği tek dokunuşla kaydedilir |
| Gergin anlarda | **Gerginim**: 30 sn ölçüm → 2 dk yavaş nefes → 30 sn ölçüm |
| Akşam | Günün gerginliğine 1–5 puan |
| Haftada bir | **Haftam**: özet kartı ve kişisel çıkarımlar |

## Özellikler

- **Kafein eğrisi:** Vücutta şu an ve yatma saatinde ne kadar kafein olduğu (emilim ~45 dk, yarılanma 5 saat). Ayarlar → "Kafein sende ne kadar sürüyor?" ile kısa (3,5 sa) / ortalama (5 sa) / uzun (7 sa) seçilir; seçimin son kahve saatine ve yatarken kalan kafeine etkisi aynı ekranda görünür.
- **Grafikte sınır saati:** Son kahve saati (ya da kafein bugün için bittiyse seviyenin uyku eşiğinin altına ineceği saat) grafikte kesikli çizgi ve saat etiketiyle gösterilir.
- **Su:** Kiloya göre günlük su (kg × 30 ml) + bugünkü kafein kadar ml. Su kafeini daha hızlı atmaz; ek su yalnızca kafeinin hafif idrar söktürücü etkisini dengeler ve uygulamada bu açıkça yazar.
- **Son kahve saati:** Yatarken vücutta 30 mg'den az kafein kalacak şekilde, genelde içtiğin büyüklükte bir içeceği en geç ne zaman içebileceğin.
- **Yaş ve kiloya göre günlük sınır (EFSA):** Yetişkinlerde kilo başına ~5,7 mg, en fazla 400 mg; 18 yaş altında kilo başına 3 mg; hamilelik/emzirmede en fazla 200 mg. Yaş ve kilo karşılama ekranında alınır, Ayarlar → Profil'den değişir. Sınırın %80'ine gelince ya da genelde içilen bir içecek sınırı aşacaksa "yaklaşıyorsun", aşınca kırmızı uyarı; ikisi de yalnızca Bugün ekranında grafiğin altında.
- **İçecek listesi:** 37 içecek, gruplu ve aranabilir: Kahveler (Türk kahvesi, filtre, espresso çeşitleri, kapsül, cold brew, French press, moka pot, dibek…), Çaylar, Matcha ve mate, Enerji ve gazlı içecekler, Diğer. Özel içecek de eklenebilir.
- **Uyku süresi:** Yatış ve uyanış saatinden hesaplanır; haftalık ortalama ve geç kafeinin uykuyu ne kadar kısalttığı gösterilir.
- **Dil:** 13 dil: English, 简体中文, हिन्दी, Español, العربية, Français, বাংলা, Português, Русский, Bahasa Indonesia, Deutsch, 日本語, Türkçe (İngilizce önce, sonra dünyada konuşan sayısına göre). Uygulama telefonun dilinde açılır; desteklenmeyen dillerde İngilizce. Ayarlar → Dil'den değiştirilir, anında uygulanır. Arapçada düzen sağdan sola döner.
- **Dile göre içecekler:** Yöresel içecekler yalnızca o dilde görünür: Türk kahvesi, demleme çay, dibek (Türkçe), mate (İspanyolca, Portekizce), cafezinho (Portekizce), Arap kahvesi (Arapça), masala chai (Hintçe, Bengalce), sencha (Japonca).
- **Gerginlik göstergesi:** Sabah nabzının kişisel normalden sapması (en az 5 sabah ölçümüyle oluşur) + kullanıcının kendi gerginlik puanı.
- **Ölçüm kalite kontrolü:** Sinyal kötüyse sayı gösterilmez; iki zayıf denemeden sonra "tekrar ölç / ölçümsüz devam et" sunulur.
- **Çarpıntı rehberi:** Yüksek kafein ya da yüksek nabızda öneriler; acil durum belirtilerinde acil yardım hattı.
- **Hatırlatıcılar:** Sabah ölçümü ve Pazar akşamı haftalık özet (yerel bildirim).

## Yapı

```
Caffein.xcodeproj
Caffein/
  App/            giriş, sekmeler, ayar anahtarları, gün sınırı (04:00)
  Features/
    Today/        Bugün ekranı: sabah, kafein, içecek ekleme, gerginlik, akşam
    Morning/      sabah akışı (nabız + uyku soruları)
    Tense/        Gerginim akışı ve nefes egzersizi
    Weekly/       Haftam: özet kartı, grafikler, çıkarımlar
    Guide/        çarpıntı rehberi
    Measure/      kamera nabız ölçüm bileşeni
    Settings/ Onboarding/ Profile/
  Services/       kayıtlardan ekran verisine dönüşüm, bildirimler
  Storage/        SwiftData modelleri (yalnızca cihazda)
  Signal/         kamera ve (simülatör için) sentetik nabız kaynağı
PulseKit/         saf Swift paketi
  PulseKit        nabız: filtre, atım tespiti, spektral kontrol
  CaffeineKit     kafein modeli, içecek kataloğu, gerginlik göstergesi, çıkarımlar
QA.md             test rehberi
l10n/             çeviri dosyaları ve katalog üretme betikleri
```

## Çalıştırma

`Caffein.xcodeproj`'yi Xcode ile açıp ▶. Simülatörde kamera yok, sentetik nabız sinyali kullanılır.

Testler (43 adet): Xcode'da ⌘U ya da

```bash
cd PulseKit && swift test
```

## Durum

- [x] Ölçüm motoru, kafein modeli, gerginlik göstergesi, çıkarımlar + testler
- [x] Tüm ekranlar, simülatörde örnek veriyle denendi
- [ ] Gerçek cihazda nabız doğruluğu (QA.md)
- [x] İngilizce
- [ ] Uygulama ikonu, isim kararı
- [ ] Gizlilik politikası, mağaza sayfası, ekran görüntüleri
