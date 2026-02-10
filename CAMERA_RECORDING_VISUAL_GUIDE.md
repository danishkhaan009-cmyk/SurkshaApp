# Camera Recording - Visual Guide

## Why Videos Show Black Screen

### ❌ WRONG - These positions cause black screen:

```
Position 1: Phone Face Down
┌─────────────┐
│   (BACK)    │  ← Camera facing table/surface
│   CAMERA    │
│             │
│   SCREEN    │  ← Screen touching table
└─────────────┘
     TABLE
═══════════════
Result: BLACK VIDEO (camera sees table)
```

```
Position 2: In Pocket
┌─────────────┐
│  (FRONT)    │  ← Camera covered by fabric
│   CAMERA    │
│             │
│   SCREEN    │
└─────────────┘
   POCKET/BAG
Result: BLACK VIDEO (camera sees darkness)
```

```
Position 3: Hand Covering Camera
┌─────────────┐
│  👆FINGER   │  ← Finger over camera lens
│   CAMERA    │
│             │
│   SCREEN    │
└─────────────┘
Result: BLACK VIDEO (camera blocked)
```

### ✅ CORRECT - These positions give clear video:

```
Position 1: Normal Phone Use (BEST)
        ┌─────────────┐
        │  (FRONT)    │  ← Front camera sees child's face
        │   CAMERA    │
        │      😊     │  ← Child looking at screen
        │   SCREEN    │
        └─────────────┘
            HAND
Result: ✅ CLEAR VIDEO showing child's face
```

```
Position 2: Phone on Stand/Table (Screen Up)
        ┌─────────────┐
        │  (FRONT)    │  ← Front camera sees room/child
        │   CAMERA    │
   😊   │             │  ← Child in front of phone
        │   SCREEN    │
        └─────────────┘
         TABLE/STAND
Result: ✅ CLEAR VIDEO showing child/room
```

```
Position 3: Angled on Surface
            ┌─────────────┐
        😊  │  (FRONT)    │  ← Camera facing child
            │   CAMERA    │
            │             │
            │   SCREEN    │
            └─────────────┘
               ╱
              ╱  Stand/Case
             ╱
        TABLE
Result: ✅ CLEAR VIDEO from good angle
```

## Camera Types Explained

### Front Camera (SELFIE) - ✅ NOW DEFAULT
```
┌─────────────────┐
│  📷 FRONT        │  ← This camera is used
│    CAMERA        │
│                  │
│   CHILD'S        │
│   VIEW OF        │
│   SCREEN         │
│                  │
└──────────────────┘

What it records: Child's face (like taking a selfie)
Pros: 
  ✅ Sees child's face
  ✅ Less likely to be blocked
  ✅ Good for monitoring who child is
Cons:
  ❌ Lower quality than back camera
  ❌ Child might notice
```

### Back Camera (REAR) - Previous Default
```
┌──────────────────┐
│                  │
│   CHILD'S        │
│   VIEW OF        │
│   SCREEN         │
│                  │
│    CAMERA   📷   │  ← This camera (on back)
│     BACK         │
└──────────────────┘

What it records: What child is looking at / environment
Pros:
  ✅ Better quality
  ✅ Sees what child sees
  ✅ More discreet
Cons:
  ❌ Often blocked (phone face down)
  ❌ Usually sees table/ceiling
```

## Lighting Requirements

### ❌ Too Dark:
```
     🌙 NIGHT
   No lights on
   
┌─────────────┐
│  📷 CAMERA  │  ← Can't see anything
│      ▓▓     │     (all black)
│      ▓▓     │
└─────────────┘

Result: BLACK or very dark video
```

### ⚠️ Low Light:
```
     🌙 DIM
   Minimal light
   
┌─────────────┐
│  📷 CAMERA  │  ← Can barely see
│      ░░     │     (very grainy)
│      😐     │
└─────────────┘

Result: Dark, grainy video
```

### ✅ Good Light:
```
     ☀️ DAY / 💡 LIGHTS ON
   
┌─────────────┐
│  📷 CAMERA  │  ← Clear visibility
│             │
│      😊     │
└─────────────┘

Result: ✅ Clear, visible video
```

## Recording Flow

### Parent Side:
```
PARENT'S PHONE
┌────────────────────────────┐
│  Suraksha App             │
│  ┌──────────────────────┐ │
│  │ Child's Device       │ │
│  │                      │ │
│  │ Camera Recording Tab │ │
│  │                      │ │
│  │ [Start Recording]    │ │  ← 1. Parent taps
│  │     (Green)          │ │
│  └──────────────────────┘ │
└────────────────────────────┘
           │
           │ Request sent via
           │ Supabase database
           ↓
```

### Child Side:
```
CHILD'S PHONE
┌────────────────────────────┐
│  Suraksha App             │  ← 2. App receives request
│  ┌──────────────────────┐ │
│  │   📱 Active           │ │
│  │   🔓 Unlocked         │ │
│  │   📷 Permission OK    │ │
│  │                      │ │
│  │   😊 Recording...    │ │  ← 3. Front camera records
│  │                      │ │     (child sees normal app)
│  └──────────────────────┘ │
└────────────────────────────┘
           │
           │ 30 seconds
           │
           ↓
       📤 Upload to
       Google Drive
           │
           ↓
```

### Parent Receives Video:
```
PARENT'S PHONE
┌────────────────────────────┐
│  Suraksha App             │
│  ┌──────────────────────┐ │
│  │ Camera Recording Tab │ │
│  │                      │ │
│  │ Recent Recordings:   │ │  ← 4. Parent sees new video
│  │                      │ │
│  │ ▶️ Feb 5, 3:20 PM    │ │
│  │   30 seconds         │ │
│  │   756 KB             │ │
│  │   [View Video]       │ │  ← 5. Parent clicks to watch
│  └──────────────────────┘ │
└────────────────────────────┘
```

## File Size Chart

```
Video Quality → File Size

BLANK/BLACK
(Camera blocked)
▓▓▓▓▓                        < 50 KB
❌ Rejected

VERY DARK
(Low light)
░░░░░░░░░                    50-200 KB
⚠️ Poor quality

NORMAL VIDEO
(Good lighting)
█████████████████          500-1000 KB
✅ Good quality

HD VIDEO
(High settings)
███████████████████████   1500-3000 KB
✅ Excellent (optional)
```

## Troubleshooting Decision Tree

```
Recording shows black screen?
          │
          ├─── Is child device unlocked? ──NO──→ UNLOCK DEVICE
          │                               YES
          │                                │
          ├─── Is app in foreground? ──NO──→ OPEN APP
          │                             YES
          │                              │
          ├─── Camera permission granted? ──NO──→ GRANT PERMISSION
          │                                 YES
          │                                  │
          ├─── Are lights on? ──NO──→ TURN ON LIGHTS
          │                     YES
          │                      │
          ├─── Is phone held normally? ──NO──→ HOLD UPRIGHT
          │                                YES
          │                                 │
          ├─── Is camera lens clean? ──NO──→ CLEAN LENS
          │                              YES
          │                               │
          └─── Camera might be faulty ──→ TRY DIFFERENT DEVICE
```

## Quick Checklist

Before starting a recording, ensure:

### On Child Device:
```
☑️  Screen is ON
☑️  Device is UNLOCKED  
☑️  App is OPEN (in foreground)
☑️  Phone held UPRIGHT (not face down)
☑️  LIGHTS are on in room
☑️  Camera lens is CLEAN
☑️  Front camera is NOT COVERED
☑️  Google Drive is CONNECTED
☑️  Internet connection is ACTIVE
```

### On Parent Device:
```
☑️  Device ID is correct
☑️  Watching the correct child
☑️  In "Camera Recording" tab
☑️  Clicked "Start Recording" button
☑️  Button shows "Stop Recording" (red)
```

## Success Indicators

### During Recording (Child Device):
- Small notification appears
- Camera is active (may see indicator LED)
- App continues working normally
- Screen stays on

### After Recording (Parent Device):
- New recording appears in list
- File size is >500 KB
- Timestamp is recent
- Video plays when clicked
- Can see child's face clearly

## Still Having Issues?

Check logs:
```bash
adb logcat | grep -E "CameraRecordService|GoogleDriveUploader"
```

Look for:
- ❌ "Camera permission not granted"
- ❌ "Recording file too small"
- ❌ "Device is locked"
- ❌ "App not in foreground"
- ✅ "Using FRONT camera"
- ✅ "Video file validated"
- ✅ "Recording uploaded successfully"

## Summary

### Main Fixes Applied:
1. ✅ **Front camera** now default (shows child's face)
2. ✅ **File size validation** (rejects black videos <10KB)
3. ✅ **Buffer overflow fix** (prevents "can't acquire buffer" error)
4. ✅ **Better logging** (easier to debug)

### Key Requirements:
- Child device must be **unlocked** and **screen on**
- App must be in **foreground** (not minimized)
- **Camera permissions** must be granted
- Phone should be **held upright** with front camera visible
- Recording needs **adequate lighting**

### Expected Result:
- 30-second video of child's face
- File size: 500-1000 KB
- Uploads to Google Drive automatically
- Appears in parent's recording list within 40 seconds
