```
$ LANG=C wc -l vg*.rb common.rb
   66 vgasm.rb
  375 vgcodegen.rb
   58 vglexer.rb
  370 vgparser.rb
  447 vgvm.rb
   52 common.rb
 1368 total
```

![image](https://raw.githubusercontent.com/sonota88/vm2gol-v2/images/images/run_gol_step62.gif)

![image](https://raw.githubusercontent.com/sonota88/vm2gol-v2/images/images/run_gol_step62_step.gif)


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


# Ports

These are ports of the compiler part only, with some exceptions.

- [Tcl](https://github.com/sonota88/vm2gol-v2-tcl)
- [Shell Script (Bash Script)](https://github.com/sonota88/vm2gol-v2-bash)
- [なでしこ3](https://github.com/sonota88/vm2gol-v2-nadesiko3)
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
