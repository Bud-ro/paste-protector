# Code Signing

## Windows

Windows SmartScreen will flag unsigned executables. To avoid this during development:

### Self-sign (development only)

```powershell
# Create a self-signed code signing certificate
$cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=Paste Protector Dev" -CertStoreLocation Cert:\CurrentUser\My

# Sign the executable
Set-AuthenticodeSignature -FilePath .\paste-protector.exe -Certificate $cert -TimestampServer "http://timestamp.digicert.com"
```

### Production signing

For distribution, purchase a code signing certificate from a CA (DigiCert, Sectigo, etc.) or use Azure Trusted Signing:

```powershell
signtool sign /fd sha256 /tr http://timestamp.digicert.com /td sha256 /f cert.pfx /p PASSWORD paste-protector.exe
```

### Alternative: Skip SmartScreen prompt

Right-click the .exe → Properties → check "Unblock" → Apply.

## macOS

macOS requires signing for Gatekeeper. For local testing:

```bash
# Ad-hoc sign (no Apple Developer account needed)
codesign --force --deep --sign - paste-protector.app

# With Apple Developer ID (for distribution)
codesign --force --deep --sign "Developer ID Application: Your Name" paste-protector.app
```

For distribution outside the App Store, also notarize:

```bash
xcrun notarytool submit paste-protector.zip --apple-id you@email.com --team-id TEAMID --password @keychain:notarize
```
