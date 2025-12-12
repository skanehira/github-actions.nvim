# PR Checks 機能 設計ドキュメント

生成日: 2025-12-12
ジェネレーター: requirements-analysis

## システム概要

### 目的
PRに紐づくワークフロー実行ステータスを確認する機能を追加する。GitHubのPR画面下部に表示されるステータスチェック一覧のような情報をNeovim内で確認できるようにする。

### 解決する問題
- PRのCI/CDステータスを確認するためにブラウザを開く必要がある
- 既存の履歴機能はワークフローファイル単位であり、PR単位での確認ができない

### ビジネス価値
- 開発フローの効率化（エディタから離れずにPRステータスを確認）
- 既存の履歴機能との統合による一貫したUX

### 対象ユーザー
- GitHub Actionsを使用するプロジェクトで開発を行うNeovimユーザー

## 機能要件

### 必須機能（MUST have）

1. **PR番号入力機能**
   - `show_pr_checks()` 関数を呼び出すと `vim.ui.input` でPR番号の入力プロンプトを表示
   - 入力されたPR番号に対応するチェック情報を取得

2. **ユーザーコマンド**
   - `:GithubActionsShowPRChecks` コマンドを提供
   - コマンド実行で `show_pr_checks()` を呼び出し

3. **チェック一覧表示**
   - PRに紐づくワークフロー実行を履歴バッファ形式で表示
   - 各run（ワークフロー実行）を展開してjobs/stepsを確認可能

4. **既存履歴機能との統合**
   - 既存の履歴バッファと同じキーマップ（expand, collapse, refresh, rerun, watch, cancel, logs, close）
   - 同じアイコン・ハイライト設定を使用

### オプション機能（NICE to have）

- カレントブランチに紐づくPRを自動検出（将来の拡張）

## 非機能要件

### パフォーマンス要件
- PR checksの取得は非同期で行い、UIをブロックしない
- 取得中は「Loading...」を表示

### 保守性
- 既存の履歴機能のコンポーネント（runs_buffer, api等）を最大限再利用
- 新規モジュールは最小限に抑える

## アーキテクチャ設計

### システム構成

```
lua/github-actions/
├── init.lua                    # エントリポイント（show_pr_checks追加）
├── pr_checks/                  # 新規モジュール
│   ├── init.lua               # エントリポイント
│   └── api.lua                # GitHub API呼び出し
└── history/
    ├── api.lua                # 既存（fetch_jobs, fetch_logs, rerun, cancel）
    └── ui/
        └── runs_buffer.lua    # 既存（バッファ表示、再利用）
```

### データフロー

```
1. ユーザー: show_pr_checks() 呼び出し
2. vim.ui.input: PR番号入力
3. pr_checks/api.lua: gh pr checks --json で checkを取得
4. pr_checks/api.lua: checkのlinkからrun_idを抽出、重複排除
5. pr_checks/api.lua: 各run_idに対して gh run view --json で詳細取得
6. history/ui/runs_buffer.lua: 既存のrenderを使って表示
```

### 技術選定

- **GitHub API**: `gh pr checks --json` コマンド（gh CLI）
- **Workflow Run取得**: `gh run view <run_id> --json` コマンド
- **UIコンポーネント**: 既存の `history/ui/runs_buffer.lua` を再利用

## データ設計

### gh pr checks のレスポンス構造（実測）

```bash
gh pr checks 12286 --repo cli/cli --json bucket,completedAt,name,startedAt,state,workflow,link
```

```json
[
  {
    "bucket": "skipping",
    "completedAt": "2025-12-10T20:54:10Z",
    "link": "https://github.com/cli/cli/actions/runs/20112969933/job/57715054905",
    "name": "issue",
    "startedAt": "2025-12-10T20:54:10Z",
    "state": "SKIPPED",
    "workflow": "Discussion Triage"
  },
  {
    "bucket": "pass",
    "completedAt": "2025-12-10T20:54:00Z",
    "link": "https://github.com/cli/cli/actions/runs/20112962633/job/57715026466",
    "name": "pr-auto",
    "startedAt": "2025-12-10T20:53:55Z",
    "state": "SUCCESS",
    "workflow": "PR Automation"
  }
]
```

### gh run view のレスポンス構造（実測）

```bash
gh run view 20112962633 --repo cli/cli --json conclusion,createdAt,databaseId,displayTitle,headBranch,status,updatedAt
```

```json
{
  "conclusion": "success",
  "createdAt": "2025-12-10T20:53:51Z",
  "databaseId": 20112962633,
  "displayTitle": "`gh pr create`: add `--head-repo` flag",
  "headBranch": "gh-pr-create-head_repo",
  "status": "completed",
  "updatedAt": "2025-12-10T20:54:01Z"
}
```

### run_id抽出パターン

linkフィールドから正規表現でrun_idを抽出:
```lua
link:match('/actions/runs/(%d+)/')
```

### 既存runs形式との互換性

既存の `history/api.fetch_runs` が返す形式と `gh run view` の出力は同一構造。
そのまま `runs_buffer.render()` に渡せる。

## API設計

### 新規関数

#### pr_checks/api.lua

```lua
---@class PRCheck
---@field bucket string "pass" | "fail" | "pending" | "skipping" | "cancel"
---@field completedAt string ISO8601 timestamp
---@field name string Check name
---@field startedAt string ISO8601 timestamp
---@field state string "SUCCESS" | "FAILURE" | "PENDING" | "SKIPPED" | "CANCELLED"
---@field workflow string Workflow name
---@field link string URL to the check (contains run_id)

---Fetch PR checks using gh CLI
---@param pr_number number PR number
---@param callback fun(checks: PRCheck[]|nil, err: string|nil)
function M.fetch_pr_checks(pr_number, callback)

---Extract unique run IDs from PR checks
---@param checks PRCheck[] List of PR checks
---@return number[] run_ids Unique run IDs
function M.extract_run_ids(checks)

---Fetch workflow runs for given run IDs
---@param run_ids number[] List of run IDs
---@param callback fun(runs: table[]|nil, err: string|nil)
function M.fetch_runs_by_ids(run_ids, callback)
```

#### pr_checks/init.lua

```lua
---Show PR checks for a specific PR number
---Prompts user for PR number via vim.ui.input
---@param history_config? HistoryOptions History configuration
function M.show_pr_checks(history_config)
```

### init.lua への追加

```lua
---Show PR checks
function M.show_pr_checks()
  pr_checks.show_pr_checks(config.history)
end
```

### plugin/github-actions.lua への追加（コマンド登録）

```lua
vim.api.nvim_create_user_command('GithubActionsPRChecks', function()
  github_actions.show_pr_checks()
end, {
  desc = 'Show PR checks status',
})
```

## 実装の詳細

### PR checks取得コマンド

```bash
gh pr checks <pr_number> --json bucket,completedAt,name,startedAt,state,workflow,link
```

### Run詳細取得コマンド

```bash
gh run view <run_id> --json conclusion,createdAt,databaseId,displayTitle,headBranch,status,updatedAt
```

### バッファ名

```
[GitHub Actions] PR #<number> - Checks
```

### runs_buffer.lua の修正

現状の `create_buffer` は `workflow_file` と `workflow_filepath` を必須としている。
PR checks用に以下の対応が必要:

1. `workflow_file` を省略可能にするか、PR番号ベースの識別子を使用
2. refresh機能をPR checks用にカスタマイズ（`fetch_pr_checks`を再呼び出し）
3. dispatch機能は無効化（PRに対してdispatchは不可）

**アプローチ**:
- `runs_buffer.create_buffer` に `buffer_type` パラメータを追加
- `buffer_type = "pr_checks"` の場合はPR番号を使用
- refreshコールバックをオプションで渡せるようにする

### エラーハンドリング

- PRが存在しない場合: 「PR #N not found」
- checksがない場合: 「No checks found for PR #N」
- run_idの取得に失敗した場合: 個別にスキップし、取得できたもののみ表示

## 制約と前提

### 技術的制約
- `gh` CLI がインストールされ、認証済みであること
- Neovim 0.9+ が必要

### ビジネス制約
- 既存のUIコンポーネントを最大限再利用し、コード量を最小限に抑える

### 依存関係
- 既存モジュール: `history/api.lua`, `history/ui/runs_buffer.lua`
- 外部コマンド: `gh pr checks`, `gh run view`

## 参照

- タスク分解: task-planning スキルでTODO.mdを生成
- 既存コード: `lua/github-actions/history/`
