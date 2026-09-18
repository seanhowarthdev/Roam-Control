# Third-party notices

Roam Control includes a native bridge linked against open-source Rust software.

## idevice

- Project: [jkcoxson/idevice](https://github.com/jkcoxson/idevice)
- Revision: `2bc58aaea40c9ced0167c8e7b512ee13c34c760f`
- Licence: MIT
- Copyright: Jackson Coxson
- Licence text: [`idevice-LICENSE.txt`](ThirdParty/idevice-LICENSE.txt)

## Rust dependencies

The exact dependency graph used by the native bridge is pinned in `Native/RoamPairingFFI/Cargo.lock`. Those packages remain the property of their respective authors and are distributed under the licence stated by each package. Common licences in this dependency graph include MIT, Apache-2.0, BSD and Unicode licences.

## LocalDevVPN / StosVPN

Roam Control's built-in local VPN uses code from LocalDevVPN / StosVPN, including its packet-tunnel provider, CIDR validation and tunnel constants.

- Project: [jkcoxson/LocalDevVPN](https://github.com/jkcoxson/LocalDevVPN)
- Authors: SideStore Team, Stossy11 and contributors
- Licence: StosVPN License (includes attribution and branding conditions)
- Licence text: [`LocalDevVPN-LICENSE.txt`](ThirdParty/LocalDevVPN-LICENSE.txt)
- The licence is also bundled in the application and displayed on the Built-in Local VPN page.

Roam Control's own source is licensed separately under the repository's [`LICENSE`](../../LICENSE) file. Roam Control 0.9.0 Beta 1 remains available under the MIT Licence preserved in [`LICENSE-BETA1-MIT`](LICENSE-BETA1-MIT). Neither project licence replaces or alters any third-party licence. Anyone redistributing a rebuilt native framework or IPA is responsible for retaining the applicable third-party copyright and licence notices for the dependency versions they distribute.
