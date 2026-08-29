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


def find_block(haystack, anchor):
    """Return (start, end) indices of the { ... } block that immediately
    follows the first occurrence of `anchor`, using brace counting so
    similarly-named sibling/nested blocks elsewhere in the file are
    never confused for it."""
    idx = haystack.find(anchor)
    if idx == -1:
        return None
    brace_open = haystack.find('{', idx)
    if brace_open == -1:
        return None
    depth = 0
    i = brace_open
    while i < len(haystack):
        if haystack[i] == '{':
            depth += 1
        elif haystack[i] == '}':
            depth -= 1
            if depth == 0:
                return (brace_open, i + 1)
        i += 1
    return None


def patch_within_block(full_text, block_anchor, target, replacement):
    """v92 FIX: v91 used text.replace(target, ...) anywhere in the WHOLE
    file to wire up buildTypes.debug/release signingConfig. On newer
    AGP/Flutter templates that broke in CI with "Unresolved reference
    'signingConfig'" because the file also had an unrelated block (e.g.
    sourceSets { getByName("debug") { ... } }) containing the exact same
    getByName("debug") { text, appearing earlier in the file, which has
    no signingConfig property at all. This scopes the replacement to
    ONLY the brace-matched contents of `block_anchor` (buildTypes {}),
    so an identically-named block anywhere else in the file can never
    be matched by mistake."""
    block = find_block(full_text, block_anchor)
    if block is None:
        return full_text, False
    start, end = block
    segment = full_text[start:end]
    if target not in segment:
        return full_text, False
    new_segment = segment.replace(target, replacement, 1)
    return full_text[:start] + new_segment + full_text[end:], True


def has_signing_configs_block(t):
    return 'signingConfigs {' in t

key_props_path = Path('key.properties')
if key_props_path.exists() and not has_signing_configs_block(text):
    if is_kts:
        text, wired = patch_within_block(
            text, 'buildTypes {',
            'getByName("release") {',
            'getByName("release") {\n            signingConfig = signingConfigs.getByName("release")',
        )
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
    path.write_text(text)
    if wired:
        print('Release signingConfig wired up from key.properties')
    else:
        print('WARNING: could not find getByName("release") inside buildTypes {} -- release signingConfigs block added, but NOT wired into the release buildType. Check the generated build.gradle.kts manually.')
elif not key_props_path.exists():
    print('No key.properties found -- release build will remain unsigned/debug-signed for now')
elif has_signing_configs_block(text):
    print('A signingConfigs {} block already exists -- not overwriting it (release path)')

debug_keystore_path = Path('debug.keystore')
if debug_keystore_path.exists() and not has_signing_configs_block(text):
    if is_kts:
        text, wired = patch_within_block(
            text, 'buildTypes {',
            'getByName("debug") {',
            'getByName("debug") {\n            signingConfig = signingConfigs.getByName("debug")',
        )
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
        wired = True
    path.write_text(text)
    if wired:
        print('Explicit debug signingConfig wired up -- Gradle will now deterministically use the committed debug.keystore instead of guessing its location')
    else:
        print('WARNING: could not find getByName("debug") inside buildTypes {} -- signingConfigs block added, but debug buildType was NOT wired to it. AGP will fall back to its own default debug signing for this build; check the generated build.gradle.kts manually.')
elif has_signing_configs_block(text):
    print('A signingConfigs {} block already exists (release path just added it, or one pre-existed) -- debug entry must be added manually inside it if not already covered')
else:
    print('WARNING: debug.keystore not found at repo root -- explicit debug signingConfig NOT added')
