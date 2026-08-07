// Template for the admin sign-in credentials used by admin_login_screen.
//
// Copy this file to `admin_credentials.dart` in the same directory and fill in
// the real values. `admin_credentials.dart` is gitignored so the actual
// password never lands in the repo. The admin app is only ever installed on
// the owner's device, so the runtime cost of a hardcoded password is
// acceptable — but committing one to git isn't.
//
// The values must match a Firebase Auth account whose custom claim
// `admin: true` is set (see the `set-admin-claim.js` script referenced in
// CLAUDE.md).
class AdminCredentials {
  static const String email = 'kammeugnejulio41@gmail.com';
  static const String password = 'REPLACE_ME';
}
