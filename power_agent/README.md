# PowerAgent — PrivateAgent se powerful

Original `orailnoor/private-agent` ka code padhkar banaya gaya. Usme ye problems thi, yahan fix hain:

| Original problem | PowerAgent fix |
|---|---|
| Overlay disabled (`floatingOverlayEnabled=false`, manifest me `SYSTEM_ALERT_WINDOW` remove) | Stable foreground-service overlay wapas, manifest entry + permission kept |
| `dispatchGesture(null,null)` — result pata nahi, swipe me duration missing, `longPress/openRecents` expose nahi | Har gesture callback + latch se await, `doubleTap/longPress/pinch/swipe(durationMs)/openRecents` sab expose |
| Absolute pixels, hardcoded swipe `540,1800→600` | Relative 0..1000 coords, density-independent `toPx()` |
| `clickByText` exact-match only, hint-only nodes drop | Fuzzy 3-stage match (exact→contains→lowercase), editable-hint match |
| Screenshot API30+ JPEG60, tree me 50-char truncate | Screenshot 768px JPEG55 (token bachao) + full tree 6000 chars + vision fusion |
| Single provider, 999 steps blowup, temp 1.0, client leak, greedy `{..}` parse | Multi-provider fallback, hard cap 60, temp 0.2, client always-close, balanced-brace parser |
| Blind coordinate skill replay | Sirf `click_text/type_text/open_app` replay, 30-day expiry |
| Koi sensitive-action confirm nahi | Pay/call/delete par Allow/Deny dialog |

## Features (Vision + Overlay + Gestures focus)
- Vision mode: screenshot + UI tree dono LLM ko (OpenAI vision format), fail par text-only fallback. Settings me Vision toggle.
- Stable overlay bubble (56px) ↔ panel (300x380), foreground service.
- Full gestures: tap, double-tap, long-press, swipe(duration), pinch in/out, scroll, back/home/recents/notifications.
- Multi-provider: primary + fallback list (OpenRouter free default `openai/gpt-oss-120b:free`).
- Skill memory + scheduler-ready `TaskExecutor` (cancel, onStep callback).

## Build
1. Flutter 3.10+ + Android SDK 34 install karo.
2. `cd power_agent && flutter pub get`
3. `flutter run` ya `flutter build apk --release` (universal APK).
4. App kholo → Settings me Base URL + API Key + Model → Accessibility me **PowerAgent Screen Control** on karo (sideload par **Allow restricted settings** pehle).
5. Goal likho: "WhatsApp kholo aur Ammi ko Hi bhejo".

## Test
`flutter test` — JSON parser + action allowlist unit tests.
