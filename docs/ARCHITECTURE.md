# Sham Streets 3D — technical architecture

## Platform
Godot 4.x, GDScript, Android native export. Mobile compatibility renderer; target low/midrange devices first. No external AI API required for core gameplay.

## World
Original Syrian-inspired fictionalized districts in Aleppo and Damascus, with recognizable architectural atmosphere but no copied proprietary game assets. Stream districts in chunks; use LOD and occlusion to protect memory and battery.

## Modules
- Core: boot, save versioning, settings, localization, input remapping
- Player: locomotion, animation state machine, camera, inventory, outfits
- Vehicles: physics, enter/exit, traffic AI, garages
- City: streaming, traffic lanes, NPC spawning, shops and interiors
- Gameplay: mission state machine, police heat, economy, ownership
- UI: Arabic RTL HUD, map, mobile controls, accessibility
- Monetization: rewarded ads via supported native Android SDK integration; VIP entitlement verified server-side

## Payments and security
Sham Cash payment verification must be performed by a trusted backend/admin workflow, never by trusting a screenshot or client flag. Do not store payment secrets in GitHub or ship them in the APK. If publishing through Google Play, confirm applicable Play Billing and payment policy requirements before enabling any external-only digital subscriptions. Never promise an unsupported payment flow.

## Definition of done
A feature is done only after code review, automated checks where possible, device playtesting, performance profiling, and save/load regression testing.

## Release gates
Playable movement -> driving -> city systems -> missions -> monetization sandbox -> Android beta -> policy review -> production release.

## Current reality
Initial files are committed. The full game is NOT complete; no device tests or APK export have yet been verified.
