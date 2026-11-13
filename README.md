# ArtisanROM 990 – Instagram Soft Reboot Fix

KernelSU module that stops the **SurfaceFlinger soft reboots** (ArtisanROM boot logo, back to the
system in a few seconds) that happen while using **Instagram** on **ArtisanROM 4.0.2** for
**Exynos 990** devices.

Tested on: **Galaxy Note 20 (c1s)**, ArtisanROM 4.0.2, KernelSU Next 3.x.
No wipe needed. Fully reversible.

---

## Symptoms

- Using Instagram (especially Reels) the phone "soft reboots" after a few minutes.
- Very often right when the **volume panel** or the **notification shade** is opened over a video.
- Sometimes with no interaction at all, while Reels auto-scroll.
- Instagram Lite is not affected.

Crash signature in `logcat`:

```
mali_winsys: Unrecognised Android chroma siting range: [2, 2]. Applying default
skia: Could not create EGL image, err = (0x3003)
F SurfaceFlinger: Unable to generate SkImage. isTextureValid:0 dataspace:...
F libc: Fatal signal 6 (SIGABRT) ... (RenderEngine), pid ... (surfaceflinger)
```

## Root cause

The vendor Mali driver (Android 11 vendor) cannot import some of the video buffers Instagram
produces (YUV / 10-bit P010, often HDR). That is harmless while the video layer is sent directly to
the display (HWC overlay). It becomes fatal when SurfaceFlinger has to **compose the video on the
GPU**: the texture import fails and RenderEngine aborts.

ArtisanROM 4.0.1 already includes a patch for an earlier abort in the same path
(`zzzz_sf_renderengine_compat`). On 4.0.2 the crash now happens one step later, in
`Unable to generate SkImage`.

Several things force GPU composition while Instagram is playing video:

1. **Blur.** Samsung's blur (volume panel, notification shade, ...) drawn over the video.
2. **Afterimage compensation.** Samsung `AfterimageCompensationService` calls `captureDisplay`
   **every 30 seconds** (`config_AFC_type=5`). On this ROM it fails anyway
   (`mAFPC_ABC: setImageSize fail(4)`), so it does nothing useful. It is what causes the crashes
   "without touching anything".
3. **Closing a screen over an HDR video.** When a screen opened on top of a video (comments, a
   profile, ...) slides away, the video layer gets squeezed into a strip a few pixels wide. The
   display hardware can't show a layer that thin, so it falls back to the GPU.
4. **Edge lighting pop-ups.** With notification pop-up style set to *Brief*, a notification shows
   as an edge lighting window with its own blur, which ignores *Reduce transparency and blur*.

## What the module does

| Trigger | Fix |
|---|---|
| Afterimage compensation capture | Bind-mounts a copy of `/product/overlay/framework-res__c1sxxx__auto_generated_rro_product.apk` whose **only** change is `config_AFC_type` **5 → 0**. It is applied only if the original file matches the ArtisanROM 4.0.2 c1s hash. |
| Blur over video | Listens for app-switch events (`wm_set_resumed_activity`, no polling) and turns on Samsung **Reduce transparency and blur** (`settings global accessibility_reduce_transparency`) **only while Instagram is in the foreground**. Blur stays on everywhere else. |
| Closing animation over video | Same listener: sets `window_animation_scale` and `transition_animation_scale` to **0 only while Instagram is in the foreground**, so screens open and close instantly there. Your own values are saved and restored when you leave the app (and on uninstall). |
| Edge lighting pop-ups | Same listener: sets `system edge_lighting` to **0** (pop-up style *Detailed*) only while Instagram is in the foreground, restored afterwards. |

Nothing on `/system`, `/product` or `/vendor` is modified on disk.

## Install

1. Download the zip from **Releases**.
2. KernelSU Next → Modules → Install from storage → select the zip.
3. Reboot.

The installer reports whether the afterimage fix is compatible with your ROM. If your overlay is
different (other device or ROM version), that part is skipped and only the per-app part (blur + animations) works.

## Configure

Apps where blur and transition animations are turned off: `/data/adb/modules/artisan990_noblur/apps.txt`, one package per
line. Example: add `com.zhiliaoapp.musically` for TikTok.

## Uninstall

Disable or remove the module in KernelSU Next and reboot.
If something goes wrong at boot, hold **Volume Down** during boot (KernelSU safe mode) to disable
all modules.

## Verify it is working

```sh
adb logcat -d | grep "AfterimageCompensationService: mAfcType"
# mAfcType : 0, mThreadAFPC : false ...

adb shell settings get global accessibility_reduce_transparency
# 1 while Instagram is open, 0 elsewhere
```

## Known limitations

- Some Instagram videos are decoded as **AV1 in software** (Dav1d). The Exynos 990 has no AV1
  hardware decoder, so a few videos can stutter. That is unrelated to this module.
- Some Samsung pop-ups draw their own blur and ignore *Reduce transparency and blur*, for
  example the "Copied to clipboard" toast. If one shows up over an HDR video it can still cause a
  soft reboot. It is rare, but it can happen.
- Inside Instagram, screens open and close without animation, and notification pop-ups use the
  *Detailed* style. Both go back to normal when you leave the app.
- This is a workaround. The real fix belongs in the ROM (RenderEngine / Mali import path).

## Rebuilding the overlay

`tools/build_overlay.sh` pulls the original overlay from a connected rooted device, changes only
`config_AFC_type`, rebuilds, aligns and signs it, and prints a resource diff plus hashes.
Requires Android SDK build-tools, `adb`, `python3` and `keytool`. Then run `./build.sh` to
package the module into `dist/`.

## License

GPL-3.0-or-later, same as ArtisanROM.
