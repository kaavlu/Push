# App Store Privacy Disclosure Inputs

Last reviewed: 2026-07-20 for Issue #36.

This is an engineering inventory for App Store Connect, not legal advice. Re-audit the shipping Release binary, backend retention, Supabase configuration, and every third-party SDK before submission. Apple requires the answers to include third-party partners and to stay current as practices change.

## Current Release data flow

Release uses Supabase authentication and the live repositories. The backend retains account/profile data and social coordination data so they are collected under Apple's definition. Push does not currently use advertising, cross-app tracking, analytics, crash reporting, the device contacts database, or device location services.

## Proposed App Store Connect answers

Select **Yes, data is collected**. The following data is linked to the user's account, used for **App Functionality**, and is **not used for tracking**:

| Apple data type | Push data | Notes |
|---|---|---|
| Contact Info → Name | Profile display name | Stored in `profiles`. |
| Contact Info → Email Address | Sign-in email | Stored/processed by Supabase Auth. Confirm Supabase retention and operator access before submission. |
| Identifiers → User ID | Supabase Auth UUID and profile/person IDs | Joins account, profile, friendships, groups, and Pushes. |
| Contacts | Friend relationships, friend requests, and group memberships | Apple's category includes a user's social graph; Push does not read the iOS address book. |
| User Content → Other User Content | Handle, availability choice, privacy settings, Push title/note/location hint, recipients, and RSVP state | User-entered or user-selected social coordination content retained by the backend. |

## Do not select for the current implementation

- **Precise Location / Coarse Location:** Release does not request device location or upload live presence. Map and seed coordinates are bundled mock content; live presence/feed return empty. Reassess before any real location or presence feature ships. A user-entered Push location is currently inventoried as Other User Content.
- **Photos or Videos:** profile photo editing is a prototype-only local affordance and does not upload media.
- **Phone Number:** mobile sign-up is unavailable.
- **Emails or Text Messages:** Pushes are structured coordination objects, not private messaging, email, or SMS. Reassess if chat or free-form messaging expands.
- **Usage Data / Diagnostics:** no analytics or crash-reporting pipeline is currently integrated. Issue #37 may change this.
- **Device ID, Purchases, Financial Info, Health & Fitness, Sensitive Info, Browsing/Search History, Advertising Data:** no implemented collection path was found.

## Submission checklist

- Replace the placeholder URLs in `Push/LegalDestinations.swift` with stable, public HTTPS documents requiring no login.
- Put the same Privacy Policy URL in App Store Connect. Apple requires it for iOS apps; a Privacy Choices URL is optional.
- Confirm the policy identifies the operator, contact method, retention/deletion process, Supabase's role, security practices, and user rights for every launch territory.
- Validate the table above against the archived binary, server logs, Supabase Auth/database behavior, and all dependency privacy manifests.
- Decide whether account deletion/privacy choices require a separate public URL and in-app flow.
- Re-audit whenever auth methods, contacts import, location, presence, uploads, analytics, diagnostics, notifications, or third-party SDKs change.

References: [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/), [Manage App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy), and [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
