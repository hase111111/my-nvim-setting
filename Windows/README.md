# Windows版 Neovim の管理

C++開発環境を含む一連の構築手順は、[Windows Neovim C++環境構築ガイド](docs/nvim-cpp-setup.md)にまとめています。

`manage-nvim.bat` から、Neovim本体と、このリポジトリにある最小構成のLua設定を管理できます。
内部ではWindows標準のPowerShellとwingetを使用します。

## 使い方

PowerShellまたはコマンドプロンプトで、このディレクトリに移動して実行します。

```powershell
# インストール
.\manage-nvim.bat install

# 不足している検索・展開ツールをインストール
.\manage-nvim.bat install-tools

# 状態確認
.\manage-nvim.bat status

# Lua設定を配置（既存設定はバックアップ）
.\manage-nvim.bat setup

# Lua設定を配置（既存設定をバックアップせず完全上書き）
.\manage-nvim.bat setup --force

# Lua設定を読み込めるか確認
.\manage-nvim.bat check

# プラグインをインストール・更新・整理
.\manage-nvim.bat update

# アンインストール
.\manage-nvim.bat uninstall

# ヘルプ
.\manage-nvim.bat help
```

インストール後に`nvim`が見つからない場合は、ターミナルを一度閉じて開き直してから状態確認を実行してください。

## 設定の配置

管理対象のLua設定は`Windows/nvim`にあります。`setup`はその内容を`%LOCALAPPDATA%\nvim`へ配置します。

配置先に既存設定がある場合、通常は`%LOCALAPPDATA%\nvim-backups\nvim-日時`へバックアップしてから置き換えます。`--force`を指定するとバックアップを作らず、既存設定を完全に置き換えます。

初期設定ではインデントにスペース2個を使います。

## プラグイン

設定の配置後、初めてNeovimを起動すると`lazy.nvim`と各プラグインが自動的にダウンロードされます。Gitが必要です。

```powershell
git --version
nvim
```

導入するプラグインは次のとおりです。

- `lazy.nvim`: プラグイン管理
- `tokyonight.nvim`: カラーテーマ
- `which-key.nvim`: キーマップのガイド
- `telescope.nvim`: ファイル・文字列検索
- `nvim-tree.lua`: ツリー型ファイラー
- `nvim-treesitter`: 構文解析とハイライト
- `mason.nvim`: clangdなどの開発ツール管理
- `nvim-lspconfig`: NeovimのLSP設定
- `blink.cmp`: コード補完
- `barbar.nvim`: バッファをタブ風に表示
- `lualine.nvim`: ステータスライン
- `toggleterm.nvim`: Neovim内ターミナル
- `winresizer`: 分割ウィンドウのサイズ変更
- `nvim-autopairs`: 括弧や引用符の自動補完
- `nvim-hlslens`: 検索結果の位置と件数を表示
- `nvim-scrollbar`: カーソル・診断・検索結果をスクロールバーに表示
- `accelerated-jk.nvim`: `j` / `k`の連続移動を加速

Neovim内では`:Lazy`で管理画面を開けます。コマンドラインから一括更新する場合は`manage-nvim.bat update`を実行します。更新後の`lazy-lock.json`は`Windows/nvim`へコピーされ、Gitで管理できます。次回`setup`すると、固定されたバージョンも配置されます。

### 主なキーマップ

| キー | 機能 |
|---|---|
| `<Space>?` | 現在のバッファのキーマップを表示 |
| `<Space>ff` | ファイルを検索 |
| `<Space>fg` | ファイル内容を検索 |
| `<Space>fb` | 開いているバッファを検索 |
| `<Space>fh` | ヘルプを検索 |
| `<Space>e` | ファイラーを開閉 |
| `<Space>t` / `Ctrl+\` | ターミナルを開閉 |
| `j` / `k` | 通常移動（連続入力すると加速） |
| `<Space>wr` | ウィンドウサイズ変更モード |
| `Alt+,` / `Alt+.` | 前後のバッファへ移動 |
| `Alt+c` | バッファを閉じる |
| `Alt+p` | バッファを固定／解除 |
| `gd` | 定義へ移動 |
| `gD` | 宣言へ移動 |
| `gr` | 参照箇所を表示 |
| `K` | シンボル情報を表示 |
| `<Space>rn` | シンボル名を変更 |
| `<Space>ca` | コードアクション |
| `<Space>d` | 診断内容を表示 |
| `[d` / `]d` | 前後の診断へ移動 |

`<Space>fg`にはripgrepが必要です。通常は`manage-nvim.bat install`でNeovimと一緒に導入されます。Neovimを導入済みの場合は次を実行してください。

```powershell
.\manage-nvim.bat install-tools
```

`install-tools`は、MasonがWindowsでアーカイブを展開するための7-Zipも導入します。

## C/C++開発

`manage-nvim.bat update`を実行すると、Masonがclangdを導入します。`tree-sitter-cli`は公式Tree-sitterリリースから取得し、SHA-256を検証して`%LOCALAPPDATA%\Programs\tree-sitter-cli`へ配置します。起動時にPATH上の`gcc`と`g++`を検索し、見つかったコンパイラをclangdの`--query-driver`へ自動設定します。

C/C++のTreesitterパーサーを自動導入します。一部のウイルス対策ソフトが生成された`parser.so`を誤検知する場合は、取得元とファイルパスを確認したうえで、検出されたファイルだけを個別に扱ってください。Treesitterのディレクトリ全体を除外することは推奨しません。

CMakeプロジェクトでは、clangdが正しいコンパイル条件を取得できるよう、`compile_commands.json`を生成してください。

```powershell
cmake -S . -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build
```

NeovimでC++ファイルを開いた後、`:LspInfo`でclangdの接続状態を確認できます。補完候補は`Ctrl+Space`で手動表示、`Ctrl+y`で確定できます。

## 管理する範囲

Neovim本体はwingetの`Neovim.Neovim`パッケージとして管理します。
アンインストールしても、`%LOCALAPPDATA%\nvim`にある設定ファイルと、他の用途でも利用できるripgrepは削除しません。

`winget`が見つからない場合は、Microsoft Storeの「アプリ インストーラー」を導入または更新してください。
