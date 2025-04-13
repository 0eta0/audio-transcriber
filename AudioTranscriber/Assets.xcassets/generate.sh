#!/bin/bash

SOURCE_ICON=$1
OUTPUT_DIR="AppIcon.appiconset"

if [ -z "$SOURCE_ICON" ]; then
  echo "使い方: $0 <元画像ファイル.png>"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# サイズとファイル名のリスト
icons=(
  "16 1"
  "16 2"
  "32 1"
  "32 2"
  "128 1"
  "128 2"
  "256 1"
  "256 2"
  "512 1"
  "512 2"
)

for icon in "${icons[@]}"; do
  size=$(echo $icon | cut -d' ' -f1)
  scale=$(echo $icon | cut -d' ' -f2)
  pixels=$((size * scale))
  filename="icon_${size}x${size}@${scale}x.png"
  convert "$SOURCE_ICON" -resize ${pixels}x${pixels} "$OUTPUT_DIR/$filename"
done

# Contents.json の生成
cat > "$OUTPUT_DIR/Contents.json" <<EOF
{
  "images": [
    $(for icon in "${icons[@]}"; do
        size=$(echo $icon | cut -d' ' -f1)
        scale=$(echo $icon | cut -d' ' -f2)
        echo "{
      \"size\": \"${size}x${size}\",
      \"idiom\": \"mac\",
      \"filename\": \"icon_${size}x${size}@${scale}x.png\",
      \"scale\": \"${scale}x\"
    },"
      done | sed '$ s/,$//')
  ],
  "info": {
    "version": 1,
    "author": "xcode"
  }
}
EOF

echo "✅ アイコンセットを $OUTPUT_DIR に生成しました。"
