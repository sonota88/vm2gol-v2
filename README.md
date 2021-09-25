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
