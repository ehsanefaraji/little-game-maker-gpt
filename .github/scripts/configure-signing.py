from pathlib import Path
import re

path = Path('android/app/build.gradle.kts')
source = path.read_text()
pattern = r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)'
if source.count('android {') != 1 or len(re.findall(pattern, source)) != 1:
    raise SystemExit('Unexpected Flutter Android template; refusing to build without release signing.')
source = re.sub(pattern, 'signingConfig = signingConfigs.getByName("release")', source)
source = source.replace('android {', '''val releaseSigning = Properties().apply {
    rootProject.file("key.properties").inputStream().use { load(it) }
}

android {
    signingConfigs {
        create("release") {
            storeFile = file("release-signing.p12")
            storeType = "PKCS12"
            storePassword = releaseSigning.getProperty("storePassword")
            keyPassword = releaseSigning.getProperty("storePassword")
            keyAlias = "little-game-maker"
        }
    }
''', 1)
path.write_text('import java.util.Properties\n\n' + source)
