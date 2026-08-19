# MFA-App: Hardware-backed Passwordless Authentication

Demo app for passwordless / MFA authentication using a **hardware-backed asymmetric key** (Secure Enclave), similar to the WebAuthn/FIDO2 flow but implemented specifically for iOS.

- **iOS app**: SwiftUI, MVVM
- **Backend**: Python (FastAPI)

## Full Flow

```
[Registration]
CryptoService.generateKeyPair(in: .a)    -> EC P-256 key pair in the Secure Enclave
CryptoService.exportPublicKeyBase64()    -> only the public key ever leaves
FingerprintService.current()             -> SHA-256 of device info
NetworkService.register()                -> POST /register -> keyId
SecureStorageService.saveKeyId()         -> keyId stored in Keychain

[Authentication]
NetworkService.challenge(keyId)          -> GET /challenge -> {challenge, nonce}
CryptoService.sign(challenge+nonce)      -> signs with the private key
                                             (automatically triggers Face ID/Touch ID
                                             because of the key's access control)
NetworkService.verify()                  -> POST /verify -> {verified: true/false}
```

## Security Requirement Implementation

| Requirement | Implementation |
|---|---|
| Hardware-backed key | `CryptoService` uses `kSecAttrTokenIDSecureEnclave`, EC P-256, `SecKeyCreateRandomKey` |
| Private key never leaves the device | All operations go through `SecKey` (opaque reference). No private-key-export function anywhere in the codebase |
| Access control | `SecAccessControlCreateWithFlags([.privateKeyUsage, .biometryCurrentSet])`. Signing requires Face ID/Touch ID |
| Digital signature | ECDSA P-256 (`.ecdsaSignatureMessageX962SHA256`), verified on the backend with `cryptography`'s `ec.ECDSA(SHA256())` |
| Hash | SHA-256 for the fingerprint (`CryptoKit.SHA256` on iOS, `hashlib`/`cryptography` on the backend) |
| No sensitive data stored | `SecureStorageService` only stores the `keyId` + active key slot in the Keychain. |
| Export restriction | Key is created with `kSecAttrIsPermanent` + Secure Enclave. The app actually **attempts** to export it and reports that the chip refuses |
| Replay prevention | Backend: 32-byte random challenge + nonce, bound to one `keyId`, single-use (deleted after one `/verify` call, whether it succeeds or fails), expires after 60 seconds |


**Device fingerprint**: `FingerprintService` hashes device model + OS version +
app version + bundle ID + vendor ID + team ID + Secure Enclave flag into one
SHA-256. Only the hash is sent.

## In-App Security Checklist

**Set Up** / **Security** screens run live checks, not static text. Calling
`SecKeyCopyExternalRepresentation` and confirming it's refused, scanning
`UserDefaults` for leaked secret-shaped keys, validating the pin hash and
HTTPS base URL. Register stays disabled until every check is green.

## Additional Security

| Feature | How |
|---|---|
| Jailbreak detection | 4 heuristics: Cydia/Sileo/MobileSubstrate files, writes outside sandbox, suspicious symlinks, `cydia://` scheme |
| Simulator block | No Secure Enclave chip → refuses to run, checked before Register/Login UI |
| Debugger detection | `sysctl`/`P_TRACED` (Apple QA1361); auto-off in Debug so Xcode can attach |
| Injection detection | Checks `DYLD_INSERT_LIBRARIES` (basic Frida signal) |
| Rate limiting | `rate_limit.py`, fixed-window 10 req/60s per-IP on `/register`+`/challenge`, per-`keyId` on `/verify`+`/rotate` |
| SSL cert pinning | Pins the server's *public key* hash, certs can renew without an app update as long as the key stays the same |
| Key rotation | `RegisterService.rotateKey()` + `POST /rotate`: old key signs proof → new key generated in a second slot → server swaps public key → client commits + deletes old key. Two fixed slots because in-place Keychain tag rename is unreliable. If the app dies between server/client commit, `AuthenticationService` auto-detects and recovers on next login |
| Reinstall handling | Reinstall wipes the Secure Enclave key, backend detects the repeat `deviceId` and revokes the old registration |

Any integrity check tripping (jailbreak/simulator/debugger/injection) routes
to `BlockedView` instead of Register/Login. Backend behaviors above are all
covered by tests in `Backend/tests/test_api.py`.

## Not Yet Implemented

- **App Attest / DeviceCheck** — needs a `.p8` key from a paid Apple
  Developer account to call Apple's validation servers.
