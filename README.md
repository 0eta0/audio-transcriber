# AudioTranscriber

[ダウンロードはこちら](https://github.com/0eta0/audio-transcriber/releases/download/v1.0.0/audio-transcriber.macos.zip)

ローカルで動作する音声文字起こしアプリケーションです。音声ファイルを選択して文字起こしし、再生中の部分をリアルタイムで強調表示します。

|||
|---|---|
|![モデル選択](docs/image1.webp)|![ファイル選択](docs/image2.webp)|
|![文字起こし](docs/image3.webp)||

## 機能

- 音声ファイル（MP3, WAV, M4A, FLACなど）の読み込み
- Open AIのWhisperベースのモデルを使用したローカル文字起こし
- 音声の再生、一時停止、シークなどのコントロール
- 再生中のテキスト部分の強調表示
- 文字起こしされたテキストをクリックして該当位置から再生
- 文字起こしされたテキストの保存機能

## 技術仕様

- mlx-whisperを使用したローカル音声認識

## 要件

- macOS 14.6以上
