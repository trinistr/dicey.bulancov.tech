# Dicey on the Web

## What's this?

This is an online version of [Dicey](https://github.com/trinistr/dicey): a dice distribution calculator and roller.

See it in action at [dicey.bulancov.tech](https://dicey.bulancov.tech)!

It has these amazing, never-before-seen features:
- support for custom dice: any numbers will do!
- support for textual dice: who needs numbers when you can use words?
- fast<sup>1</sup> calculation of probabilities for *each* possible roll
- meaningful addition of text and numbers
- works well in major browsers, with desktop and mobile layouts and light/dark themes
- can be used offline or installed as a web app
- will probably hang your browser tab

<sup>1</sup> fastness not guaranteed, depends on number of distinct rolls

## How's it work?

There are several components to this app:
- a [Ruby interpreter WASM module](https://github.com/ruby/ruby.wasm) that allows running Ruby code in the browser
- [Dicey](https://github.com/trinistr/dicey), the underlying Ruby gem that does the calculations
- [VectorNumber](https://github.com/trinistr/vector_number), another Ruby gem that handles mathematical operations on mixed text and numbers
- a [gluing script](/public/main.rb) (in Ruby again) that handles UI
- and a [service worker](/public/worker.js) to infest your computer with all of the above

There are also my awesome CSS, HTML and SVG skills that created the UI.

### What's the custom dice syntax?

Informally, following forms are allowed:
- `N` — a regular die with *N* faces
- `N..M` — a die with faces from *N* to *M*
  - Accepts negative integers
- `A,B,C,D` — a die with faces *A*, *B*, *C*, *D*
  - Accepts fractions in decimal-dotted and vulgar forms: `1.5`, `3/2`
  - Accepts arbitrary text
- Any form above can be prefixed with `Nd` to add *N* dice

## Why's this?

I was very dissatisfied with dice calculators I could find as they were just glorified combinatorics calculators with unneeded explanations and convoluted UIs. Maybe there are actually good ones? I dunno, I could only find teaching aids and "roll around and find out" thingies.

So I created Dicey as a personal project to actually get useful data all at once: a full table with all results, and no unneeded garbage. And then it kept expanding. At one point I decided to create VectorNumber, as more esoteric dice can have non-numeric faces, and we need to be able to meaningfully add everything together (though integrating it took a long while, whew!).

I was talking to a friend one day about this project and the possibility of spreading it other people, and they said "If your program is hard for users to access or install, it's shit." I was understandably miffed, but they were right: a CLI app written in Ruby is not exactly user-friendly. Most people dealing with dice probably wouldn't even understand how to download it!

At some point I learned about the WebAssembly Ruby port and a lightbulb went off in my head: why not just run the actual Dicey code in the browser? And off I went ~~to see the wizard~~ to create this online version.
