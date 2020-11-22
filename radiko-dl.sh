#!/bin/zsh

dir=~/Desktop
area='off'

# オプションを取得
while [ $# -gt 0 ]
do
    case $1 in
        -id) shift; id="$1" ;;
        -ft) shift; ft="$1" ;;
        -to) shift; to="$1" ;;
        -n) shift; program="$1" ;;
        -o) shift; dir="$1" ;;
        -a) area='on' ;;
        *) break ;;
    esac
    shift
done

# ファイル名を決める
if [ -z "$program" ]; then
    filename=`echo "$id"_"$ft"`
else
    filename=`echo ${program}`    
fi

# フォルダへ移動
if [ -d "$dir" ]; then
    cd "$dir"
else
    mkdir "$dir"
    cd "$dir"
fi

# 必要書類をそろえる
if ! [ -e 'myplayer-release.swf' ]; then
    curl -O http://radiko.jp/apps/js/flash/myplayer-release.swf
fi
if ! [ -e 'authkey.png' ]; then
    swfextract myplayer-release.swf -b 12 -o authkey.png
fi

# 承認ひとつめ
auth1=`curl 'https://radiko.jp/v2/api/auth1_fms' \
    -XPOST \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H 'Referer: http://radiko.jp/' \
    -H 'Pragma: no-cache' \
    -H 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/11.1 Safari/605.1.15' \
    -H 'X-Radiko-Device: pc' \
    -H 'X-Radiko-App-Version: 4.0.0' \
    -H 'X-Radiko-User: test-stream' \
    -H 'X-Radiko-App: pc_ts' \
    --data $'\r\n'`

authtoken=`echo "${auth1}" | grep -i 'x-radiko-authtoken' | awk -F'[=]' '{print$2}' | tr -d "\r"`
token=`echo "${auth1}" | grep -i 'x-radiko-authtoken' | awk -F'[=]' '{print$1}' | tr -d "\r"`
length=`echo "${auth1}" | grep -i 'x-radiko-keylength' | awk -F'[=]' '{print$2}' | tr -d "\r"`
offset=`echo "${auth1}" | grep -i 'x-radiko-keyoffset' | awk -F'[=]' '{print$2}' | tr -d "\r"`

partialkey=`dd if=authkey.png ibs=1 skip=${offset} count=${length} 2> /dev/null | base64`

# 承認ふたつめ
curl 'https://radiko.jp/v2/api/auth2_fms' \
    -XPOST \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H 'Referer: http://radiko.jp/' \
    -H 'Pragma: no-cache' \
    -H 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/11.1 Safari/605.1.15' \
    -H 'X-Radiko-Device: pc' \
    -H $token': '$authtoken \
    -H 'X-Radiko-App-Version: 4.0.0' \
    -H 'X-Radiko-User: test-stream' \
    -H 'X-Radiko-Partialkey: '$partialkey \
    -H 'X-Radiko-App: pc_ts' > auth2

# エリアを表示して終了
if [ "$area" = 'on' ]; then
    cat auth2 | tr -d '\r' | grep -v ^$ | awk -F'[,]' '{print $1}'
    exit 0
fi

# オプションがそろっているかチェック
if [ -z "$id" -o -z "$ft" -o -z "$to" ]; then
    echo '-id 放送局ID -ft 開始時間（20190430133000） -to 終了時間'
    exit 1
fi

# 放送済みかどうかチェック
now=`date +%Y%m%d%H%m%S`
if [ $to -ge $now ]; then
    echo '放送終了前です'
    exit 0
fi

# ダウンロード
ffmpeg \
    -loglevel fatal \
    -content_type 'application/x-www-form-urlencoded' \
    -headers 'Referer: http://radiko.jp/' \
    -headers 'Pragma: no-cache' \
    -headers 'X-Radiko-AuthToken: '$authtoken \
    -i 'https://radiko.jp/v2/api/ts/playlist.m3u8?station_id='$id'&l=15&ft='$ft'&to='$to \
    -bsf:a aac_adtstoasc -acodec copy "${filename}".m4a

# 通知など出してみる
osascript -e 'display notification "'"$filename"' 完了しました" with title "radiko-dl.sh" sound name "Glass"'
