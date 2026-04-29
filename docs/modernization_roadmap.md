# Dios Delices Modernization Roadmap

## Current baseline

- Flutter project reconnected to a modern dependency graph.
- Hive adapters are generated again.
- App startup config is centralized in `lib/config/app_config.dart`.
- Initial data synchronization is extracted to `lib/services/app_bootstrap_service.dart`.
- Splash screen no longer owns data-fetching details directly.

## Architecture issues to tackle next

- Too much business logic lives inside screens, especially auth, cart, restaurant, and verification flows.
- Models mix remote API calls, local persistence, navigation concerns, and presentation assumptions.
- Role logic is duplicated and hard-coded in several places.
- Parse/Stripe/notification secrets are still hard-coded and should move to environment-specific config.
- The project still contains many legacy naming/style issues and a large amount of `print`-driven debugging.

## Recommended delivery phases

### Phase 1: foundation

- Introduce a clear app layer split: `core`, `data`, `domain`, `presentation`.
- Move Parse and local storage access out of widgets into repositories/services.
- Replace direct `SharedPreferences` and role branching in screens with a session/auth service.
- Add `.env` or flavor-based configuration for API keys and server URLs.

### Phase 2: core user journeys

- Stabilize auth and verification.
- Stabilize restaurant creation/update and approval.
- Stabilize cart, payment, and order creation.
- Add explicit order status handling, including "commande en attente".

### Phase 3: missing business features

- Restaurant management page: orders, opening hours, portions, available dishes, delivery fees.
- User experience pages: favorites, dish details, nearby restaurants, search, payment flow, order tracking.
- Notifications for new orders.
- Restaurant favorites and reductions.
- Professional/amateur restaurant distinction with badges.

### Phase 4: admin and cleanup

- Admin dashboard for validation, stats, basket inclusion, and moderation.
- Database cleanup and role synchronization.
- API cleanup and documentation.
- Test coverage for the most critical flows.

## Priority backlog from your notes

- `Server URL and Live Query`
- `Nearby restaurants`
- `Search`
- `Payments`
- `Restaurant management page`
- `Admin page and stats`
- `Favorites`
- `Notifications`
- `Professional badges`

## Suggested next implementation batch

1. Create repository/service layers for users, restaurants, orders, and payments.
2. Refactor login/session bootstrap around those services.
3. Rebuild restaurant and user home flows on top of that cleaned architecture.
4. Then add the remaining product features in vertical slices.
