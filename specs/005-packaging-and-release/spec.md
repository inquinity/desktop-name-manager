# Feature Specification: Packaging and Release

**Feature Branch**: `n/a (spec directory 005-packaging-and-release; work happens on main)`

**Created**: 2026-10-05

**Status**: Draft

**Input**: User description: "Packaging and release (spec 005): turn the dnm command-line tool (and later the app) into a signed, notarized release that people can install and upgrade through the maintainer's existing Homebrew tap, as an unlisted ("quiet") cask. A maintainer cuts a release only after the constitution's gates pass (independent code review, security review, macOS 26 and 27 live checks). A release is built reproducibly from a tagged commit, signed with the maintainer's Developer ID, notarized and stapled, packaged as a download hosted on this repository's GitHub Releases, with release notes and a checksum. The cask lives in the existing tap, is not listed in the tap's README, installs dnm (and the desktop-name alias) onto the user's PATH, supports upgrade and uninstall, requires macOS 26 or later, and never needs permissions, network access at run time, or disabling SIP. Out of scope: Intel builds (deferred), submission to the official Homebrew cask repository, the menu-bar app itself. Maintainer-held credentials (Developer ID, notarization profile) never enter the repository."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The maintainer cuts a release that has passed its gates (Priority: P1)

The maintainer decides a version is ready. They run one release procedure for a version number. It first checks that the constitution's gates are met: the pre-release code review and security review are recorded with no unresolved findings, the live checks have been recorded on macOS 26 and macOS 27, the automated tests and the unused-code scan pass, and the working tree is clean at the commit being released. It then builds the release from that commit, signs it, has Apple notarize it, verifies the result, and prepares a draft release with the download, its checksum and release notes. Nothing is public until the maintainer publishes the draft.

**Why this priority**: This is the product's only way to reach users, and the constitution makes the gates and the signing non-negotiable. Everything else depends on a trustworthy release.

**Independent Test**: Run the procedure for a test version on a commit where one gate is unmet (for example no macOS 26 record). It refuses and says which gate. Fix the gap, run it again, and it produces a verified draft release without publishing anything.

**Acceptance Scenarios**:

1. **Given** a clean, tagged commit with every gate recorded, **When** the maintainer runs the release procedure for that version, **Then** a draft release exists with the download, its checksum and release notes, and nothing has been published or pushed anywhere public.
2. **Given** a gate is unmet (a review has an unresolved finding, a macOS version has no live-check record, a test fails, or the tree is dirty), **When** the procedure runs, **Then** it stops before building, names the unmet gate, and changes nothing.
3. **Given** the build, signing or notarization step fails, **When** the procedure runs, **Then** it stops, leaves no published artifact and no partial draft, and says what failed and how to retry.
4. **Given** a built download, **When** the procedure verifies it, **Then** it confirms the signature is valid and from the maintainer's Developer ID, that Apple's notarization is attached, that macOS's download check accepts it, and that the checksum matches, and it refuses to proceed if any of these fail.
5. **Given** a verified draft, **When** the maintainer publishes it, **Then** the release becomes public with the same files and notes, and the maintainer can withdraw it again (see User Story 6).

---

### User Story 2 - A user installs the tool quietly through the tap (Priority: P1)

A person who knows about the tool, but has not been told through any public listing, installs it with one Homebrew command that names the tap and the tool. They get `dnm` and its alias `desktop-name` on their PATH. macOS accepts the download without a warning, the tool asks for no permissions, and it works with the network off.

**Why this priority**: Installation is the whole point of the release, and "without a warning" is a constitutional requirement.

**Independent Test**: On a Mac with a fresh user account on macOS 26 or later, add the tap if needed and run the install command. Run `dnm --version` and `desktop-name --version`; both work. No Gatekeeper or permission prompt appears.

**Acceptance Scenarios**:

1. **Given** a Mac on macOS 26 or later with Homebrew, **When** the user installs the cask by its name, **Then** both `dnm` and `desktop-name` run from a new terminal and report the same version.
2. **Given** the install has finished, **When** the user runs the tool for the first time, **Then** macOS shows no Gatekeeper warning and no permission prompt.
3. **Given** the network is off after installation, **When** the user runs any command, **Then** it works.
4. **Given** a Mac older than macOS 26, **When** the user tries to install, **Then** the install refuses with a clear message about the supported macOS versions and changes nothing.
5. **Given** an Intel Mac, **When** the user tries to install, **Then** the install refuses with a clear message that only Apple-silicon Macs are supported for now, and changes nothing.
6. **Given** the cask is in the tap, **When** someone reads the tap's public README, **Then** it does not list the tool (the cask is unlisted, not hidden: the file is in the public tap, and anyone who knows its name can install it).

---

### User Story 3 - A user upgrades to a newer release (Priority: P2)

When a new release is published, a user who installed earlier upgrades with the normal Homebrew upgrade command and gets the new version. Everything they had set up (their labels, and the Desktops that show them) keeps working through the upgrade.

**Why this priority**: Updates are how fixes, including security fixes, reach users, and labels must survive them (the constitution's reversibility principle).

**Independent Test**: Install release A, label a Desktop, upgrade to release B, and confirm the label is still on the Desktop and `dnm show` and `dnm remove` still work.

**Acceptance Scenarios**:

1. **Given** release A is installed and B is published, **When** the user upgrades, **Then** the installed tool reports B's version and A's files are gone.
2. **Given** a labeled Desktop before the upgrade, **When** the upgrade finishes, **Then** the label is still shown, and `dnm show`, `dnm undo` (within its window) and `dnm remove` work.
3. **Given** the stored data was written by a newer release than the installed tool understands, **When** the user runs a command, **Then** the tool reports that and changes nothing (existing behavior, kept through packaging).

---

### User Story 4 - A user uninstalls without losing their wallpaper (Priority: P2)

A user uninstalls the tool. The commands disappear from their PATH. Their Desktops keep whatever they show at that moment, including labeled wallpapers. A separate, clearly described step removes the tool's stored data as well, and it warns the user first that Desktops may still be using labeled images.

**Why this priority**: A tool that changes the wallpaper must not leave a Desktop blank or broken when removed.

**Independent Test**: Label a Desktop, uninstall, and confirm the wallpaper still shows. Then run the full removal and confirm the documented warning appears before any stored data is deleted.

**Acceptance Scenarios**:

1. **Given** the tool is installed and a Desktop is labeled, **When** the user uninstalls it, **Then** `dnm` and `desktop-name` are gone from the PATH and the labeled wallpaper still shows.
2. **Given** the tool is uninstalled, **When** the user uses the full-removal option, **Then** the documented instructions tell them first to remove labels they want gone (with the tool, before uninstalling) or accept that those Desktops will lose their labeled picture, and no stored data is removed silently.
3. **Given** an uninstall, **When** it finishes, **Then** nothing the tool installed remains on the PATH or in the install locations, except the user's stored data unless they chose full removal.

---

### User Story 5 - Anyone can verify a release independently (Priority: P3)

A cautious user or reviewer can check a release without trusting the maintainer's word: the signature and notarization of the downloaded files, the checksum against the one in the release and the cask, and which source commit and toolchain produced it.

**Why this priority**: The project's identity is security-minded and local-only; verifiability backs that up. It is not needed to ship the first release.

**Independent Test**: Download a release's files and run the documented verification commands; each reports success for a genuine release and failure for a file that was altered.

**Acceptance Scenarios**:

1. **Given** a published release, **When** a person follows the verification instructions in the release notes, **Then** they can confirm signature, notarization and checksum, and see the source commit and toolchain versions the release was built from.
2. **Given** a downloaded file altered after release, **When** the same steps are run, **Then** at least one check fails.

---

### User Story 6 - The maintainer can withdraw a bad release (Priority: P3)

If a published release turns out to be bad, the maintainer can withdraw it quickly so new installs stop getting it, and point users at the last good release.

**Why this priority**: Mistakes happen; the recovery path must exist before it is needed.

**Independent Test**: Publish a test release, then run the documented withdrawal steps and confirm new installs no longer receive it and the tap points at the previous release.

**Acceptance Scenarios**:

1. **Given** a published release, **When** the maintainer follows the withdrawal steps, **Then** the release is marked withdrawn, the cask in the tap returns to the previous release, and new installs get the previous release.
2. **Given** users already on the withdrawn release, **When** they upgrade, **Then** they get the next good release, and the release notes explain what to do.

---

### Edge Cases

- The tag exists but points at a different commit than the one being released; the procedure refuses.
- The same version is released twice; the procedure refuses to overwrite a published version.
- Notarization is slow or Apple's service is unavailable; the procedure waits a bounded time, then stops with a clear message and leaves nothing published.
- The maintainer's signing identity or notarization profile is missing or expired; the procedure stops before building and says which is missing, without printing any secret.
- The download is interrupted or its checksum does not match the cask; the install fails safely with Homebrew's checksum error.
- A user installs while another `dnm` is already on the PATH (for example a development build); the install reports the conflict instead of overwriting it silently.
- A user has labeled Desktops stored by a development build (a separate store); upgrades and uninstalls never touch that store.
- The tap's README or contents listing gets edited later to include the tool; that is the maintainer's choice, and nothing in the release procedure adds it.
- Homebrew's own behavior changes (for example the syntax for installing a command-line tool from a cask); the release procedure's dry run against a local copy of the tap catches it before anything is pushed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A single release procedure MUST take a version number and, from a clean working tree at a tagged commit, produce a verified draft release. It MUST NOT publish, push to any public location, or change the tap unless the maintainer separately confirms each of those steps.
- **FR-002**: The procedure MUST refuse to start, naming the unmet gate, unless: the pre-release code review and security review for that commit range are recorded with no unresolved finding (or each remaining finding is explicitly accepted in the record); live checks are recorded on macOS 26 and macOS 27; the automated tests and the unused-code scan pass; and the version number is new.
- **FR-003**: The version number MUST follow semantic versioning, MUST be the single source for the tool's reported version, the tag, the download file names and the cask, and MUST NOT be reused once published. Builds that are not releases MUST report which commit they came from, and whether the tree had uncommitted changes, in the version the tool prints (for example `0.1.0-dev+9398ae4`); a release build MUST report the plain version. A build with no commit information MUST say so rather than look like a release.
- **FR-004**: The build MUST come from the tagged commit only, with the toolchain and dependency versions recorded in the release notes, so that the same commit and toolchain give an equivalent build (identical apart from signature and timestamps).
- **FR-005**: Release artifacts MUST be signed with the maintainer's Developer ID, notarized by Apple, and carry the notarization ticket so that macOS accepts them without a warning, including with no network connection.
- **FR-006**: Before a release can be published, the procedure MUST verify, and show the result of, each of: the signature is valid and from the expected identity; notarization is present; macOS's download check accepts the artifact; the published checksum matches the file. Any failure MUST stop the procedure.
- **FR-007**: Each release MUST be hosted on this repository's public releases, containing the installable download and its checksum, and release notes stating: what changed, known gaps (for example untested configurations), the gate outcomes and their record, the supported macOS versions, the source commit, the toolchain versions, and how to verify the download.
- **FR-008**: Maintainer-held credentials (the signing identity, the notarization profile and any tokens) MUST be read from the maintainer's own keychain or environment at run time and MUST NEVER be written to the repository, to logs, to release files or to the tap. A scan of tracked files MUST fail if such a credential name or value appears.
- **FR-009**: The cask MUST live in the maintainer's existing tap. It MUST specify the download location, the version, the checksum, a minimum of macOS 26, and Apple-silicon only, and it MUST make both `dnm` and `desktop-name` available on the user's PATH. It MUST declare a way for Homebrew to detect new versions.
- **FR-010**: The cask MUST NOT be listed in the tap's public README or contents table. The release procedure MUST NOT add it there.
- **FR-011**: Before the cask is pushed to the tap, the procedure MUST check it against Homebrew's own cask audit and test an install, upgrade and uninstall from a local copy of the tap, reporting the results.
- **FR-012**: On an unsupported macOS version or an Intel Mac, installation MUST refuse with a clear message and change nothing.
- **FR-013**: Installing MUST NOT request any macOS permission, MUST NOT require disabling SIP or any other security setting, and MUST NOT make network connections other than the download itself. The installed tool MUST make no network connection when run (the constitution's local-only rule).
- **FR-014**: Upgrading MUST replace the installed files with the new release's and MUST preserve the user's stored data and their labeled Desktops. A stored-data format newer than the installed tool understands MUST be reported and left untouched.
- **FR-015**: Uninstalling MUST remove everything the install placed (the commands and their links) and MUST leave the user's stored data and their Desktops' current wallpapers untouched. A separate full-removal option MUST be documented, MUST describe what it deletes, and MUST warn that Desktops may still show labeled images and how to remove labels first.
- **FR-016**: A published release MUST be withdrawable by a documented procedure that marks it withdrawn, returns the cask to the previous good release, and does not delete the record of what was released.
- **FR-017**: The procedure MUST record, for each release, which gates passed and when, who ran it, and the checksums, in a file in this repository that contains no personal paths, identifiers or credentials.
- **FR-018**: The procedure MUST support a dry-run mode that performs every check and build step that does not publish, and prints what it would publish.
- **FR-019**: The release procedure and the cask MUST be free of personal paths, user names, display or Space identifiers and keychain profile names in tracked files (the constitution's hygiene rule).

### Key Entities

- **Release**: A version of the tool that passed the gates. It has a version number, the commit and tag it came from, the toolchain versions, the gate record, the release notes, and a state (draft, published, withdrawn).
- **Artifact**: The signed, notarized, installable download for a release, with its checksum.
- **Gate record**: What was checked before the release: reviews, live checks per macOS version, tests, scans, and their outcomes and dates.
- **Cask**: The tap's description of how to install, upgrade and uninstall a release: location, version, checksum, requirements, and the commands it provides.
- **Credentials**: The maintainer's signing identity and notarization profile. They exist only on the maintainer's machine and are never part of the repository or any release.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user on a fresh account on macOS 26 and on macOS 27 installs the tool with one command and runs `dnm --version` and `desktop-name --version` in under 2 minutes, with zero Gatekeeper warnings and zero permission prompts.
- **SC-002**: 100% of published releases have a gate record in the repository showing every gate met or explicitly accepted, and 0 releases were published with an unmet gate.
- **SC-003**: For every release, the signature, notarization, download check and checksum verifications all pass, and a file altered by one byte fails at least one of them.
- **SC-004**: In 100% of upgrade tests, labels set before the upgrade still show, and `dnm show` and `dnm remove` work afterwards.
- **SC-005**: In 100% of uninstall tests, no file the install placed remains on the PATH or in the install locations, and Desktops show the same wallpaper before and after.
- **SC-006**: A scan of all tracked files finds no credential name or value, personal path or identifier.
- **SC-007**: The dry run of the release procedure completes without publishing anything, and a withdrawn test release no longer reaches new installs within the time it takes the tap to update.

## Assumptions

- The tap already exists, is public, and the maintainer can push to it. "Quiet" means unlisted, not private: the cask file is visible in the public tap, and anyone who knows the name can install it. A truly private channel (a separate private tap, or private downloads) is a different, later decision.
- The maintainer holds the Developer ID identity and the notarization profile on their own Mac, and builds, signs and notarizes locally rather than in CI. The existing release pipeline of a sibling project is the starting reference for the steps.
- The first release contains only the command-line tool (and its alias). The menu-bar app (spec 002) adds an app bundle to the cask later; this spec's requirements apply to it then.
- Supported platform: macOS 26 or later on Apple-silicon Macs. Intel Macs are deferred (a universal build, with testing on the maintainer's 2019 MacBook Pro, is revisited later) and the cask refuses them until then.
- The pre-release code and security reviews are the ones defined in the constitution and recorded in `specs/001-labels-and-cli/review-notes.md`-style records; for later features, the record lives with that feature.
- The download format (a disk image or an archive) and the exact tool for each step are decided in planning; the requirements above hold for either.
- Submitting to the official Homebrew cask repository is out of scope and needs the popularity and age thresholds noted in the project notes.
- Release notes and the gate record are public, so they must never contain anything private (FR-017, FR-019).
