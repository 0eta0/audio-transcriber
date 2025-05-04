# AudioTranscriber

[ダウンロードはこちら](https://github.com/0eta0/audio-transcriber/releases/download/v1.1.0/audio-transcriber.macos.zip)

ローカルで動作する音声文字起こしアプリケーションです。音声ファイル、動画ファイルを選択して文字起こしし、再生中の部分をリアルタイムで強調表示します。

|||
|---|---|
|![モデル選択](docs/image3.webp)|![ファイル選択](docs/image2.webp)|
|![文字起こし](docs/image1.webp)||

## 機能

- 音声ファイル（MP3, WAV, M4A, FLAC, MP4, MOVなど）の読み込み
- OpenAIのWhisperベースのモデルを使用したローカル文字起こし
- 動画、音声の再生、一時停止、シークなどのコントロール
- 動画のウィンドウ内の動画表示
- 再生中のテキスト部分の強調表示
- 文字起こしされたテキストをクリックして該当位置から再生
- 文字起こしされたテキストの保存機能
- 用途に合わせた文字起こしモデルの選択

## 技術仕様

- mlx-whisperを使用したローカル音声認識

## 要件

- macOS 14.6以上
