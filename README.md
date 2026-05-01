# OmniWatchCare - Raspberry Pi System Optimizations

Raspberry Pi（特にRaspberry Pi 5）を無人・連続稼働させるための、必須・おすすめのシステム設定を全自動で行うセットアップスクリプトです。

## 🌟 概要

このリポジトリに含まれる `setup_system_optimizations.sh` を実行するだけで、IoTデバイスやエッジサーバーとしてRaspberry Piを安定運用するための以下の3つの強力な設定が自動で適用されます。

1. **ログの不揮発化 (Persistent Logging)**
2. **WiFiの省電力機能の無効化 (Disable WiFi Power Management)**
3. **ハードウェアWatchdogの有効化 (Hardware Watchdog Setup)**

設定の重複を防ぐ冪等性（べきとうせい）を備えており、複数回実行しても安全です。また、変更前の設定ファイルのバックアップも自動で作成します。

## ✨ 主な機能

### 1. ログの不揮発化 (`systemd-journald`)
デフォルトのRaspberry Pi OSでは、再起動すると過去のシステムログが消去されてしまいます。
このスクリプトは `/var/log/journal` ディレクトリを作成し、過去の再起動をまたいでログを保持できるようにします。
- **制限設定**: ディスク容量を圧迫しないよう、最大使用量を `500M`、保存期間を `1month` (1ヶ月) に制限します。

### 2. WiFi省電力機能の無効化 (`NetworkManager`)
Raspberry PiのWiFiは省電力機能が原因で、SSH接続が途切れたりネットワークが不安定になることがあります。
このスクリプトは `NetworkManager` の設定ファイルを自動生成/更新し、`wifi.powersave = 2` (無効) に設定することで、常時安定したネットワーク通信を確保します。

### 3. ハードウェアWatchdogの有効化 (`bcm2835-wdt`)
システムが完全にフリーズ（カーネルパニックやリソース枯渇）した場合でも、ハードウェアレベルで異常を検知して自動的に再起動をかけるWatchdogタイマーを設定します。
- **タイムアウト設定**: `RuntimeWatchdogSec=10` (10秒間生存通知がなければリセット)
- 遠隔地に設置したRaspberry Piの「死にっぱなし」を防ぎます。

## 🎯 動作環境

- **ハードウェア**: Raspberry Pi 5 (Pi 4や3でも動作する可能性があります)
- **OS**: Raspberry Pi OS (Debian Bookwormベース / `systemd` および `NetworkManager` 稼働環境)

## 🚀 使い方

Raspberry PiのターミナルにSSH接続し、以下スクリプトを実行してください。
```Bash
git clone https://github.com/maruriki/PI_setup.git
cd PI_setup/
chmod +x setup_system_optimizations.sh
sudo ./setup_system_optimizations.sh
```

## ⚠️ 実行後の重要な注意事項

**Watchdogのハードウェアタイマーを有効にするため、スクリプト実行後は必ずシステムの再起動を行ってください。**
```bash
sudo reboot
```

## 🛠️ トラブルシューティング / 確認用コマンド

スクリプト実行後、設定が正しく反映されているか確認するための便利なコマンドです。

- **ログの容量確認**: `journalctl --disk-usage`
- **過去の起動履歴確認**: `journalctl --list-boots`
- **WiFiのステータス確認**: `nmcli device show wlan0`
- **Watchdogの動作テスト**: 
  以下のコマンドを実行すると意図的にシステムをフリーズ（カーネルパニック）させることができます。約10秒後に自動で再起動がかかればWatchdogは正常に作動しています。
  *(※注意: 保存していないデータは失われます。自己責任で実行してください。)*
  ```bash
  echo c | sudo tee /proc/sysrq-trigger
  ```
