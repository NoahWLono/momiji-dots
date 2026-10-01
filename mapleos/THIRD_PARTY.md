# Third-party notices and release obligations

MapleOS is an aggregate of independently licensed software. The MapleOS integration-code MIT license does not replace the licenses of Linux, Arch packages, Archiso templates, fonts, firmware, artwork or any other dependency.

* Linux and installed packages: exact names, versions, package license fields and upstream project URLs are recorded in `package-metadata.txt` for each build. Packaged license files remain in `/usr/share/licenses` in the image.
* Archiso: the build generates a derivative of the installed `releng` profile. Archiso is GPL-3.0-or-later; preserve its license and source when redistributing the generated profile. Official source: https://gitlab.archlinux.org/archlinux/archiso and its GitHub mirror https://github.com/archlinux/archiso .
* Arch packaging recipes: https://gitlab.archlinux.org/archlinux/packaging/packages . Upstream source locations are recorded in the package metadata and packaging recipes. Historical binary versions are available through the Arch Linux Archive, subject to that project's retention.
* Selected Momiji assets: `wallpapers/maple.png`, `rice/fastfetch/maple-ascii.txt`, and the two provenance-only Caelestia override files originate from NoahWLono/momiji-dots. Inclusion is authorized by the repository owner's MapleOS request. This does not assert that every file elsewhere in momiji-dots is freely redistributable, or grant rights to unrelated third-party characters/assets. The build allowlist excludes the optional pony assets and optional sound collection.
* Caelestia is acknowledged as the inspiration for Momiji. The full Caelestia shell and CLI are not bundled in this preview, and MapleOS is not affiliated with its maintainers.
* Arch Linux, Firefox, Hyprland and other names identify their upstream projects. MapleOS does not claim endorsement or ownership of their marks.

## Before a general stable release

A package manifest and links alone are not a blanket determination that all source-distribution obligations have been fulfilled. The maintainer must audit the exact components and licenses, preserve required copyright notices and corresponding source/build materials, and arrange an appropriate source-distribution channel and retention period for the licenses used. Do not publish a claim of completed legal or trademark review on the basis of this file.

This preview does not add a binding source offer on behalf of the maintainer. Source-retention and redistribution review remain explicit stable-release gates. No maintainer signing identity is generated or impersonated by the build.
