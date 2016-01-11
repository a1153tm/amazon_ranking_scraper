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

- 以下コマンドを実行します

```
cd <インストールフォルダ>
bundle install
```

- 上記コマンドで何もエラーが表示されなければOKです

セットアップは以上で終了です。お疲れさまでした。

## 実行方法

### ASINの設定
asin.txtにデータを取得するASINを記載します。

### CSVに出力する場合
```
ruby scrape_mnrate.rb
```

### Excelに出力する場合
```
ruby scrape_mnrate.rb excel
```
