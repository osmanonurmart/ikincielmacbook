# İkinci El MacBook Test Uygulaması

İkinci el MacBook alırken satıcının yanında yapılacak tüm kontroller.

## Kullanım

1. Bu repoyu test edeceğin MacBook'a indir (GitHub → Code → Download ZIP) ya da USB bellekle getir.
2. **Terminal'de otomatik kontrol:**
   ```
   bash macbook-kontrol.sh
   bash macbook-kontrol.sh --stres 5   # + 5 dk CPU stres testi
   ```
   Okur: model, seri no, RAM, SSD, batarya döngü/kapasite, Activation Lock, Mac'imi Bul,
   MDM/kurumsal kayıt, FileVault, SIP, SSD SMART, kernel panic ve kapanma geçmişi. Hiçbir şeyi değiştirmez.
3. **`index.html`'i Safari veya Chrome'da aç:** kontrol listesi (42 madde), ekran (ölü piksel, ışık sızması,
   bantlanma), klavye (tüm tuşlar + çift basma tespiti), trackpad (tık, jest, Force Click), hoparlör
   (sol/sağ, cızırtı taraması), mikrofon, kamera ve rapor.

Kamera/mikrofon dosyadan açıldığında çalışmazsa Chrome'da aç veya Photo Booth / Sesli Notlar ile dene.
GitHub Pages açarsan (Settings → Pages → main branch) uygulama doğrudan linkten de çalışır.

## Asla alma
- Activation Lock / Mac'imi Bul açık ve satıcı kapatmıyor
- MDM / DEP (kurumsal) kaydı var
- Firmware şifresi var
- Batarya şişmiş (trackpad yükselmiş, kasa bombeli)
