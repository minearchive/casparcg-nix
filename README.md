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
`nix flake check` は minimal/full package build、Media Scanner build、module evaluation、headless VM 上の AMCP/HTML/Media Scanner smoke test を実行します。

## CI

GitHub Actions は pull request、`main` への push、手動実行で動きます。`ubuntu-24.04` の `x86_64-linux` runner 上で、まず formatter、flake の評価、workflow lint を実行し、成功した場合だけ KVM を使う全 package/module/VM check に進みます。同じ pull request の古い実行はキャンセルしますが、`main` push の実行はキャンセルしません。CI での check は次のコマンドに対応します。

```console
nix fmt -- --ci
nix flake show --all-systems --no-update-lock-file
nix flake check --no-build --all-systems --no-update-lock-file
nix build .#checks.x86_64-linux.workflow-lint --print-build-logs
nix flake check --all-systems --no-update-lock-file --print-build-logs
```

### Cachix 公開キャッシュ

公開 Cachix cache を CI で使うには、まず Cachix で cache を作成し、GitHub repository の Settings → Secrets and variables → Actions に次を登録します。

- Repository variable `CACHIX_CACHE_NAME`: 作成した公開 cache 名
- Repository secret `CACHIX_AUTH_TOKEN`: 成果物の push を許可した Cachix auth token

両方が設定された `main` push だけが daemon mode で成果物を cache へ push します。push に失敗した場合は CI も失敗します。pull request（fork からの pull request を含む）と手動実行は、secret が利用可能でも常に read-only です。cache 名だけ設定した場合、または token が無い場合も公開 cache の pull のみを試みます。cache が未設定なら Cachix の step を省略して通常の Nix build に fallback します。公開 cache の pull 障害は build を妨げません。

利用者側で公開 cache を有効にする場合は Cachix CLI をインストールし、次を実行します。

```console
cachix use <cache-name>
```

`<cache-name>` は `CACHIX_CACHE_NAME` と同じ値です。

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

## Media Scanner

Media Scanner 1.4.0 は独立した package としてもビルドできます。Node.js 24、FFmpeg 7、および Node 24 向けにソースビルドした native `leveldown` module を runtime closure に含みます。

```console
nix build .#media-scanner
```

NixOS service は CasparCG service の下で opt-in できます。

```nix
services.casparcg = {
  enable = true;
  configFile = ./casparcg.config;

  mediaScanner = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 8000;
  };
};
```

scanner は同じ XML 設定と `mediaDir` / `templateDir` を参照し、既定では `127.0.0.1:8000` のみに bind します。firewall は自動で開きません。scanner の database は `/var/lib/casparcg-media-scanner` に保存され、scanner が停止しても CasparCG 本体は停止しません。

## DeckLink

DeckLink は opt-in です。NixOS 標準の `hardware.decklink` module が kernel module と `DesktopVideoHelper.service` を提供し、この flake は CasparCG の起動順序と `libDeckLinkAPI.so` の runtime search path だけを追加します。

```nix
{
  services.casparcg = {
    enable = true;
    configFile = ./casparcg.config;
    decklink.enable = true;
  };

  hardware.decklink.enable = true;
}
```

Blackmagic Desktop Video は unfree です。この module が `allowUnfree` を暗黙に変更することはありません。ホスト側で `blackmagic-desktop-video` と `decklink` のみを許可してください。完全な例は [`examples/decklink.nix`](examples/decklink.nix) にあります。`services.casparcg.decklink.enable = true` に対して `hardware.decklink.enable` が無い構成は assertion error になります。

実機更新時は、少なくとも次を確認します。

- CPU の AVX2 対応と、lock された kernel / Desktop Video の組み合わせ
- `blackmagic` / `blackmagic-io` kernel module と `DesktopVideoHelper.service` の起動
- `/dev/blackmagic/*` を `casparcg` user から読み書きできること
- CasparCG log での card 列挙、video mode、reference、keyer の認識
- SDI video/audio 出力、frame rate、reference lock、必要な fill/key 出力
- CasparCG と helper の restart、連続運転、前世代への NixOS rollback

DeckLink hardware を使う放送品質試験は自動 VM check の対象外です。driver または card の初期化に失敗した場合も、両方の DeckLink option を無効にすれば unfree package を要求せず core service を利用できます。

## Roadmap

1. flake skeleton（完了）
2. CEF なしの CasparCG Server package（完了）
3. headless NixOS service（完了）
4. module/AMCP checks（完了）
5. CEF 142 対応 package（完了）
6. Media Scanner（完了）
7. DeckLink 統合文書（完了）
8. GitHub Actions CI と Cachix 公開キャッシュ（完了）
