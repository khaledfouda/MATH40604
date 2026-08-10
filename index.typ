// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [Advanced Mathematical Tools for Management],
  subtitle: [MATH 40604 --- Study Notes],
  author: "Khaled Fouda",
  date: "7 August 2026",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
  supplement-chapter: "Chapter",
)


// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 1, numbering: none)[How to use these notes]
<how-to-use-these-notes>
These notes accompany #strong[MATH 40604, Advanced Mathematical Tools for Management]. They are a study aid, not a replacement for the lectures: the official course material is the slide deck distributed each week. What the slides compress --- the intermediate algebra, the reason a definition is written the way it is, the mistake that costs marks --- is what these notes expand.

They are written on one assumption: that you are a capable adult who has not done mathematics in a while. Nothing here requires you to remember a formula from years ago. Where a step looks small, it is written out anyway.

#heading(level: 2, numbering: none)[The structure of each chapter]
<the-structure-of-each-chapter>
Every chapter follows the same path.

- #strong[Definitions] state an idea precisely, and are always followed by an #emph[In words] reading in plain English. If the symbols do not land, read the plain-English version first and come back.
- #strong[Key results] are the facts you will actually use. Each one is derived, not asserted.
- #strong[Worked examples] are set in a business or analytics context and show every algebraic step.
- #strong[Common pitfalls] collect the errors that recur --- usually not from misunderstanding the concept, but from a small slip in notation.
- #strong[One-minute recap] is what to reread on the train.

#heading(level: 2, numbering: none)[Notation used throughout]
<notation-used-throughout>
Mathematical notation varies between textbooks, countries, and software. The conventions below are fixed for the whole course; where a different convention is common elsewhere, it is noted.

Symbol | Meaning | Note |

#heading(level: 3, numbering: none)[What the typeface tells you]
<what-the-typeface-tells-you>
Mathematics uses the #emph[shape] of a letter to signal what kind of object it is. Learn these five and you can often tell what a symbol is before you have read its definition.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.header([Typeface], [Kind of object], [Examples],),
  table.hline(),
  [lowercase italic], [a #strong[scalar] --- a single number], [$x$, $q$, $c$, $beta_1$],
  [#strong[bold lowercase]], [a #strong[vector] --- an ordered list of numbers], [\$\\vect{x}\$, \$\\vect{w}\$],
  [#strong[bold uppercase]], [a #strong[matrix] --- a rectangular table of numbers], [$upright(bold(X))$],
  [uppercase italic], [a #strong[set], or a #strong[random variable]], [$A$, $U$, $Omega$\; $Y_i$, $X_i$],
  [blackboard $bb()$], [a #strong[standard number system]], [\$\\R\$, \$\\N\$, \$\\Z\$, \$\\Q\$],
  [calligraphic $cal()$], [a #strong[named structured set] or distribution], [\$\\normal\$, \$\\simplex{p}\$],
)
#strong[The bold rule is the one to internalise.] Bold means "not a single number." Nothing else in these notes is ever bold inside mathematics, so if you see bold, you are looking at a vector or a matrix. This resolves ambiguities that case alone cannot: $upright(bold(X))$ is the data matrix, $X_i$ is a random variable, and $X_1\,dots.h\,X_k$ are the pieces of a partition --- three different objects, told apart by weight and by subscript rather than by which letter was chosen.

Uppercase italic has to carry two jobs --- sets and random variables --- because both conventions are universal and neither can be dropped. Context separates them reliably: sets appear with $in$, $union$, $inter$\; random variables appear with $tilde.op$ and with subscripts indexing observations.

#heading(level: 3, numbering: none)[Reserved symbols]
<reserved-symbols>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.header([Symbol], [Meaning], [Note],),
  table.hline(),
  [\$\\N\$], [natural numbers ${ 0\,1\,2\,dots.h }$], [#strong[includes zero] in this course],
  [\$\\Z\$], [integers ${ dots.h\,- 1\,0\,1\,dots.h }$], [],
  [\$\\Q\$], [rational numbers], [quotients $a\/b$ with $b eq.not 0$],
  [\$\\R\$], [real numbers], [],
  [\$\\Rp\$], [non-negative reals, $\[0\,+ oo\)$], [includes $0$],
  [\$\\R^p\$], [real vectors with $p$ components], [],
  [\$\\R^{n \\times p}\$], [real matrices, $n$ rows and $p$ columns], [],
  [$\(a\,b\)$], [open interval], [#strong[parentheses], not $\]a\,b\[$],
  [$\[a\,b\]$], [closed interval], [],
  [\$\\simplex{p}\$], [the simplex in \$\\R^p\$], [$p$ components, non-negative, summing to $1$],
  [\$\\vect{x}\$], [a vector], [#strong[bold], always],
  [$upright(bold(X))$], [a data matrix], [#strong[bold], always],
  [$n$], [number of observations], [reserved],
  [$p$], [number of variables], [reserved wherever a data set is in play],
  [$i\,j\,k$], [summation and index letters], [never used for a quantity],
  [\$\\xbar\$], [mean of an observed sample], [],
  [$mu$], [mean of a population or distribution], [not the same object as \$\\xbar\$],
  [$hat(beta)$], [an estimate of $beta$], [the hat means "computed from data"],
  [$ln$], [natural logarithm, base $e$], [written $ln$, never $log$],
  [$log_10$], [logarithm base ten], [always written with its base],
)
Five of these are worth pausing on, because they are the ones that silently change answers.

#strong[Zero is a natural number here.] Many textbooks, particularly North American ones, start \$\\N\$ at $1$. This course starts at $0$. So "\$0 \\in \\N\$" is #emph[true] in this course and false in some books you may own. When in doubt, look at the convention table rather than at your memory.

#strong[Open intervals use parentheses.] French-language material writes the open interval from $a$ to $b$ as $\]a\,b\[$. This course writes $\(a\,b\)$, the convention used in statistics and data science software. You will see the French form on some slides; it means the same thing.

#strong["Non-negative" and "positive" are different words.] #emph[Positive] means strictly greater than zero. #emph[Non-negative] means greater than or equal to zero. French uses #emph[positif] for both, so translated material sometimes says "positive" where "non-negative" is meant. When it matters, this course says which.

#strong[$ln$ and $log$ are not interchangeable.] In R, #NormalTok("log()"); is the #emph[natural] logarithm and #NormalTok("log10()"); is base ten. In many spreadsheets and in engineering texts, #NormalTok("LOG"); means base ten. These notes always write $ln$ for the natural logarithm and always write the base explicitly otherwise.

#strong[A letter can be reused, and sometimes must be.] There are twenty-six letters and rather more than twenty-six ideas, so reuse is unavoidable --- even in professional writing. Two cases appear in these notes. The letter $p$ means the number of variables whenever a data set is present, but in the growth formula $Q_0\(1 + p\/100\)^t$ it is a percentage rate; the $%$ or the $\/100$ is what tells you which. The letter $Delta$ is the discriminant of a quadratic when bare, and the simplex \$\\simplex{p}\$ when subscripted. Both reuses are flagged where they occur. The lesson is not that notation is sloppy but that it is #emph[local]: a symbol means what the surrounding text says it means, and checking is a habit worth forming rather than a sign that you have missed something.

#heading(level: 2, numbering: none)[A note on effort]
<a-note-on-effort>
You will get more out of a worked example by covering the solution and attempting it than by reading it. The examples are chosen so that this is realistic: none of them requires an insight you have not been given.

= Modelling, Sets, and Algebra
<modelling-sets-and-algebra>
#heading(level: 2, numbering: none)[This week at a glance]
<this-week-at-a-glance>
By the end of this chapter you should be able to:

- take a described business situation and say which quantities are #strong[variables] and which are #strong[parameters], and justify the split;
- write down the objective and constraints of a small decision problem in symbols;
- describe a set three ways --- by listing, by a defining property, and as an interval --- and move between them;
- read and write $union$, $inter$, complement, and difference#strike[, and compute the size of a union without double-counting]\;
- #text(fill: rgb("#128a3a"))[translate a tolerance stated with an absolute value into an interval, and read interval notation correctly;]
- #text(fill: rgb("#128a3a"))[recognise when a family of subsets forms a partition of a universe;]
- expand and condense $sum$ notation, and #strike[prove] #text(fill: rgb("#128a3a"))[use] the two identities about deviations from the mean;
- solve linear and quadratic equations#strike[, and use logarithms to turn a multiplicative relationship into a linear one]#text(fill: rgb("#128a3a"))[\;]
- #text(fill: rgb("#128a3a"))[apply the exponent and logarithm rules, and compute compound growth and decay.]

#text(fill: rgb("#8a6d3b"))[#emph[Why: the list promised three things the chapter no longer delivers --- inclusion--exclusion, proofs of the summation identities (now set as exercises), and log-linearisation. It was also silent on three things the chapter does cover: absolute value and intervals, partitions, and growth/decay.]]

Nothing here is new mathematics. Most of it you have met before and put down. The aim is to pick it up in a form you can use.

#horizontalrule

= What a mathematical model is
<what-a-mathematical-model-is>
A #strong[mathematical model] is a simplified description of a real-world situation, written in symbols. We say simplified because a mathematical model leaves things out on purpose. For example, a model of a delivery network that accounted for every pothole would be useless, because you could not solve it and could not learn anything from it.

The mathematical model is represented by an equation between variables and parameters. A #strong[parameter] is a quantity whose value is settled before you solve the model. It is either an input given in the problem statement, measured, or estimated from the data. A #strong[variable] is a quantity whose value is produced by solving the model, or supplied by an observation. \ \ Consider a straight-line relationship $y = beta_0 + beta_1 x$. If you are a manager who has been handed $beta_0 = 12$ and $beta_1 = 3$ and asked to predict $y$ when $x = 20$, then $beta_0\,beta_1$ are #strong[parameters] and $y\,x$ are #strong[variables].

== The components of an optimization problem (decision model)
<the-components-of-an-optimization-problem-decision-model>
#block[
#callout(
body: 
[
A company manufactures two products, $A$ and $B$. It must determine the quantities to produce each week in order to maximize its profit.

Product $A$ generates a profit of \$30 per unit and requires 2 hours of labor. Product $B$ generates a profit of \$20 per unit and requires 1 hour of labor. The company has 100 labor hours available per week. Because of demand limitations, it cannot sell more than 40 units of $A$ or more than 70 units of $B$.

#strong[Setting up the mathematical model:]

What are the variables? How much of each product to make.

$ x_A = upright("units of ") A upright(" produced per week")\,#h(2em) x_B = upright("units of ") B upright(" produced per week") . $

What are the parameters? #strike[We know in advance that the total weekly profit is \$30 for every unit of] $A$ plus \$20 for every unit of $B$. #text(fill: rgb("#128a3a"))[Every number the company was handed rather than chose: the unit profits \$30 and \$20, the labor times of 2 hours and 1 hour, the weekly capacity of 100 hours, and the demand ceilings of 40 and 70 units.]

#text(fill: rgb("#8a6d3b"))[#emph[Why: as written this answered "what is the objective?" rather than "what are the parameters?", and it named only two of the seven parameters the table below lists.]]

What is our goal? Maximize the profit. The profit is an #strike[equation] #text(fill: rgb("#128a3a"))[expression built] of the variables and parameters.

$ upright("maximize") quad 30 x_A + 20 x_B . $

Left alone, this could grow without bound. In reality, however, #strike[resources are] #text(fill: rgb("#128a3a"))[both the company's resources and its market are] limited. Thus, we define the following constraints:

Each unit of $A$ consumes 2 hours and each unit of $B$ consumes 1 hour, and only 100 hours exist:

$ 2 x_A + x_B lt.eq 100 . $

Moreover, we cannot sell more than 40 units of $A$ or more than 70 units of $B$. Of course, the number of units produced cannot be negative!

$ x_A lt.eq 40\,#h(2em) x_B lt.eq 70\,#h(2em) x_A gt.eq 0\,quad x_B gt.eq 0 . $

The last components of the model to be defined are the assumptions. Earlier we mentioned that the mathematical model is a simplified representation as we cannot realistically account for all possibilities. However, in order for the problem to be solvable and for us to be confident in the solution, some assumptions need to be made. For instance, in this example we may assume that the profit per unit is constant, that we know the production times, that we know the maximum demand, and that each unit produced can be sold. \ \ This is all the information we need to solve the model. A clear definition of the optimization problem is crucial and must come before attempting to solve it. We will defer solving this problem to later classes.

]
, 
title: 
[
Example
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
Below we summarize the components of an optimization problem as we saw them in the example.

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.header([Component], [What it is], [In the example],),
  table.hline(),
  [#strong[Decision variables]], [The quantities you choose. Unknown before solving.], [$x_A$, $x_B$],
  [#strong[Parameters]], [Values handed to you. Known before solving.], [unit profits 30 and 20; labor times 2 h and 1 h; capacity 100 h; demand ceilings 40 and 70],
  [#strong[Objective function]], [The single number you are making as large or as small as possible.], [$30 x_A + 20 x_B$, maximized],
  [#strong[Constraints]], [Equations and inequalities every admissible answer must satisfy.], [$2 x_A + x_B lt.eq 100$\; $x_A lt.eq 40$\; $x_B lt.eq 70$\; $x_A\,x_B gt.eq 0$],
  [#strong[Assumptions]], [Simplifications that make the problem solvable, and that you should be prepared to defend.], [unit profits constant; labor times known; maximum demand known; every unit produced can be sold],
)
#block[
#callout(
body: 
[
Some assumptions are necessary for the validity of the solution even though they are not necessary to obtain a solution. For example, we will obtain a solution to the optimization problem regardless of whether we assume that every unit produced can be sold. However, our solution is valid only under this assumption. Assumptions allow us to simplify the optimization problem and, in particular, the objective function. But we must state them clearly, as they affect the interpretation of the results.

]
, 
title: 
[
Caution
]
, 
background_color: 
rgb("#ffe5d0")
, 
icon_color: 
rgb("#FC5300")
, 
icon: 
fa-fire()
, 
body_background_color: 
white
)
]
== Deterministic and probabilistic models
<deterministic-and-probabilistic-models>
In the example above, the model is #strong[deterministic] because profits, production times, capacity and maximum demand are assumed to be known with certainty. That is a strong assumption. If some of these data were uncertain, then the model would become #strong[probabilistic]. For example, recall that we assumed a demand ceiling of 40 units for product $A$. Now, if we assume instead that the demand for product $A$ follows a normal distribution with mean $40$ and standard deviation of $5$, then the demand for product $A$ will be represented by the random variable:

\$\$D\_A \\sim \\normal(40, 5^2).\$\$

#text(fill: rgb("#128a3a"))[Notice what has happened to the vocabulary. Demand is no longer a parameter but a #strong[variable], because we no longer know its value before solving. The numbers $40$ and $5^2$ are the parameters now: they describe the distribution, and they are still known in advance. The test from the start of this chapter still works, one level up.]

The company would then have to choose its production level while accounting for the risk of producing more than the realized demand.

#block[
#callout(
body: 
[
In the notation \$\\normal(\\mu, \\sigma^2)\$ the #strong[second argument is the variance, not the standard deviation]. Writing \$\\normal(40, 5^2)\$ means a standard deviation of 5. Some software, including R's #NormalTok("rnorm");, takes the standard deviation as its argument instead, which is a frequent source of error when moving between a formula and code.

]
, 
title: 
[
Caution
]
, 
background_color: 
rgb("#ffe5d0")
, 
icon_color: 
rgb("#FC5300")
, 
icon: 
fa-fire()
, 
body_background_color: 
white
)
]
== Statistical models
<sec-stat-model>
In the #strike[example above] #text(fill: rgb("#128a3a"))[production example], profits per unit were given to us. We said earlier that model parameters are either known in advance or estimated. A statistical model allows us to estimate those parameters from observed data and to say how much we trust them.

#block[
#callout(
body: 
[
Suppose we want to explain a company's sales as a function of its advertising expenditures. For period $i$ we record sales $Y_i$ and advertising spend $X_i$, and propose

\$\$Y\_i = \\beta\_0 + \\beta\_1 X\_i + \\varepsilon\_i, \\qquad \\varepsilon\_i \\sim \\normal(0, \\sigma^2).\$\$

where

- $beta_0$ is baseline sales. This is what the model says would be sold with no advertising at all.
- $beta_1$ is the effect of advertising. That is, the change in sales associated with one extra dollar spent.
- $epsilon_i$ is everything the model does not capture, for example, a competitor's promotion, the weather, a supply problem. It is not an error in the sense of a mistake; it is the part of $Y_i$ that advertising does not explain.
- $sigma^2$ is the error variance, measuring how much that unexplained part varies.

#strike[In a statistical model, the #strong[response variable] (also called the #strong[dependent variable]) is the quantity the model sets out to explain or predict. It sits on the left-hand side.]

#strike[An #strong[explanatory variable] (also called an #strong[independent variable], a #emph[predictor], a #emph[regressor], or a #emph[covariate]) is a quantity used to explain the variation in the response.]

]
, 
title: 
[
Example
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
#text(fill: rgb("#8a6d3b"))[#emph[Why: this is a definition, and every other definition in the chapter sits in its own #NormalTok("callout-note");. Moved out of the Example box and reformatted below --- delete the struck text above and keep the block that follows, or the reverse.]]

#block[
#callout(
body: 
[
#text(fill: rgb("#128a3a"))[In a statistical model, the #strong[response variable] (also called the #strong[dependent variable]) is the quantity the model sets out to explain or predict. It sits on the left-hand side.]

#text(fill: rgb("#128a3a"))[An #strong[explanatory variable] (also called an #strong[independent variable], a #emph[predictor], a #emph[regressor], or a #emph[covariate]) is a quantity used to explain the variation in the response. Explanatory variables sit on the right-hand side.]

#text(fill: rgb("#128a3a"))[#emph[In words: the response is what you want to know; the explanatory variables are what you already know and are using to guess it.]]

]
, 
title: 
[
Definition: response and explanatory variables
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
In the sales model, $Y_i$ is the response and $X_i$ is the explanatory variable. The quantities $beta_0$ and $beta_1$ are the model parameters. We assume that we have a limited number of observations of pairs $\(Y_i\,X_i\)$ which we use to estimate the model parameters as well as the error variance. Then, we use the #strike[parameters] #text(fill: rgb("#128a3a"))[estimated parameters] and the explanatory variable(s) to #strike[estimate] #text(fill: rgb("#128a3a"))[#strong[predict]] future values of the response. #text(fill: rgb("#128a3a"))[These are two different jobs, and the words are not interchangeable: we #emph[estimate] the parameters, which are fixed but unknown, and we #emph[predict] the response, which is random. Predicting carries more uncertainty than estimating, because a future response contains its own $epsilon_i$ on top of whatever error we made in the parameters.] One final note: the names "dependent" and "independent" are somewhat misleading, as they have nothing to do with statistical independence.

= Sets and subsets
<sets-and-subsets>
A #strong[set] is a well-defined #strike["unordered"] #text(fill: rgb("#128a3a"))[unordered] collection of #text(fill: rgb("#128a3a"))[distinct] objects, called its #strong[elements].

#text(fill: rgb("#8a6d3b"))[#emph[Why: the quotation marks make "unordered" look like a hedge when it is a precise property ---] ${ 1\,2 }$ and ${ 2\,1 }$ are the same set. "Distinct" is the companion property: an element is either in the set or not, so listing it twice changes nothing.] Sets are useful because so many things are naturally collections, for example, a population, the domain of a variable, the set of feasible decisions, a set of observations.

We write $x in A$ for "$x$ belongs to the set $A$", and $x in.not A$ for "$x$ does not belong to $A$". We first present #strike[the following] some basic mathematical notation that we will rely on for the rest of the course. Here, lower-case letters denote scalars ($a\,b\,x$), and $P$ and $Q$ are statements. Statements could be mathematical relationships (e.g., $a = b$) or just plain English (e.g., this course is fun).

== Basic mathematical notation
<basic-mathematical-notation>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.header([Symbol], [Reading], [Example],),
  table.hline(),
  [$a = b$], [$a$ is equal to $b$], [$x = 3$],
  [$a eq.not b$], [$a$ is not equal to $b$], [$x eq.not 0$],
  [$a < b$], [$a$ is less than $b$], [$x < 10$],
  [$a lt.eq b$], [$a$ is less than or equal to $b$], [$x lt.eq 10$],
  [$a > b$], [$a$ is greater than $b$], [$x > 10$],
  [$a gt.eq b$], [$a$ is greater than or equal to $b$], [$x gt.eq 10$],
  [$a in A$], [$a$ belongs to the set $A$], [\$\\sqrt{2} \\in \\R\$],
  [$a in.not A$], [$a$ does not belong to $A$], [\$-1 \\notin \\N\$],
  [$forall x$], [for every $x$, for all $x$, for any $x$], [\$\\forall x \\in \\R\$],
  [$exists$], [there exists], [$exists x > 0$],
  [$arrow.r.double$], [implies], [$P arrow.r.double Q$],
  [$arrow.l.r.double$], [is equivalent to, if and only if], [$P arrow.l.r.double Q$],
)
\$\\R\$ and \$\\N\$ are the sets of real and natural numbers, respectively. We will introduce them #strike[later below] #text(fill: rgb("#128a3a"))[below] along with other standard number sets. First, let's look at the last two in the table above.

#block[
#callout(
body: 
[
#strong[An implication.] Let total revenue be

$ R = p q\, $

where $p$ is unit price and $q$ is quantity sold. If the selling price rises while demand is unchanged, then revenue increases:

$ #scale(x: 120%, y: 120%)[\(] p_1 > p_0 med upright(" and ") med q_1 = q_0 #scale(x: 120%, y: 120%)[\)] arrow.r.double.long R_1 > R_0 . $

The arrow runs one way only. The opposite does not necessarily hold. That is, observing $R_1 > R_0$ does #emph[not] let you conclude the price went up.

]
, 
title: 
[
Example
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
#strong[An equivalence.] Let revenue and cost be

$ R = p q\,#h(2em) C\(q\)= C_f + C_v q\, $

with $C_f$ the fixed cost and $C_v$ the variable cost per unit. A company reaches its break-even point exactly when revenue equals total cost:

$ upright("break-even reached") arrow.l.r.double p q = C_f + C_v q . $

Here the arrow runs both ways: break-even implies the equation, and the equation implies break-even.

]
, 
title: 
[
Example
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
== Describing a set
<describing-a-set>
A set can be defined in three main ways.

#block[
#callout(
body: 
[
#strong[a) By enumeration] $ A = { 1\,2\,3\,4 } . $ The set $A$ contains exactly the elements 1, 2, 3 and 4.

#strong[b) By a property] (set-builder notation) \$\$B = \\{\\, x \\in \\R \\mid x \\geq 0 \\,\\}, \\qquad C = \\{\\, x \\in \\R \\mid a \\leq x \\leq b \\,\\}.\$\$ The vertical bar #text(fill: rgb("#128a3a"))[is] read "such that". $B$ is the set of non-negative real numbers; $C$ is the set of reals between $a$ and $b$ inclusive.

#strong[c) By an interval]

#emph[In words: name the members one by one, state the rule for membership, or --- if the members form an unbroken stretch of the number line --- give the two endpoints.]

]
, 
title: 
[
Definition: the three descriptions
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
Enumeration is only practical for small finite sets. Set-builder notation is essential because it makes it possible to define precisely #strike[the] which values a variable or a decision is allowed to take. It usually has the structure of first defining a general set of admissible values followed by one or more conditions.

\$\$\\underbrace{\\{\\, x \\in \\R}\_{\\text{where } x \\text{ lives}} \\ \\mid \\ \\underbrace{x \\geq 0}\_{\\text{the condition}} \\,\\}\$\$

Finally, intervals are defined by #text(fill: rgb("#128a3a"))[a] region with a starting point and #strike[and] #text(fill: rgb("#128a3a"))[an] end point. #strike[Every thing within this region is included.] #text(fill: rgb("#128a3a"))[Everything strictly between those two points is included.] The inclusion or exclusion of the endpoints is decided by the type of brackets. In the table below we show the different ways we write intervals. Notice that infinity always takes a round bracket because infinity is not a number and cannot be an element of anything.

#table(
  columns: (21.62%, 50%, 28.38%),
  align: (left,left,left,),
  table.header([Interval form], [Set-builder form], [Endpoints included?],),
  table.hline(),
  [$\[a\,b\]$], [\$\\{x \\in \\R \\mid a \\leq x \\leq b\\}\$], [both],
  [$\(a\,b\)$], [\$\\{x \\in \\R \\mid a \< x \< b\\}\$], [neither],
  [$\[a\,b\)$], [\$\\{x \\in \\R \\mid a \\leq x \< b\\}\$], [left only],
  [$\(a\,b\]$], [\$\\{x \\in \\R \\mid a \< x \\leq b\\}\$], [right only],
  [$\[a\,+ oo\)$], [\$\\{x \\in \\R \\mid x \\geq a\\}\$], [left only],
  [$\(- oo\,a\]$], [\$\\{x \\in \\R \\mid x \\leq a\\}\$], [right only],
)
Below, we show a representation of intervals on the real line.

#figure([
#box(image("chapters/../images/intervals-real-line.png", width: 90.0%))
], caption: figure.caption(
position: bottom, 
[
#text(fill: rgb("#128a3a"))[Intervals represented on the real line]
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-intervals>


#text(fill: rgb("#8a6d3b"))[#emph[Why: a Quarto figure needs a caption for its #NormalTok("#fig-"); label to resolve. With the caption empty, the #NormalTok("@fig-intervals"); reference in the next paragraph renders as #NormalTok("?fig-intervals"); instead of "Figure 1". Any caption text works; this restores the original.]]

In #ref(<fig-intervals>, supplement: [Figure]), $A =\[- 4\,- 2\]$, $B =\[0\,1\)$ and $C =\(2\,5\)$. The number $- 3$ is an #strong[interior point] of $A$ because it lies in $A$ with a little room on both sides, unlike the endpoints $- 4$ and $- 2$. Note that $B$ contains $0$ but not $1$, and that $C$ contains neither $2$ nor $5$.

== The standard number sets
<the-standard-number-sets>
#text(fill: rgb("#128a3a"))[We briefly mentioned the sets of real and natural numbers earlier. The table below presents the standard number sets used throughout the course.]

#text(fill: rgb("#8a6d3b"))[#emph[Why: this lead-in sat above the section heading, so it read as the closing line of the intervals section and the new section opened cold on a table. Moved below the heading.]]

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.header([Notation], [Name], [Example of use],),
  table.hline(),
  [\$\\N\$], [natural numbers], [$0\,1\,2\,3\,dots.h$\; number of customers, products, periods],
  [\$\\Z\$], [integers], [$dots.h\,- 2\,- 1\,0\,1\,2\,dots.h$\; integer changes up or down],
  [\$\\Q\$], [rational numbers], [fractions $p\/q$ with \$p, q \\in \\Z\$, $q eq.not 0$\; exact proportions],
  [\$\\R\$], [real numbers], [numbers on the real line; return, temperature, profit],
  [\$\\Rp\$], [non-negative reals], [$\[0\,+ oo\)$\; prices, costs, revenues, probabilities],
  [\$\\R^p\$], [real vectors of dimension $p$], [\$\\vect{x} = (x\_1, \\dots, x\_p)\$\; one observation on $p$ variables],
  [\$\\R^{n \\times p}\$], [real $n times p$ matrices], [a whole data set: $n$ observations, $p$ variables],
)
== Absolute value of a number
<absolute-value-of-a-number>
#block[
#callout(
body: 
[
The absolute value of a real number $a$, written \$\\abs{a}\$, is \$\$\\abs{a} = \\begin{cases} a, & \\text{if } a \\geq 0, \\\\ -a, & \\text{if } a \< 0. \\end{cases}\$\$

#emph[In words: remove the sign. The absolute value is how far the number is from zero, and distance is never negative.]

]
, 
title: 
[
Definition: absolute value
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
For example,

\$\$\\abs{13} = 13, \\qquad \\abs{-13} = -(-13) = 13, \\qquad \\left\\lvert -\\tfrac{1}{2} \\right\\rvert = \\tfrac{1}{2}, \\qquad \\abs{0} = 0.\$\$

=== Distance between two real numbers
<distance-between-two-real-numbers>
#block[
#callout(
body: 
[
Let $x_1$ and $x_2$ be real. The distance between them on the real line is \$\$d(x\_1, x\_2) = \\abs{x\_1 - x\_2}.\$\$ Distance is always non-negative, and it is zero exactly when the two numbers are equal: $ d\(x_1\,x_2\)gt.eq 0\,#h(2em) d\(x_1\,x_2\)= 0 arrow.l.r.double x_1 = x_2 . $ For $a > 0$, \$\$\\abs{x} \< a \\iff -a \< x \< a \\iff x \\in (-a, a), \\qquad \\abs{x} \\leq a \\iff x \\in \[-a, a\].\$\$

#emph[In words: "]$x$ is within $a$ of zero" #strike[or] #text(fill: rgb("#128a3a"))[and] "$x$ lies in the interval of width $2 a$ centred at zero" say the same thing.

#text(fill: rgb("#8a6d3b"))[#emph[Why: the italic span was closing at the first #NormalTok("$");, so most of the sentence lost its formatting --- the visual editor does this whenever emphasis meets inline maths. Also "or … say the same thing" should be "and": the claim is that both readings hold, not that either does.]]

]
, 
title: 
[
Key result: distance and tolerance
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
fa-exclamation()
, 
body_background_color: 
white
)
]
== Summation notation (sigma)
<summation-notation-sigma>
Summation notation is shorthand for addition.

#block[
#callout(
body: 
[
$ sum_(i = 1)^n a_i = a_1 + a_2 + dots.h.c + a_n . $

#text(fill: rgb("#128a3a"))[The letter $i$ is the #strong[index], the numbers below and above $sum$ are the #strong[limits], and $a_i$ is the #strong[summand]. The index is a placeholder: $sum_(j = 1)^n a_j$ denotes exactly the same number.]

]
, 
title: 
[
Definition: the summation symbol
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#text(fill: rgb("#8a6d3b"))[#emph[Why: "index" and "indices" are used later --- in the summation-rules callout and in the double-sums paragraph --- but with this sentence cut the words are never introduced.]]

Economists frequently use census data. Suppose a country is divided into six regions and $N_i$ denotes the population of region $i$. The country's total population is then

$ N_1 + N_2 + N_3 + N_4 + N_5 + N_6 = sum_(i = 1)^6 N_i . $

Here are more examples of summation

$ sum_(i = 1)^4 x_i = x_1 + x_2 + x_3 + x_4\,#h(2em) sum_(j = 2)^5\(2 j - 1\)= 3 + 5 + 7 + 9 = 24\,#h(2em) sum_(k = 1)^n c = underbrace(c + dots.h.c + c, n upright(" terms")) = n c . $

=== Example: price index
<example-price-index>
#block[
#callout(
body: 
[
Suppose the prices of several goods vary over time in an economy. Price indices are used to summarize the overall effect of these changes.

Consider a basket containing $n$ goods. For each good $i = 1\,dots.h\,n$ let

$  & q_i = upright("quantity of good ") i upright(" in the basket")\,\
 & p_i^0 = upright("unit price of good ") i upright(" in the base year ") 0\,\
 & p_i^t = upright("unit price of good ") i upright(" in year ") t . $

#text(fill: rgb("#8a6d3b"))[#emph[Why: #NormalTok("align"); cannot be nested inside #NormalTok("$$ ... $$"); --- LaTeX raises "erroneous nesting of equation structures" and the PDF build fails. MathJax tolerates it, so this looks fine in the HTML preview and breaks only on render to PDF. #NormalTok("aligned"); is the version that nests. Verified by compiling both.]]

#strong[Cost of the basket in the base year.] The total cost of the basket in year $0$ is the sum of the product of quantities times their prices in year $0$:

$ p_1^0 q_1 + p_2^0 q_2 + dots.h.c + p_n^0 q_n = sum_(i = 1)^n p_i^0 q_i . $

#strong[Cost of the same basket in year] $t$. We do the same but we replace the prices at year $0$ with the prices at year $t$:

$ sum_(i = 1)^n p_i^t q_i . $

#strong[The price index.] The price index for the base year is set equal to 100, so the price index for year $t$ is

$ I_t = frac(sum_(i = 1)^n p_i^t q_i, sum_(i = 1)^n p_i^0 q_i) times 100 . $

#strong[Interpretation.]

- If $I_t = 100$, the cost of the basket has not changed.
- If $I_t > 100$, it has increased.
- If $I_t < 100$, it has decreased.
- If $I_t = 150$, the basket costs 150% of its base-year cost. In other words, prices have risen by $150 - 100 = 50 %$.

]
, 
title: 
[
Example
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
=== Summation rules
<summation-rules>
The following properties are useful when manipulating sums. #strike[They are called linearity.] #text(fill: rgb("#128a3a"))[Together they are called #strong[linearity].]

#block[
#callout(
body: 
[
For any numbers $a_i\,b_i$ and any constant $c$ (a value not depending on the index):

$ bold("Additivity:") quad sum_(i = 1)^n\(a_i + b_i\)= sum_(i = 1)^n a_i + sum_(i = 1)^n b_i $

$ bold("Homogeneity:") quad sum_(i = 1)^n c thin a_i = c sum_(i = 1)^n a_i $

#text(fill: rgb("#128a3a"))[$ bold("Constant:") quad sum_(i = 1)^n c = n c $]

]
, 
title: 
[
Key result: algebra of sums
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
fa-exclamation()
, 
body_background_color: 
white
)
]
#text(fill: rgb("#8a6d3b"))[#emph[Why: the constant rule is used twice in what follows --- in the example] $sum_(k = 1)^n c = n c$ just above, and as the essential step in the derivation of \$\\sum(x\_i - \\xbar) = 0\$ that you now set as an exercise. A student cannot do that exercise from the two rules currently listed.]

It is important to note that there is no product rule #text(fill: rgb("#128a3a"))[and no rule for squares]. That is,

$ sum a_i b_i eq.not (sum a_i) (sum b_i)\,#h(2em) sum a_i^2 eq.not (sum a_i)^2 . $

#text(fill: rgb("#128a3a"))[A two-term counterexample settles it: with $a =\(1\,2\)$, $sum a_i^2 = 1 + 4 = 5$ while $(sum a_i)^2 = 3^2 = 9$.]

#text(fill: rgb("#8a6d3b"))[#emph[Why: the delimiters here were #NormalTok("\\$$ ... $\\$");, which renders as literal text rather than mathematics --- the display would have appeared as raw LaTeX on the page. Fixed to #NormalTok("$$ ... $$");. The counterexample is optional; the second inequality is about squares rather than products, so the sentence now names both.]]

=== Example: arithmetic mean and deviations from the mean
<example-arithmetic-mean-and-deviations-from-the-mean>
#block[
#callout(
body: 
[
The arithmetic mean of $n$ numbers $x_1\,x_2\,dots.h\,x_n$ is their sum divided by $n$: \$\$\\xbar = \\frac{1}{n}\\sum\_{i=1}^{n} x\_i.\$\$

]
, 
title: 
[
Definition: arithmetic mean
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
Multiplying through by $n$ gives a form we use constantly in derivations:

\$\$\\sum\_{i=1}^{n} x\_i = n\\xbar,\$\$

and as a result we have (show the derivation as an exercise)

\$\$\\sum\_{i=1}^{n}(x\_i - \\xbar) = 0.\$\$

The quantity \$x\_i - \\xbar\$ is the deviation of observation $i$ from the mean. #text(fill: rgb("#128a3a"))[Because the deviations always total zero, they are useless on their own as a measure of spread.] To measure the spread of the observations, we square these #strike[deviation] #text(fill: rgb("#128a3a"))[deviations]. In particular#text(fill: rgb("#128a3a"))[,] we have that (show the derivation as an exercise)

#text(fill: rgb("#8a6d3b"))[#emph[Why: as written, "to measure spread we square the deviations" is a non-sequitur --- the reader has just been told the deviations sum to zero but not that this is why squaring is necessary. One clause restores the logic.]]

\$\$\\sum\_{i=1}^{n}(x\_i - \\xbar)^2 = \\sum\_{i=1}^{n} x\_i^2 - n\\xbar^{\\,2}.\$\$

=== Double sums
<double-sums>
It is often necessary to combine two or more summation symbols. For example, when data are arranged in a grid (matrix), two indices are needed: $a_(i j)$ for row $i$, column $j$. Consider a matrix with $m$ rows and $n$ columns, and let $S_i$ be the total of row $i$:

$ a_11 & a_12 & dots.h.c & a_(1 n) & arrow.r med sum_(j = 1)^n a_(1 j) = S_1\
a_21 & a_22 & dots.h.c & a_(2 n) & arrow.r med sum_(j = 1)^n a_(2 j) = S_2\
dots.v & dots.v &  & dots.v & \
a_(m 1) & a_(m 2) & dots.h.c & a_(m n) & arrow.r med sum_(j = 1)^n a_(m j) = S_m $

Adding the row totals gives the grand total, and the same grand total is reached by adding column totals instead:

$ S_1 + S_2 + dots.h.c + S_m = sum_(i = 1)^m S_i = sum_(i = 1)^m sum_(j = 1)^n a_(i j) = sum_(j = 1)^n sum_(i = 1)^m a_(i j) . $

== Subsets, cardinality, and set operations
<subsets-cardinality-and-set-operations>
#block[
#callout(
body: 
[
A set $A$ is a #strong[subset] of $B$ if every element of $A$ also belongs to $B$: $ A subset.eq B arrow.l.r.double forall x\,med x in A arrow.r.double x in B . $

]
, 
title: 
[
Definition: subset
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
Some of the standard sets we defined earlier #strike[are subsets of each other] #text(fill: rgb("#128a3a"))[are nested inside one another]. For example#text(fill: rgb("#128a3a"))[,] we have \$\\N \\subset \\Z \\subset \\Q \\subset \\R\$.

#text(fill: rgb("#8a6d3b"))[#emph[Why: "subsets of each other" describes a mutual relation, and two sets that are each a subset of the other are equal. The chain is one-directional.]] This means that every integer is rational (write $- 3$ as $- 3\/1$) and every rational is real. The reverse fails, for example, $sqrt(2)$ and $pi$ are real but not rational. \ Note: The symbol $A subset.eq B$ indicates that $A$ is either a subset of $B$ or exactly equal to $B$, while $A subset B$ indicates that $A$ is strictly a subset of $B$. That is, #strike[\$\\exists x \\in B\$\$ such that] $x in.not A$ #text(fill: rgb("#128a3a"))[$A subset.eq B$ and there is at least one $x in B$ with $x in.not A$]. Think of it as the difference between $lt.eq$ and $<$ #strike[in scalars] #text(fill: rgb("#128a3a"))[for numbers].

#text(fill: rgb("#8a6d3b"))[\*Why: two problems. The math was mangled (#NormalTok("\\$\\\\exists x \\\\in B\\$\\$");) and would not render. And the condition as stated was incomplete --- "there exists\* $x in B$ not in $A$" alone does not make $A$ a strict subset; $A$ must still be contained in $B$. Both halves are needed.]

Two further terms:

- The #strong[universal set] $U$ is the reference set within which we are working.
- The #strong[cardinality] of a finite set $A$, written \$\\card{A}\$, is its number of elements.

So \$\\card{\\{1,2,3,4\\}} = 4\$, and \$\\card{\\varnothing} = 0\$ where $diameter$ is the #strong[empty set].

Let $A$ and $B$ be two subsets of a universal set $U$.

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (left,left,left,left,),
  table.header([Operation], [Notation], [Definition], [Management interpretation],),
  table.hline(),
  [Union], [$A union B$], [${ x in U divides x in A upright(" or ") x in B }$], [customers in at least one of the two segments],
  [Intersection], [$A inter B$], [${ x in U divides x in A upright(" and ") x in B }$], [customers in both segments simultaneously],
  [Difference], [$A - B = A inter B^c$], [${ x in U divides x in A upright(" and ") x in.not B }$], [customers in $A$ but not in $B$],
  [Complement], [$A^c = U - A$], [${ x in U divides x in.not A }$], [customers in the universe who are not in $A$],
)
=== Cartesian product and multidimensional observations
<cartesian-product-and-multidimensional-observations>
#block[
#callout(
body: 
[
The Cartesian product of two sets $A$ and $B$ is the set of ordered pairs whose first component belongs to $A$ and whose second belongs to $B$: $ A times B = {\(a\,b\)divides a in A\,med b in B } . $

]
, 
title: 
[
Definition: Cartesian product
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
In a data set, an individual is usually described by several variables at once, and is therefore represented by a vector:

\$\$\\vect{x}\_i = \\left(x\_{i1}, x\_{i2}, \\dots, x\_{ip}\\right) \\in \\R^p,\$\$

where $p$ is the number of variables measured for individual $i$.

#block[
#callout(
body: 
[
A Netflix user may be represented by a vector containing age, the number of hours watched per week, a preferred movie genre encoded numerically, the number of series abandoned before completion, and the user's average rating of content. This five-dimensional vector, with $p = 5$ variables, lets a recommendation algorithm compare the user with others who have similar profiles.

]
, 
title: 
[
Example
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
=== Partition of a universal set
<partition-of-a-universal-set>
#block[
#callout(
body: 
[
Let $X_1\,X_2\,dots.h\,X_k$ be non-empty subsets of $U$. The family ${ X_i }_(i in { 1\,2\,dots.h\,k })$ forms a #strong[partition] of $U$ if

$ union.big_(i = 1)^k X_i = U\, $ and $ #h(2em) X_i inter X_j = diameter med upright(" for every ") i eq.not j\, $

where

$ union.big_(i = 1)^k X_i = X_1 union X_2 union X_3 union dots.h.c union X_k . $

#emph[That is, the subsets split] $U$ into pieces with no gaps or overlaps#text(fill: rgb("#128a3a"))[,] and every element in $U$ #strike[belong] #text(fill: rgb("#128a3a"))[belongs] to exactly one piece.

]
, 
title: 
[
Definition: partition
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#figure([
#box(image("chapters/../images/partition-universe.png", width: 65.0%))
], caption: figure.caption(
position: bottom, 
[
Partition of a universal set into six non-empty subsets
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-partition>


= Essential algebra for working with models
<essential-algebra-for-working-with-models>
Algebra allows us to simplify an expression, isolate a variable, solve an equation, linearize a relationship, or prepare an optimization problem.

== Algebraic expressions
<algebraic-expressions>
An algebraic expression combines numbers, variables and operations. The basic manipulations are as follows#text(fill: rgb("#128a3a"))[:]

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (left,left,left,),
  table.header([Operation], [Formula], [Purpose],),
  table.hline(),
  [Combine like terms], [$2 x + 3 x = 5 x$], [group like terms],
  [Expand], [$a\(b + c\)= a b + a c$], [remove parentheses],
  [Factor], [$a b + a c = a\(b + c\)$], [factor out a common factor],
  [Square of a sum], [$\(a + b\)^2= a^2 + 2 a b + b^2$], [simplify quadratic functions],
  [Difference of squares], [$a^2 - b^2 =\(a - b\)\(a + b\)$], [solve or factor expressions],
)
== Polynomials and quadratic equations
<polynomials-and-quadratic-equations>
A polynomial of degree $n$ is an expression of the form

$ P\(x\)= a_n x^n + a_(n - 1) x^(n - 1) + dots.h.c + a_1 x + a_0\,#h(2em) a_n eq.not 0 . $

The condition $a_n eq.not 0$ is what makes the degree well defined --- it is the highest power that actually appears.

#strong[Examples.]

- $P\(x\)= 3 x + 1$: a polynomial of degree 1.
- $P\(x\)= 2 x^2 - 3 x + 1$: a polynomial of degree 2.
- $Q\(x\)= 5 x^3 + x - 7$: a polynomial of degree 3. #text(fill: rgb("#128a3a"))[Note that the $x^2$ term is simply absent, which is allowed --- only the #emph[leading] coefficient must be non-zero.]

=== Roots of a first-degree polynomial
<roots-of-a-first-degree-polynomial>
A linear equation in one unknown is written as

$ a x + b = 0\,#h(2em) a eq.not 0\, $

with the single solution

$ x = - b / a = - a^(- 1) b . $

#text(fill: rgb("#128a3a"))[The condition $a eq.not 0$ is what makes this a single solution. If $a = 0$ the equation reads $b = 0$, which is either true for every $x$ (when $b = 0$) or for no $x$ at all (when $b eq.not 0$). Dividing by $a$ without first checking it is non-zero is the standard way to lose a case.]

#text(fill: rgb("#8a6d3b"))[#emph[Why: the condition] $a eq.not 0$ is stated in the formula but never explained, and "why is that there?" is exactly the question this audience will have. Optional --- reject if you prefer to keep the section lean.]

=== Roots of a quadratic polynomial
<roots-of-a-quadratic-polynomial>
A quadratic equation is written $ a x^2 + b x + c = 0\,#h(2em) a eq.not 0\, $ and its #text(fill: rgb("#128a3a"))[\*\*]discriminant#text(fill: rgb("#128a3a"))[\*\*] is $ Delta = b^2 - 4 a c . $

- If $Delta > 0$, there are two distinct real roots: $ x_1 = frac(- b - sqrt(Delta), 2 a)\,#h(2em) x_2 = frac(- b + sqrt(Delta), 2 a) . $

- If $Delta = 0$, there is one repeated real root: $ x = - frac(b, 2 a) . $

- If $Delta < 0$, there is no real root.

#emph[That is, the discriminant tells us whether we have #strike[one, two, or no solutions]#text(fill: rgb("#128a3a"))[two, one, or no #strong[real] solutions].]

#text(fill: rgb("#8a6d3b"))[#emph[Why: two small things. The list order now matches the three cases above it, and "no solutions" should be "no real solutions" --- when] $Delta < 0$ the roots exist, they are just not real. Worth the extra word so nothing has to be unlearned later.]

== Exponents and logarithms
<exponents-and-logarithms>
For $a\,b > 0$ and compatible exponents, the basic rules are

$ a^m a^n = a^(m + n)\,#h(2em) a^m / a^n = a^(m - n)\,#h(2em)\(a^m\)^n= a^(m n)\, $

$ \(a b\)^n= a^n b^n\,#h(2em) a^(- n) = 1 / a^n\,#h(2em) a^0 = 1 . $

For equations with the same positive base $a eq.not 1$,

$ a^f = a^g arrow.l.r.double f = g\,#h(2em) upright("and in particular") #h(2em) e^f = e^g arrow.l.r.double f = g . $

#block[
#callout(
body: 
[
$a^m a^n = a^(m + n)$, #strong[not] $a^(m n)$.

]
, 
title: 
[
Common pitfall
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
The logarithm to base $a > 0$, with $a eq.not 1$, is defined by $ log_a\(x\)= y arrow.l.r.double a^y = x . $ The #strong[natural logarithm] is written $ln$ and corresponds to base $e$: $ ln\(x\)= y arrow.l.r.double e^y = x . $

\*That is, a logarithm answers "what power do I raise the base to, in order to get\* $x$?"

#text(fill: rgb("#8a6d3b"))[#emph[Why: the italic span was closing at the first #NormalTok("$"); again --- same visual-editor behaviour as in the previous sections.]]

Useful rules #strike[includes] #text(fill: rgb("#128a3a"))[include]

$ ln\(x y\)= ln x + ln y\,#h(2em) ln #h(-1em) (x / y) = ln x - ln y\,#h(2em) ln\(x^r\)= r ln x\, $

$ ln\(e\)= 1\,#h(2em) ln\(1\)= 0\,#h(2em) ln\(e^x\)= x\,#h(2em) e^(ln x) = x med med\(x > 0\). $

And for equations,

$ log_a\(f\)= log_a\(g\)arrow.l.r.double f = g\,#h(2em) upright("in particular") #h(2em) ln\(f\)= ln\(g\)arrow.l.r.double f = g . $

#block[
#callout(
body: 
[
The notation "$log$" can sometimes be ambiguous. In R and most mathematical writing, #NormalTok("log(x)"); is the natural logarithm#strike[\;]#text(fill: rgb("#128a3a"))[.] However, in calculators, #NormalTok("LOG"); means base 10. These notes always write $ln$ for the natural log and always show the base otherwise. Moreover, there is no rule for the logarithm of a sum: $ ln\(x + y\)eq.not ln x + ln y . $

]
, 
title: 
[
Common pitfall
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
=== Applied example: exponential growth and decay
<applied-example-exponential-growth-and-decay>
#block[
#callout(
body: 
[
An initial quantity $Q_0$ that #strong[increases] by $p %$ each year has, after $t$ years, the value $ Q_0 (1 + p / 100)^t . $ An initial quantity $Q_0$ that #strong[decreases] by $p %$ each year has, after $t$ years, the value $ Q_0 (1 - p / 100)^t . $ The number $1 + p\/100$ is the #strong[growth factor] associated with an increase of $p %$\; the number $1 - p\/100$ is the #strong[decay factor] associated with a decrease of $p %$. Here $Q_0$ is the initial value, $p$ the annual rate as a percentage, and $t$ the number of years.

]
, 
title: 
[
Key result: growth and decay factors
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
fa-exclamation()
, 
body_background_color: 
white
)
]
The factor is #emph[multiplied] repeatedly rather than added because each year's change applies to the new total (compounded), not to the original.

#block[
#callout(
body: 
[
A new car was purchased for \$30,000. Assume its value decreases by 15% per year. What will its value be after six years?

The rate is a decrease, so the decay factor is

$ 1 - 15 / 100 = 0.85 . $

After six years the value is

$ 30000 times\(0.85\)^6= 30000 times 0.377150 approx\$11\,314.49 . $

]
, 
title: 
[
Example
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
A sum of \$5,000 deposited in an account grew to \$10,000 after 15 years. What constant annual interest rate $p$ was applied?

Set up the growth equation with the rate unknown:

\$\$5000\\left(1 + \\frac{p}{100}\\right)^{15} = 10000\~\~.\~\~\[,\]{style=\"color:\#128a3a\"}\$\$

#strike[or] #text(fill: rgb("#128a3a"))[Or] equivalently, #text(fill: rgb("#128a3a"))[dividing both sides by $5000$ --- note that the initial deposit cancels, so the answer does not depend on how much you started with:]

\$\$\\left(1 + \\frac{p}{100}\\right)^{15} = 2\~\~,\~\~\[.\]{style=\"color:\#128a3a\"}\$\$

#strike[and we solve for] $p$. The final solution for $p$ is $p approx 4.73 %$.

#text(fill: rgb("#128a3a"))[The unknown sits inside a power, so take natural logarithms of both sides and use $ln\(x^r\)= r ln x$ to bring the exponent down:]

#text(fill: rgb("#128a3a"))[$ 15 thin ln #h(-1em) (1 + p / 100) = ln 2 #h(2em) arrow.r.double #h(2em) ln #h(-1em) (1 + p / 100) = frac(ln 2, 15) approx 0.046210 . $]

#text(fill: rgb("#128a3a"))[Exponentiating both sides undoes the logarithm:]

#text(fill: rgb("#128a3a"))[$ 1 + p / 100 = e^0.046210 approx 1.047294 #h(2em) arrow.r.double #h(2em) p approx 4.73 % . $]

#text(fill: rgb("#128a3a"))[#strong[Check.] $5000 times\(1.047294\)^15approx\$10\,000$.]

#text(fill: rgb("#8a6d3b"))[\*Why: this is the only worked example in the logarithm section, and as written it stopped at "and we solve for\* $p$" --- so it demonstrated none of the log rules that had just been introduced. The rule $ln\(x^r\)= r ln x$ has no other application in the chapter. Trim the steps if it feels long, but the section needs at least one place where a logarithm is actually used to extract an unknown.]

]
, 
title: 
[
Example
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]

#horizontalrule

#heading(level: 1, numbering: none)[recap #text(fill: rgb("#128a3a"))[One-minute recap]]
<recap-one-minute-recap>
#block[
#callout(
body: 
[
- #strong[Variable or parameter?] Ask whether you know the number before you start solving. Known in advance $arrow.r.double$ parameter. The same symbol can switch roles when the question changes. #strike[\- #strong[When a resource is scarce, rank options by return per unit of that resource], not per unit of output. Product] $A$ wins on profit per unit and loses on profit per labor hour.
- #text(fill: rgb("#128a3a"))[#strong[A model has five parts:] decision variables, parameters, an objective, constraints, and assumptions. Naming all five is the skill; solving comes later.]
- #strong[Set-builder notation needs a universe.] \$\\{x \\in \\R \\mid x \\geq 0\\}\$, not ${ x divides x gt.eq 0 }$.
- #strong[Brackets:] square includes the endpoint, round excludes it. Infinity always gets round.
- \$\\abs{\~\~u - v\~\~}\$ #text(fill: rgb("#128a3a"))[\$\\abs{x}\$] $lt.eq$ $c$ #text(fill: rgb("#128a3a"))[$a$] #strong[is] the interval $\[v - c\,med v + c\]$ #text(fill: rgb("#128a3a"))[$\[- a\,med a\]$]. Every tolerance statement is an interval statement. #strike[\-] \$\\card{A \\cup B} = \\card{A} + \\card{B} - \\card{A \\cap B}\$ --- subtract the overlap or you double-count.
- #text(fill: rgb("#128a3a"))[#strong[Union means "at least one", intersection means "both".] The mathematical "or" always includes the case where both hold.]
- #strong[A partition means exactly one.] #strike[Use half-open bands] $\[a\,b\)$ so boundary values land in one bin only. #text(fill: rgb("#128a3a"))[No gaps and no overlaps: every element of $U$ lands in one piece and only one.]
- $sum$ #strong[is linear and nothing more:] it splits over $+$ and lets constants out. There is no product rule.
- \$\\sum(x\_i - \\xbar) = 0\$ always. Use it as an arithmetic check on any mean you compute.
- #strong[An index of 150 is a 50% increase], not a 150% one.
- #text(fill: rgb("#128a3a"))[#strong[Growth compounds.] Losing 15% a year for six years is $times\(0.85\)^6$, not $times\(1 - 6 times 0.15\)$.]
- #text(fill: rgb("#128a3a"))[#strong[Logs bring an exponent down], via $ln\(x^r\)= r ln x$. That is how you solve for an unknown stuck in a power. But $ln\(x + y\)$ does not simplify.]
- #text(fill: rgb("#128a3a"))[#strong[In this course:] \$0 \\in \\N\$\; $n$ = observations, $p$ = variables; vectors are #strong[bold]\; $ln$ is the natural log.]

#text(fill: rgb("#8a6d3b"))[#emph[Why: the recap listed four things the chapter no longer contains --- inclusion--exclusion, the shifted tolerance form] \$\\abs{u-v}\\le c\$, the half-open banding advice, and the solved production model. Those bullets are replaced above with claims the chapter does support. The three added here cover the growth, logarithm, and convention material that had no recap line at all.] - #strong[Logs turn powers into products and products into sums] --- that is how you get an unknown out of an exponent. But $ln\(x + y\)$ does not simplify. - #strong[Growth compounds.] Losing 15% a year for six years is $times\(0.85\)^6$, not $times\(1 - 6 times 0.15\)$. - #strong[In this course:] \$0 \\in \\N\$\; $n$ = observations, $p$ = variables; vectors are bold; $ln$ is the natural log.

]
, 
title: 
[
If you remember nothing else
]
, 
background_color: 
rgb("#ffe5d0")
, 
icon_color: 
rgb("#FC5300")
, 
icon: 
fa-fire()
, 
body_background_color: 
white
)
]



