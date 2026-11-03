# ICASSP 2027 — Paper Outline

- **Target**: ICASSP 2027 (4 pages of text + 1 page of references, two-column)
- **Base**: ASJ 2026 Autumn Meeting, 3-8-7, "SPレコード写真からの音声再生における音溝底部の形状抽出方法の検討"
- **Status**: outline draft (structure and talking points only — no prose paragraphs yet)
- **作成日**: 2026-09-16

> This file fixes the *structure* of the paper before it is written in Overleaf. Each section lists what it must say, not how it will say it. Items marked **[TODO]** are facts that are not recoverable from the repository or the ASJ manuscript and must be supplied by the author.

**Page budget**: title + abstract 0.25, Sec. 1 0.75, Sec. 2 0.4, Sec. 3 1.0, Sec. 4 0.5, Sec. 5 1.0, Sec. 6 0.25 → **4.15 pages**, i.e. about 0.15 page over the 4-page limit. Sec. 2 and Sec. 4 are the intended absorbers (the parameter table can move inline, and the related-work survey can lose a sentence each on [1]–[2]). Confirm the actual limit before tuning — see Open Item 5.

---

## 0. Title / Abstract / Index Terms

### Title candidates

1. *Subpixel Groove-Bottom Extraction and Darkness-Domain Interpolation for Optical Audio Reconstruction from 78-rpm Record Photographs* — conveys both contributions; long.
2. *Deterministic Pseudo-Super-Resolution for Optical Audio Reconstruction from Photographs of 78-rpm Records* — leads with replacing generative-AI upscaling; shorter, but hides contribution I.
3. *Optical Audio Reconstruction from Photographs of 78-rpm Records Using Centroid-Based Groove-Bottom Estimation* — concise; hides contribution II.

Recommendation: a trimmed variant of (1), since the two contributions are to be presented as equal pillars.

### Abstract skeleton (~120 words; bullet the argument before writing prose)

- Shellac (78-rpm) discs degrade under stylus playback, so non-contact optical playback is desirable; camera-based capture is the cheapest route but is resolution-limited.
- The authors' previous system estimates the groove bottom as the single darkest pixel in each image column, which (a) quantizes the groove shape to a staircase and (b) depends on a black-box generative-AI upscaler to compensate for the low pixel resolution.
- This paper proposes two things: **(i)** a centroid estimator that computes the groove-bottom coordinate as the darkness-weighted centroid of the groove-bottom interval, giving subpixel resolution without upscaling the image; **(ii)** a deterministic pseudo-super-resolution that interpolates the *darkness* signal rather than the image — either 1-D across the groove, or 2-D.
- One revolution (~0.8 s) of a speech record is reconstructed under four upsampling conditions and compared qualitatively.
- Key finding: **resolution across the groove dominates audio quality**; resolution along the groove affects only the noise above roughly 10 kHz.

### Index Terms

`optical audio reconstruction`, `non-contact playback`, `78-rpm record`, `groove extraction`, `subpixel estimation`, `image interpolation`

---

## 1. Introduction (~0.75 page)

- Shellac 78-rpm discs were the dominant medium from the late 19th century to the mid 20th century; the natural-resin substrate degrades with both storage and stylus playback → non-contact playback is wanted for archival purposes.
- Survey the non-contact approaches and their trade-offs (one sentence each; details deferred to Sec. 2): laser / microscope readout (accurate, but bulky and expensive apparatus); flatbed scanner (cheap, but fixed illumination and limited optical resolution); consumer digital camera (cheap, small, and *illumination can be controlled* — the route taken here).
- Position this work: a consumer digital camera plus a purpose-built lighting box; the groove bottom is read from the photometric information (the "darkness" of each pixel) rather than from a binarized edge.
- Name the two limitations of the authors' previous system explicitly, because they motivate the two contributions one-to-one:
  1. The groove-bottom coordinate is an argmax over a single pixel → the extracted groove shape is a staircase, which is heard as musical noise.
  2. The only way to refine that estimate was to upscale the image with commercial photo-editing software whose super-resolution is generative; it fabricates structure absent from the original photograph — a reproducibility problem as much as a noise problem.
- State the two contributions as an equal pair:
  - **C1** — centroid-based subpixel estimation of the groove bottom from the darkness profile.
  - **C2** — deterministic pseudo-super-resolution by interpolating the darkness signal (1-D across the groove / 2-D), replacing the generative upscaler.
- Preview the main experimental finding (cross-groove resolution dominates), so the reader knows where the paper is going.
- Paper organization.

---

## 2. Related Work (~0.4 page)

- Laser full-surface readout of cylinders and discs [1].
- Image-processing reconstruction of mechanically recorded sound (Fadeyev & Haber) [2].
- *Digital Needle* — flatbed-scanner capture with a centroid-like groove estimator [3]. **Acknowledge explicitly that a comparable centroid formulation was proposed there**; the contribution here is its use on darkness maps from camera photographs, together with C2 — not the centroid idea in isolation.
- Authors' earlier camera-based work: binarization + edge detection of the flat-surface / slope boundary [4]; darkness-based groove-bottom extraction [5].
- **Authors' POMA paper `[POMA]`** — positioned here as *the method this paper starts from*. Declare the boundary once, in this section, so Sec. 3 does not have to re-argue it: imaging, preprocessing, and the definition of darkness are taken from `[POMA]` and only summarized; everything from groove-bottom interval estimation onward is revised and is described in full in this paper.
- Contrast with learning-based single-image super-resolution: for an archival-restoration task the mapping must be deterministic and reproducible, and must not synthesize structure that was never photographed. This is the requirement that rules out the generative upscaler and motivates C2.

---

## 3. Groove-Bottom Extraction from Record Photographs (~1.0 page)

> **Split of labour with `[POMA]`**: 3.1–3.2 are already published in `[POMA]` and are compressed to a citation plus the minimum needed to keep this paper self-contained. 3.3–3.6 differ from `[POMA]` and are described in full here. The space freed by compressing 3.1–3.2 goes to 3.3–3.5 and to Sec. 5.

### 3.1 Imaging and preprocessing — *summarize, cite `[POMA]`* (a few sentences + Fig. 1)

- The disc surface is photographed in 8 exposures; one eighth of a revolution is cropped from each photograph and warped so that the grooves run horizontally.
- Each rectified photograph is further split into 10 horizontal segments (80 segments per revolution); invalid margins at the left and right of each segment are masked off.
- Close with "see `[POMA]` for details of the capture geometry and the rectification."
- **[TODO]** Camera body, lens, illumination (lighting box), working distance, effective optical resolution (dpi) — none of these are recorded anywhere in the codebase or in the image metadata.

### 3.2 Darkness `D` — *summarize, cite `[POMA]`* (a few sentences + Fig. 2)

- Definition from the luminance `L` of each pixel: `D = 1 - L/255` (Eq. 1).
- The cross-sectional model of a groove and how it appears in the photograph: flat land = dark, slope = bright, groove bottom = moderately dark. Hence a groove bottom is *a narrow region whose darkness is locally higher than its surroundings*; in a 3-D rendering of `D` it appears as a thin ridge running along the groove.
- One figure carries this whole subsection (groove cross-section ↔ photograph ↔ darkness).

### 3.3 Groove-bottom interval estimation — *described in full* (Fig. 3)

- For each column `x`, take the darkness profile `D(y)` across the groove and mark the runs where `D > D_th`.
- The flat land also exceeds `D_th`, so runs are additionally filtered by width: only runs narrower than a width threshold are accepted as groove-bottom intervals. Report the start and end index of each accepted run.
- Give the parameter values used (`D_th = 0.6`, width threshold = 8 px; see Table 1).
- **[TODO]** State precisely what changed relative to `[POMA]` here — the author must enumerate the differences so this subsection can claim novelty accurately.

### 3.4 Proposed I — Centroid-based subpixel estimation (Fig. 4)

- Baseline (local-maximum method, used in [5] and `[POMA]`): the groove-bottom coordinate is the index of the largest darkness in the interval,
  `y = argmax_i D_i`  (Eq. 2). Only one pixel contributes, so `y` is integer-valued → staircase artifacts.
- Proposed: the darkness-weighted centroid over the same interval,
  `y = (Σ_i D_i · i) / (Σ_i D_i)`  (Eq. 3). Every pixel of the interval contributes and `y` becomes real-valued, i.e. subpixel, *without touching the image resolution*.
- Note the relation to [3] (same estimator, different acquisition, different darkness definition).
- Emphasize the property that matters downstream: C1 alone already removes the quantization of the groove shape, which is what suppresses musical noise.

### 3.5 Proposed II — Pseudo-super-resolution by darkness interpolation (Figs. 5–6)

- Motivation: the pixel grid, not the estimator, limits how finely the darkness ridge is sampled. Interpolating *darkness* is deterministic and reproducible, unlike upscaling the *image* with a generative model.
- **1-D resampling**: resample `D(y)` along the cross-groove direction only (factor 8). Only the `y` resolution increases; `x` (along the groove) is untouched.
- **2-D interpolation**: interpolate `D(x, y)` on a grid 8× finer in both directions (cubic spline, query step 0.125).
- A figure showing the sample positions for {original, 1-D resampling, 2-D interpolation} makes the distinction clear in one glance; a second figure shows the resulting darkness surfaces.
- Inverse scaling: coordinates found on the upsampled grid are mapped back to original image space by `(i - 1)/s + 1`, where `s` is the row scale factor. Stating this makes the conditions directly comparable.
- Note that the two proposals compose: the centroid is computed on whichever darkness grid is in use.

### 3.6 Waveform reconstruction — *described in full*

- Within each segment, a single groove is selected and its trend removed: the candidate points are fitted by a straight line inside a selected parallelogram (groove tilt correction), the tracked groove is chosen as the histogram peak of `y` nearest the previous segment's center, points within a tolerance of that center are gathered onto the `x` query grid, and gaps are filled by linear interpolation.
- A degree-3 polynomial is fitted and subtracted to remove the residual curvature of the groove, and the result is zero-meaned.
- The 80 detrended segments are concatenated into one revolution.
- The sampling rate follows from the rotation speed: one revolution lasts `60/78 = 0.769 s`, so `f_s = N / (60/78)`, where `N` is the number of `x` samples in the revolution. With `N = 32099`, `f_s = 41729 Hz` for the original and 1-D-resampled conditions; the 2-D-interpolated condition also upsamples `x`, so its `f_s` is 8× higher.
- **[TODO]** Confirm which parts of 3.6 differ from `[POMA]` (the groove-selection and detrending steps are the likely changes).

---

## 4. Experimental Setup (~0.5 page)

- **Material**: a speech record (male voice), the same disc used in [4] and [5]. One revolution ≈ 0.8 s, consisting of a vowel /a/ (~0.2 s) followed by ~0.6 s of silence. The silent part is what exposes the noise floor, so it is deliberately kept in the excerpt. **[TODO]** disc title / label / year, if it can be cited.
- **Conditions** — two comparisons, deliberately separated so the two contributions are evaluated independently:
  - **(a) Estimator**, at native image resolution: local maximum (conventional) vs. centroid (proposed).
  - **(b) Upsampling**, with the estimator fixed to centroid: 1. original image; 2. photo-editing software 8× (conventional); 3. 1-D darkness resampling (proposed); 4. 2-D darkness interpolation (proposed).
- **Reference**: the same passage played back with a stylus, recorded at 44.1 kHz and high-pass filtered at 100 Hz. Used as an upper bound on what the disc still carries, not as ground truth.
- **Table 1 — parameters** (all values verified against the implementation):

  | Item | Value |
  | --- | --- |
  | Photographs / segments | 8 photographs × 10 splits = 80 segments per revolution |
  | Input image size | ≈ 4005 × 460–560 px per photograph |
  | `x` samples per revolution | 32099 (after masking) |
  | Rotation speed → sampling rate | 78 rpm → `f_s = N/(60/78)` = 41729 Hz (original / 1-D resampled); ×8 for 2-D interpolation |
  | Darkness threshold `D_th` | 0.6 |
  | Groove-bottom width threshold | 8 px |
  | 1-D resampling factor | 8 (cross-groove direction only) |
  | 2-D interpolation | query step 0.125 (8× in both directions), cubic spline |
  | Detrending polynomial degree | 3 |
  | Photo-editing 8× image size | 30000 × 3736 px |
  | Stylus reference | 44.1 kHz, 100 Hz high-pass |
  | STFT | Hann window, 1024 samples, 50 % overlap |

- **[TODO]** Name the photo-editing software's upscaling mode, or soften the claim to "a commercial upscaler that synthesizes detail" if the algorithm cannot be named with confidence.

---

## 5. Results and Discussion (~1.0 page)

Evaluation is **qualitative**, matching the ASJ manuscript: extracted groove shapes, waveforms and spectrograms are compared visually, supported by listening. An objective evaluation is desirable but is not yet implemented (see 5.6).

### 5.1 Extracted groove shape (Fig. 7)

- Overlay three traces on one groove: original image × local maximum (staircase), original image × centroid (smoother), 1-D resampled × centroid (smoothest).
- The 2-D-interpolated trace is omitted because it lies almost exactly on the 1-D-resampled one — **this coincidence is itself evidence for the claim in 5.3** and should be stated, not hidden.

### 5.2 Waveforms and spectrograms (Figs. 8–9)

- (a) Estimator comparison at native resolution: the centroid method audibly reduces noise, in particular the warbling musical noise produced by the staircase groove shape.
- (b) Upsampling comparison: all three upsampling conditions markedly lower the broadband noise relative to the original image, but **differ little from each other** in the speech band.
- In every condition the speech content extends only to roughly 1.5 kHz.

### 5.3 Which direction of resolution matters (the paper's main claim)

- The three upsampling conditions differ in *which directions* are refined: 1-D resampling refines across the groove only; photo-editing 8× and 2-D interpolation refine both directions.
- Since the speech band is essentially unchanged among the three, cross-groove resolution is what governs audio quality — the extra along-groove resolution buys almost nothing there.
- Widening the spectrogram display to 20 kHz shows where along-groove resolution *does* act: the noise above roughly 10 kHz is somewhat reduced by the two conditions that refine `x`.
- Practical consequence worth stating: 1-D darkness resampling delivers nearly all of the benefit at a fraction of the memory and computation of a 2-D interpolation, and with no generative model in the loop.

### 5.4 Comparison with stylus playback (Fig. 10)

- Speech band of the reconstructed audio ≈ 1.5 kHz vs. ≈ 2.6 kHz for the stylus playback; the gap quantifies how much of the recorded information the optical path still loses.
- The stylus reference also carries a different noise character, so the comparison is a bound rather than a target.

### 5.5 Artifacts of generative upscaling (Fig. 11)

- Show a region where the upscaled image contains oblique dark streaks that have no counterpart in the original photograph, and where those streaks land as groove-bottom detections.
- Argue the reproducibility point: even when the generative upscaler happens to help, its output is neither reproducible nor auditable, which disqualifies it for archival restoration. Darkness interpolation is a closed-form alternative with comparable benefit.

### 5.6 (Optional) Objective evaluation

- Include **only if time before the deadline allows**; otherwise drop this subsection and keep the evaluation qualitative.
- Candidate measures, all referenced to the stylus playback of the same passage: upper edge of the speech band, stationary noise-floor level measured on the ~0.6 s silent part, and segmental SNR between the voiced and silent parts.
- **[TODO]** No SNR / correlation / RMSE code exists in the repository today; adding this subsection means implementing the metric from scratch and re-running the four conditions.

---

## 6. Conclusion (~0.25 page)

- Restate the two contributions and what each bought: the centroid estimator removes the staircase quantization of the groove shape (musical noise), and darkness-domain interpolation replaces a generative upscaler with a deterministic, reproducible one at no loss of quality.
- Restate the main finding: cross-groove resolution dominates audio quality; along-groove resolution only touches the noise above ~10 kHz. 1-D darkness resampling is therefore the efficient choice.
- Future work (condensed from the ASJ closing): lowering the residual stationary noise, widening the reproducible band, reconstructing longer passages, making groove-bottom detection independent of illumination intensity (adaptive darkness threshold), and establishing an objective evaluation protocol.

---

## Figures and Tables

ICASSP is two-column. The ASJ figures were sized for a 79 mm column at 10 pt and **will need re-rendering / re-sizing** for the ICASSP template. Figure generation is *not* part of this outline task — the source `.mat` results live under `experiments/`.

| # | Caption (draft) | Source script | On disk? |
| --- | --- | --- | --- |
| 1 | Capture and preprocessing pipeline: 8 photographs → 1/8 revolution → rectified segment | **[TODO]** new schematic | no |
| 2 | Groove cross-section, the corresponding photograph, and the darkness profile | `scripts/slides/202609asj/grooveShape3d.m` | yes |
| 3 | Darkness profile of one column with the estimated groove-bottom interval | `scripts/slides/202609asj/darknessProfile.m` | yes |
| 4 | Local maximum vs. centroid estimate on the same darkness profile | `scripts/slides/202609asj/darknessProfile.m` (`_centroid` / `_localMax` variants) | yes |
| 5 | Sample positions for original / 1-D resampling / 2-D interpolation | **[TODO]** schematic (exists as a slide graphic only) | no |
| 6 | Darkness surfaces under the three upsampling conditions | `scripts/slides/202609asj/darkness3dComparison.m` | yes |
| 7 | Extracted groove shapes overlaid (original × max, original × centroid, resampled × centroid) | `scripts/paper/202609asj/fig_grooveShapeComparison.m` | no |
| 8 | Reconstructed waveforms, four upsampling conditions | `scripts/paper/202609asj/fig_waveformUpsampling.m`, `fig_waveformComparisonOrigD.m` | partly |
| 9 | Spectrograms, four upsampling conditions (5 kHz and 20 kHz views) | `scripts/paper/202609asj/fig6_spectrogramUpsampling.m` | yes |
| 10 | Stylus playback waveform and spectrogram | `scripts/slides/202609asj/stylusPlayback.m` | yes |
| 11 | Artifacts introduced by generative upscaling, and their effect on detection | `scripts/slides/202609asj/photoshopNoise.m` | yes |
| — | Groove-bottom points on the image, per upsampling condition (backup figure) | `scripts/paper/202609asj/fig_grvBtmOnImgOrigUpsamplingD.m` | yes |
| T1 | Experimental parameters | — (Sec. 4) | — |

Expect to cut to ~8 figures for 4 pages; Figs. 1, 4 and the backup figure are the first candidates to drop or merge.

---

## References (provisional)

1. N. Takeoka, N. Hattori, Y. Yamasaki, "Reproduction of wax cylinders and records by full-surface laser readout," *J. Acoust. Soc. Jpn.*, 60(10), pp. 581–587, 2004. **[TODO]** confirm the official English title.
2. V. Fadeyev and C. Haber, "Reconstruction of Mechanically Recorded Sound by Image Processing," *J. Audio Eng. Soc.*, 51(2), 2003.
3. *Digital Needle — Final Report*, KTH, 2003. https://web.archive.org/web/20070827221105/http://www.s3.kth.se/signal/edu/projekt/students/03/lightblue/pdf/DOC_final_report_v01.pdf (accessed 2026-09-01).
4. R. Matsuda, A. Maeyama, N. Kishi, Y. Oikawa, "Audio reproduction from photographs of SP record grooves," *Proc. ASJ Spring Meeting*, pp. 303–304, Mar. 2025. **[TODO]** English title.
5. H. Miwa, N. Kishi, Y. Oikawa, "Audio reproduction from groove-bottom shapes extracted from luminance information in SP record photographs," *Proc. ASJ Spring Meeting*, pp. 217–218, Mar. 2026. **[TODO]** English title.
6. `[POMA]` — H. Miwa *et al.*, *Proc. Meetings on Acoustics*. **[TODO]** full bibliographic record. This is the most load-bearing citation in the paper: Secs. 3.1–3.2 are compressed against it.

ASJ proceedings are Japanese-language; their English titles must be taken from the official record rather than translated ad hoc.

---

## Open Items / TODO

1. Bibliographic record for `[POMA]` (replace the placeholder).
2. Enumerate exactly what changed from `[POMA]` in the groove-bottom interval estimation and the waveform reconstruction (Secs. 3.3, 3.6) — needed to state the novelty of those subsections accurately.
3. Capture metadata: camera body, lens, illumination setup, effective dpi, and the identity of the disc.
4. Final decision on whether Sec. 5.6 (objective evaluation) is in or out, and if in, which metric and how much implementation it needs.
5. ICASSP 2027 submission deadline, page limit and template version — confirm before fixing the page budget above.
6. Name of the photo-editing software's upscaling algorithm, or soften the "generative AI" wording.
7. Re-render the ASJ figures at ICASSP two-column sizes; several paper figures are not currently on disk (see the table).
