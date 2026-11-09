# API compatibility

The client code read for this check was:

- web: `src/account/cloudRepository.js` and `src/account/AccountProvider.jsx`;
- iOS: `ios/Sources/FORMACore/WorkspaceTransport.swift` and
  `ios/Sources/FORMACore/AccountWire.swift`.

No iOS file was changed. No request or response body field was removed or
renamed. The workspace schema (`src/storage.js`) is unchanged, so saved data,
backups and the native resource manifest are unaffected
(`build-ios-resources --check` passes).

| Change                                                                                        | Who sees it                                   | Web client                                                               | iOS client                                                                                                                                   |
| --------------------------------------------------------------------------------------------- | --------------------------------------------- | ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `503 temporarily_unavailable` instead of `401` when the session store fails                   | Members during a database outage              | Non-401 is transient; the member stays signed in (`AccountProvider.jsx`) | 5xx maps to `.server` / `.transient` (`AccountWire.swift`, `WorkspaceTransport.swift`)                                                       |
| The Worker replaces upstream 5xx bodies with `{"error":"upstream_error"}`                     | Everyone, on server errors                    | Acts on the status only                                                  | Acts on the status only                                                                                                                      |
| `/readyz`                                                                                     | Operations only; not routed by the Worker     | n/a                                                                      | n/a                                                                                                                                          |
| Coach `removesActive` / `400 active_removal_unconfirmed`                                      | External coach tools with `full` tokens       | n/a                                                                      | n/a. Documented in `docs/accounts/api.md`.                                                                                                   |
| Coach mint `429 rate_limited` (10/hour) and member-wide writes (120/hour)                     | Coach tools and the Account page              | The existing error handling shows a generic message                      | n/a                                                                                                                                          |
| Coach tokens and trusted devices revoked on password change or reset, and sign-out everywhere | Members using coach tools                     | The confirmation copy now says so                                        | Same server behaviour. The iOS sign-out confirmation copy is unchanged, because the native app is out of scope (worth updating there later). |
| Anonymous workspace PUT and coach PATCH bodies capped small at the Worker                     | Anonymous callers only                        | Signed-in saves carry the session cookie                                 | Signed-in saves carry the cookie or bearer; `NATIVE-*` Worker tests stay green                                                               |
| Cross-site link GETs need `Sec-Fetch-Mode: navigate`                                          | Browsers following email links                | Real link clicks send `navigate`                                         | Non-browser requests without `Sec-Fetch-Site` are unaffected                                                                                 |
| Background auth mail in production                                                            | Sign-up, reset, change-email and delete flows | The response no longer reports provider failures; resend exists          | Same                                                                                                                                         |
| Workspace fingerprint                                                                         | Retries of member saves                       | Identical retries replay; legacy ledger rows replay                      | iOS key order does not matter, because the parsed form is canonical                                                                          |

The account browser journeys (`npm run test:accounts` and
`npm run test:accounts:production`) exercise these flows end to end. Their
results on the final branch are in TEST_RESULTS.md.
