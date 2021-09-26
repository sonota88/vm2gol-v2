```
$ LANG=C wc -l vg*.rb
   66 vgasm.rb
  381 vgcodegen.rb
   58 vglexer.rb
  377 vgparser.rb
  447 vgvm.rb
 1329 total
```

Rubyで素朴な自作言語のコンパイラを作った - memo88  
https://memo88.hatenablog.com/entry/2020/05/04/155425

vm2gol v2 製作メモ - memo88  
https://memo88.hatenablog.com/entry/2019/05/04/234516


```
# Run tests / テストの実行
rake test

# Run game of life / ライフゲームの実行
./run.sh gol.vg.txt
```


# Porting

These are ports of the compiler part only, with some exceptions.

- [Haskell](https://github.com/sonota88/vm2gol-v2-haskell)
- [OCaml](https://github.com/sonota88/vm2gol-v2-ocaml)
- [Pascal](https://github.com/sonota88/vm2gol-v2-pascal)
- [Julia](https://github.com/sonota88/vm2gol-v2-julia)
- [Rust](https://github.com/sonota88/vm2gol-v2-rust)
- [Crystal](https://github.com/sonota88/vm2gol-v2-crystal)
- [Pric (self-hosting)](https://github.com/sonota88/pric)
- [Kotlin](https://github.com/sonota88/vm2gol-v2-kotlin)
- [Zig](https://github.com/sonota88/vm2gol-v2-zig)
- [LibreOffice Basic](https://github.com/sonota88/vm2gol-v2-libreoffice-basic)
- [Go](https://github.com/sonota88/vm2gol-v2-go)
- [PHP](https://github.com/sonota88/vm2gol-v2-php)
- [C♭](https://github.com/sonota88/vm2gol-v2-cflat)
- [Perl](https://github.com/sonota88/vm2gol-v2-perl)
- [C](https://github.com/sonota88/vm2gol-v2-c)
- [Java](https://github.com/sonota88/vm2gol-v2-java)
- [Dart](https://github.com/sonota88/vm2gol-v2-dart)
- [Python](https://github.com/sonota88/vm2gol-v2-python)
- [TypeScript (Deno)](https://github.com/sonota88/vm2gol-v2-typescript)
