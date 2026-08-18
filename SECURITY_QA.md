# Security Questions

### 1. Mengapa hardware-backed secure storage (Secure Enclave/StrongBox/Hardware Keystore) lebih aman dibanding software-based key storage?

Software-based key storage biasa menyimpan private key dalam file system yang dapat diakses OS, atau bahkan in-app memory. Dalam hal tersebut, key dapat diakses oleh device yang telah di-jailbreak/root. Sedangkan hardware-backed seperti Secure Enclave memiliki cara kerja dengan membuat private key yang secara fisik memiliki memory sendiri yang tidak dapat diakses OS. Sistem operasi hanya mengirim dan menerima data signed. Sehingga, key tidak pernah keluar sebagai readable byte.


### 2. Apa perbedaan implementasi hardware-backed key management pada Android dan iOS? Jelaskan kelebihan serta keterbatasan masing-masing.

iOS menyediakan akses ke Secure Enclave lewat Keychain API `kSecAttrTokenIDSecureEnclave`. Secure Enclave memiliki kelebihan dengan API yang cukup sederhana dan terintegrasi dengan biometric device seperti Face ID/Touch ID.  Namun, Secure Enclave hanya mendukung satu algoritma, EC P-256, tidak ada RSA. Dalam iOS juga attest (Keychain API untuk verif ke server bahwa key itu benar-benar hardware-backed) hanya tersedia pada layanan Apple Developer berbayar.

Sedangkan pada Andorid, terdapat Android Keystore `KeyGenParameterSpec` dengan untuk memaksa key masuk ke chip StrongBox yang terpisah. Pada android juga EC P-256 dan RSA. Key attest certificate chain sudah termasuk dalam root Google sehingga bisa diverifikasi dari sisi server dan bahkan mengetahui levelnya, StrongBox atau TEE biasa. Namun, kebanyakan pada device Android yang sudah outdated tidak memiliki StrongBox. Sedangkan pada iOS relatif seragam mendukung Secure Enclave

### 3. Bagaimana aplikasi seharusnya menangani perangkat yang tidak mendukung hardware-backed key storage?

Aplikasi dapat membuat pilihan MFA alternatif lain, seperti mekanisme OTP lewat SMS, email, ataupun authenticator app.


### 4. Mengapa private key tidak boleh diekspor dari secure storage?

Karena saat private key bisa diekspor menjadi raw bytes yang bisa disalin, attacker bisa menggunakan berpura-pura menjadi user dan server akan mengijikannya sampai key tersebut di-revoke.


### 5. Mengapa public key aman untuk dikirim dan disimpan di backend?

Guna public key hanya untuk memverifikasi signature, bukan membuatnya. Jika public key bocor, attacker hanya mendapatkan akses untuk melihat apakah signature valid atau tidak. Attacker tidak memiliki akses untuk untuk membuat ataupun memalsukan signature sehingga tidak dapat berpura-pura menjadi user.


### 6. Mengapa server harus mengirimkan challenge yang bersifat random dan unik pada setiap proses autentikasi?

Challenge bersifat random dan unik setiap proses autentikasi bertujuan agar hanya dapat digunakan satu kali saja. Jika challenge tersebut dapat dipakai berulang atau mudah ditebak, maka attacker dapat memakai ulang signature tersebut dan login sebagai user.


### 7. Mekanisme mencegah replay attack pada flow ini?

Ada 3 lapis perlindungan:
1. Challange akan di-generate secara random pada tiap proses autentikasi.
2. Menggunakan single use `storage.consume_challenge()` menghapus challenge dari dict `_challenges` saat telah dipakai untuk verifikasi, baik itu gagal maupun berhasil. Function ini dipanggil di awal `routers/verify.py` sebelum pengecekan lain berjalan.
3. Dipasang juga time out dalam waktu 60 detik yang akan expired, melindungi jika ada attacker mencoba melakukan pending mengirim signature.


### 8. Mengapa fingerprint perangkat tidak boleh dikirim dalam bentuk raw device information?

Raw device information mancakup mode,OS ver, dan identifier. Data-data tersebut jika dikirim secara raw dapat dipakai untuk melacak atau mengidentifikasi user. Berbahaya jika terjadi kebocoran data. Sehingga, device info tersebut harus di-hash sebelum dikirim ke back-end Ini bersifat one-way, sehingga hash yang tersimpan, tidak bisa diterjemahkan menjadi device info.


### 9. Apa risiko jika fingerprint hanya menggunakan satu identifier perangkat (misalnya Vendor ID, Android ID, atau identifier lainnya)?

Jika hanya menggunakan 1 identifier, hal tersebut riskan karena mudah berubah atau dipalsukan. Contohnya, seperti di iOS vendorID dapat berubah saat user uninstall aplikasi. Selain itu, dapat mempermudah attacker untuk masuk karena hanya memerlukan satu sinyal. Karena itu, pada aplikasi ini  `FingerprintService.canonicalString` menggabungkan tujuh field sekaligus yang berisi informasi model, OS, app version, bundle ID, vendor ID, team ID, dan flag hardware security.


### 10. Jelaskan perbedaan antara Digital Signature, Encryption, dan Hash Function

- **Hash function** bekerja secara satu arah, `data -> digest` berukuran tetap yang tidak bisa dibalik ke data aslinya. Tujuannya untuk menyamarkan agar tidak terlihat data aslinya. 
- **Encryption** berkerja secara dua arah, `plaintext -> ciphertext -> plaintext`. Tujuannya agar hanya pemegang key yang benar yang bisa membaca isi aslinya.
- **Digital signature** bekerja dengan memakai private key untuk verifikasi. Tujuannya agar autentikasi hanya bisa dibuktikan oleh identitas siapa yang melakukan signature.


### 11. Bagaimana backend melakukan verifikasi digital signature yang dikirim oleh aplikasi?

Backend akan mengambil public key yang sudah tersimpan sejak register. Lalu di-decode sendiri dengan challange + nonce yang di-signed dengan yang sudah backend miliki. Jika match, proses akan berhasil.


### 12. Apa risiko jika challenge, nonce, atau signature disimpan pada persistent local storage (misalnya UserDefaults, SharedPreferences, database, atau file)?

Jika hal-hal tersebut disimpan di local storage, data tersebut dapat diakses dengan mudah jika aplikasi di-jailbreak. Signature yang tersimpan berpotensi disalahgunakan jika tidak ada perlindungan seperti single-use dan expire-time.


### 13. Bagaimana Anda menangani kondisi ketika aplikasi di-install ulang sehingga key yang sebelumnya digunakan tidak lagi tersedia?

Proses reinstall menyebabkan penghapusan key di secure storage beserta keyId yang tersimpan lokal. Sehingga, aplikasi tidak akan menemukan key lama dan mengarahkan user untuk registrasi ulang. Dari sisi backend, saat device yang sama melakukan registrasi ulang, key lama miliknya sebaiknya didesain untuk otomatis di-revoke, supaya public key sebelumnya tidak menumpuk karena bisa disalahgunakan.

### 14. Bagaimana strategi melakukan key rotation tanpa mengganggu pengalaman pengguna?

Key rotation dilakukan dengan tetap mempertahankan key lama sampai key baru benar-benar aktif, bukan dengan langsung menggantinya. Hal ini juga diimplementasikan pada aplikasi ini dengan alur sebagai berikut.
1. App membuktikan kepemilikan pakai key lama (biometrik)
2. Key baru di-generate tanpa menghapus key lama
3. Server memvalidasi bukti itu dulu, baru dilanjutkan dengan menyimpan public key baru
4. App sudah siap untuk memakai key baru, dan menghapus yang lama. 
Dengan alur tersebut, jika ada kegagalan di tengah proses, user tidak kehilangan akses.


### 15. Bagaimana cara mengimplementasikan SSL/TLS Certificate Pinning, dan apa konsekuensinya ketika sertifikat server diperbarui?

Certificate pinning dilakukan dengan menyimpan hash dari sertifikat (atau public key-nya) di aplikasi. Selanjutnya, akan dibandingkan setiap kali koneksi TLS terjadi. Jika tidak cocok, koneksi langsung ditolak walau sertifikatnya valid secara CA. 

Untuk konsekuensinya tergantung apa yang di-pin. Jika sertifikat leaf yang di-pin, setiap kali sertifikat diperpanjang (walau key-nya sama), aplikasi lama akan langsung gagal connect dan harus update. Jika yang di-pin public key-nya saja, sertifikat boleh diperpanjang tanpa update aplikasi, selama key-nya tidak berubah.


### 16. Bagaimana memastikan bahwa private key benar-benar berada di hardware-backed storage dan bukan software fallback?

Cara paling meyakinkan adalah dengan key attestation, yaitu certificate chain dari vendor platform (Google/Apple) yang membuktikan key memang dibuat di dalam chip hardware. Hal ini dapat diverifikasi langsung pada server side. Jika tidak memakai attestation, alternatifnya dengan memastikan API yang dipakai untuk generate key tidak punya mode fallback ke software. Saat hardware tidak tersedia, proses generate key harus gagal secara eksplisit.


### 17. Apa perbedaan autentikasi menggunakan digital signature dibandingkan OTP atau bearer token?

Bearer token hanya bukti kepemilikan token itu sendiri. Siapapun yang memegangnya, bisa dianggap sah. Sedangkan OTP harus dikirimkan melalui channel tertentu, yang merupakan shared secret lewat jaringan. Hal tersebut bisa di-phising atau dicegat. Jika ada orang lain yang mengetahui kode OTP, hal tersebut juga dapat dibobol.

Digital signature tidak pernah mengirim apa pun lewat jaringan. Pengiriman hanyalah challenge spesifik, jadi tidak bisa dipakai ulang atau di-phishing.


### 18. Apa keuntungan menggunakan ECDSA P-256 dibanding algoritma RSA pada aplikasi mobile?

Untuk level keamanan yang setara, key ECDSA P-256 jauh lebih kecil dibanding RSA. Sehingga, signature juga lebih kecil. Hal itu dapat membuat  proses sign/verify lebih cepat serta lebih hemat CPU dan baterai.


### 19. Bagaimana cara melindungi aplikasi dari proses instrumentation atau runtime hooking (misalnya Frida atau debugger)?

Bisa dideteksi lewat sinyal yang tidak wajar muncul di eksekusi normal, seperti proses yang sedang di-trace oleh debugger, atau environment variable yang dipakai tools seperti Frida untuk inject dirinya ke proses. Jika salah satu terdeteksi, aplikasi langsung diblokir.


### 20. Jika Anda mendesain backend untuk mendukung jutaan perangkat, bagaimana Anda mengelola registrasi public key, revocation, key rotation, dan verifikasi signature secara aman dan efisien?

- **Registrasi**: Database ter-index per keyId/device, dengan rate limit per akun. Hal ini dilakukan agar suspicious activition seperti registrasi massal dengan menyebar dari banyak IP tidak akan lulus.
- **Verifikasi**: Operasi ECDSA verify murah secara CPU, jadi layanan verifikasi bisa dibuat stateless dan di-scale horizontal; challenge sementara disimpan di cache cepat-expire seperti Redis, bukan database utama.
- **Revocation**: Melakukan penambahkan status aktif/revoked per key, dapat dicek terlebih dahulu sebelum proses verifikasi signature dijalankan.
- **Key rotation**: Dilakukan penjagaan agar tetap independen per device. Sehingga, jutaan device bisa rotasi kapan saja tanpa saling mengganggu karena tidak memerlukan koordinasi terpusat atau downtime.
- **Operasional**: Audit log untuk setiap register/revoke/verify, dan rate limit/circuit breaker per key (bukan hanya per IP) untuk menahan brute force yang menyebar dari banyak IP.
