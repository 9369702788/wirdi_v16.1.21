from pathlib import Path

kts_path = Path('android/app/build.gradle.kts')
groovy_path = Path('android/app/build.gradle')
path = kts_path if kts_path.exists() else groovy_path
text = path.read_text()
is_kts = path.suffix == '.kts'

if 'isCoreLibraryDesugaringEnabled' not in text and 'coreLibraryDesugaringEnabled' not in text:
    flag = '        isCoreLibraryDesugaringEnabled = true\n' if is_kts else '        coreLibraryDesugaringEnabled true\n'
    text = text.replace('compileOptions {\n', 'compileOptions {\n' + flag, 1)

if 'coreLibraryDesugaring(' not in text and 'coreLibraryDesugaring ' not in text:
    dep = '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n' if is_kts else "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n"
    if '\ndependencies {' in text:
        text = text.replace('\ndependencies {', '\ndependencies {\n' + dep, 1)
    else:
        text += '\ndependencies {\n' + dep + '}\n'

path.write_text(text)
print('Gradle patched')

# ---- Release signing (added for Play Store submission) ----
key_props_path = Path('key.properties')
if key_props_path.exists() and 'signingConfigs' not in text:
    if is_kts:
        signing_block = (
            "\nval keystoreProperties = java.util.Properties()\n"
            "val keystorePropertiesFile = rootProject.file(\"../../key.properties\")\n"
            "if (keystorePropertiesFile.exists()) {\n"
            "    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))\n"
            "}\n"
        )
        text = text.replace('android {', signing_block + '\nandroid {', 1)
        signing_configs = (
            "    signingConfigs {\n"
            "        create(\"release\") {\n"
            "            keyAlias = keystoreProperties.getProperty(\"keyAlias\")\n"
            "            keyPassword = keystoreProperties.getProperty(\"keyPassword\")\n"
            "            storeFile = keystoreProperties.getProperty(\"storeFile\")?.let { rootProject.file(\"../../$it\") }\n"
            "            storePassword = keystoreProperties.getProperty(\"storePassword\")\n"
            "        }\n"
            "    }\n"
        )
        text = text.replace('    buildTypes {', signing_configs + '    buildTypes {', 1)
        text = text.replace(
            'getByName("release") {',
            'getByName("release") {\n            signingConfig = signingConfigs.getByName("release")',
            1,
        )
    path.write_text(text)
    print('Release signingConfig wired up from key.properties')
elif not key_props_path.exists():
    print('No key.properties found -- release build will remain unsigned/debug-signed for now')


# ---- ROOT CAUSE FIX (debug signing) ----
# Proven via direct inspection of the installed APK's actual embedded
# certificate (extracted from the APK Signing Block itself) that AGP's
# implicit "$HOME/.android/debug.keystore" convention was NOT reliably
# picking up our committed debug.keystore -- Gradle was silently
# auto-generating a random, UNREGISTERED debug certificate on builds
# instead, which is why Google Sign-In kept failing with
# ApiException: 10 no matter how many times the Firebase-side
# configuration was fixed. This block makes the debug signingConfig
# EXPLICIT so there is zero ambiguity about which keystore file is used.
debug_keystore_path = Path('debug.keystore')
if debug_keystore_path.exists() and 'signingConfigs' not in text:
    if is_kts:
        debug_signing_configs = (
            "    signingConfigs {\n"
            "        getByName(\"debug\") {\n"
            "            storeFile = rootProject.file(\"../../debug.keystore\")\n"
            "            storePassword = \"android\"\n"
            "            keyAlias = \"androiddebugkey\"\n"
            "            keyPassword = \"android\"\n"
            "        }\n"
            "    }\n"
        )
        text = text.replace('    buildTypes {', debug_signing_configs + '    buildTypes {', 1)
        text = text.replace(
            'getByName("debug") {',
            'getByName("debug") {\n            signingConfig = signingConfigs.getByName("debug")',
            1,
        )
    else:
        debug_signing_configs = (
            "    signingConfigs {\n"
            "        debug {\n"
            "            storeFile rootProject.file('../../debug.keystore')\n"
            "            storePassword 'android'\n"
            "            keyAlias 'androiddebugkey'\n"
            "            keyPassword 'android'\n"
            "        }\n"
            "    }\n"
        )
        text = text.replace('    buildTypes {', debug_signing_configs + '    buildTypes {', 1)
    path.write_text(text)
    print('Explicit debug signingConfig wired up -- Gradle will now deterministically use the committed debug.keystore instead of guessing its location')
elif 'signingConfigs' in text:
    print('signingConfigs already present (release path) -- debug signing left to whatever release patching already wired up')
else:
    print('WARNING: debug.keystore not found at repo root -- explicit debug signingConfig NOT added')
