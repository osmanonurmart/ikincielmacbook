#!/bin/bash
# İkinci el MacBook otomatik kontrol betiği.
# Kullanım:  bash macbook-kontrol.sh            -> sistem raporu
#            bash macbook-kontrol.sh --stres 5  -> rapor + 5 dakika CPU stres testi
# Hiçbir şeyi değiştirmez, sadece okur. sudo gerekmez.

if [ "$(uname)" != "Darwin" ]; then
  echo "Bu betik sadece macOS'ta çalışır."; exit 1
fi

R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[1m'; N=$'\033[0m'
FLAGS=""
ok()   { echo "  ${G}✔${N} $1"; }
warn() { echo "  ${Y}!${N} $1"; FLAGS="$FLAGS\n  ${Y}!${N} $1"; }
bad()  { echo "  ${R}✘${N} $1"; FLAGS="$FLAGS\n  ${R}✘${N} $1"; }
info() { echo "    $1"; }
title(){ echo; echo "${B}== $1 ==${N}"; }
# "Anahtar: değer" satırından değeri al
val()  { echo "$1" | grep -m1 "$2:" | sed 's/^[^:]*: *//'; }

echo "${B}İKİNCİ EL MACBOOK KONTROLÜ${N}  ($(date '+%d.%m.%Y %H:%M'))"
echo "Bilgiler toplanıyor, 10-30 sn sürebilir..."

HW=$(system_profiler SPHardwareDataType 2>/dev/null)
PW=$(system_profiler SPPowerDataType 2>/dev/null)

# ---------------- Donanım ----------------
title "Donanım"
info "Model:        $(val "$HW" "Model Name") ($(val "$HW" "Model Identifier"))"
MN=$(val "$HW" "Model Number"); [ -n "$MN" ] && info "Model No:     $MN"
CHIP=$(val "$HW" "Chip"); [ -z "$CHIP" ] && CHIP="$(val "$HW" "Processor Name") $(val "$HW" "Processor Speed")"
info "İşlemci:      $CHIP"
info "Çekirdek:     $(val "$HW" "Total Number of Cores")"
info "RAM:          $(val "$HW" "Memory")"
SERIAL=$(val "$HW" "Serial Number (system)")
info "Seri no:      $SERIAL"
info "macOS:        $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
info "Açık kalma:   $(uptime | sed 's/.*up \([^,]*\),.*/\1/')"
echo "    -> Seri numarasını checkcoverage.apple.com'da sorgula, kutu/fatura ile karşılaştır."

# ---------------- Kilitler ----------------
title "Kilitler ve sahiplik"
AL=$(val "$HW" "Activation Lock Status")
case "$AL" in
  Disabled) ok "Activation Lock: kapalı" ;;
  Enabled)  bad "Activation Lock: AÇIK — satıcı Apple ID'den çıkmadan ALMA" ;;
  *)        warn "Activation Lock durumu okunamadı (T2/Apple Silicon olmayan eski model olabilir)" ;;
esac

if nvram -x -p 2>/dev/null | grep -q "fmm-mobileme-token-FMM"; then
  bad "Mac'imi Bul (Find My): AÇIK — Ayarlar > Apple ID > Çıkış Yap yaptırılmalı"
else
  ok "Mac'imi Bul (Find My): kapalı"
fi

ENR=$(profiles status -type enrollment 2>/dev/null)
if [ -n "$ENR" ]; then
  echo "$ENR" | sed 's/^/    /'
  if echo "$ENR" | grep -qi "DEP: Yes"; then
    bad "Kurumsal DEP/ABM kaydı var — sıfırlayınca şirket yönetimine kilitlenir"
  elif echo "$ENR" | grep -qi "MDM enrollment: Yes"; then
    bad "MDM yönetim profili yüklü — şirket/okul cihazı olabilir"
  else
    ok "MDM / kurumsal kayıt yok"
  fi
else
  warn "MDM kaydı okunamadı"
fi
CNT=$(profiles list 2>/dev/null | grep -c "profileIdentifier")
[ "$CNT" -gt 0 ] 2>/dev/null && warn "Yüklü yapılandırma profili var ($CNT adet) — Ayarlar > Gizlilik ve Güvenlik > Profiller"

FV=$(fdesetup status 2>/dev/null)
info "FileVault:    $FV"

SIP=$(csrutil status 2>/dev/null)
if echo "$SIP" | grep -q "enabled."; then ok "SIP (Sistem Bütünlük Koruması): açık"
else warn "SIP kapalı/değiştirilmiş — sistemle oynanmış olabilir ($SIP)"; fi

if [ "$(uname -m)" = "x86_64" ]; then
  info "Intel Mac: firmware şifresi için açılışta Option'a bas; şifre sorarsa satıcı kaldırmalı."
  info "(Kontrol: sudo firmwarepasswd -check)"
fi

# ---------------- Batarya ----------------
title "Batarya"
if echo "$PW" | grep -q "Cycle Count"; then
  CYC=$(val "$PW" "Cycle Count")
  COND=$(val "$PW" "Condition")
  MAXP=$(val "$PW" "Maximum Capacity" | tr -d '%')
  IO=$(ioreg -rd1 -c AppleSmartBattery 2>/dev/null)
  iov() { echo "$IO" | grep -m1 "\"$1\" = " | awk '{print $NF}'; }
  DES=$(iov DesignCapacity)
  RAW=$(iov AppleRawMaxCapacity)
  [ -z "$RAW" ] && { M=$(iov MaxCapacity); [ -n "$M" ] && [ "$M" -gt 100 ] 2>/dev/null && RAW=$M; }
  NOM=$(iov NominalChargeCapacity)
  [ -z "$RAW" ] && RAW=$NOM
  HP=""
  CYCDES=$(iov DesignCycleCount9C); [ -z "$CYCDES" ] && CYCDES=1000

  info "Döngü sayısı: $CYC / $CYCDES"
  info "Durum:        $COND"
  [ -n "$MAXP" ] && info "Maks. kapasite (macOS): %$MAXP"
  if [ -n "$DES" ] && [ -n "$RAW" ] && [ "$DES" -gt 0 ] 2>/dev/null; then
    HP=$((RAW * 100 / DES))
    info "Gerçek kapasite: $RAW mAh / tasarım $DES mAh = %$HP"
  fi
  [ -z "$MAXP" ] && MAXP=$HP

  if   [ "$CYC" -lt 300 ] 2>/dev/null; then ok "Döngü sayısı düşük ($CYC)"
  elif [ "$CYC" -lt 700 ] 2>/dev/null; then warn "Döngü sayısı orta ($CYC)"
  else bad "Döngü sayısı yüksek ($CYC) — batarya değişimi yakın"; fi

  if [ -n "$MAXP" ]; then
    if   [ "$MAXP" -ge 90 ] 2>/dev/null; then ok "Kapasite iyi (%$MAXP)"
    elif [ "$MAXP" -ge 80 ] 2>/dev/null; then warn "Kapasite kabul edilebilir (%$MAXP)"
    else bad "Kapasite düşük (%$MAXP) — değişim gerekli"; fi
  fi
  case "$COND" in
    Normal|"") ;;
    *) bad "Batarya durumu: $COND" ;;
  esac
  if [ -n "$CYC" ] && [ -n "$MAXP" ] && [ "$CYC" -lt 50 ] 2>/dev/null && [ "$MAXP" -lt 85 ] 2>/dev/null; then
    warn "Döngü çok düşük ama kapasite düşük — batarya değişmiş veya çok uzun süre bekletilmiş olabilir"
  fi
else
  warn "Batarya bilgisi bulunamadı"
fi

CHG=$(echo "$PW" | sed -n '/AC Charger Information/,/^$/p')
if echo "$CHG" | grep -q "Connected: Yes"; then
  W=$(val "$CHG" "Wattage (W)")
  info "Adaptör:      takılı, ${W}W, şarj ediyor: $(val "$CHG" "Charging")  $(val "$CHG" "Name")"
  info "-> Adaptörü her porta takıp bu betiği tekrar çalıştırarak her portun şarj ettiğini doğrula."
else
  info "Adaptör takılı değil (watt değerini görmek için adaptörü takıp tekrar çalıştır)."
fi

# ---------------- Depolama ----------------
title "Depolama (SSD)"
D0=$(diskutil info disk0 2>/dev/null)
info "Disk:         $(val "$D0" "Device / Media Name")"
info "Boyut:        $(val "$D0" "Disk Size" | sed 's/ (.*//')"
SM=$(val "$D0" "SMART Status")
case "$SM" in
  Verified) ok "SMART durumu: Verified" ;;
  "")       warn "SMART durumu okunamadı" ;;
  *)        bad "SMART durumu: $SM — disk arızalı olabilir" ;;
esac
info "Boş alan:     $(df -h / | awk 'NR==2{print $4" boş / "$2}')"
if command -v smartctl >/dev/null 2>&1; then
  SC=$(smartctl -a disk0 2>/dev/null)
  info "Aşınma:       $(val "$SC" "Percentage Used")"
  info "Yazılan veri: $(val "$SC" "Data Units Written")"
  info "Çalışma saati:$(val "$SC" "Power On Hours")"
  ERR=$(val "$SC" "Media and Data Integrity Errors")
  [ -n "$ERR" ] && [ "$ERR" != "0" ] && bad "SSD veri bütünlüğü hatası: $ERR"
else
  info "(SSD aşınma yüzdesi için: brew install smartmontools — opsiyonel)"
fi

# ---------------- Diğer donanım ----------------
title "Ekran, kamera, kablosuz"
DS=$(system_profiler SPDisplaysDataType 2>/dev/null)
info "GPU:          $(val "$DS" "Chipset Model")"
info "Ekran:        $(val "$DS" "Display Type") $(val "$DS" "Resolution")"
CAM=$(system_profiler SPCameraDataType 2>/dev/null | grep -m1 "Model ID" | sed 's/^[^:]*: *//')
[ -n "$CAM" ] && ok "Kamera algılandı ($CAM)" || bad "Kamera algılanmadı"
WIF=$(networksetup -listallhardwareports 2>/dev/null | grep -A1 "Wi-Fi" | grep Device | awk '{print $2}')
[ -n "$WIF" ] && ok "Wi-Fi kartı algılandı ($WIF)" || bad "Wi-Fi kartı algılanmadı"
BT=$(system_profiler SPBluetoothDataType 2>/dev/null | grep -m1 -E "Address:")
[ -n "$BT" ] && ok "Bluetooth algılandı" || warn "Bluetooth algılanamadı"
info "Termal:       $(pmset -g therm 2>/dev/null | grep -v '^$' | tail -1 | sed 's/^ *//')"

# ---------------- Çökme geçmişi ----------------
title "Çökme / kapanma geçmişi"
PAN=$(ls /Library/Logs/DiagnosticReports/ 2>/dev/null | grep -ci "panic")
if [ "$PAN" -gt 0 ]; then
  bad "Kernel panic kaydı: $PAN adet (donanım sorunu belirtisi olabilir)"
  ls -t /Library/Logs/DiagnosticReports/ | grep -i panic | head -5 | sed 's/^/      /'
else
  ok "Kernel panic kaydı yok"
fi
echo "    Son kapanma nedenleri (son 7 gün)..."
SD=$(log show --style compact --predicate 'eventMessage contains "Previous shutdown cause"' --last 7d 2>/dev/null \
     | grep -o "Previous shutdown cause: -\{0,1\}[0-9]*" | awk '{print $NF}')
if [ -n "$SD" ]; then
  echo "    Kodlar: $(echo $SD | tr '\n' ' ')"
  BADSD=$(echo "$SD" | grep -vE '^(5|3|-128|-129|-3)$' | sort -u | tr '\n' ' ')
  [ -n "$BADSD" ] && warn "Olağandışı kapanma kodları: $BADSD (0=güç kesildi, -60/-61/-62/-74/-86/-95/-112=batarya/termal/donanım)" \
                  || ok "Kapanmalar normal"
else
  info "Kayıt yok (cihaz yeni sıfırlanmış olabilir)."
fi

# ---------------- Özet ----------------
title "ÖZET"
if [ -z "$FLAGS" ]; then
  echo "  ${G}Otomatik kontrollerde sorun bulunmadı.${N}"
else
  printf "Dikkat edilecekler:$FLAGS\n"
fi
echo
echo "Şimdi index.html'deki elle testleri yap (ekran, klavye, trackpad, ses, kamera, portlar)"
echo "ve Apple Diagnostics çalıştır (Apple Silicon: güç tuşu basılı açılış -> Cmd+D, Intel: açılışta D)."

# ---------------- Stres testi ----------------
if [ "$1" = "--stres" ]; then
  MIN=${2:-5}
  NCPU=$(sysctl -n hw.ncpu)
  title "CPU stres testi: $MIN dakika, $NCPU çekirdek"
  echo "  Fan sesi, ısınma ve ani kapanma takip edilir. Durdurmak için Ctrl+C."
  PIDS=""
  cleanup() { kill $PIDS 2>/dev/null; echo; echo "Stres testi durduruldu."; exit 0; }
  trap cleanup INT TERM
  for _ in $(seq "$NCPU"); do yes > /dev/null & PIDS="$PIDS $!"; done
  END=$(( $(date +%s) + MIN * 60 ))
  while [ "$(date +%s)" -lt "$END" ]; do
    BAT=$(pmset -g batt | grep -o '[0-9]*%' | head -1)
    TH=$(pmset -g therm | grep -E "CPU_Speed_Limit|thermal warning|performance warning" | head -1 | sed 's/^ *//')
    LEFT=$(( (END - $(date +%s)) ))
    echo "  [$(date +%H:%M:%S)] kalan ${LEFT}s | batarya $BAT | $TH"
    sleep 15
  done
  kill $PIDS 2>/dev/null
  echo "  ${G}Stres testi bitti.${N} Cihaz kapanmadıysa ve fan çalıştıysa sorun yok."
  echo "  CPU_Speed_Limit 100'ün çok altına düştüyse soğutma/termal macun sorunu olabilir (Intel)."
fi
