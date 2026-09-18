#!/usr/bin/env python3
"""Regression checks for the application's display-only language selection."""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'RoamControl'

def literal(s,i):
    triple=s.startswith('"""',i); quote='"""' if triple else '"'; start=i; i+=len(quote); out=''
    while i<len(s):
        if s.startswith(quote,i):return i+len(quote),out
        if s.startswith('\\(',i):
            i+=2; depth=1
            while depth:
                if s[i]=='"':i,_=literal(s,i);continue
                if s[i]=='(':depth+=1
                elif s[i]==')':depth-=1
                i+=1
            out+='%@';continue
        if s[i]=='\\':
            out+= {'n':'\n','t':'\t','"':'"','\\':'\\'}.get(s[i+1],s[i+1]);i+=2;continue
        out+=s[i];i+=1
    raise ValueError(s[start:start+100])
def strings(s):
    i=0
    while i<len(s):
        if s.startswith('//',i):
            j=s.find('\n',i);i=len(s) if j<0 else j;continue
        if s.startswith('/*',i):i=s.index('*/',i)+2;continue
        if s[i]=='"':
            end,key=literal(s,i);yield i,end,key;i=end
        else:i+=1
def human(k):
    return bool(re.search('[A-Za-z]',k)) and ((' ' in k and not k.startswith(('com.','https:','http:','SELECT '))) or bool(re.fullmatch('[A-Z][a-z]+(?:…)?',k)) or k in ['N','E','S','W']) and '\n' not in k


def check():
    zh_path = APP / 'Resources/zh-Hans.lproj/Localizable.strings'
    source = zh_path.read_text()
    pairs = re.findall(r'^"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)";', source, re.M)
    keys = [key for key, _ in pairs]
    assert len(keys) == len(set(keys)), 'Duplicate translation keys'
    for key in ('Share Anonymous Usage Statistics', 'Search places or coordinates', 'Language', 'Follow System', 'Connecting…'):
        assert key in keys, f'Missing Chinese translation: {key}'
    for key, value in pairs:
        assert key.count('%@') == value.count('%@'), f'Changed interpolation arguments: {key}'
    english = (APP / 'Resources/en.lproj/Localizable.strings').read_text()
    english_pairs = re.findall(r'^"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)";', english, re.M)
    assert set(dict(english_pairs)) == set(keys), 'English catalog coverage changed'
    # Known proper names, formatting tokens and source-only matching fragments.
    unchanged = {'Roam Control', 'ROAM CONTROL', 'English', '%.5f, %.5f', ' mi',
                 'Starting point for ', 'Walking to ', '% complete',
                 'through LocalDevVPN', 'make the iPhone connection available',
                 'open the secure device tunnel', 'Roam Control pairing',
                 'Roam Control Local Tunnel', 'Cat Go', 'Cat Go Local Tunnel', 'Cat Go Device Connection'}
    files = list((APP / 'Features').rglob('*.swift'))
    files += [APP / 'Models/AppPreferences.swift']
    files += list((APP / 'Services/Pairing').glob('*.swift'))
    files += list((APP / 'Services/Tunnel').glob('*.swift'))
    for path in files:
        for _, _, key in strings(path.read_text()):
            if human(key) and key not in unchanged:
                assert key.replace('"', '\\"') in keys, f'Missing Chinese display string in {path.name}: {key}'
    recovery_view = (APP / 'Features/Home/SessionRecoveryView.swift').read_text()
    assert 'Text(AppLocalization.text(value, locale: locale))' not in recovery_view, 'User place names must not be translated again in recovery details'
    language = (APP / 'Models/AppLanguage.swift').read_text()
    app = (APP / 'App/RoamControlApp.swift').read_text()
    assert '.environment(\\.locale,' in app
    assert '.id(' not in app, 'Language changes must not recreate the app or its session'
    assert 'AppleLanguages' not in language, 'Do not change system language preferences'
    assert 'deviceSession' not in language and 'pairingService' not in language
    settings = (APP / 'Features/Settings/SettingsView.swift').read_text()
    assert 'LanguagePicker' in settings
    with tempfile.TemporaryDirectory() as temporary:
        main = Path(temporary) / 'main.swift'
        main.write_text('''import Foundation
struct LocationTarget { let name: String; let subtitle: String }
let resources = Bundle(path: CommandLine.arguments[1])!
let zh = Locale(identifier: "zh-Hans")
let traditional = Locale(identifier: "zh-Hant")
let en = Locale(identifier: "en")
assert(AppLocalization.text("Ready", locale: zh, bundle: resources) == "就绪")
assert(AppLocalization.text("Roam Control", locale: en, bundle: resources) == "Cat Go")
assert(AppLocalization.text("ROAM CONTROL", locale: en, bundle: resources) == "CAT GO")
assert(AppLocalization.text("Roam Control could not start its pairing engine.", locale: zh, bundle: resources).contains("Cat Go"))
assert(AppLocalization.text("Roam Control unknown native failure", locale: en, bundle: resources) == "Cat Go unknown native failure")
assert(AppLocalization.text("Ready", locale: en, bundle: resources) == "Ready")
assert(AppLocalization.text("Ready", locale: traditional, bundle: resources) == "就绪")
for source in ["Built-in Local VPN", "Connecting Built-in VPN…", "LocalDevVPN unknown failure", "Connecting the built-in local tunnel."] {
    for locale in [zh, en] {
        let display = AppLocalization.text(source, locale: locale, bundle: resources)
        assert(!display.contains("LocalDevVPN") && !display.contains("built-in") && !display.contains("隧道") && !display.contains("内置"))
    }
}
assert(AppLocalization.text("Built-in Local VPN", locale: zh, bundle: resources) == "设备连接")
assert(AppLocalization.text("Built-in Local VPN", locale: en, bundle: resources) == "Device Connection")
let catalogURL = resources.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: "zh-Hans")!
let entries = try! PropertyListSerialization.propertyList(from: Data(contentsOf: catalogURL), options: [], format: nil) as! [String: String]
for (key, translation) in entries {
    assert(AppLocalization.text(key, locale: zh, bundle: resources) == translation)
    assert(AppLocalization.text(key, locale: en, bundle: resources) == AppLocalization.brandedText(key))
    if key.contains("%@") {
        let sample = key.replacingOccurrences(of: "%@", with: "Custom Place (35%)")
        let expected = translation.replacingOccurrences(of: "%@", with: "Custom Place (35%)")
        assert(AppLocalization.text(sample, locale: zh, bundle: resources) == expected, key)
    }
}
assert(AppLocalization.text("Heading to My Place · 35%", locale: zh, bundle: resources) == "正在前往 My Place · 35%")
assert(AppLocalization.text("My custom place", locale: zh, bundle: resources) == "My custom place")
assert(AppLocalization.text("Unknown engine error", locale: en, bundle: resources) == "Unknown engine error")
// Natural-scale distances must retain the system region's unit convention.
func distance(_ locale: Locale) -> String {
    let formatter = MeasurementFormatter()
    formatter.locale = locale
    formatter.unitOptions = .naturalScale
    formatter.unitStyle = .short
    formatter.numberFormatter.maximumFractionDigits = 1
    return formatter.string(from: Measurement(value: 1609.344, unit: UnitLength.meters))
}
let digits = try! NSRegularExpression(pattern: "[0-9]+(?:[.,][0-9]+)?")
func number(_ value: String) -> String {
    let match = digits.firstMatch(in: value, range: NSRange(value.startIndex..., in: value))!
    return String(value[Range(match.range, in: value)!])
}
for region in ["US", "CN", "GB"] {
    let original = Locale(identifier: "en_" + region)
    let localized = AppLocalization.measurementLocale(for: zh, region: region)
    assert(number(distance(original)) == number(distance(localized)), "Language changed the displayed distance")
}
let custom = LocationTarget(name: "Ready", subtitle: "My custom address")
assert(custom.displayName(locale: zh) == "Ready")
assert(custom.displaySubtitle(locale: zh) == "My custom address")
let generated = LocationTarget(name: "Dropped Pin", subtitle: "Selected from the map")
assert(generated.displayName(locale: en) == "Dropped Pin")
assert(generated.name == "Dropped Pin" && generated.subtitle == "Selected from the map")
let suite = UserDefaults(suiteName: "roam-localization-regression")!
suite.removePersistentDomain(forName: "roam-localization-regression")
suite.set("active", forKey: "session")
AppLanguage.chinese.save(in: suite)
assert(AppLanguage.load(from: suite) == .chinese)
assert(suite.string(forKey: "session") == "active")
assert(suite.persistentDomain(forName: "roam-localization-regression")?["AppleLanguages"] == nil)
suite.set("unsupported", forKey: AppLanguage.preferenceKey)
assert(AppLanguage.load(from: suite) == .automatic)
suite.removePersistentDomain(forName: "roam-localization-regression")
print("Language persistence, interpolation and English fallback checks passed.")
''')
        executable = Path(temporary) / 'localization-tests'
        subprocess.run(['swiftc', str(APP / 'Models/AppLanguage.swift'), str(APP / 'Features/Map/LocalizedLocationTarget.swift'), str(main), '-o', str(executable)], check=True)
        subprocess.run([str(executable), str(APP / 'Resources')], check=True)
    print('Display-only localization regression checks passed.')

if __name__ == '__main__':
    check()
