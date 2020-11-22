#!/bin/zsh

# radiko法則局ID radiko.jp/#!/live/ここに記載されるIDを以下の変数に転記
radio_id=NACK5
# 日時yyyymmddhhmmssss
start_at=20201123000000
end_at=20201123003000 
# 保存タイトル
title="TEST"
# 保存先
dir=~/Desktop/hobby
./radiko-dl.sh -id $radio_id -ft $start_at -to $end_at -n $title -o $dir
