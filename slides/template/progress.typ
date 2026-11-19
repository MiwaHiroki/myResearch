// 進捗報告のスライドのテンプレート。
//
// 寸法・色・文字の大きさは、Google Slides で使っていた自作テンプレートと、
// 2026/11/03・11/17 の進捗報告のスライドを実測した値に合わせている。
// 書き方は docs/progress-slides.md、Claude が守るルールは docs/rules/slides.md にある。
//
// 座標は、スライドの左上を原点とし、右と下を正とする（単位は pt）。
// スライドの大きさは 720pt × 405pt（16:9）。

// ───────── 寸法 ─────────
#let slide-width = 720pt
#let slide-height = 405pt
#let body-left = 31.3pt // 本文の文字の左端
#let body-right = 688.3pt // 本文の文字の右端
#let body-top = 88.9pt // 本文の1行目の上端
#let column-gap = 10pt // 左右に並べるときの間
#let fig-bottom = 398pt // 図とファイル名を置く範囲の下端（既定値）
#let caption-gap = 2pt // 図とファイル名の間

// ───────── 色 ─────────
#let rule-color = rgb("#1C4587") // タイトルの下の線
#let page-number-color = rgb("#595959")
#let caption-color = rgb("#666666") // 図の下のファイル名
#let mark-color = rgb("#FF0000") // 強調の図形（赤）
#let highlight-color = rgb("#F4CCCC") // 文字の背景の強調

// ───────── 文字の大きさ ─────────
#let title-size = 28pt
#let body-size = 20pt
#let sub-size = 16pt // 箇条書きの2段目、補足の行
#let caption-size = 10pt
#let page-number-size = 10pt
#let copy-label-size = 14pt
#let cover-title-size = 52pt // 表紙の「進捗報告」
#let cover-info-size = 28pt // 表紙の日付と氏名
#let subhead-size = 24pt // 本文の中の小見出し（「完了」「実装案」など。`= 完了` と書く）

// タイトルの文字の縁取り。BIZ UDPゴシックの太字は細めなので、縁取りを足して、
// Google Slides のタイトル（MS Pゴシックに縁取りを足して太くしたもの）と同じくらいの太さにする。
#let title-stroke = 0.6pt

// 線の太さ（Google Slides の 1px・2px・4px）
#let thin = 0.75pt
#let medium = 1.5pt
#let thick = 3pt

// 行の送りと段落の間。
// Google Slides の「行間1.1、段落前6pt・段落後6pt」は、実測すると
// 段落の中の行の送りが文字の大きさの1.32倍、段落の間がそれより6pt広い。
// 行の箱の高さを文字の大きさ（1em）にそろえたうえで、この見た目を再現する。
#let line-gap = 0.32em
#let para-gap = 0.32em + 6pt

#let fonts = ("BIZ UDPGothic",)

// ───────── 全体の設定 ─────────

// main.typ の先頭で `#show: progress-slides` として使う。
#let progress-slides(body) = {
  set document(author: "三輪尋希")
  set page(
    width: slide-width,
    height: slide-height,
    // 下の余白は 0（Google Slides と同じく、本文はスライドの下端まで書ける）
    margin: (left: body-left, right: slide-width - body-right, top: body-top, bottom: 0pt),
    // ページ番号は、図や過去のスライドの画像の上に描く
    foreground: context place(
      top + left,
      dx: 0pt,
      dy: 378.5pt,
      box(width: 710.3pt, align(right, text(
        size: page-number-size,
        fill: page-number-color,
        counter(page).display(),
      ))),
    ),
  )
  set text(
    font: fonts,
    size: body-size,
    lang: "ja",
    region: "JP",
    top-edge: 0.88em,
    bottom-edge: -0.12em,
    cjk-latin-spacing: none,
  )
  set par(leading: line-gap, spacing: para-gap, justify: false)
  set block(spacing: para-gap)
  // 箇条書き：1段目は「●」20pt、2段目は「○」16pt（11/03 のスライドの大きさ）。
  // 項の間（Enter）は段落の間と同じだけ空け、項の中の改行（shift+Enter）は `\` で書く。
  // 記号は文字の0.6倍の大きさにし、少し上げて行の中央に合わせる（Google Slides の見た目）。
  set list(
    marker: (text(size: 0.6em, baseline: -0.15em)[●], text(size: 0.6em, baseline: -0.15em)[○]),
    indent: 6pt,
    body-indent: 17pt,
    spacing: para-gap,
  )
  show list: it => {
    show list: set text(size: sub-size)
    show list: set list(indent: 8pt, body-indent: 18pt)
    it
  }
  set enum(indent: 0pt, body-indent: 6pt, spacing: para-gap)
  // 小見出し（`= 完了`）：太字で少し大きくし、前後は段落の間と同じだけ空ける。
  // PDF のしおりと目次には入れない。
  set heading(outlined: false, bookmarked: false)
  show heading: it => block(above: para-gap, below: para-gap, text(
    size: subhead-size,
    weight: "bold",
    it.body,
  ))
  body
}

// ───────── 位置の指定 ─────────

// スライドの左上を原点とする座標 (x, y) に、body の左上を置く。
#let at(x, y, body) = place(top + left, dx: x - body-left, dy: y - body-top, body)

// 図形の座標と大きさを解く。
// 長さ（pt）はそのまま使い、数（0〜1）は基準の幅・高さに対する割合とみなす。
#let _resolve(v, total) = {
  if type(v) == length { v } else if type(v) == ratio { total * (v / 100%) } else { total * v }
}

// ───────── 強調の図形 ─────────
// どれも「基準の幅 W と高さ H を受け取って図形を描く関数」を返す。
// 図の marks に渡すと図の大きさが基準になり、draw に渡すとスライド全体が基準になる。
// 位置と大きさは、PowerPoint と同じく、図形を囲む四角の左上 (x, y) と幅・高さで指定する。

// 楕円（丸）。h を省くと円になる。
#let mark-oval(x, y, w, h: auto, stroke: thin, color: mark-color) = (W, H) => {
  let cw = _resolve(w, W)
  let ch = if h == auto { cw } else { _resolve(h, H) }
  place(top + left, dx: _resolve(x, W), dy: _resolve(y, H), ellipse(width: cw, height: ch, stroke: stroke + color))
}

// 四角。
#let mark-rect(x, y, w, h, stroke: thin, color: mark-color) = (W, H) => {
  place(top + left, dx: _resolve(x, W), dy: _resolve(y, H), rect(
    width: _resolve(w, W),
    height: _resolve(h, H),
    stroke: stroke + color,
  ))
}

// 線。from と to は (x, y)。
#let mark-line(from, to, stroke: thin, color: mark-color) = (W, H) => {
  place(top + left, line(
    start: (_resolve(from.at(0), W), _resolve(from.at(1), H)),
    end: (_resolve(to.at(0), W), _resolve(to.at(1), H)),
    stroke: stroke + color,
  ))
}

// 矢印。to の側に矢じりを付ける。矢じりの大きさは Google Slides の矢印に合わせた。
#let mark-arrow(from, to, stroke: medium, color: black) = (W, H) => {
  let x1 = _resolve(from.at(0), W)
  let y1 = _resolve(from.at(1), H)
  let x2 = _resolve(to.at(0), W)
  let y2 = _resolve(to.at(1), H)
  let len = calc.sqrt(calc.pow((x2 - x1) / 1pt, 2) + calc.pow((y2 - y1) / 1pt, 2)) * 1pt
  let ux = (x2 - x1) / len
  let uy = (y2 - y1) / len
  let head-length = stroke * 4.6
  let head-half = stroke * 1.7
  let bx = x2 - head-length * ux
  let by = y2 - head-length * uy
  place(top + left, line(start: (x1, y1), end: (bx, by), stroke: stroke + color))
  place(top + left, polygon(
    fill: color,
    (x2, y2),
    (bx - head-half * uy, by + head-half * ux),
    (bx + head-half * uy, by - head-half * ux),
  ))
}

// 文字。(x, y) は文字の左上。
#let mark-text(x, y, body, size: 14pt, color: black) = (W, H) => {
  place(top + left, dx: _resolve(x, W), dy: _resolve(y, H), text(size: size, fill: color, body))
}

// 白塗り・黒枠の四角に入れた文字（吹き出し）。center: true で中央揃えにする。
#let mark-callout(x, y, body, center: false, size: body-size, width: auto) = (W, H) => {
  place(top + left, dx: _resolve(x, W), dy: _resolve(y, H), box(
    width: if width == auto { auto } else { _resolve(width, W) },
    fill: white,
    stroke: thin + black,
    inset: 7.2pt,
    align(if center { std.center } else { left }, text(size: size, body)),
  ))
}

// スライドの上に図形を描く。座標はスライド全体が基準（長さなら pt、数なら割合）。
#let draw(..marks) = at(0pt, 0pt, box(width: slide-width, height: slide-height, {
  for m in marks.pos() { m(slide-width, slide-height) }
}))

// ───────── 文字の飾り ─────────

// 文字の背景を薄い赤で塗る。
#let hl(body) = highlight(fill: highlight-color, top-edge: 0.88em, bottom-edge: -0.12em, body)

// 小さい字の補足（16pt）。項の中で `\` の後に書くと、11/17 の「（ギリギリ…）」の形になる。
#let note(body) = text(size: sub-size, body)

// 空の行を1行入れる（Google Slides で何も書かずに Enter を押したときと同じ）。
#let blank = v(1.32 * body-size)

// ───────── 図 ─────────

// 図の下に書くファイル名。`_` の後ろで折り返せるようにする。
#let _caption(name, width) = block(width: width, align(center, text(
  size: caption-size,
  fill: caption-color,
  name.replace("_", "_\u{200B}"),
)))

#let _file-name(img) = {
  let src = img.source
  if type(src) == str { src.split("/").last() } else { repr(src) }
}

// 表示する図の本体。crop は切り出す範囲 (x0, y0, x1, y1)（図に対する割合）。
// marks は図の上に描く強調の図形で、図（切り出した後）の大きさが基準になる。
#let _figure-body(img, display-width, aspect, crop, marks) = {
  let (x0, y0, x1, y1) = crop
  let full-width = display-width / (x1 - x0)
  let full-height = full-width * aspect
  let display-height = full-height * (y1 - y0)
  box(width: display-width, height: display-height, clip: crop != (0, 0, 1, 1), {
    // 画像を同じ大きさの box に入れる。入れないと、表示範囲より大きい画像が上下中央に寄ってしまう
    place(top + left, dx: -full-width * x0, dy: -full-height * y0, box(width: full-width, height: full-height, {
      set image(width: full-width)
      img
    }))
    for m in marks { m(display-width, display-height) }
  })
}

// 図を、幅 w・高さ h の範囲に収まる最大の大きさで置き、下にファイル名を書く。
// (x, y) はスライドの座標で、範囲の左上。図とファイル名は範囲の中で左右中央・上寄せにする。
// image() には width・height を付けない（大きさはこの関数が決める）。
#let fig-at(x, y, w, h, img, crop: none, marks: (), caption: true) = at(x, y, context {
  let natural = measure(img)
  let aspect = natural.height / natural.width
  let crop = if crop == none { (0, 0, 1, 1) } else { crop }
  let crop-aspect = aspect * (crop.at(3) - crop.at(1)) / (crop.at(2) - crop.at(0))
  let cap = if caption { _caption(_file-name(img), w) } else { none }
  let cap-height = if caption { measure(cap).height + caption-gap } else { 0pt }
  let display-width = calc.min(w, (h - cap-height) / crop-aspect)
  box(width: w, height: h, align(center + top, stack(
    spacing: caption-gap,
    _figure-body(img, display-width, aspect, crop, marks),
    cap,
  )))
})

// 本文の流れの中に図を置く。width か height のどちらかで大きさを決める（省くと本文の幅）。
#let fig(img, width: auto, height: auto, crop: none, marks: (), caption: true) = context {
  let natural = measure(img)
  let aspect = natural.height / natural.width
  let crop = if crop == none { (0, 0, 1, 1) } else { crop }
  let crop-aspect = aspect * (crop.at(3) - crop.at(1)) / (crop.at(2) - crop.at(0))
  let display-width = if width != auto { width } else if height != auto { height / crop-aspect } else {
    body-right - body-left
  }
  stack(
    spacing: caption-gap,
    _figure-body(img, display-width, aspect, crop, marks),
    if caption { _caption(_file-name(img), display-width) },
  )
}

// ───────── 図の配置の型 ─────────
// 図の位置をスライドごとにそろえるため、よく使う範囲を (x, y, w, h) で返す。
// `#fig-at(..cell-left(), image("figures/a.png"))` のように、.. を付けて fig-at に渡す。
// top は範囲の上端。上の文が長いときだけ変える。

#let _half-width = (body-right - body-left - column-gap) / 2

// 左右に2枚並べるときの左側。
#let cell-left(top: 150pt, bottom: fig-bottom) = (body-left, top, _half-width, bottom - top)

// 左右に2枚並べるときの右側。
#let cell-right(top: 150pt, bottom: fig-bottom) = (
  body-left + _half-width + column-gap,
  top,
  _half-width,
  bottom - top,
)

// 本文の幅いっぱいに1枚置く（横長の図）。
#let cell-full(top: 150pt, bottom: fig-bottom) = (body-left, top, body-right - body-left, bottom - top)

// 左に文、右に図を1枚置くときの右側。left は図の範囲の左端。
#let cell-side(left: 380pt, top: body-top, bottom: fig-bottom) = (left, top, body-right - left, bottom - top)

// 左に文、右に図を置くときの、左側の文の幅。cell-side と同じ left を渡す。
#let side-text(left: 380pt, body) = block(width: left - body-left - column-gap, body)

// 文を左右2列に分けて書く（左右の列は cell-left・cell-right の幅にそろう）。
#let cols(left, right) = grid(columns: (_half-width, _half-width), column-gutter: column-gap, left, right)

// ───────── スライド ─────────

// 「MM/DDのスライド」の表示（過去のスライドをコピーしたとき、右上に赤字で書く）。
#let _copy-label(from) = at(0pt, 8.2pt, box(width: 713pt, align(right, text(
  size: copy-label-size,
  weight: "bold",
  fill: mark-color,
  from + "のスライド",
))))

// 表紙（タイトルスライド）。進捗報告の1枚目だけに使う。
#let title-slide(date: none, author: "三輪尋希") = {
  pagebreak(weak: true)
  at(24.5pt, 58.6pt, box(width: 671pt, height: 77.6pt, align(center + horizon, text(
    size: cover-title-size,
  )[進捗報告])))
  at(24.5pt, 223.2pt, box(width: 671pt, height: 88.4pt, align(center + horizon, text(
    size: cover-info-size,
    date + linebreak() + author,
  ))))
}

// タイトルと本文（タイトルのみのスライドも、本文を書かずにこれを使う）。
// title-note はタイトルの後ろに細い字で添える文字（「(1周分)」など）。
// copied-from に "MM/DD" を渡すと、右上に赤字で「MM/DDのスライド」と書く
// （Typst で作った過去のスライドを、ソースごとコピーしたとき）。
#let slide(title: none, title-note: none, copied-from: none, body) = {
  pagebreak(weak: true)
  if title != none {
    at(24.5pt, 20pt, box(width: 671pt, height: 48.5pt, inset: (left: 6.8pt), align(left + horizon, {
      text(size: title-size, weight: "bold", stroke: title-stroke + black, title)
      if title-note != none { text(size: title-size, weight: "regular", [ #title-note]) }
    })))
    at(24.6pt, 75pt, line(length: 670.8pt, stroke: thin + rule-color))
  }
  if copied-from != none { _copy-label(copied-from) }
  body
}

// 白紙。
#let blank-slide(body) = {
  pagebreak(weak: true)
  body
}

// 過去のスライドの画像（PNG、または1ページの PDF）を、スライド全体に置く。
// ファイル名を `<MMDD>_p<ページ番号>.png`（または .pdf）にすると、右上に「MM/DDのスライド」と書く。
// from に "MM/DD" を渡すと、ファイル名の代わりにそれを使う。
// 画像に元の表示やページ番号があれば、白で隠してから描き直す。
#let copied-slide(img, from: auto) = {
  pagebreak(weak: true)
  let label = if from != auto { from } else {
    let m = _file-name(img).match(regex("^(\d{2})(\d{2})_p\d+"))
    assert(m != none, message: "過去のスライドのファイル名は <MMDD>_p<ページ番号> にする: " + _file-name(img))
    m.captures.at(0) + "/" + m.captures.at(1)
  }
  at(0pt, 0pt, box(width: slide-width, height: slide-height, {
    set image(width: slide-width, height: slide-height, fit: "contain")
    img
  }))
  at(590pt, 0pt, rect(width: 130pt, height: 31.5pt, fill: white, stroke: none))
  at(690pt, 376pt, rect(width: 24pt, height: 15pt, fill: white, stroke: none))
  _copy-label(label)
}
