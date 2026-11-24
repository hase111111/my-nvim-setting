# WSL2 Neovim 環境構築 — 引き継ぎメモ

## 目的と現在地
WSL2上にNeovimの最新安定版を導入し、自分でLua設定を管理できる開発環境を段階的に構築する。Ubuntu/Debian、Bashを基本想定（実際のディストリビューション・シェルは未確認）。

これまでのチャットではインストール・リセット用スクリプトと設定構成を提案した。ユーザー環境での実行結果は未確認。設定ファイルの配置、lazy.nvimや各プラグインの導入は次の作業。LazyVimの完成済み構成ではなく、自前の設定 + lazy.nvimを推奨した段階であり、最終決定ではない。

## 1. 本体インストール・更新
`install-nvim.sh` として保存して `chmod +x install-nvim.sh`、`./install-nvim.sh` で実行する。再実行で更新する想定。既存の設定・プラグインは保持する。

```bash
#!/usr/bin/env bash
set -euo pipefail
case "$(uname -m)" in
    x86_64) ARCH=x86_64 ;;
    aarch64) ARCH=arm64 ;;
    *) echo 'Unsupported architecture'; exit 1 ;;
esac
NVIM_DIR="nvim-linux-${ARCH}"
ARCHIVE="${NVIM_DIR}.tar.gz"
URL="https://github.com/neovim/neovim/releases/latest/download/${ARCHIVE}"
sudo apt-get update
sudo apt-get install -y curl git unzip tar ripgrep fd-find build-essential ca-certificates
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
curl -fL --retry 3 "$URL" -o "$TMP_DIR/$ARCHIVE"
tar -xzf "$TMP_DIR/$ARCHIVE" -C "$TMP_DIR"
"$TMP_DIR/$NVIM_DIR/bin/nvim" --version
sudo apt-get remove -y neovim
if command -v snap >/dev/null 2>&1 && snap list nvim >/dev/null 2>&1; then
    sudo snap remove nvim
fi
sudo rm -rf /opt/nvim /opt/nvim-linux64 /opt/nvim-linux-x86_64 /opt/nvim-linux-arm64
sudo rm -f /usr/local/bin/nvim
sudo mv "$TMP_DIR/$NVIM_DIR" "/opt/$NVIM_DIR"
sudo ln -sfn "/opt/$NVIM_DIR/bin/nvim" /usr/local/bin/nvim
PATH_LINE='export PATH="/usr/local/bin:$PATH"'
for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$RC" ]] && ! grep -Fxq "$PATH_LINE" "$RC"; then
        printf '\n%s\n' "$PATH_LINE" >> "$RC"
    fi
done
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    sudo ln -sfn "$(command -v fdfind)" /usr/local/bin/fd
fi
/usr/local/bin/nvim --version
```

確認: `hash -r; command -v nvim; nvim --version`。想定パスは `/usr/local/bin/nvim`。必要ならシェルを再起動する。手動配置先の削除を含むため、独自インストールがある場合は事前確認する。Homebrew等は対象外。新バイナリの起動確認後に旧版を削除するが、ロールバック機能はない。

## 2. 設定・プラグインのリセット
Neovimを終了してから実行する。本体は削除しない。標準パスでの完全リセット（バックアップなし）:

```bash
rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
```

推奨の `reset-nvim.sh`（確認・任意バックアップ付き）:

```bash
#!/usr/bin/env bash
set -euo pipefail
DIRS=(
    "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
    "${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
    "${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
    "${XDG_CACHE_HOME:-$HOME/.cache}/nvim"
)
printf '  %s\n' "${DIRS[@]}"
read -r -p 'Continue? [y/N]: ' CONFIRM
[[ "$CONFIRM" =~ ^[yY]$ ]] || exit 0
read -r -p 'Create backup? [Y/n]: ' BACKUP
if [[ ! "$BACKUP" =~ ^[nN]$ ]]; then
    BACKUP_DIR=$(mktemp -d "$HOME/nvim-backup-$(date +%Y%m%d-%H%M%S)-XXXXXX")
    NAMES=(config data state cache)
    for i in "${!DIRS[@]}"; do
        if [[ -e "${DIRS[$i]}" || -L "${DIRS[$i]}" ]]; then
            cp -a "${DIRS[$i]}" "$BACKUP_DIR/${NAMES[$i]}"
        fi
    done
    echo "Backup saved: $BACKUP_DIR"
fi
for DIR in "${DIRS[@]}"; do
    rm -rf -- "$DIR"
done
echo 'Reset complete.'
```

`NVIM_APPNAME` による別環境は対象外。シンボリックリンクのバックアップはリンク自体を保存する。部分リセットは `~/.local/share/nvim/lazy`（プラグイン）、`~/.local/share/nvim/mason`（言語ツール）、`~/.cache/nvim`（キャッシュ）など。

## 3. 推奨構成（未実装）

```text
nvim-setup/
├── install-nvim.sh
├── reset-nvim.sh
├── setup-nvim.sh
├── update-nvim.sh
├── README.md
└── nvim/
    ├── init.lua
    ├── lazy-lock.json
    └── lua/
        ├── config/
        │   ├── options.lua
        │   ├── keymaps.lua
        │   ├── autocmds.lua
        │   └── lazy.lua
        └── plugins/
            ├── colorscheme.lua
            ├── editor.lua
            ├── ui.lua
            ├── telescope.lua
            ├── treesitter.lua
            ├── lsp.lua
            ├── completion.lua
            └── git.lua
```

配置先は `~/.config/nvim`。従来の `.vimrc` ではなく `init.lua` を使用する。Leaderキーはプラグイン読み込み前に設定する。`lazy-lock.json` は自動生成しGit管理する想定。

### options.lua の提案

```lua
local opt = vim.opt
opt.encoding = "utf-8"
opt.fileencoding = "utf-8"
opt.number = true
opt.relativenumber = true
opt.termguicolors = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.showmode = false
opt.laststatus = 3
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.expandtab = true
opt.autoindent = true
opt.smartindent = true
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true
opt.backup = false
opt.writebackup = true
opt.undofile = true
opt.confirm = true
opt.splitright = true
opt.splitbelow = true
opt.mouse = "a"
opt.updatetime = 250
opt.timeoutlen = 400
opt.completeopt = { "menu", "menuone", "noselect" }
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
```

### keymaps.lua の提案

```lua
vim.g.mapleader = " "
vim.g.maplocalleader = " "
local map = vim.keymap.set
map("n", "<leader>w", "<cmd>w<CR>")
map("n", "<leader>q", "<cmd>q<CR>")
map("n", "<Esc>", "<cmd>nohlsearch<CR>")
map("n", "<leader>sv", "<cmd>vsplit<CR>")
map("n", "<leader>sh", "<cmd>split<CR>")
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")
map("n", "<S-h>", "<cmd>bprevious<CR>")
map("n", "<S-l>", "<cmd>bnext<CR>")
map("v", "<", "<gv")
map("v", ">", ">gv")
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "<leader>ec", function()
    vim.cmd.edit(vim.fn.stdpath("config") .. "/init.lua")
end)
```

## 4. プラグイン候補（未導入）

| 分類 | 候補 | 用途 |
|---|---|---|
| 管理 | lazy.nvim | プラグイン管理 |
| UI | tokyonight.nvim | カラーテーマ |
| UI | nvim-tree.lua | ファイルツリー |
| UI | lualine.nvim | ステータスライン |
| UI | bufferline.nvim | バッファ表示 |
| UI | which-key.nvim | キー操作ガイド |
| UI | nvim-web-devicons | アイコン |
| 検索 | telescope.nvim | ファイル・文字列検索 |
| 構文 | nvim-treesitter | 構文解析 |
| 補完 | blink.cmp | 自動補完 |
| LSP | mason.nvim / nvim-lspconfig | 言語ツール管理・設定 |
| 編集 | nvim-autopairs / indent-blankline.nvim | 括弧補完・インデントガイド |
| Git | gitsigns.nvim | 変更箇所表示 |
| 品質 | conform.nvim / nvim-lint | フォーマット・Lint |
| その他 | toggleterm.nvim / trouble.nvim / nvim-dap | ターミナル・診断・デバッグ |

プラグインの最新API、依存関係、対応Neovimバージョンは実装時に公式情報で確認する。使用言語は未指定。

## 5. WSL2固有の設定
Windows Terminal側で JetBrainsMono Nerd Font 等を設定する案。Windowsクリップボード連携は win32yank.exe がPATH上にある場合に以下を使用する案（未導入・未検証）。

```lua
if vim.fn.has("wsl") == 1 and vim.fn.executable("win32yank.exe") == 1 then
    vim.g.clipboard = {
        name = "win32yank",
        copy = {
            ["+"] = "win32yank.exe -i --crlf",
            ["*"] = "win32yank.exe -i --crlf",
        },
        paste = {
            ["+"] = "win32yank.exe -o --lf",
            ["*"] = "win32yank.exe -o --lf",
        },
        cache_enabled = 0,
    }
    vim.opt.clipboard = "unnamedplus"
end
```

## 6. 次のチャットで進めたい作業
1. 現在の環境を確認する（`cat /etc/os-release`、`nvim --version`、`command -v nvim`、既存設定の有無）。
2. `setup-nvim.sh` を作成する。設定ディレクトリ作成、Luaファイル生成または配置、lazy.nvimのブートストラップ、プラグイン導入を自動化する。既存設定を無断で上書きせず、バックアップや確認を用意する。
3. 基本設定 → UI → 検索・操作性 → LSP・補完・Treesitter → Git・開発支援 → WSL2連携の順で段階的に導入する。
4. `:checkhealth`、起動確認、各機能の確認を行う。
5. `update-nvim.sh` とREADMEを整備し、dotfilesとしてGit管理できるようにする。

設定案の既定値はインデント4、Space Leader、Tokyo Night。ユーザーが確定した好みではないため変更可能。スクリプト・Lua設定とも実機テスト未実施。

## 参考リンク
- https://github.com/neovim/neovim/blob/master/INSTALL.md
- https://github.com/neovim/neovim/releases/latest
- https://lazy.folke.io/installation
- https://www.nerdfonts.com/font-downloads

## 新しいチャットへの依頼文
このMarkdownはWSL2上のNeovim環境構築の引き継ぎ資料です。ここまでの提案と実施状況を区別して把握し、次は `setup-nvim.sh` と分割したLua設定の作成から進めてください。既存のインストール・リセットスクリプトと連携させ、再現性と安全性を重視してください。必要に応じて環境や使用言語を確認し、プラグインの最新仕様に合わせて実装してください。
