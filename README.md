# SHIFT 13: The Night Audit 🏢🕯️

> **Platform:** Roblox  
> **Genre:** Cooperative Psychological Horror / Observation  
> **Target Party Size:** 1–4 Players  
> **Target Session Length:** 8–12 Minutes per Shift Cycle  

---

## 📖 Overview

*SHIFT 13: The Night Audit* is an observation horror game built in Luau. Players assume the role of night shift auditors assigned to monitor and inspect an unsettling 1980s corporate office. Your job is simple: memorise the baseline environment, explore the office during each shift, identify anomalies before time expires, and log your findings at the central Audit Terminal.

If the office matches the baseline, certify the shift as **Normal**. If an anomaly has manifested, diagnose and report the **exact category** to secure Evidence points and survive the night.

---

## 📂 Project Architecture

```
Roblox/
├── README.md
└── src/
    ├── shared/
    │   └── AnomalyConfig.luau              -- Master category dictionary, rewards, & shift constants
    ├── server/
    │   ├── OfficeManager.luau              -- 3D procedural office builder, prop baseline & mutation logic
    │   └── PrototypeController.server.luau -- Master server authority, shift lifecycle & validation
    └── client/
        └── LocalHUDController.client.luau  -- Retro CRT HUD, ProximityPrompt modal & dynamic menu
```

### Roblox Studio Hierarchy Mapping

| File Path in Repo | Roblox Studio Location | Instance Type | Purpose |
| :--- | :--- | :--- | :--- |
| `src/shared/AnomalyConfig.luau` | `ReplicatedStorage.AnomalyConfig` | `ModuleScript` | Single source of truth for categories & parameters |
| `src/server/OfficeManager.luau` | `ServerScriptService.OfficeManager` | `ModuleScript` | Physical office generation & prop mutations |
| `src/server/PrototypeController.server.luau` | `ServerScriptService.PrototypeController` | `Script` | Authoritative shift loop, anti-cheat validation |
| `src/client/LocalHUDController.client.luau` | `StarterGui.Shift13HUD.LocalHUDController` | `LocalScript` | Player HUD, category selection modal & audio cues |
| *Auto-Generated Network Remotes* | `ReplicatedStorage.Shift13Remotes` | `Folder` | Network events: `ShiftStateUpdate`, `SubmitReport`, `OpenTerminalUI` |

---

## 🔍 Milestone 5: Anomaly Variety & Specific Identification

### 1. Specific Anomaly Reporting
Instead of a basic binary "Yes / No" button, the reporting terminal features a modal dialog with specific categories:
- **Normal (No Anomaly)** — Confirm everything is standard baseline.
- **Clock / Time** (`ClockTime`) — Wall clock spinning out of control or frozen at impossible hours.
- **Furniture Shift** (`FurnitureShift`) — Office chair levitating or filing cabinet displaced across the room.
- **Terminal Glitch** (`TerminalError`) — CRT screen flashing blood-red static and override errors.
- **Door / Passage** (`DoorAjar`) — Heavy office door cracked wide open into the pitch black abyss.
- **Electrical / Lights** (`FlickeringLight`) — Fluorescent fixture violently flickering with ominous amber tint.
- **Painting / Decor** (`PaintingChange`) — East wall artwork inverted upside down with tainted hues.

### 2. Server Authority & Anti-Exploit Security
- The server secretly picks and stores the current anomaly (`currentAnomaly`) in memory.
- The client only submits a hypothesis string (`reportedCategory`).
- The server validates:
  1. Is the payload a valid string within `AnomalyConfig`?
  2. Is the shift state currently `"Active"`?
  3. Has the player already submitted a report for this shift? (Prevents brute-force spamming).
- Only correct identifications award Evidence (`+15` to `+20` PTS).
- Incorrect reports apply an Evidence penalty (`-5` PTS) and register an Audit Strike.

### 3. Dual Interaction
- **Physical In-World Terminal:** Walk up to the desk terminal and trigger the `ProximityPrompt` (`[E] Audit Terminal`).
- **HUD Quick-Access:** Convenient HUD button (`💻 AUDIT TERMINAL`) designed for mobile, testing, and accessibility.

---

## 🕹️ Testing Checklist

1. **Launch Roblox Studio Playtest (F5)**:
   - Ensure the office spawns in `Workspace.OfficeEnvironment`.
   - Verify top HUD shows `SHIFT 13 // AUDIT #1 [PREPARATION]` then transitions to `[ACTIVE]`.
2. **Explore & Inspect the Office**:
   - Check the wall clock on the North wall.
   - Check the office chair behind the desk and the filing cabinet in the corner.
   - Check the terminal display screen on the desk.
   - Check the door in the South wall.
   - Check the ceiling fluorescent light fixture.
   - Check the framed artwork on the East wall.
3. **Interact with the Terminal**:
   - Walk to the desk and hold **[E]** on the monitor, or click the **💻 AUDIT TERMINAL** button on screen.
   - Verify the retro category menu appears with icons, labels, hints, and potential evidence rewards.
4. **Test Correct Report**:
   - Select the matching anomaly (or "Normal" if nothing changed).
   - Verify green banner appears: `VERIFIED! Correctly identified: [...] (+20 Evidence)`.
   - Evidence counter increases and shift transitions to `[COMPLETED]`.
5. **Test Inaccurate Report**:
   - In a subsequent shift, deliberately pick an incorrect category.
   - Verify red banner appears: `AUDIT FAILED! Reported [...], but actual phenomenon was [...] (-5 Evidence)`.
   - Evidence score is penalized (minimum 0) and shift transitions to `[FAILED]`.
6. **Test Rate-Limit / Anti-Spam**:
   - Attempt to click another category after submitting.
   - Verify buttons lock out until the next shift begins.

---

## 💡 Practical Monetization Advice for Solo Horror Developers

1. **Evidence Multipliers (Gamepasses)**:
   - *Senior Auditor Clearance* (2x Evidence gain).
   - Sells well because horror players love unlocking cosmetic equipment faster without breaking game balance.
2. **Cosmetic Sanity & Flashlights**:
   - Vintage 1980s heavy-duty brass flashlight, UV blacklight lens, or retro cassette voice recorders.
3. **Audio Cassette / Lore Tapes**:
   - Collectible audio logs scattered in rare shifts that reveal why Shift 13 was quarantined.
