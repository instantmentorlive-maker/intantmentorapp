# Call Feature Module

Production‑grade in‑app 1:1 audio/video calling foundation.

## Architecture Overview
Component | Purpose
--------- | -------
`SignalingService` | Socket.IO signaling (presence, call lifecycle, offer/answer/ICE relays)
`WebRTCMediaService` | Manages `RTCPeerConnection`, local/remote streams, ICE gathering
`CallController` | Riverpod state machine: call lifecycle + media orchestration
`CallScreen` | UI driven by `CallState`, renders video via `RTCVideoView`
Models (`Participant`, `CallEvent`, `CallSession`) | Domain objects and history logging
`CallHistoryRepository` | In‑memory history (extensible to Supabase persistence)
Stubs | `pip_stub.dart`, `screen_share_stub.dart` (future expansion)

Legacy (to be removed soon): `webrtc_call_screen.dart`, `core/services/webrtc_service.dart` (superseded by the controller/media service pattern).

## Current Capabilities
✔ Initiate / accept / reject / end calls
✔ Offer / Answer / ICE relay via server (`webrtc_offer`, `webrtc_answer`, `webrtc_ice_candidate`, `webrtc_hangup`)
✔ Local & remote video rendering (`RTCVideoView`)
✔ Mic / camera toggles wired to actual track enable states
✔ Error handling (permission denial, remote hangup, teardown)
✔ Clean disposal (tracks, peer connection, renderers)
✔ Basic call history logging (start, accept, end)
✔ Remote hangup feedback

## Negotiation Flow (Bullet Sequence)
1. Caller presses Call → `initiate_call` (signaling) stored as ringing.
2. Callee receives `call_initiated` → UI shows incoming screen.
3. Callee taps Accept → `accept_call` → caller gets `call_accepted`.
4. Caller (on `call_accepted`) creates local media & Offer → sends `webrtc_offer`.
5. Callee receives Offer → sets remote description → starts local media → creates Answer → sends `webrtc_answer`.
6. Caller receives Answer → sets remote description.
7. Both sides gather ICE candidates → each candidate emitted via `webrtc_ice_candidate` → peer adds candidate.
8. First remote track triggers UI remote video tile activation.
9. Either side ends → `end_call` + optional `webrtc_hangup` for early hangup during negotiation.

## Sequence Diagram (Conceptual)
Caller            Signaling Server            Callee
 |  initiate_call  --->                         |
 | <--- call_initiated                           |
 |                   (ringing)                  |
 |                   <--- accept_call --------- |
 | call_accepted --->                           |
 | create offer                                 |
 | webrtc_offer  --->                           |
 |                          webrtc_offer  --->  |
 |                          setRemoteDesc       |
 |                          create answer       |
 |                          webrtc_answer  ---> |
 | webrtc_answer (relay) --->                   |
 | setRemoteDesc                                |
 | gather ICE                                   | gather ICE
 | webrtc_ice_candidate --->                    |
 |                          relay ---> addIce   |
 |                          webrtc_ice_candidate (reverse path) ...
 | remote track event                           | remote track event

## WebSocket Event Contract (Negotiation)
Event | Direction | Payload Core
------|-----------|-------------
`webrtc_offer` | Caller → Callee | `{ callId, payload: { sdp, type } }`
`webrtc_answer` | Callee → Caller | `{ callId, payload: { sdp, type } }`
`webrtc_ice_candidate` | Either | `{ callId, payload: { candidate, sdpMid, sdpMLineIndex } }`
`webrtc_hangup` | Either | `{ callId, payload: { reason? } }`

## Troubleshooting Guide
Problem | Likely Cause | Action
------- | ------------ | ------
No remote video after 20s | Offer/Answer not exchanged or ICE blocked | Check signaling logs, ensure STUN reachable, confirm both peers called `startLocalMedia()`
Only local video shows | Remote never sent tracks | Confirm remote side added tracks before creating SDP; inspect onTrack callback
Permission denied error | User denied camera/mic | System dialog: instruct user to enable in OS/app settings and retry
Stuck “connecting…” | Offer never sent (caller) or answer not produced (callee) | Verify `call_accepted` received; ensure `webrtc_offer` emitted; watch console
Intermittent freeze | Network route change / ICE disconnect | (Future) implement ICE restart; for now end + retry
Green mic icon but silent remote | Track disabled or volume low | Toggle mic twice; inspect audio track enabled flags

## Defensive Timeouts
Implemented plan: add a (configurable) watchdog that ends call attempt if no remote track within N seconds (default suggestion: 20s). Pending (see TODO in controller if not yet integrated).

## Stats & Debug (Pluggable)
Add a button to call `peerConnection.getStats()` and surface:
Metric | Meaning
------ | -------
`outbound-rtp` bitrate | Uplink video bitrate (adaptation indicator)
`currentRoundTripTime` | RTT for media path
`framesDropped` | Rendering issues / performance

Example:
```dart
final stats = await _pc!.getStats();
for (final report in stats) { debugPrint(report.toString()); }
```

## Supabase Persistence Extension
Table (example):
```sql
create table if not exists call_history (
	call_id uuid primary key,
	caller_id text not null,
	receiver_id text not null,
	started_at timestamptz not null,
	accepted_at timestamptz,
	ended_at timestamptz,
	end_reason text,
	metadata jsonb default '{}'::jsonb
);
```
Upgrade repository:
```dart
final supa = Supabase.instance.client;
await supa.from('call_history').upsert({
	'call_id': callId,
	'caller_id': callerId,
	'receiver_id': receiverId,
	'started_at': startedAt.toIso8601String(),
	'accepted_at': acceptedAt?.toIso8601String(),
	'ended_at': endedAt?.toIso8601String(),
	'end_reason': reason,
});
```
Batch writes after end; fallback to local queue if offline.

## Deprecation Notice
Legacy prototype files retained temporarily:
- `webrtc_call_screen.dart`
- `core/services/webrtc_service.dart`

Mark for deletion after validation of the controller-driven path. Do **not** modify both paths in parallel.

## Roadmap
Priority | Feature | Notes
-------- | ------- | -----
P1 | Remote track timeout enforcement | Auto-fail negotiation
P1 | Supabase call history persistence | Replace in-memory only
P2 | PiP (Android/iOS) | Add platform channels & manifest flags
P2 | Screen share | Desktop/Web vs mobile divergence
P3 | Group calls / SFU | Replace mesh with server forwarding
P3 | Recording | Likely server side (SFU mix) or local composite
P4 | E2EE Insertable Streams | Key management + frame transforms
P4 | Push notifications for incoming call | FCM/APNS integration

## Dev Tips
- Use two different userIds in separate emulator/device instances.
- If debugging ICE, add `debug: true` STUN/TURN logging or temporarily force relay.
- Always verify permission flows on each platform (Android 13+ + iOS 17 changes).

---
Maintained by: Real-time/Media subsystem.
