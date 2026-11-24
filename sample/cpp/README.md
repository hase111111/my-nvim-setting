# C++ Sample: Brainfuck Interpreter

NeovimのC++開発環境を確認するための、C++20製Brainfuckインタプリタです。

## 確認できる機能

- clangdによる補完、診断、定義ジャンプ、参照検索
- CMakeが生成する`compile_commands.json`の認識
- GCCによるC++20コードのコンパイル
- 標準ライブラリ、クラス、例外、コンテナの解析

## ビルド

```powershell
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
```

`CMAKE_EXPORT_COMPILE_COMMANDS`は`CMakeLists.txt`で有効にしているため、`build/compile_commands.json`が生成されます。

## 実行

```powershell
.\build\brainfuck.exe .\examples\hello.bf
```

インラインコードも実行できます。

```powershell
.\build\brainfuck.exe --code "++++++++[>++++++++<-]>+."
```

## Neovimでの確認

```powershell
nvim .\src\main.cpp
```

Neovim内で`:LspInfo`を実行し、clangdが接続されていることを確認してください。
