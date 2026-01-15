& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore bloomee.jks -keyalg RSA -keysize 2048 -validity 10000 -alias rt_music -storepass rtmusic123 -keypass rtmusic123 -dname "CN=RT Music, OU=Development, O=RT Music, L=Unknown, ST=Unknown, C=US"
Write-Host "Keystore generated successfully!"
