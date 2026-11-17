# Caffein QA rehberi

Uygulama mağazaya çıkmadan üç yerde test edilir:

| Ortam | Ne gerekir | Neyi test eder | Neyi test edemez |
|---|---|---|---|
| **1. Simülatör** (Mac'te) | Xcode | Tüm ekranlar, kafein hesapları, haftalık özet, çıkarımlar | Gerçek nabız (kamera yok), titreşim, bildirim zamanlaması |
| **2. Kendi iPhone'un** (kabloyla) | Xcode + ücretsiz Apple ID | Gerçek kamera, flaş, titreşim, nabız doğruluğu | Başkalarının cihazları |
| **3. TestFlight** | Apple Developer üyeliği (99 $/yıl) | Farklı iPhone'lar, gerçek kullanıcılar, birkaç haftalık gerçek kullanım | — |

---

## 1. Simülatör

1. `Caffein.xcodeproj` dosyasını Xcode ile aç, bir iPhone simülatörü seç, ▶ (⌘R).
2. Simülatörde kamera olmadığı için nabız ölçümleri sahte bir 72 BPM sinyaliyle çalışır: 1 sn sonra parmak "konmuş" sayılır. Ekranları ve akışları denemek için yeterlidir; doğruluk telefonda test edilir.

**Birim testleri:** ⌘U (49 test: nabız algoritması + kafein modeli + yaş/kilo sınırı + kişiye göre nabız aralığı + su önerisi + gerginlik + uyku süresi + çıkarımlar).

## 2. Kendi iPhone'un

1. iPhone'u kabloyla bağla, "Bu bilgisayara güven" de.
2. iPhone'da **Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu**'nu aç.
3. Xcode → Caffein hedefi → **Signing & Capabilities** → Team: kendi Apple ID'n.
   - Bundle ID alınmışsa `com.secilgunay.vuru` kısmını değiştir.
   - Ücretsiz hesapla HealthKit imzalama hatası verirse Build Settings → Code Signing Entitlements alanını geçici olarak boşalt.
4. Telefonu seç, ▶. İlk açılışta **Ayarlar → Genel → VPN ve Cihaz Yönetimi**'nden geliştiriciye güven.

Ücretsiz Apple ID ile kurulan uygulama 7 gün sonra açılmaz; Xcode'dan tekrar ▶ yeter.

### Nabız doğruluğu

Referans: Apple Watch, parmak oksimetresi ya da 30 sn bilekten sayıp 2 ile çarpmak.

1. Sabah ölçümü ya da Gerginim ölçümü yap, aynı anda referans değeri not al.
2. Uygulamanın gösterdiği değerle referansı bir tabloya yaz.
3. Farklı durumlar dene: dinlenme, merdiven sonrası, soğuk/sıcak el, aydınlık/karanlık oda, farklı kişiler ve cilt tonları.
4. Hedef: ortalama fark 3–5 BPM'in altında.

## 3. TestFlight

1. App Store Connect → yeni uygulama (bundle ID: `com.secilgunay.vuru`).
2. Xcode → Product → **Archive** → Distribute App → **TestFlight & App Store**.
3. **Dahili test** (100 kişiye kadar): inceleme yok. **Harici test** (10.000 kişiye kadar, açık link): ilk derlemede kısa beta incelemesi.
4. Bu uygulamanın değeri haftalar içinde ortaya çıkar: test edenlerden **en az 2 hafta** düzenli kullanmalarını iste, sonra Haftam ekranındaki çıkarımların anlamlı gelip gelmediğini sor.

---

## Ekran ekran kontrol listesi

### Karşılama
- [ ] 5 sayfa; 4. sayfada yaş, kilo, hamilelik ve canlı hesaplanan günlük sınır; son sayfada yalnızca yatış saati (dil sorulmuyor)
- [ ] Uygulama telefonun dilinde açılıyor

### Bugün
- [ ] Sabah kartı: ölçüm yapılmamışsa buton, yapılmışsa nabız + uyku özeti ve "normalinden X yüksek/düşük"
- [ ] Kafein kartı: şu anki mg, yatarken mg (30 mg üstü kırmızı), eğri, "şimdi" ve ay işaretleri, kesikli uyku eşiği
- [ ] Son kahve saati makul (23:00 yatış, ortalama süre → öğleden sonra)
- [ ] Son kahve saati varsa grafikte o saatte kesikli turuncu çizgi ve fincan + saat etiketi
- [ ] Yatarken eşik aşılacaksa "Bugün için kafeini burada bırak" mesajı, eşiğin altına ineceği saatle ("yarın 10:10" gibi); grafikte o saatte kesikli mavi çizgi ve ay + saat etiketi
- [ ] Hızlı ekleme ya da listeden bir içecek seçince ekleme formu açılıyor: adet (varsayılan 1, − ve + ile, en fazla 10) ve toplam mg; saat varsayılanı "Şimdi"
- [ ] Saat seçilince "Şimdi" seçimi kalkıyor; "Şimdi"ye dokununca saat şimdiye dönüyor; şimdiden sonraki bir saat (örn. 01:00'de 23:30) dünün tarihine yazılıyor ve formda "Dün … olarak kaydedilecek" notu çıkıyor
- [ ] "Ekle" sonrası "2 × … eklendi · … mg · Geri al" bildirimi, liste ve ilerleme çubuğu güncellenir
- [ ] Kayıtlı içecekte adet kutucuğu (− sayı +): + adedi artırır, − azaltır, 1'in altına inince kayıt silinir ve "Geri al" bildirimi çıkar
- [ ] Görünür çöp kutusu yok; kaydı sola kaydırınca kırmızı sil butonu açılıyor; butona dokunmak ya da uzun kaydırmak siliyor; satıra dokununca kapanıyor (Arapçada sağa kaydırma)
- [ ] Kayda basılı tutunca da "Sil"; VoiceOver'da satırın "Sil" eylemi var
- [ ] "Ne içtin?" başlığına (+ simgesine) ya da "Diğer"e dokununca aynı liste açılıyor: gruplu liste (Kahveler, Çaylar, Matcha ve mate, Enerji ve gazlı, Diğer), arama, özel içecek (ad + mg)
- [ ] Kapsül kahve listede; 3'ü 1 arada yok
- [ ] Yaş/kilo sınırı: %80'e gelince ya da genelde içilen içecek aşacaksa grafiğin altında "yaklaşıyorsun" (kalan mg ile), aşınca kırmızı uyarı + Çarpıntı rehberi bağlantısı
- [ ] Örnek: 30 yaş, 62 kg → 350 mg; 3 filtre kahve (285) "yaklaşıyorsun", 4. (380) "geçtin"
- [ ] Yaş/kilo girilmemişse grafiğin altında "Yaşını ve kilonu gir" bağlantısı, sınır 400 mg
- [ ] Hızlı ekleme butonları gün içinde yer değiştirmiyor
- [ ] Vücutta ≥200 mg varken grafiğin altında çarpıntı uyarısı ve rehber bağlantısı
- [ ] Su kartı: kiloya göre ihtiyaç (kg × 30 ml) + bugünkü kafein kadar ml; litre ve bardak sayısı; "su kafeini hızlandırmaz" notu
- [ ] Gerginlik kartı: 5 sabah ölçümüne kadar "x/5" ilerleme; puan ve nabız sapması açıklaması
- [ ] Akşam: 1–5 seçimi kaydediliyor, değiştirilebiliyor
- [ ] Saat 04:00'ten önce eklenen içecek bir önceki güne sayılıyor

### Sabah akışı
- [ ] 60 sn ölçüm → yatış + uyanış saati, uyku süresi, uyku kalitesi → özet
- [ ] Uyku süresi 1–16 saat dışındaysa Kaydet pasif ve uyarı var
- [ ] Öğleden önce açılınca uyanış = şimdi, sonra açılınca 07:00
- [ ] Sinyal kötüyse sayı yok, "Tekrar ölç" / "Ölçümsüz devam et"
- [ ] Yatış saati varsayılanı ayarlardaki saat; gece yarısından sonrası doğru güne yazılıyor
- [ ] Sağlık açıksa nabız Apple Sağlık'ta görünüyor

### Gerginim
- [ ] 30 sn ölçümden sonra sonuç ekranı: büyük sayı, "Normal / Biraz yüksek / Yüksek" etiketi, renkli aralık çubuğu, kişiye göre beklenen nabız ve sınırlar
- [ ] Simülatörde farklı nabız denemek için uygulamayı `-simulatorBPM 95` argümanıyla başlat (30 yaş, 62 kg kadın için 95 = biraz yüksek, 100 = yüksek, 72 = normal)
- [ ] Normal: "Bitti" ana buton, "Yine de nefes egzersizi yap" ikincil
- [ ] Biraz yüksek / yüksek: "2 dakikalık nefes egzersizine başla" ana buton, "Şimdi değil" ikincil; yüksekte çarpıntı rehberi bağlantısı
- [ ] Profil eksikse genel değer notu ve "Profilini tamamla"; cinsiyet girilmemişse ona dair not
- [ ] Nefes (4 sn al / 6 sn ver, geri sayım, Atla) → 30 sn ölçüm → önce/sonra, her biri seviye etiketiyle
- [ ] Nefes evrelerinde hafif titreşim
- [ ] Sonra ölçümü yüksekse ya da vücutta ≥200 mg kafein varsa çarpıntı rehberi bağlantısı

### Haftam
- [ ] Özet kartı 6 değer (ortalama uyku süresi dahil); paylaş butonu görsel üretiyor
- [ ] Uyku grafiği: yatarken kafein olan geceler turuncu, ortalama çizgisi var
- [ ] Günlük kafein grafiği, kişisel sınırı aşan gün kırmızı
- [ ] Uyku satırları ve yatarkenki kafein
- [ ] 7 günden az kayıtta "x/7" ilerleme; sonra çıkarımlar

### Çarpıntı rehberi
- [ ] Acil durum belirtileri en üstte; arama butonu (Türkiye'de 112)
- [ ] Şu anki kafein ve 30 mg altına ineceği tahmini saat
- [ ] Nefes egzersizine geçiş

### Ayarlar
- [ ] "Kafein sende ne kadar sürüyor?": Kısa / Ortalama / Uzun seçilince aynı ekrandaki son kahve saati ve yatarken kalan kafein değişiyor
- [ ] Yatış saati, yaş/kilo, hamilelik, kafein süresi değişince Bugün ekranı hemen güncelleniyor
- [ ] Test / QA paneli bölümü yok
- [ ] Sabah ve haftalık hatırlatıcı izin istiyor, reddedilince kapanıyor
- [ ] Tüm verileri sil onay istiyor

### Dil
- [ ] Ayarlar → Dil: Telefonun dili, sonra English, 简体中文, हिन्दी, Español, العربية, Français, বাংলা, Português, Русский, Bahasa Indonesia, Deutsch, 日本語, Türkçe; anında değişiyor
- [ ] Telefon desteklenmeyen bir dildeyse (ör. İtalyanca) uygulama ve izin pencereleri İngilizce
- [ ] Arapçada düzen sağdan sola
- [ ] İngilizcede Türk kahvesi, demleme çay, dibek, mate, sencha listede yok; Türkçede var
- [ ] Her dilde hızlı ekleme butonları o dile uygun (ör. Arapça: Arap kahvesi, Hintçe: masala chai)
- [ ] İçecek adları, çıkarımlar, saat biçimi (23:00 / 11:00 PM) seçilen dilde
- [ ] Uygulama kapatılıp açılınca kamera izni penceresi de seçilen dilde

### İkon ve ad
- [ ] Ana ekranda ölçü çizgili fincan ikonu ve "Caffein - Track Your Daily Caffeine Consumption" adı (kısaltılmış)
- [ ] Ana ekranda Özelleştir → Koyu ve Renklendirilmiş seçeneklerinde ikonun koyu ve gri varyantları
- [ ] İzin pencereleri, bildirimler ve Ayarlar'daki uygulama adı Caffein

### Genel
- [ ] Açık ve koyu modda tüm renkler okunaklı
- [ ] VoiceOver: kartlar, içecek butonları, ölçüm ekranı okunuyor
- [ ] En büyük metin boyutunda taşma yok
- [ ] Uçak modunda her şey çalışıyor (ağ kullanılmıyor)
- [ ] iPhone SE boyutunda düzen bozulmuyor
