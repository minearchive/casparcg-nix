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

開発 shell には Nix formatter、静的解析ツール、および CMake/Ninja build に必要な基本ツールが含まれます。
`nix flake check` は minimal/full package build、module evaluation、headless VM 上の AMCP/HTML smoke test を実行します。

## Full package

CEF 142 と HTML Producer を含む CasparCG Server 2.5.0 をビルドします。これは flake と NixOS module の既定 package です。

```console
nix build
# または
nix build .#casparcg-server
```

CEF archive は hash を固定して事前取得し、CasparCG の build 中には download しません。CEF runtime、resources、locales、snapshot、および SwiftShader/Vulkan 関連ファイルは Nix store closure に収録されます。`chrome-sandbox` は setuid にせず、CasparCG が CEF sandbox を無効化して起動します。

HTML Producer を使う場合は、XML の `<configuration>` 以下に書込可能な cache path を指定します。

```xml
<html>
  <cache-path>/var/cache/casparcg/cef</cache-path>
  <enable-gpu>false</enable-gpu>
</html>
```

## Minimal package

CEF/HTML Producer を含まない CasparCG Server 2.5.0 をビルドします。

```console
nix build .#casparcg-server-minimal
```

設定ファイルを第1引数に指定して起動します。

```console
./result/bin/casparcg-server /path/to/casparcg.config
```

full/minimal package はともに AVX2 対応 CPU を前提とします。

## NixOS service

flake の module を読み込み、CasparCG XML を指定します。

```nix
{
  inputs.casparcg-nix = {
    url = "github:OWNER/casparcg-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, casparcg-nix, ... }: {
    nixosConfigurations.playout = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        casparcg-nix.nixosModules.casparcg
        {
          services.casparcg = {
            enable = true;
            configFile = ./casparcg.config;
          };
        }
      ];
    };
  };
}
```

module は XML を生成しません。`configFile` 内の path/port と module options を一致させる責任は利用側にあります。AMCP firewall は既定では開きません。

HTML Producer が不要なホストでは package を明示的に軽量版へ切り替えられます。

```nix
services.casparcg.package = pkgs.casparcg-server-minimal;
```

## Roadmap

1. flake skeleton（完了）
2. CEF なしの CasparCG Server package（完了）
3. headless NixOS service（完了）
4. module/AMCP checks（完了）
5. CEF 142 対応 package（完了）
6. Media Scanner
7. DeckLink と `casperctl` の統合文書
