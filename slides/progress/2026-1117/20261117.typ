// 2026/11/17 の進捗報告。
// Google Slides で作った slides/reference/20261117.pdf を、テンプレートの試しとして Typst で作り直したもの。
// PDF を作るには、リポジトリの直下で次を実行する（同じフォルダに 20261117.pdf ができる）。
//   typst compile --root slides slides/progress/2026-1117/20261117.typ
//
// 素材の出どころ
// - copied/1103_p*.pdf：11/03 のスライドをコピーしたページ。slides/reference/20261117.pdf の p.3・p.4・p.6・p.8 を切り出した
//   （ファイル名の番号は 11/03 のスライドでのページ番号。p.16 はコピーした後に文言を直してある）。
// - figures/compare_(centroid_method)(original)_amp_track_and_manual_710-720ms.png：
//   results/figures/progress/ から削除済みの図を、git の履歴（84dac9f の親）から取り出した。
// - figures/fromSlide_20261117_p5_right.jpeg：元の図がリポジトリに無いため、20261117.pdf の p.5 から取り出した。
// - そのほかの図：results/figures/progress/grooveTracking/ と results/figures/slides/202609asj/ からコピーした。

#import "../../template/progress.typ": *
#show: progress-slides

#title-slide(date: "2026/11/17")

#slide(title: [11/03 → 11/17])[
  = 完了
  - 自動追跡の外れ値の解析

  #blank
  = 未着手
  - 複数本の自動抽出でどこまでできるか？
    - それを基準に撮影条件を考える
  - ほかのレコードの撮影
  - 照明の検討
]

#copied-slide(image("copied/1103_p9.pdf"))

#copied-slide(image("copied/1103_p14.pdf"))

#slide(title: [自動追跡と手動追跡の比較])[
  さらに拡大

  #fig-at(..cell-left(top: 165pt), image("figures/compare_(centroid_method)(original)_amp_track_and_manual_710-720ms.png"))
  #fig-at(..cell-right(top: 165pt), image("figures/fromSlide_20261117_p5_right.jpeg"))
  #draw(
    mark-arrow((328pt, 272pt), (392pt, 272pt)),
    mark-text(344pt, 250pt, [拡大]),
  )
]

#copied-slide(image("copied/1103_p15.pdf"))

#slide(title: [自動追跡の外れ値の解析])[
  （念のため確認）

  ※上下反転している

  #fig-at(
    ..cell-left(top: 160pt),
    image("figures/grooveOnImage_manualVsTrack_origD_inclBound_centroid_1014_img8_seg5_715-716ms.png"),
    crop: (0.305, 0.226, 0.774, 0.695),
  )
  #fig-at(..cell-right(top: 160pt), image("figures/fromSlide_20261117_p5_right.jpeg"))
]

#copied-slide(image("copied/1103_p16.pdf"))

#slide(title: [溝底の中心から離れた点])[
  #cols[
    溝底範囲が広くなっている \
    ←通常よりも暗い部分が広い
  ][
    溝側面の傷(?)で \
    影ができていると推測される
  ]

  #fig-at(
    ..cell-left(),
    image("figures/grooveOnImage_origD_inclBound_centroid_1014_img8_seg5_715-716ms_grooveBtmRange.png"),
  )
  #fig-at(
    ..cell-right(),
    image("figures/image_1014_img8_seg5_715-716ms.png"),
    marks: (mark-oval(0.424, 0.483, 0.221, h: 0.094),),
  )
]

#slide(title: [今後の方針])[
  #note[
    高解像度化を行ったデータに対する自動追跡を考える前に、 \
    溝底から離れた点が溝底として検出されない方法を考える。

    →溝底範囲が広い部分をどうにかしたい
  ]

  #blank
  = 実装案
  + 現在、溝底範囲（黄点～赤点の距離）が小さい部分を溝底としている \
    →この条件を今よりも厳しくする？
  + 重心の算出式を変え、暗い点がより重く評価されるようにする
]

#slide(title: [溝底範囲・重心の求め方], title-note: [（参考）])[
  #fig-at(..cell-left(top: 85pt, bottom: 260pt), image("figures/darknessProfile_grooveBtmRange.png"))
  #fig-at(..cell-right(top: 85pt, bottom: 260pt), image("figures/darknessProfile_profile.png"))
  #v(190pt)
  #align(center)[（重心法の式）]
]

#slide(title: [写真の再撮影])[
  2025waseda > 写真 > 20261117 配下
  - README: 撮影条件等のまとめ
  - 撮影した写真
]

#slide(title: [前回の音響学会], title-note: [（2026/09）])[
  *セッション*：電気音響 > 音響信号処理

  *発表形式*：オーラル

  *題名*：SPレコード写真からの音声再生における音溝底部の形状抽出方法の検討

  *キーワード*：

  *アブストラクト*： \
  我々は、SPレコードをデジタルカメラで撮影した画像から、輝度反転値である暗度を用いて音溝形状を抽出し、音声を再生する研究を行ってきた。本研究では、溝横断方向の暗度分布をリサンプリングし、実質的な空間解像度を向上させる手法を提案する。(116字)
]

#slide(title: [学会の申し込みについて], title-note: [（2027/03）])[
  発表内容
  - 溝の自動追跡
  - 複数本の自動抽出結果（手法は発表済み） \
    →溝底の抽出方法を再検討したい

  （以下は未着手）
  - 高解像度化画像に対する自動抽出
  - 現在の手法でどのくらいの本数の溝を抽出できるか \
    →本手法の限界
]

#slide(title: [学会の申し込みについて], title-note: [（2027/03）])[
  *セッション*：電気音響 > 音響信号処理

  *発表形式*：ポスター

  *著者*：三輪尋希（◎）、来住伸子、及川靖広

  *題名*： \
  SPレコードの盤面画像からの音声再生における自動溝抽出手法の検討

  *キーワード*：SPレコード、音溝、画像解析

  *アブストラクト*： \
  我々は、SPレコードの音溝画像からの音声復元に取り組んできた。従来手法では溝底位置を表した点群をクラスタリングするために手動で溝を選択する必要があったが、本研究では、逐次追跡を用いて自動で溝を抽出する手法を提案する。(108)
]

#slide(title: [11/17 → 12/08])[
  - 溝底範囲が広くなってしまうところを対処したい
    - 溝底範囲の幅を変える
    - 前のピクセルから2px跳んだら戻る（未検討、来住先生のアイデア。そこまでのいくつかの溝底点のy座標の標準偏差を超えたら、とかも考えられる）
    - 重心法の算出方法を変える（次のissueにする予定だった）
]
