# Map and navigation pilot setup

The Flutter app now uses a shared `flutter_map` tile component for the Space map, fixed place picker, and pinned photo viewer. The Space map opens privately and requests a current location fix; the **Start sharing** action is still separate. A recent device fix can center the map while GPS resolves. Panning stops automatic recentering until **Recenter** is pressed. Photo maps use only the saved pin and never request the viewer's location.

## MapTiler free development key

1. Create a MapTiler Cloud Free account and a public API key in its dashboard. Restrict the key to this app's use where MapTiler supports it. Do not activate billing.
2. Run Flutter with `--dart-define=MAPTILER_KEY=YOUR_PUBLIC_KEY`. For example, `flutter run --dart-define=MAPTILER_KEY=YOUR_PUBLIC_KEY`. The key is compiled into the app; it is **not** a secret. Do not commit a personal key or put a server credential here.
3. Satellite is the default; Streets is available beside it. With no key, the component uses OpenStreetMap Streets tiles and explains why satellite is unavailable. Tile errors show a retry action and suggest Streets.
4. Check [MapTiler's current Free allowance and terms](https://www.maptiler.com/cloud/pricing/) before using a key and before public/commercial release. The free plan is for the private development pilot in this rollout. Review a suitable licensed plan before commercial launch. MapTiler requires visible [map attribution](https://docs.maptiler.com/guides/map-design/attribution/add-attribution/), including its linked logo on Free. The current shared map displays linked attribution text; add the official MapTiler logo asset before enabling a MapTiler key for external testers.

The Space map, fixed pins, and photo viewer can be exercised locally without a MapTiler key using Streets. Native location permission, movement, background sharing, and map gestures still need physical-device checks on Android and iOS. The existing Supabase Cron worker and Firestore rules must be deployed together for account-wide event history; client task and ownership request cards remain available without that worker.
