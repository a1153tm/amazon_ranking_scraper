# amazon_ranking_scraper

## セットアップ

### Rubyのインストール(Winddows 64bitのみ記載)

- 以下サイトからRuby 2.1.7 (x64)をダウンロードします
 - http://rubyinstaller.org/downloads/

- ダウンロードしたインストーラを起動しまうす。以下を参考にインストールを進めます
 - http://qiita.com/shimoju/items/41035b213ad0ac3a979e
 - Rubyの実行ファイルへ環境変数PATHを追加するのを忘れないようにします

### アプリケーションのダウンロード

- 以下サイトにアクセスします
 - https://github.com/a1153tm/amazon_ranking_scraper

- [Download ZIP]ボタンをクリックします
 - amazon_ranking_scraperのファイル一式がダウンロードされます

- ダウンロードしたZIPファイルを任意のフォルダに展開します
 - 以下このフォルダを"インストールフォルダ"と記載します

### 必要ライブラリのインストール

- command propmt(Windows)またはターミナル(MAC)を開きます

- bundlerをインストールします。以下コマンドを実行します

```
cd <インストールフォルダ>
gem install bundler
```

- 必要ライブラリをインストールします。以下コマンドを実行します

```
bundle install
```

- 上記コマンドで何もエラーが表示されなければOKです

### Chromeドライバの追加 (WinddowsでChromeを使用する場合)
chromedriver.exe をRubyインストールディレクトリのbin(ex C:¥Ruby21-x64¥bin)にコピーします。

セットアップは以上で終了です。お疲れさまでした。

## 実行方法

以下、US版、日本版をあわせて説明するためus|jaと表記します。
usはUS版、jaは日本版を表します。

### ASINの設定
asin_us|ja.txtにデータを取得するASINを記載します。

### ブラウザ、出力フォーマット、待ち時間の設定
config_us|ja.ymlを適宜書き換えます。 詳細はconfig_us|ja.ymlのコメントを参照。

```
# 使用するブラウザ. "chrome" or "filrefox"
browser: "chrome"

# 出力フォーマット. "txt" or "csv" or "excel"
format: "csv"

# 最大リクエスト回数
max_try: 8

# 基本待ち時間(sec).
# 実際の待ち時間は 20sec × (リクエスト回数 - 1)の2乗 となる
# 20sec, 40sec, 80sec, 160sec,...,2560
wait_time_base: 20
```

### 実行コマンド
```
ruby scrape_mnrate_us|ja.rb
```

