# casparcg-nix

CasparCG Server を再現可能にビルドし、NixOS 上で宣言的に運用するための独立した Nix flake です。

## 対応環境

- `x86_64-linux`
- Nix flakes
- Nixpkgs 26.05（`flake.lock` で revision を固定）

## 開発

flake の出力を確認します。

```console
nix flake show
```

開発 shell へ入ります。

```console
nix develop
```

書式を整え、flake の check を実行します。

```console
nix fmt
nix flake check
```

開発 shell には Nix formatter、静的解析ツール、および今後の CMake/Ninja build に必要な基本ツールが含まれます。

## Minimal package

CEF/HTML Producer を含まない CasparCG Server 2.5.0 をビルドします。

```console
nix build .#casparcg-server-minimal
```

設定ファイルを第1引数に指定して起動します。

```console
./result/bin/casparcg-server /path/to/casparcg.config
```

この package は AVX2 対応 CPU を前提とします。HTML Producer 対応 package は後続で追加します。

## Roadmap

1. flake skeleton（完了）
2. CEF なしの CasparCG Server package（完了）
3. headless NixOS service
4. module/AMCP checks
5. CEF 142 対応 package
6. Media Scanner
7. DeckLink と `casperctl` の統合文書
