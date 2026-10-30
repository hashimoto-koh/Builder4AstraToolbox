# Builder4AstraToolbox

BinaryBuilder.jl build recipe repository for **ASTRA Toolbox** and Julia C ABI bridge, intended for distribution as `AstraToolbox_jll` and eventual inclusion in [Yggdrasil](https://github.com/JuliaPackaging/Yggdrasil).

---

## 1. 概要 (Overview)

本リポジトリは、[hashimoto-koh/AstraToolbox.jl](https://github.com/hashimoto-koh/AstraToolbox.jl) が利用する native ASTRA C++/CUDA backend および Julia 用 C ABI bridge を、[BinaryBuilder.jl](https://github.com/JuliaPackaging/BinaryBuilder.jl) で再現可能にビルドし、Yggdrasil 登録と JLL (`AstraToolbox_jll`) 配布を行うための **build recipe 開発リポジトリ** です。

- **目標 JLL 名**: `AstraToolbox_jll`
- **対象プラットフォーム**: **Linux x86_64 / NVIDIA GPU (CUDA 12 系)**
- **方針**: **CUDA-enabled 単一 JLL のみを配布**。同一の `libastra.so` 内に CPU 2D アルゴリズムと CUDA 2D/3D アルゴリズムをすべて内包し、Julia 側から `backend=cpu()` と `backend=cuda()` の両方をシームレスに利用できます。GPU を搭載しない環境での実行・配布はサポート対象外です。

---

## 2. ディレクトリ構成 (Repository Layout)

```text
Builder4AstraToolbox/
  AGENTS.md                     # 開発規約・ローカル記録ルール
  PLAN.md                       # マイルストーン開発計画
  README.md                     # 本ドキュメント
  LICENSE                       # GPL-3.0-or-later
  THIRD_PARTY_NOTICES.md        # upstream ASTRA / CWI / imec 著作権・論文引用
  build_tarballs.jl             # BinaryBuilder ビルドレシピ
  platforms/
    cuda.jl                     # Yggdrasil 公式 CUDA プラットフォームヘルパー
  patches/
    0001-fix-darthelper-typo.patch
    0002-add-julia-c-api-to-makefile.patch
    README.md
  wrapper/
    include/astra/julia_c_api.h # Julia C ABI 定義
    src/julia_c_api.cpp         # Julia C ABI 実装
  scripts/
    inspect_abi.sh              # ELF 動的依存および 114 個の export シンボル検査
    test_products.jl            # C ABI 直接呼び出しによる診断・CPU/CUDA 数値検証
  test/
    runtests.jl                 # 自動テストスイート
  docs/
    inventory.md                # 現行実装の棚卸しとリビジョン固定
    abi-contract.md             # Julia C ABI 契約書（全 114 シンボル仕様）
    dependency-matrix.md        # 依存関係マトリクス
    build-validation.md         # ビルド・検証仕様書および実機受入ログ
    integration-guide.md        # AstraToolbox.jl 統合・移行手順書
```

---

## 3. テストの実行方法 (Verification)

本リポジトリ単体で、C ABI の整合性および実機 GPU での動作検証を実行できます:

```bash
# 全テストスイートの実行
julia --startup-file=no --project=. test/runtests.jl

# ABI および export シンボルの静的検査
./scripts/inspect_abi.sh

# C ABI 経由の直接数値テスト (CPU vs CUDA)
julia --startup-file=no --project=. scripts/test_products.jl
```

---

## 4. ライセンス・免責事項 (License & Attribution)

- **ライセンス**: 本リポジトリおよび生成物は [GNU General Public License v3.0 or later (GPL-3.0-or-later)](LICENSE) の下で配布されます。
- **Upstream ASTRA Toolbox**: Copyright (c) 2010–2024, imec Vision Lab, University of Antwerp & CWI, Amsterdam.
- **非公式明記**: 本リポジトリは非公式の Julia コミュニティパッケージングプロジェクトであり、公式 ASTRA Toolbox チームによる支援・公認を示唆するものではありません。学術利用の際は [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) に記載の原著論文を引用してください。
