// 2026/12/08 の進捗報告（下書き）。
// PDF を作るには、リポジトリの直下で次を実行する（同じフォルダに 20261208.pdf ができる）。
//   typst compile --root slides slides/progress/2026-1208/20261208.typ
//
// 素材の出どころ
// - figures/ の図：results/figures/progress/grooveBottomDetection/ からコピーした（issue #35 の進捗報告の素材 M1〜M3・M6・M8・M9）。
// - 表と数値：docs/issues/closed/35-wide-bottom-outliers/progress-material.md の M4・M5・M7・M10。
// - 2枚目：slides/progress/2026-1117/20261117.typ の最後のスライドをコピーし、進捗ログ docs/progress/2026-1117_1208.md をもとに分けた。

#import "../../template/progress.typ": *
#show: progress-slides

#title-slide(date: "2026/12/08")

#slide(title: [11/17 → 12/08])[
  = 完了
  - 溝底範囲が広くなってしまうところへの対処
    - 溝底範囲の幅を変える（幅の上限 8px → 4px）

  #blank
  = 未着手
  - 前のピクセルから2px跳んだら戻る（来住先生のアイデア）
  - 重心法の算出方法を変える（次のissueの案として記録）
]

// ---- 1. 実装内容の説明 ----

#slide(title: [自動追跡の音声に出た振幅1付近の外れ値], title-note: [(1周分)])[
  #note[
    下：従来法(manual)と自動追跡(tracking)の音声の波形(1014、直す前、710\~720 ms) \
    ※従来法で出ないのは、溝底点がたまたま帯の外にあり、前後から補間したため
  ]

  #fig-at(
    ..cell-full(top: 140pt),
    image("figures/waveform_manualVsTrack_origD_inclBound_centroid_1014_710-720ms.png"),
    marks: (mark-oval(0.535, 0.06, 0.06, h: 0.32),),
  )
]

#slide(title: [外れ値の付近の溝底区間])[
  #side-text[
    写真8の x=1862\~1865 で、緑の点（幅5以上の溝底区間から求めた点）が溝底の暗い線より下にある

    →溝底区間の終わり（黄）が y=291 まで下がり、線の下の薄暗い所（溝の斜面？）までつながっている

    #note[※すべての溝底点（水色）は、ほかの点の下に隠れて見えない]
  ]

  #fig-at(
    ..cell-side(),
    image("figures/grooveOnImage_origD_inclBound_centroid_track_1014_img8_715-716ms_grooveBtmRange.png"),
    marks: (mark-rect(0.49, 0.71, 0.08, 0.09),),
  )
]

#slide(title: [しきい値すれすれの行による溝底区間の広がり])[
  #side-text[
    #note[
      右：外れ値の付近の3列の暗さの分布 \
      黒の横線：しきい値 $D_"th"$ = 0.6 \
      色の縦線：各列の重心(= 溝底点)
    ]

    - y=289\~291 の暗さが 0.59\~0.62 \
      →しきい値をわずかに上回ると、溝底区間が y=291 まで広がる
    - 重心：286.53 → 287.92 → 288.39 \
      #note[区間が片側に1行広がるごとに、約 0.45px ずれる]
  ]

  #fig-at(
    ..cell-side(),
    image("figures/darknessProfile_origD_inclBound_centroid_1014_img8_715-716ms.png"),
  )
]

#slide(title: [溝底区間の幅ごとの局所的なずれ], title-note: [(1104、5周分)])[
  #note[
    局所的なずれ：選んだ溝底点の y − 前後10列の y の中央値 [px] \
    外れ値：局所的なずれが 1px を超える点
  ]

  #note[
    #table(
      columns: (auto,) * 10,
      align: (left,) + (right,) * 9,
      inset: (x: 4pt, y: 6pt),
      table.header([幅 [px]], [0], [1], [2], [3], [4], [5], [6], [7], [8]),
      [点の数], [215], [33,494], [98,155], [26,952], [1,493], [75], [26], [2], [1],
      [ずれの最大], [0.509], [0.967], [0.936], [0.932], [0.962], [*1.487*], [*1.842*], [*1.846*], [*1.342*],
      [外れ値], [0], [0], [0], [0], [0], [*6*], [*17*], [*2*], [*1*],
    )
  ]

  →外れ値の26点はすべて幅5以上（幅5以上は全体の0.06%）
]

#slide(title: [外れ値を減らす案の比較], title-note: [(1104、5周分、重心法)])[
  #note[
    #table(
      columns: (1fr, auto, auto, auto),
      align: (left, right, right, right),
      inset: (x: 5pt, y: 5pt),
      table.header([案], [外れ値], [|振幅| > 1], [変わった列 \ (うち幅4以下)]),
      [直す前], [26], [32], [—],
      table.cell(fill: highlight-color)[1. 幅の上限を 8 → 4 にする（採用）],
      table.cell(fill: highlight-color)[0], table.cell(fill: highlight-color)[0], table.cell(fill: highlight-color)[106 (0)],
      [2. 自動追跡のパラメータを変える], [減らない], [—], [—],
      [3. ずれが 1px を超える点を除いて補間], [2], [17], [28 (0)],
      [4. 幅5以上だけ、最も暗い行の上下2行で重心], [0], [0], [104 (0)],
      [5. すべての点で重みを「暗さ − しきい値」に], [2], [—], [すべて],
    )
  ]

  #note[
    ※2：1014 で許す範囲を狭くすると、|振幅| > 0.8 が 2 → 22 に増える \
    ※3：11列以上続く外れ値を見逃す　※4：約 0.45px のずれが残る
  ]
]

// ---- 2. 結果 ----

#slide(title: [幅の上限を 8 → 4 にした結果], title-note: [(1014)])[
  #cols[
    左：直す前(黄)と直した後(マゼンタ)に選んだ溝底点(715 ms付近)
  ][
    右：直す前(赤橙)と直した後(青)の音声の波形(714\~717 ms)
  ]

  #fig-at(
    ..cell-left(top: 160pt),
    image("figures/grooveOnImage_wTh8VsWTh4_origD_inclBound_centroid_track_1014_img8_715-716ms.png"),
    marks: (mark-oval(0.48, 0.715, 0.09, h: 0.07),),
  )
  #fig-at(
    ..cell-right(top: 160pt),
    image("figures/waveform_wTh8VsWTh4_origD_inclBound_centroid_track_1014_img8_714-717ms.png"),
    marks: (mark-oval(0.44, 0.1, 0.08, h: 0.3),),
  )
]

#slide(title: [直す前と後の外れ値と振幅の数], title-note: [（重心法）])[
  #note[
    #table(
      columns: (1fr, auto, auto, auto),
      align: (left, center, center, center),
      inset: (x: 5pt, y: 6pt),
      table.header([直す前 → 直した後], [1014 自動追跡 \ (1周分)], [1104 本実装 \ (5周分)], [1104 正解データ \ (5周分)]),
      [外れ値の数], [1 → #hl[0]], [26 → #hl[0]], [25 → #hl[0]],
      [|振幅| > 1 のサンプル], [1 → #hl[0]], [32 → #hl[0]], [31 → #hl[0]],
      [|振幅| > 0.8 のサンプル], [2 → 1], [56 → 9], [55 → 9],
      [変わった列（うち幅4以下の点の列）], [7 (#hl[0])], [106 (#hl[0])], [106 (#hl[0])],
    )
  ]

  →幅4以下の点を採っていた列は1列も変わらない

  #note[※直した後も |振幅| > 0.8 で残るのは幅1\~3の点（ずれは最大 0.935px で、跳びではない）]
]

// ---- 3. 結果の考察 ----

#slide(title: [直した後も残る溝底の線の下がり], title-note: [(1104)])[
  #cols[
    左：直す前(黄)と直した後(マゼンタ)に選んだ溝底点(4本目、写真5)
  ][
    右：直す前(赤橙)と直した後(青)の音声の波形(2717\~2720 ms)
  ]

  #fig-at(
    ..cell-left(top: 160pt),
    image("figures/grooveOnImage_wTh8VsWTh4_origD_inclBound_centroid_hist_5cyc_1104_img5_groove4_2718-2719ms.png"),
    marks: (mark-rect(0.38, 0.27, 0.29, 0.09),),
  )
  #fig-at(
    ..cell-right(top: 160pt),
    image("figures/waveform_wTh8VsWTh4_origD_inclBound_centroid_hist_5cyc_1104_img5_groove4_2717-2720ms.png"),
  )
]

#slide(title: [直した後も残る溝底の線の下がり], title-note: [（続き）])[
  - 幅5の点が17列続いていた \
    →前後の中央値も一緒に動くので、外れ値として数えられない
  - 直した後：17列は補間され、|振幅| の最大は 1.228 → 0.777
  - 溝底の暗い線そのものが x=1138\~1160 で約 1px 下がっている \
    →直した後も、振幅が 0.7\~0.8 に持ち上がった所が残る

  #blank
  針が溝の斜面の一部を削り、溝底が部分的に広くなった所の影と思われる \
  →溝の形か影かを、写真の暗さだけで区別できる？
]

#slide(title: [幅の広い点の補間への置き換え], title-note: [(1014、写真8)])[
  #side-text[
    #note[右：直す前(黄)と直した後(マゼンタ)に選んだ溝底点(671 ms付近)]

    - x=33\~36：溝底区間が上下に1行ずつ広がり幅5 \
      →重心はずれていないが、補間に置き換わる
    - 1104 では78点が置き換わる \
      #note[y の変化：中央値 0.45px、最大 1.24px]

    →暗さのしきい値で溝底を決める限り避けられない欠点として受け入れる
  ]

  #fig-at(
    ..cell-side(),
    image("figures/grooveOnImage_wTh8VsWTh4_origD_inclBound_centroid_track_1014_img8_671-672ms.png"),
    marks: (mark-oval(0.5, 0.71, 0.09, h: 0.06),),
  )
]

// ---- 4. 検討事項・今後の方針 ----

#slide(title: [幅の上限を4にした後も残る問題])[
  #note[
    #table(
      columns: (1.1fr, 1.2fr, 1.2fr),
      align: left,
      inset: (x: 5pt, y: 6pt),
      table.header([残った問題], [分かっていること], [次にすること]),
      [外れ値でない幅の広い点も補間に置き換わる], [1104 で78点。点が溝底の上にあっても置き換わる], [重み「暗さ − しきい値」と組み合わせて、幅の上限を上げる？],
      [溝底の線そのものの下がりが残る], [1104 の4本目・写真5 で約 1px、振幅 0.7\~0.8], [溝の形か影か？],
      [幅4以下の点でも約 0.9px の跳びが残る], [溝底区間がまるごと1行ずれると起きる], [重心の重みを「暗さ − しきい値」にする \ (試行：ずれ > 0.75px の点が 193 → 0)],
    )
  ]
]

// ---- 5. 補足・参考事項 ----

#slide(title: [そのほかの残った問題], title-note: [（参考）])[
  - 11列以上続く外れ値を数えられない \
    #note[→続いた外れ値を数える指標を作る（急がない）]
  - 高解像度化した画像では確かめていない \
    #note[→高解像度化のissueで確かめる]
  - 従来法（幅の上限 8）と自動追跡（4）を、溝底点の一致を前提に比べられない \
    #note[→実験をやり直すときに比べ方を決め直す]
  - ほかのレコード・撮影条件では、溝底の線そのものが幅5以上になりうる \
    #note[→`trackGroove:longGap` の警告が出たら、幅の上限を見直す]
]

#slide(title: [12/08 → MM/DD])[
  - #sym.zws
]
