# Windows Neovim C++環境構築ガイド

この文書は、Windowsネイティブ環境でNeovimを導入し、GCC、clangd、CMake、Ninjaを使ってC++を開発するまでの手順をまとめたものです。

## 1. 構成

この環境では、各ツールを次の用途に使います。

| ツール | 用途 |
|---|---|
| Neovim | エディタ |
| GCC / G++ | C/C++のコンパイル |
| CMake | ビルド設定の生成 |
| Ninja | 実際のビルド実行 |
| clangd | 補完、診断、定義ジャンプ、参照検索 |
| Tree-sitter | 構文解析とハイライト |
| ripgrep | Telescopeによるファイル内容検索 |
| lazy.nvim | Neovimプラグイン管理 |
| Mason | clangdの管理 |

コンパイラにはGCCを使用します。clangdはエディタ上の解析にのみ使用し、実際のビルドにはG++を使います。

## 2. Neovimと補助ツールの導入

PowerShellで`Windows`ディレクトリへ移動します。

```powershell
cd C:\Users\taisei\Desktop\main\program\my-nvim-setting\Windows
```

Neovim、ripgrep、7-Zipを導入します。

```powershell
.\manage-nvim.bat install
```

Neovimを導入済みで、補助ツールだけ追加する場合は次を使います。

```powershell
.\manage-nvim.bat install-tools
```

`install-tools`はTree-sitter CLIも導入します。公式リリースをダウンロードし、SHA-256を検証して次へ配置します。

```text
%LOCALAPPDATA%\Programs\tree-sitter-cli
```

インストール後はターミナルを開き直します。

## 3. Neovim設定の配置

通常の配置では、既存設定を日時付きディレクトリへバックアップしてから置き換えます。

```powershell
.\manage-nvim.bat setup
```

バックアップ先は次の場所です。

```text
%LOCALAPPDATA%\nvim-backups\nvim-YYYYMMDD-HHMMSS
```

既存設定をバックアップせず、完全に置き換える場合は`--force`を指定します。

```powershell
.\manage-nvim.bat setup --force
```

配置先は次の場所です。

```text
%LOCALAPPDATA%\nvim
```

## 4. プラグインとclangdの導入

設定を配置してから、プラグインとclangdを同期します。

```powershell
.\manage-nvim.bat update
```

主に次のプラグインを導入します。

- `tokyonight.nvim`
- `which-key.nvim`
- `telescope.nvim`
- `nvim-treesitter`
- `mason.nvim`
- `nvim-lspconfig`
- `blink.cmp`

更新後の`lazy-lock.json`はリポジトリの`Windows/nvim`へ戻され、Gitで管理されます。

## 5. 状態確認

管理スクリプトから状態を確認します。

```powershell
.\manage-nvim.bat check
```

次の項目が見つかることを確認します。

```text
Command : ...\nvim.exe
Git     : git version ...
Ripgrep : ripgrep ...
G++     : ...\g++.exe
Clangd  : ...\mason\bin\clangd.cmd
TS CLI  : ...\tree-sitter.exe
```

Neovim内では次を使用できます。

```vim
:Lazy
:LspInfo
:checkhealth mason
:checkhealth nvim-treesitter
```

導入済みのTree-sitterパーサーはLua APIから確認できます。

```vim
:lua print(vim.inspect(require("nvim-treesitter").get_installed("parsers")))
```

`c`と`cpp`が含まれていれば、C/C++パーサーは導入されています。`:TSStatus`はプラグインのコミットによって未実装の場合があるため、`E471`または`E492`になる場合は上記の方法を使います。

## 6. CMakeとNinjaの導入

GCCだけではCMakeプロジェクトを構成できないため、CMakeとNinjaを追加します。

```powershell
winget install --id Kitware.CMake --exact --source winget
winget install --id Ninja-build.Ninja --exact --source winget
```

ターミナルを開き直して確認します。

```powershell
cmake --version
ninja --version
gcc --version
g++ --version
```

## 7. C++サンプルのビルド

サンプルにはC++20製のBrainfuckインタプリタがあります。

```powershell
cd C:\Users\taisei\Desktop\main\program\my-nvim-setting\sample\cpp
```

GCCとNinjaを明示して構成します。

```powershell
cmake -S . -B build -G Ninja `
  -DCMAKE_BUILD_TYPE=Debug `
  -DCMAKE_CXX_COMPILER=g++
```

ビルドして実行します。

```powershell
cmake --build build
.\build\brainfuck.exe .\examples\hello.bf
```

成功すると次のように表示されます。

```text
Hello World!
```

## 8. compile_commands.json

`CMakeLists.txt`で`CMAKE_EXPORT_COMPILE_COMMANDS`を有効にしているため、CMakeの構成後に次のファイルが生成されます。

```text
sample\cpp\build\compile_commands.json
```

clangdはこのファイルから次の情報を取得します。

- C++規格（このサンプルではC++20）
- 使用するG++
- インクルードパス
- プリプロセッサ定義
- コンパイルオプション

このファイルがない場合、clangdはフォールバック設定で解析するため、`std::string_view`や`starts_with`などを未定義と誤判定することがあります。

CMakeを実行した後、サンプルをNeovimで開きます。

```powershell
nvim .\src\main.cpp
```

## 9. C++で使用するキーマップ

| キー | 機能 |
|---|---|
| `Ctrl+Space` | 補完候補を表示 |
| `Ctrl+y` | 補完候補を確定 |
| `gd` | 定義へ移動 |
| `gD` | 宣言へ移動 |
| `gr` | 参照箇所を表示 |
| `K` | 型やドキュメントを表示 |
| `<Space>rn` | シンボル名を変更 |
| `<Space>ca` | コードアクション |
| `<Space>d` | 現在位置の診断を表示 |
| `[d` / `]d` | 前後の診断へ移動 |

## 10. トラブルシューティング

### インストール直後にコマンドが見つからない

wingetや管理スクリプトがPATHを更新しても、起動中のターミナルには反映されません。Windows TerminalまたはPowerShellを完全に閉じて開き直します。

```powershell
where.exe nvim
where.exe rg
where.exe cmake
where.exe ninja
where.exe g++
```

### clangdが標準ライブラリを認識しない

まずG++がPATH上にあることを確認します。

```powershell
where.exe g++
```

設定は検出した`gcc.exe`と`g++.exe`をclangdの`--query-driver`へ渡します。プロジェクト側では`build/compile_commands.json`も生成してください。

### Tree-sitter CLIが見つからない

```powershell
.\manage-nvim.bat install-tools
tree-sitter --version
```

MasonのWindows用`tree-sitter-cli`でリンクエラーが発生したため、この構成ではMason経由でTree-sitter CLIを導入しません。

### Nortonがparser.soを検出する

`nvim-treesitter`がC/C++パーサーをコンパイルすると、例えば次のファイルが生成されます。

```text
%LOCALAPPDATA%\nvim-data\tree-sitter-cpp\parser.so
```

ウイルス対策ソフトがヒューリスティック検出する場合があります。復元や許可を行う場合は、取得元とパスを確認し、検出された個別ファイルだけを対象にします。Tree-sitterやNeovimのデータディレクトリ全体を除外することは推奨しません。

### Treesitterの世代不一致

Neovim 0.12では`nvim-treesitter`の`main`ブランチを使用します。0.11互換用の`master`を使うと、`conceal_line`や`range`に関するエラーが発生する場合があります。

設定を再配置して更新します。

```powershell
.\manage-nvim.bat setup
.\manage-nvim.bat update
```

### プラグインの状態を初期化したい

設定そのものは残したまま、lazy.nvimの管理画面から同期できます。

```vim
:Lazy sync
```

コマンドラインから同期する場合は次を使います。

```powershell
.\manage-nvim.bat update
```

## 11. 日常的な更新手順

リポジトリ側の設定を変更した場合は、Neovimを終了して次を実行します。

```powershell
.\manage-nvim.bat setup
.\manage-nvim.bat update
.\manage-nvim.bat check
```

設定変更だけでプラグイン更新が不要な場合は、`setup`と`check`だけで構いません。

