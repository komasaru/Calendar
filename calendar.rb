#! /usr/local/bin/ruby
# coding: utf-8
#=カレンダー情報
#   ：カレンダー情報を取得する
#
# date          name            version
# 2011.08.30    mk-mode         1.00 新規作成
# 2012.11.06    mk-mode         1.01 Ruby らしく整形＆微修正
#                                    (アルゴリズムの変更は無し)
# 2012.11.19    mk-mode         1.02 朔日行列から旧暦を求める部分のバグ改修
#                                    (高野氏AWKのバグ部分)
# 2015.12.13    mk-mode         1.03 休日に「山の日（8月11日）」を追加
# 2016.01.03    mk-mode         1.04 コーディング再整形
# 2016.03.03    mk-mode         1.05 地球自転遅れ補正値ΔTの計算機能を追加
#                                    Ref: [NASA - Polynomial Expressions for Delta T](http://eclipse.gsfc.nasa.gov/SEhelp/deltatpoly2004.html)
# 2016.03.07    mk-mode         1.06 うるう秒挿入が明確な場合の処理を追加
#
# Copyright(C) 2011-2016 mk-mode.com All Rights Reserved.
#---------------------------------------------------------------------------------
# 原典 : 「旧暦計算サンプルプログラム」
#        Copyright (C) 1993,1994 by H.Takano
#        http://www.vector.co.jp/soft/dos/personal/se016093.html
#
# ※・このRubyスクリプトの計算結果は無保証です。
#   ・このRubyスクリプトはフリーソフトであり、自由に再利用・改良を行ってかまいませ
#     んが、旧暦計算アルゴリズム部分についての著作権は原典の jgAWK版を開発された高
#     野英明氏に帰属しています。上記のリンクより高野氏の「QRSAMP」を取得し、そのド
#     キュメント内に書かれている再配布規定に従ってください。
#   ・旧暦計算アルゴリズム部分以外(休日・曜日・干支・二十四節気・雑節・節句・月齢)
#     についての著作権は mk-mode.comに帰属します。個人的に再利用・改良を行ってもか
#     まいませんし、再配布について一方的に拒否することはありませんが、念のためご一
#     報だけください。( MAIL : postmaster@mk-mode.com )
#---------------------------------------------------------------------------------
# 引数 :  [ オプション ] a : 曜日
#                        b : 休日
#                        c : ユリウス通日
#                        d : 干支
#                        e : 旧暦
#                        f : 六曜
#                        g : 二十四節気
#                        h : 雑節
#                        i : 節句
#                        j : 黄経(太陽)
#                        k : 黄経(月)
#                        l : 月齢
#             上記の半角小文字アルファベットが指定可能です。
#             無指定なら全指定と判断します。
#
#         [ 計算日付 ]   新暦 ( グレゴリオ暦 ) [ 半角８桁数字 ]
#             新暦(グレゴリオ暦)を半角８桁数字で指定します。
#             無指定なら当日(システム日付)と判断します。
#
# 引数パターン :  +------------+------------+
#                 |  第１引数  |  第２引数  |
#                 +------------+------------+
#                 |     無     |     無     |
#                 +------------+------------+
#                 |  ８桁数字  |     無     |
#                 +------------+------------+
#                 |  半角英字  |     無     |
#                 +------------+------------+
#                 |  半角英字  |  ８桁数字  |
#                 +------------+------------+
#---------------------------------------------------------------------------------
# 注意 : この Ruby スクリプトは Linux Mint, CentOS 等で動作確認しております。
#        Ruby の動作可能な環境であれば動作すると思いますが、他の環境で動作させるた
#        めには文字コード等の変更が必要となる場合があります。
#---------------------------------------------------------------------------------
#+
require 'date'

class Calendar
  USAGE    = "引数指定 : [ 半角英字 ( abcdefghijkl ) ] [ 半角数字(８桁) ] "
  OPTION   = "abcdefghijkl"           # オプション初期値
  PI       = 3.141592653589793238462  # 円周率の定義
  K        = PI / 180.0               # （角度の）度からラジアンに変換する係数の定義
  YOBI     = ["日", "月", "火", "水", "木", "金", "土"]
  ROKUYO   = ["大安", "赤口", "先勝", "友引", "先負", "仏滅"]
  KAN      = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
  SHI      = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
  SEKKI_24 = ["春分", "清明", "穀雨", "立夏", "小満", "芒種",
              "夏至", "小暑", "大暑", "立秋", "処暑", "白露",
              "秋分", "寒露", "霜降", "立冬", "小雪", "大雪",
              "冬至", "小寒", "大寒", "立春", "雨水", "啓蟄"]
  SEKKU    = [[0, 1, 7, "人日"],
              [1, 3, 3, "上巳"],
              [2, 5, 5, "端午"],
              [3, 7, 7, "七夕"],
              [4, 9, 9, "重陽"]]
  ZASSETSU = ["節分"      , "彼岸入(春)", "彼岸(春)"  , "彼岸明(春)",
              "社日(春)"  , "土用入(春)", "八十八夜"  , "入梅"      ,
              "半夏生"    , "土用入(夏)", "二百十日"  , "二百二十日",
              "彼岸入(秋)", "彼岸(秋)"  , "彼岸明(秋)", "社日(秋)"  ,
              "土用入(秋)", "土用入(冬)"]
  HOLIDAY  = [[ 0,  1,  1, 99, "元日"        ],
              [ 1,  1, 99, 21, "成人の日"    ],
              [ 2,  2, 11, 99, "建国記念の日"],
              [ 3,  3, 99, 80, "春分の日"    ],
              [ 4,  4, 29, 99, "昭和の日"    ],
              [ 5,  5,  3, 99, "憲法記念日"  ],
              [ 6,  5,  4, 99, "みどりの日"  ],
              [ 7,  5,  5, 99, "こどもの日"  ],
              [ 8,  7, 99, 31, "海の日"      ],
              [ 9,  8, 11, 99, "山の日"      ],
              [10,  9, 99, 31, "敬老の日"    ],
              [11,  9, 99, 81, "秋分の日"    ],
              [12, 10, 99, 21, "体育の日"    ],
              [13, 11,  3, 99, "文化の日"    ],
              [14, 11, 23, 99, "勤労感謝の日"],
              [15, 12, 23, 99, "天皇誕生日"  ],
              [90, 99, 99, 99, "国民の休日"  ],
              [91, 99, 99, 99, "振替休日"    ]]

  def initialize
    @err_msg = ""                           # エラーメッセージ
    @option  = OPTION                       # オプション
    @date    = Time.now.strftime("%Y%m%d")  # 年月日
    @hash    = Hash.new                     # 取得データ格納用
  end

  def exec
    begin
      # 引数チェック ( エラーなら終了 )
      err_msg = check_arg
      unless err_msg == ""
        $stderr.puts "[ERROR] #{err_msg}"
        exit 1
      end

      init_data  # データ初期化
      get_data   # データ取得
      display    # 結果出力
    rescue => e
      $stderr.puts "[#{e.class}] #{e.message}"
      e.backtrace.each { |tr| $stderr.puts "\t#{tr}" }
      exit 1
    end
  end

private

  # 引数チェック
  def check_arg
    # [ 第１引数 ] 存在する場合
    unless ARGV[0].nil?
      # 正規チェック ( １文字以上の半角英字 )
      if ARGV[0].to_s =~ /^[abcdefghijkl]+$/
        @option = ARGV[0].to_s
        # [ 第２引数 ] 存在する場合
        unless ARGV[1].nil?
          # 正規チェック ( ８桁の半角数字 )
          return USAGE unless ARGV[1].to_s =~ /^\d{8}$/
          @date = ARGV[1].to_s
        end
      # 正規チェック ( ８桁の半角数字 )
      elsif ARGV[0].to_s =~ /^\d{8}$/
        # [ 第２引数 ] 存在する場合
        return USAGE unless ARGV[1].nil?
        @date = ARGV[0].to_s
      # １文字以上の半角英字でも８桁の半角数字でもない場合
      else
        return USAGE
      end
    end

    # 日付妥当性チェック
    @year  = @date[0,4].to_i
    @month = @date[4,2].to_i
    @day   = @date[6,2].to_i
    unless Date.valid_date?(@year, @month, @day)
      return "引数指定 : 妥当な日付ではありません。"
    end
    return ""
  rescue => e
    raise
  end

  # データ初期化
  def init_data
    @yobi     = init_yobi      # 曜日
    @rokuyo   = init_rokuyo    # 六曜
    @kanshi   = init_kanshi    # 干支
    @sekki24  = init_24sekki   # 二十四節気
    @sekku    = init_sekku     # 節句
    @zassetsu = init_zassetsu  # 雑節
    @holiday  = init_holiday   # 休日
    # グレゴリオ暦からユリウス通日を計算
    @jd = gc_to_jd({
      year:  @year,
      month: @month,
      day:   @day,
      hour:  0,
      min:   0,
      sec:   0
    })
  rescue => e
    raise
  end

  # データ初期化（曜日）
  def init_yobi
    return YOBI
  end

  # データ初期化（六曜）
  def init_rokuyo
    return ROKUYO
  end

  # データ初期化（干支）
  def init_kanshi
    ary_kan, ary_shi, ary_kanshi = Array.new, Array.new, Array.new

    begin
      KAN.each { |col| ary_kan << col.to_s }
      SHI.each { |col| ary_shi << col.to_s }
      0.upto(59) do |i|
        ary_kanshi << ary_kan[i % 10] + ary_shi[i % 12 ]
      end
      return ary_kanshi
    rescue => e
      raise
    end
  end

  # データ初期化（二十四節気）
  def init_24sekki
    return SEKKI_24
  end

  # データ初期化（節句）
  def init_sekku
    return SEKKU
  end

  # データ初期化（雑節）
  def init_zassetsu
    return ZASSETSU
  end

  # データ初期化（休日）
  def init_holiday
    return HOLIDAY
  end

  # データ取得
  def get_data
    @hash[:holiday ] = calc_holiday              # 休日
    @hash[:sekki24 ] = calc_sekki_24(@jd)        # 二十四節気
    @hash[:zassetsu] = calc_zassetsu             # 雑節
    @hash[:yobi    ] = calc_yobi(@jd)            # 曜日
    @hash[:kanshi  ] = calc_kanshi(@jd)          # 干支
    @hash[:sekku   ] = calc_sekku                # 節句
    @hash[:lon_sun ] = calc_longitude_sun(@jd)   # 黄経（太陽）
    @hash[:lon_moon] = calc_longitude_moon(@jd)  # 黄経（月）
    @hash[:moon_age] = calc_moon_age_noon(@jd)   # 月例
    res = calc_oc                                # 旧暦
    @hash[:oc_y    ] = res[0]                    # - 年
    @hash[:oc_l    ] = res[1]                    # - 閏月フラグ
    @hash[:oc_m    ] = res[2]                    # - 月
    @hash[:oc_d    ] = res[3]                    # - 日
    @hash[:rokuyo  ] = calc_rokuyo(@hash[:oc_m], @hash[:oc_d])  # 六曜
  rescue => e
    raise
  end

  # 休日の計算
  def calc_holiday
    ary_holiday_0 = Array.new  # 変動の祝日用
    ary_holiday_1 = Array.new  # 国民の休日用
    ary_holiday_2 = Array.new  # 振替休日用

    begin
      # 変動の祝日の日付･曜日を計算 ( 振替休日,国民の休日を除く )
      @holiday.each do |holiday|
        unless holiday[1] == 99
          unless holiday[2] == 99   # 月日が既定のもの
            jd = gc_to_jd({
              year: @year, month: holiday[1], day: holiday[2],
              hour: 0, min: 0, sec: 0
            })
            yobi = calc_yobi(jd)
            ary_holiday_0 << [holiday[1], holiday[2], holiday[0], jd, yobi]
          else                      # 月日が不定のもの
            if holiday[3] == 21     # 第2月曜日 ( 8 - 14 の月曜日)
              8.upto(14) do |day|
                jd = gc_to_jd({
                  year: @year, month: holiday[1], day: day,
                  hour: 0, min: 0, sec: 0
                })
                yobi = calc_yobi(jd)
                ary_holiday_0 << [holiday[1], day, holiday[0], jd, 1] if yobi == 1
              end
            elsif holiday[3] == 31  # 第3月曜日 ( 15 - 21 の月曜日)
              15.upto(21) do |day|
                jd = gc_to_jd({
                  year: @year, month: holiday[1], day: day,
                  hour: 0, min: 0, sec: 0
                })
                yobi = calc_yobi(jd)
                ary_holiday_0 << [holiday[1], day, holiday[0], jd, 1] if yobi == 1
              end
            elsif holiday[3] == 80  # 春分の日
              jd = gc_to_jd({
                year: @year, month: holiday[1], day: 31,
                hour: 0, min: 0, sec: 0
              })
              nibun_jd = calc_last_nibun_chu(jd, 90)[0]
              day = jd_to_ymdt(nibun_jd)[2]
              wk_jd = gc_to_jd({
                year: @year, month: holiday[1], day: day,
                hour: 0, min: 0, sec: 0
              })
              yobi = calc_yobi(wk_jd)
              ary_holiday_0 << [holiday[1], day, holiday[0], wk_jd, yobi]
            elsif holiday[3] == 81  # 秋分の日
              jd = gc_to_jd({
                year: @year, month: holiday[1], day: 30,
                hour: 0, min: 0, sec: 0
              })
              nibun_jd = calc_last_nibun_chu(jd, 90)[0]
              day = jd_to_ymdt(nibun_jd)[2]
              wk_jd = gc_to_jd({
                year: @year, month: holiday[1], day: day,
                hour: 0, min: 0, sec: 0
              })
              yobi = calc_yobi(wk_jd)
              ary_holiday_0 << [holiday[1], day, holiday[0], wk_jd, yobi]
            end
          end
        end
      end

      # 国民の休日計算
      # ( 「国民の祝日」で前後を挟まれた「国民の祝日」でない日 )
      # ( 年またぎは考慮していない(今のところ不要) )
      0.upto(ary_holiday_0.length - 2) do |i|
        if ary_holiday_0[i][3] + 2 == ary_holiday_0[i+1][3]
          jd = ary_holiday_0[i][3] + 1
          yobi = (ary_holiday_0[i][4] + 1) == 7 ? 0 : (ary_holiday_0[i][4] + 1)
          wk_ary = Array.new
          wk_ary << jd_to_ymdt(jd)[1]
          wk_ary << jd_to_ymdt(jd)[2]
          wk_ary << 90
          wk_ary << jd
          wk_ary << yobi
          ary_holiday_1 << wk_ary
        end 
      end

      # 振替休日計算
      # ( 「国民の祝日」が日曜日に当たるときは、
      #   その日後においてその日に最も近い「国民の祝日」でない日 )
      0.upto(ary_holiday_0.length - 1) do |i|
        if ary_holiday_0[i][4] == 0
          next_jd = ary_holiday_0[i][3] + 1
          next_yobi = (ary_holiday_0[i][4] + 1) == 7 ? 0 : (ary_holiday_0[i][4] + 1)
          if i == ary_holiday_0.length - 1
            wk_ary = Array.new
            wk_ary << jd_to_ymdt(next_jd)[1]
            wk_ary << jd_to_ymdt(next_jd)[2]
            wk_ary << 91
            wk_ary << next_jd
            wk_ary << next_yobi
          else
            flg_furikae = 0
            plus_day = 1
            while flg_furikae == 0
              if i + plus_day < ary_holiday_0.length
                if next_jd == ary_holiday_0[i + plus_day][3]
                  next_jd += 1
                  next_yobi = (next_yobi + 1) == 7 ? 0 : (next_yobi + 1)
                  plus_day += 1
                else
                  flg_furikae = 1
                  wk_ary = Array.new
                  wk_ary << jd_to_ymdt(next_jd)[1]
                  wk_ary << jd_to_ymdt(next_jd)[2]
                  wk_ary << 91
                  wk_ary << next_jd
                  wk_ary << next_yobi
                end
              end
            end
          end
          ary_holiday_2 << wk_ary
        end
      end

      # ary_holiday_0, ary_holiday_1, ary_holiday_2 を結合
      ary_holiday_all = ary_holiday_0 + ary_holiday_1 + ary_holiday_2
      ary_holiday_all = ary_holiday_all.sort

      # 配列整理
      code_holiday = 99
      ary_holiday_all.each do |holiday|
        if holiday[0] == @month &&  holiday[1] == @day
          code_holiday = holiday[2]
          break
        end
      end
      return code_holiday
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 引数で与えられたユリウス通日(JD)の二十四節気を計算する
  #   [ 引数 ]
  #     jd : ユリウス通日
  #   [ 戻り値 ]
  #     sekki_24 : 二十四節気の黄経 ( 太陽 )
  #                ( 二十四節気でなければ、999 )
  #   ※基点ユリウス日(2451545)：2000/1/2/0/0/0(年/月/日/時/分/秒…世界時)
  #=========================================================================
  def calc_sekki_24(jd)
    # 計算対象日の太陽の黄経
    lsun_today = calc_longitude_sun(jd)

    # 計算対象日の翌日のユリウス日
    jd  += 1
    lsun_tomorrow = calc_longitude_sun(jd)

    lsun_today0    = 15 * (lsun_today / 15.0).truncate
    lsun_tomorrow0 = 15 * (lsun_tomorrow / 15.0).truncate
    return lsun_today0 == lsun_tomorrow0 ? 999 : lsun_tomorrow0
  rescue => e
    raise
  end

  #=========================================================================
  # 引数からの雑節を求める
  #   [ 引数 ]
  #     なし
  #   [ 戻り値 ] ( hash )
  #     z_1 : 雑節のｺｰﾄﾞ
  #     z_2 : 雑節のｺｰﾄﾞ(同日に複数の雑節がある場合)
  #   ※基点ユリウス日(2451545)：2000/1/2/0/0/0(年/月/日/時/分/秒…世界時)
  #=========================================================================
  def calc_zassetsu
    # 社日は他の雑節と重なる可能性があるので、
    # 重なる場合はzassetu_2を使用する。
    z_1 = 99
    z_2 = 99

    begin
      # 計算対象日の太陽の黄経
      lsun_today = calc_longitude_sun(@jd)

      # 計算対象日の翌日の太陽の黄経
      lsun_tomorrow = calc_longitude_sun(@jd + 1)

      # 計算対象日の5日前の太陽の黄経(社日計算用)
      lsun_before_5 = calc_longitude_sun(@jd - 5)

      # 計算対象日の4日前の太陽の黄経(社日計算用)
      lsun_before_4 = calc_longitude_sun(@jd - 4)

      # 計算対象日の5日後の太陽の黄経(社日計算用)
      lsun_after_5 = calc_longitude_sun(@jd + 5)

      # 計算対象日の6日後の太陽の黄経(社日計算用)
      lsun_after_6 = calc_longitude_sun(@jd + 6)

      # 太陽の黄経の整数部分( 土用, 入梅, 半夏生 計算用 )
      lsun_today0    = lsun_today.truncate
      lsun_tomorrow0 = lsun_tomorrow.truncate

      #### ここから各種雑節計算
      # 0:節分 ( 立春の前日 )
      sekki_24 = calc_sekki_24(@jd + 1)
      z_1 = 0 if sekki_24 == 315  # 立春の黄経(太陽)

      # 1:彼岸入（春） ( 春分の日の3日前 )
      sekki_24 = calc_sekki_24(@jd + 3)
      z_1 = 1 if sekki_24 == 0    # 春分の日の黄経(太陽)

      # 2:彼岸（春） ( 春分の日 )
      sekki_24 = calc_sekki_24(@jd)
      z_1 = 2 if sekki_24 == 0    # 春分の日の黄経(太陽)

      # 3:彼岸明（春） ( 春分の日の3日後 )
      sekki_24 = calc_sekki_24(@jd - 3)
      z_1 = 3 if sekki_24 == 0    # 春分の日の黄経(太陽)

      # 4:社日（春） ( 春分の日に最も近い戊(つちのえ)の日 )
      # * 計算対象日が戊の日の時、
      #   * 4日後までもしくは4日前までに春分の日がある時、
      #       この日が社日
      #   * 5日後が春分の日の時、
      #       * 春分点(黄経0度)が午前なら
      #           この日が社日
      #       * 春分点(黄経0度)が午後なら
      #           この日の10日後が社日
      if (@jd % 10).truncate == 4  # 戊の日
        # [ 当日から4日後 ]
        0.upto(4) do |i|
          sekki_24 = calc_sekki_24(@jd + i)
          if sekki_24 == 0  # 春分の日の黄経(太陽)
            if z_1 == 99
              z_1 = 4
            else
              z_2 = 4
            end
            break
          end
        end
        # [ 1日前から4日前 ]
        1.upto(4) do |i|
          sekki_24 = calc_sekki_24(@jd - i)
          if sekki_24 == 0  # 春分の日の黄経(太陽)
            if z_1 == 99
              z_1 = 4
            else
              z_2 = 4
            end
            break
          end
        end
        # [ 5日後 ]
        sekki_24 = calc_sekki_24(@jd + 5)
        if sekki_24 == 0  # 春分の日の黄経(太陽)
          # 春分の日の黄経(太陽)と翌日の黄経(太陽)の中間点が
          # 0度(360度)以上なら、春分点が午前と判断
          if (lsun_after_5 + lsun_after_6 + 360) / 2.0 >= 360
            if z_1 == 99
              z_1 = 4
            else
              z_2 = 4
            end
          end
        end
        # [ 5日前 ]
        sekki_24 = calc_sekki_24(@jd - 5)
        if sekki_24 == 0  # 春分の日の黄経(太陽)
          # 春分の日の黄経(太陽)と翌日の黄経(太陽)の中間点が
          # 0度(360度)未満なら、春分点が午後と判断
          if (lsun_before_4 + lsun_before_5 + 360) / 2.0 < 360
            if z_1 == 99
              z_1 = 4
            else
              z_2 = 4
            end
          end
        end
      end

      # 5:土用入（春） ( 黄経(太陽) = 27度 )
      unless lsun_today0 == lsun_tomorrow0
        z_1 = 5 if lsun_tomorrow0 == 27
      end

      # 6:八十八夜 ( 立春から88日目(87日後) )
      sekki_24 = calc_sekki_24(@jd - 87)
      z_1 = 6 if sekki_24 == 315  # 立春の黄経(太陽)

      # 7:入梅 ( 黄経(太陽) = 80度 )
      unless lsun_today0 == lsun_tomorrow0
        z_1 = 7 if lsun_tomorrow0 == 80
      end

      # 8:半夏生  ( 黄経(太陽) = 100度 )
      unless lsun_today0 == lsun_tomorrow0
        z_1 = 8 if lsun_tomorrow0 == 100
      end

      # 9:土用入（夏） ( 黄経(太陽) = 117度 )
      unless lsun_today0 == lsun_tomorrow0
        z_1 = 9 if lsun_tomorrow0 == 117
      end

      # 10:二百十日 ( 立春から210日目(209日後) )
      sekki_24 = calc_sekki_24(@jd - 209)
      z_1 = 10 if sekki_24 == 315  # 立春の黄経(太陽)

      # 11:二百二十日 ( 立春から220日目(219日後) )
      sekki_24 = calc_sekki_24(@jd - 219)
      z_1 = 11 if sekki_24 == 315  # 立春の黄経(太陽)

      # 12:彼岸入（秋） ( 秋分の日の3日前 )
      sekki_24 = calc_sekki_24(@jd + 3)
      z_1 = 12 if sekki_24 == 180  # 秋分の日の黄経(太陽)

      # 13:彼岸（秋）   ( 秋分の日 )
      sekki_24 = calc_sekki_24(@jd)
      z_1 = 13 if sekki_24 == 180  # 秋分の日の黄経(太陽)

      # 14:彼岸明（秋） ( 秋分の日の3日後 )
      sekki_24 = calc_sekki_24(@jd - 3)
      z_1 = 14 if sekki_24 == 180  # 春分の日の黄経(太陽)

      # 15:社日（秋） ( 秋分の日に最も近い戊(つちのえ)の日 )
      # * 計算対象日が戊の日の時、
      #   * 4日後までもしくは4日前までに秋分の日がある時、
      #       この日が社日
      #   * 5日後が秋分の日の時、
      #       * 秋分点(黄経180度)が午前なら
      #           この日が社日
      #       * 秋分点(黄経180度)が午後なら
      #           この日の10日後が社日
      if (@jd % 10).truncate == 4 # 戊の日
        # [ 当日から4日後 ]
        0.upto(4) do |i|
          sekki_24 = calc_sekki_24(@jd + i)
          if sekki_24 == 180  # 秋分の日の黄経(太陽)
            if z_1 == 99
              z_1 = 15
            else
              z_2 = 15
            end
            break
          end
        end
        # [ 1日前から4日前 ]
        1.upto(4) do |i|
          sekki_24 = calc_sekki_24(@jd - i)
          if sekki_24 == 180  # 秋分の日の黄経(太陽)
            if z_1 == 99
              z_1 = 15
            else
              z_2 = 15
            end
            break
          end
        end
        # [ 5日後 ]
        sekki_24 = calc_sekki_24(@jd + 5)
        if sekki_24 == 180  # 秋分の日の黄経(太陽)
          # 秋分の日の黄経(太陽)と翌日の黄経(太陽)の中間点が
          # 180度以上なら、秋分点が午前と判断
          if (lsun_after_5 + lsun_after_6) / 2.0 >= 180
            if z_1 == 99
              z_1 = 15
            else
              z_2 = 15
            end
          end
        end
        # [ 5日前 ]
        sekki_24 = calc_sekki_24(@jd - 5)
        if sekki_24 == 180  # 秋分の日の黄経(太陽)
          # 秋分の日の黄経(太陽)と翌日の黄経(太陽)の中間点が
          # 180度未満なら、秋分点が午後と判断
          if (lsun_before_4 + lsun_before_5) / 2.0 < 180
            if z_1 == 99
              z_1 = 15
            else
              z_2 = 15
            end
          end
        end
      end

      # 16:土用入（秋） ( 黄経(太陽) = 207度 )
      unless lsun_today0 == lsun_tomorrow0
        z_1 = 16 if lsun_tomorrow0 == 207
      end

      # 17:土用入（冬） ( 黄経(太陽) = 297度 )
      unless lsun_today0 == lsun_tomorrow0
        z_1 = 17 if lsun_tomorrow0 == 297
      end
      return {z_1: z_1, z_2: z_2}
    rescue => e
      raise
    end
  end

  #=========================================================================
  # ユリウス通日(JD)から曜日(GC)を計算する
  #
  #   曜日 = ( ユリウス通日 + 2 ) % 7
  #     0 : 日曜
  #     1 : 月曜
  #     2 : 火曜
  #     3 : 水曜
  #     4 : 木曜
  #     5 : 金曜
  #     6 : 土曜
  #
  #   [ 引数 ]
  #     jd : ユリウス通日
  #
  #   [ 戻り値 ]
  #     yobi ( 曜日 ( 0 - 6 ) )
  #=========================================================================
  def calc_yobi(jd)
    return ((jd + 2) % 7).to_i
  rescue => e
    raise
  end

  #=========================================================================
  # ユリウス通日から干支(日)を計算する
  #
  #   [ 引数 ]
  #     jd : ユリウス通日
  #
  #   [ 戻り値 ]
  #     kanshi ( 干支 ( 0(甲子) - 59(癸亥) ) )
  #     ※[ ユリウス通日 - 10日 ] を60で割った剰余
  #=========================================================================
  def calc_kanshi(jd)
    return ((jd - 10) % 60).truncate
  rescue => e
    raise
  end

  #=========================================================================
  # 指定の日付(グレゴリオ暦[月,日])の節句を求める
  #   [ 引数 ]
  #     なし
  #   [ 戻り値 ]
  #     sekku : 節句のｺｰﾄﾞ
  #   ※基点ユリウス日(2451545)：2000/1/2/0/0/0(年/月/日/時/分/秒…世界時)
  #=========================================================================
  def calc_sekku
    sekku = 9

    begin
      @sekku.each do |wk_sekku|
        if wk_sekku[1] == @month && wk_sekku[2] == @day
          sekku = wk_sekku[0]
          break
        end
      end

      return sekku
    rescue => e
      raise
    end
  end

  #=========================================================================
  # ユリウス日(JD)から旧暦を求める
  #
  #   [ 引数 ]
  #     なし
  #
  #   [ 戻り値 ] ( array )
  #     kyureki[0] : 旧暦年
  #     kyureki[1] : 平月／閏月 flag .... 平月:0 閏月:1
  #     kyureki[2] : 旧暦月
  #     kyureki[3] : 旧暦日
  #=========================================================================
  def calc_oc
    tm0 = @jd

    begin
      # 二分二至,中気の時刻･黄経用配列宣言
      chu = Array.new(4).map { Array.new(2, 0) }

      # 朔用配列宣言
      saku = Array.new(5, 0)

      # 朔日用配列宣言
      m = Array.new(5).map { Array.new(3, 0) }

      # 旧暦用配列宣言
      kyureki = Array.new(4, 0)

      # 計算対象の直前にあたる二分二至の時刻を計算
      #   chu[0][0] : 二分二至の時刻
      #   chu[0][1] : その時の太陽黄経
      chu[0] = calc_last_nibun_chu(tm0, 90)

      # 中気の時刻を計算 ( 3回計算する )
      #   chu[i][0] : 中気の時刻
      #   chu[i][1] : その時の太陽黄経
      1.upto(3) do |i|
        chu[i] = calc_last_nibun_chu(chu[i - 1][0] + 32, 30)
      end

      # 計算対象の直前にあたる二分二至の直前の朔の時刻を求める
      saku[0] = calc_saku(chu[0][0])

      # 朔の時刻を求める
      1.upto(4) do |i|
        tm  = saku[i-1]
        tm += 30
        saku[i] = calc_saku(tm)
        # 前と同じ時刻を計算した場合( 両者の差が26日以内 )には、初期値を
        # +33日にして再実行させる。
        if (saku[i-1].truncate - saku[i].truncate).abs <= 26
          saku[i] = calc_saku(saku[i-1] + 35)
        end
      end

      # saku[1]が二分二至の時刻以前になってしまった場合には、朔をさかのぼり過ぎ
      # たと考えて、朔の時刻を繰り下げて修正する。
      # その際、計算もれ（saku[4]）になっている部分を補うため、朔の時刻を計算
      # する。（近日点通過の近辺で朔があると起こる事があるようだ...？）
      if saku[1].truncate <= chu[0][0].truncate
        0.upto(3) do |i|
          saku[i] = saku[i+1]
        end
        saku[4] = calc_saku(saku[3] + 35)

      # saku[0]が二分二至の時刻以後になってしまった場合には、朔をさかのぼり足
      # りないと見て、朔の時刻を繰り上げて修正する。
      # その際、計算もれ（saku[0]）になっている部分を補うため、朔の時刻を計算
      # する。（春分点の近辺で朔があると起こる事があるようだ...？）
      elsif saku[0].truncate > chu[0][0].truncate
        4.downto(1) do |i|
          saku[i] = saku[i-1]
        end
        saku[0] = calc_saku(saku[0] - 27)
      end

      # 閏月検索Ｆｌａｇセット
      # （節月で４ヶ月の間に朔が５回あると、閏月がある可能性がある。）
      # leap=0:平月  leap=1:閏月
      leap = 0
      leap = 1 if saku[4].truncate <= chu[3][0].truncate

      # 朔日行列の作成
      # m[i][0] ... 月名 ( 1:正月 2:２月 3:３月 .... )
      # m[i][1] ... 閏フラグ ( 0:平月 1:閏月 )
      # m[i][2] ... 朔日のjd
      m[0][0] = (chu[0][1] / 30.0).truncate + 2
      # ====[2012.11.19 修正]=======>
      #   元の AWK スクリプトからのバグ
      # if m[0][1] > 12
      if m[0][0] > 12
      # <===[2012.11.19 修正]========
        m[0][0] -= 12
      end
      m[0][2] = saku[0].truncate
      m[0][1] = 0

      1.upto(4) do |i|
        if leap == 1 && i != 1
          if chu[i-1][0].truncate <= saku[i-1].truncate ||
             chu[i-1][0].truncate >= saku[i].truncate
            m[i-1][0] = m[i-2][0]
            m[i-1][1] = 1
            m[i-1][2] = saku[i-1].truncate
            leap = 0
          end
        end
        m[i][0] = m[i-1][0] + 1
        if m[i][0] > 12
          m[i][0] -= 12
        end
        m[i][2] = saku[i].truncate
        m[i][1] = 0
      end

      # 朔日行列から旧暦を求める。
      state, index = 0, 0
      0.upto(4) do |i|
        index = i
        if tm0.truncate < m[i][2].truncate
          state = 1
          break
        elsif tm0.truncate == m[i][2].truncate
          state = 2
          break
        end
      end
      # ====[2012.11.19 修正]=======>
      #   元の AWK スクリプトからのバグ
      # if state == 0 || state == 1
      if state == 1
      # <===[2012.11.19 修正]========
        index -= 1
      end
      kyureki[1] = m[index][1]
      kyureki[2] = m[index][0]
      kyureki[3] = tm0.truncate - m[index][2].truncate + 1

      # 旧暦年の計算
      # （旧暦月が10以上でかつ新暦月より大きい場合には、
      #   まだ年を越していないはず...）
      a = jd_to_ymdt(tm0)
      kyureki[0] = a[0]
      if kyureki[2] > 9 && kyureki[2] > a[1]
        kyureki[0] -= 1
      end

      return kyureki
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 年月日(グレゴリオ暦)からユリウス日(JD)を計算する
  #
  #   ﾌﾘｰｹﾞﾙの公式を使用する
  #   [ JD ] = int( 365.25 × year )
  #          + int( year / 400 )
  #          - int( year / 100 )
  #          + int( 30.59 ( month - 2 ) )
  #          + day
  #          + 1721088
  #   ※上記の int( x ) は厳密には、x を超えない最大の整数
  #     ( ちなみに、[ 準JD ]を求めるなら + 1721088 が - 678912 となる )
  #
  #   [ 戻り値 ]
  #     jd ( ユリウス日 )
  #=========================================================================
  def gc_to_jd(hash)
    year  = hash[:year]
    month = hash[:month]
    day   = hash[:day]
    hour  = hash[:hour]
    min   = hash[:min]
    sec   = hash[:sec]

    begin
      # 1月,2月は前年の13月,14月とする
      if month < 3
        year  -= 1
        month += 12
      end

      # 日付(整数)部分計算
      jd  = (365.25 * year).truncate
      jd += (year / 400.0).truncate
      jd -= (year / 100.0).truncate
      jd += (30.59 * (month - 2)).truncate
      jd += day
      jd += 1721088

      # 時間(小数)部分計算
      t  = sec / 3600.0
      t += min / 60.0
      t += hour
      t  = t / 24.0

      return jd + t
    rescue => e
      raise
    end
  end

  #=========================================================================
  # ユリウス日(JD)から年月日、時分秒(世界時)を計算する
  #
  #   [ 引数 ]
  #     jd : ユリウス通日
  #
  #   [ 戻り値 ] ( array )
  #     ymdt[0] ... 年
  #     ymdt[1] ... 月
  #     ymdt[2] ... 日
  #     ymdt[3] ... 時
  #     ymdt[4] ... 分
  #     ymdt[5] ... 秒
  #
  #   ※ この関数で求めた年月日は、グレゴリオ暦法によって表されている。
  #=========================================================================
  def jd_to_ymdt(jd)
    ymdt = Array.new(6, 0)

    begin
      x0 = (jd + 68570).truncate
      x1 = (x0 / 36524.25).truncate
      x2 = x0 - (36524.25 * x1 + 0.75).truncate
      x3 = ((x2 + 1) / 365.2425).truncate
      x4 = x2 - (365.25 * x3).truncate + 31
      x5 = (x4.truncate / 30.59).truncate
      x6 = (x5.truncate / 11.0).truncate

      ymdt[2] = x4 - (30.59 * x5).truncate
      ymdt[1] = x5 - 12 * x6 + 2
      ymdt[0] = 100 * (x1 - 49) + x3 + x6

      # 2月30日の補正
      if ymdt[1]==2 && ymdt[2] > 28
        if ymdt[0] % 100 == 0 && ymdt[0] % 400 == 0
         ymdt[2] = 29
        elsif ymdt[0] % 4 == 0
          ymdt[2] = 29
        else
          ymdt[2] = 28
        end
      end

      tm = 86400 * (jd - jd.truncate)
      ymdt[3] = (tm / 3600.0).truncate
      ymdt[4] = ((tm - 3600 * ymdt[3]) / 60.0).truncate
      ymdt[5] = (tm - 3600 * ymdt[3] - 60 * ymdt[4]).truncate

      return ymdt
    rescue => e
      raise
    end
  end

  #=========================================================================
  # ユリウス日(JD)から直前の二分二至、中気の時刻を求める
  #
  #   [ 引数 ]
  #     jd  : ユリウス日(JD)
  #     kbn : 90 ( 二分二至 ), 30 ( 中気 )
  #
  #   [ 戻り値 ] ( array )
  #     nibun_chu[0] : 二分二至、中気の時刻
  #     nibun_chu[1] : その時の黄経
  #=========================================================================
  def calc_last_nibun_chu(jd, kbn)
    begin
      # 時刻引数を分解
      tm1  = jd.truncate  # 整数部分
      tm2  = jd - tm1     # 小数部分
      tm2 -= 9.0 / 24.0   # JST ==> DT （補正時刻=0.0sec と仮定して計算）

      # 直前の二分二至の黄経 λsun0 を求める
      rm_sun  = calc_longitude_sun(jd)
      rm_sun0 = kbn * (rm_sun / kbn.to_f).truncate

      # 繰り返し計算によって直前の二分二至の時刻を計算する
      # （誤差が±1.0 sec以内になったら打ち切る。）
      delta_t1 = 0 ; delta_t2 = 1
      while (delta_t1 + delta_t2).abs > (1.0 / 86400.0)
        # λsun を計算
        #t = tm1 + tm2 + 0.5
        t = tm1 + tm2 + 9.0 / 24.0
        rm_sun = calc_longitude_sun(t)

        # 黄経差 Δλ＝λsun －λsun0
        delta_rm = rm_sun - rm_sun0

        # Δλの引き込み範囲（±180°）を逸脱した場合には、補正を行う
        if delta_rm > 180
          delta_rm -= 360
        elsif delta_rm < -180
          delta_rm += 360
        end

        # 時刻引数の補正値 Δt
        delta_t1  = (delta_rm * 365.2 / 360.0).truncate
        delta_t2  = delta_rm * 365.2 / 360.0
        delta_t2 -= delta_t1

        # 時刻引数の補正
        # tm -= delta_t
        tm1 = tm1 - delta_t1
        tm2 = tm2 - delta_t2
        if tm2 < 0
          tm2 += 1
          tm1 -= 1
        end
      end

      # 戻り値の作成
      #   nibun_chu[0] : 時刻引数を合成するのと、DT ==> JST 変換を行い、戻り値とする
      #                  ( 補正時刻=0.0sec と仮定して計算 )
      #   nibun_chu[1] : 黄経
      nibun_chu = Array.new(2, 0)
      nibun_chu[0]  = tm2 + 9 / 24.0
      nibun_chu[0] += tm1
      nibun_chu[1]  = rm_sun0
      return nibun_chu
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 与えられた時刻の直近の朔の時刻（JST）を求める
  #
  #   [ 引数 ]
  #     jd  : 計算対象となる時刻 ( ユリウス日 )
  #
  #   [ 戻り値 ]
  #     saku : 朔の時刻
  #
  #   ※ 引数、戻り値ともユリウス日で表し、時分秒は日の小数で表す。
  #=========================================================================
  def calc_saku(jd)
    lc = 1

    begin
      # 時刻引数を分解する
      tm1 = jd.truncate
      tm2 = jd - tm1
      tm2 -= 9 / 24.0

      # 繰り返し計算によって朔の時刻を計算する
      # (誤差が±1.0 sec以内になったら打ち切る。)
      delta_t1 = 0 ; delta_t2 = 1
      while (delta_t1 + delta_t2).abs > (1.0 / 86400.0)
        # 太陽の黄経λsun ,月の黄経λmoon を計算
        t = tm1 + tm2 + 9 / 24.0
        rm_sun  = calc_longitude_sun(t)
        rm_moon = calc_longitude_moon(t)

        # 月と太陽の黄経差Δλ
        # Δλ＝λmoon－λsun
        delta_rm = rm_moon - rm_sun

        # ﾙｰﾌﾟの1回目 ( lc = 1 ) で delta_rm < 0.0 の場合には引き込み範囲に
        # 入るように補正する
        if lc == 1 && delta_rm < 0
          delta_rm = normalize_angle(delta_rm)

        #   春分の近くで朔がある場合 ( 0 ≦λsun≦ 20 ) で、月の黄経λmoon≧300 の
        #   場合には、Δλ＝ 360.0 － Δλ と計算して補正する
        elsif rm_sun >= 0 && rm_sun <= 20 && rm_moon >= 300
          delta_rm = normalize_angle(delta_rm)
          delta_rm = 360 - delta_rm

        # Δλの引き込み範囲 ( ±40° ) を逸脱した場合には、補正を行う
        elsif delta_rm.abs > 40.0
          delta_rm = normalize_angle(delta_rm)
        end

        # 時刻引数の補正値 Δt
        delta_t1  = (delta_rm * 29.530589 / 360.0).truncate
        delta_t2  = delta_rm * 29.530589 / 360.0
        delta_t2 -= delta_t1

        # 時刻引数の補正
        tm1 = tm1 - delta_t1
        tm2 = tm2 - delta_t2
        if tm2 < 0
          tm2 += 1
          tm1 -= 1
        end

        # ループ回数が15回になったら、初期値 tm を tm-26 とする。
        if lc == 15 && (delta_t1 + delta_t2).abs > (1.0 / 86400.0)
          tm1 = (jd - 26).truncate
          tm2 = 0

        # 初期値を補正したにも関わらず、振動を続ける場合には初期値を答えとして
        # 返して強制的にループを抜け出して異常終了させる。
        elsif lc > 30 && (delta_t1+delta_t2).abs > (1.0 / 86400.0)
          tm1 = jd
          tm2 = 0
          break
        end

        # LOOPカウンタインクリメント
        lc += 1
      end

      # 時刻引数を合成するのと、DT ==> JST 変換を行い、戻り値とする
      # （補正時刻=0.0sec と仮定して計算）
      saku = tm2 + tm1 + 9 / 24.0
      return saku
    rescue => e
      raise
    end
  end

  #=========================================================================
  #  角度の正規化を行う。すなわち引数の範囲を ０≦θ＜３６０ にする。
  #=========================================================================
  def normalize_angle(angle)
    begin
      if angle < 0
        angle1  = angle * (-1)
        angle2  = (angle1 / 360.0).truncate
        angle1 -= 360 * angle2
        angle1  = 360 - angle1
      else
        angle1  = (angle / 360.0).truncate
        angle1  = angle - 360.0 * angle1
      end
      return angle1
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 太陽の黄経 λsun 計算
  #=========================================================================
  def calc_longitude_sun(jd)
    begin
      year, month, day, hour, min, sec = jd_to_ymdt(jd)

      # 時分秒から日計算
      t = (hour * 60 * 60 + min * 60 + sec) / 86400.0

      # 地球自転遅れ補正値(日)計算
      #rotate_rev = (calc_dt(year, month, day) + 0.8 * (year - 1990)) / 86400.0
      rotate_rev = calc_dt(year, month, day) / 86400.0  #  国立天文台の 2015 - 2017 のΔT値は 68

      # 2000年1月1日力学時正午からの経過日数(日)計算
      day_progress = calc_day_progress(year, month, day)

      # 経過ユリウス年(日)計算
      # ( 2000.0(2000年1月1日力学時正午)からの経過年数 (年) )
      jy = (day_progress + t + rotate_rev) / 365.25

      # 太陽黄経計算
      rm  = 0.0003 * Math.sin(K * normalize_angle(329.7  +   44.43  * jy))
      rm += 0.0003 * Math.sin(K * normalize_angle(352.5  + 1079.97  * jy))
      rm += 0.0004 * Math.sin(K * normalize_angle( 21.1  +  720.02  * jy))
      rm += 0.0004 * Math.sin(K * normalize_angle(157.3  +  299.30  * jy))
      rm += 0.0004 * Math.sin(K * normalize_angle(234.9  +  315.56  * jy))
      rm += 0.0005 * Math.sin(K * normalize_angle(291.2  +   22.81  * jy))
      rm += 0.0005 * Math.sin(K * normalize_angle(207.4  +    1.50  * jy))
      rm += 0.0006 * Math.sin(K * normalize_angle( 29.8  +  337.18  * jy))
      rm += 0.0007 * Math.sin(K * normalize_angle(206.8  +   30.35  * jy))
      rm += 0.0007 * Math.sin(K * normalize_angle(153.3  +   90.38  * jy))
      rm += 0.0008 * Math.sin(K * normalize_angle(132.5  +  659.29  * jy))
      rm += 0.0013 * Math.sin(K * normalize_angle( 81.4  +  225.18  * jy))
      rm += 0.0015 * Math.sin(K * normalize_angle(343.2  +  450.37  * jy))
      rm += 0.0018 * Math.sin(K * normalize_angle(251.3  +    0.20  * jy))
      rm += 0.0018 * Math.sin(K * normalize_angle(297.8  + 4452.67  * jy))
      rm += 0.0020 * Math.sin(K * normalize_angle(247.1  +  329.64  * jy))
      rm += 0.0048 * Math.sin(K * normalize_angle(234.95 +   19.341 * jy))
      rm += 0.0200 * Math.sin(K * normalize_angle(355.05 +  719.981 * jy))
      rm += (1.9146 - 0.00005 * jy) * Math.sin(K * normalize_angle(357.538 + 359.991 * jy))
      rm += normalize_angle(280.4603 + 360.00769 * jy)
      return normalize_angle(rm)
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 月の黄経 λmoon を計算する
  #=========================================================================
  def calc_longitude_moon(jd)
    begin
      year, month, day, hour, min, sec = jd_to_ymdt(jd)

      # 時分秒から日計算
      t = (hour * 60 * 60 + min * 60 + sec) / 86400.0

      # 地球自転遅れ補正値(日)計算
      #rotate_rev = (calc_dt(year, month, day) + 0.8 * (year - 1990)) / 86400.0
      #rotate_rev = 68 / 86400.0      #  国立天文台の 2015 - 2017 の設定値は 68
      #rotate_rev = 68.184 / 86400.0  # 2015-07-01 以降は 32.184 + 36 = 68.184 
      rotate_rev = calc_dt(year, month, day) / 86400.0

      # 2000年1月1日力学時正午からの経過日数(日)計算
      day_progress = calc_day_progress(year, month, day)

      # 経過ユリウス年(日)計算
      # ( 2000.0(2000年1月1日力学時正午)からの経過年数 (年) )
      jy = (day_progress + t + rotate_rev) / 365.25

      # 月黄経計算
      am  = 0.0006 * Math.sin(K * normalize_angle( 54.0 + 19.3  * jy))
      am += 0.0006 * Math.sin(K * normalize_angle( 71.0 +  0.2  * jy))
      am += 0.0020 * Math.sin(K * normalize_angle( 55.0 + 19.34 * jy))
      am += 0.0040 * Math.sin(K * normalize_angle(119.5 +  1.33 * jy))

      # 摂動項の計算
      rm_moon  = 0.0003 * Math.sin(K * normalize_angle(280.0   + 23221.3    * jy))
      rm_moon += 0.0003 * Math.sin(K * normalize_angle(161.0   +    40.7    * jy))
      rm_moon += 0.0003 * Math.sin(K * normalize_angle(311.0   +  5492.0    * jy))
      rm_moon += 0.0003 * Math.sin(K * normalize_angle(147.0   + 18089.3    * jy))
      rm_moon += 0.0003 * Math.sin(K * normalize_angle( 66.0   +  3494.7    * jy))
      rm_moon += 0.0003 * Math.sin(K * normalize_angle( 83.0   +  3814.0    * jy))
      rm_moon += 0.0004 * Math.sin(K * normalize_angle( 20.0   +   720.0    * jy))
      rm_moon += 0.0004 * Math.sin(K * normalize_angle( 71.0   +  9584.7    * jy))
      rm_moon += 0.0004 * Math.sin(K * normalize_angle(278.0   +   120.1    * jy))
      rm_moon += 0.0004 * Math.sin(K * normalize_angle(313.0   +   398.7    * jy))
      rm_moon += 0.0005 * Math.sin(K * normalize_angle(332.0   +  5091.3    * jy))
      rm_moon += 0.0005 * Math.sin(K * normalize_angle(114.0   + 17450.7    * jy))
      rm_moon += 0.0005 * Math.sin(K * normalize_angle(181.0   + 19088.0    * jy))
      rm_moon += 0.0005 * Math.sin(K * normalize_angle(247.0   + 22582.7    * jy))
      rm_moon += 0.0006 * Math.sin(K * normalize_angle(128.0   +  1118.7    * jy))
      rm_moon += 0.0007 * Math.sin(K * normalize_angle(216.0   +   278.6    * jy))
      rm_moon += 0.0007 * Math.sin(K * normalize_angle(275.0   +  4853.3    * jy))
      rm_moon += 0.0007 * Math.sin(K * normalize_angle(140.0   +  4052.0    * jy))
      rm_moon += 0.0008 * Math.sin(K * normalize_angle(204.0   +  7906.7    * jy))
      rm_moon += 0.0008 * Math.sin(K * normalize_angle(188.0   + 14037.3    * jy))
      rm_moon += 0.0009 * Math.sin(K * normalize_angle(218.0   +  8586.0    * jy))
      rm_moon += 0.0011 * Math.sin(K * normalize_angle(276.5   + 19208.02   * jy))
      rm_moon += 0.0012 * Math.sin(K * normalize_angle(339.0   + 12678.71   * jy))
      rm_moon += 0.0016 * Math.sin(K * normalize_angle(242.2   + 18569.38   * jy))
      rm_moon += 0.0018 * Math.sin(K * normalize_angle(  4.1   +  4013.29   * jy))
      rm_moon += 0.0020 * Math.sin(K * normalize_angle( 55.0   +    19.34   * jy))
      rm_moon += 0.0021 * Math.sin(K * normalize_angle(105.6   +  3413.37   * jy))
      rm_moon += 0.0021 * Math.sin(K * normalize_angle(175.1   +   719.98   * jy))
      rm_moon += 0.0021 * Math.sin(K * normalize_angle( 87.5   +  9903.97   * jy))
      rm_moon += 0.0022 * Math.sin(K * normalize_angle(240.6   +  8185.36   * jy))
      rm_moon += 0.0024 * Math.sin(K * normalize_angle(252.8   +  9224.66   * jy))
      rm_moon += 0.0024 * Math.sin(K * normalize_angle(211.9   +   988.63   * jy))
      rm_moon += 0.0026 * Math.sin(K * normalize_angle(107.2   + 13797.39   * jy))
      rm_moon += 0.0027 * Math.sin(K * normalize_angle(272.5   +  9183.99   * jy))
      rm_moon += 0.0037 * Math.sin(K * normalize_angle(349.1   +  5410.62   * jy))
      rm_moon += 0.0039 * Math.sin(K * normalize_angle(111.3   + 17810.68   * jy))
      rm_moon += 0.0040 * Math.sin(K * normalize_angle(119.5   +     1.33   * jy))
      rm_moon += 0.0040 * Math.sin(K * normalize_angle(145.6   + 18449.32   * jy))
      rm_moon += 0.0040 * Math.sin(K * normalize_angle( 13.2   + 13317.34   * jy))
      rm_moon += 0.0048 * Math.sin(K * normalize_angle(235.0   +    19.34   * jy))
      rm_moon += 0.0050 * Math.sin(K * normalize_angle(295.4   +  4812.66   * jy))
      rm_moon += 0.0052 * Math.sin(K * normalize_angle(197.2   +   319.32   * jy))
      rm_moon += 0.0068 * Math.sin(K * normalize_angle( 53.2   +  9265.33   * jy))
      rm_moon += 0.0079 * Math.sin(K * normalize_angle(278.2   +  4493.34   * jy))
      rm_moon += 0.0085 * Math.sin(K * normalize_angle(201.5   +  8266.71   * jy))
      rm_moon += 0.0100 * Math.sin(K * normalize_angle( 44.89  + 14315.966  * jy))
      rm_moon += 0.0107 * Math.sin(K * normalize_angle(336.44  + 13038.696  * jy))
      rm_moon += 0.0110 * Math.sin(K * normalize_angle(231.59  +  4892.052  * jy))
      rm_moon += 0.0125 * Math.sin(K * normalize_angle(141.51  + 14436.029  * jy))
      rm_moon += 0.0153 * Math.sin(K * normalize_angle(130.84  +   758.698  * jy))
      rm_moon += 0.0305 * Math.sin(K * normalize_angle(312.49  +  5131.979  * jy))
      rm_moon += 0.0348 * Math.sin(K * normalize_angle(117.84  +  4452.671  * jy))
      rm_moon += 0.0410 * Math.sin(K * normalize_angle(137.43  +  4411.998  * jy))
      rm_moon += 0.0459 * Math.sin(K * normalize_angle(238.18  +  8545.352  * jy))
      rm_moon += 0.0533 * Math.sin(K * normalize_angle( 10.66  + 13677.331  * jy))
      rm_moon += 0.0572 * Math.sin(K * normalize_angle(103.21  +  3773.363  * jy))
      rm_moon += 0.0588 * Math.sin(K * normalize_angle(214.22  +   638.635  * jy))
      rm_moon += 0.1143 * Math.sin(K * normalize_angle(  6.546 +  9664.0404 * jy))
      rm_moon += 0.1856 * Math.sin(K * normalize_angle(177.525 +   359.9905 * jy))
      rm_moon += 0.2136 * Math.sin(K * normalize_angle(269.926 +  9543.9773 * jy))
      rm_moon += 0.6583 * Math.sin(K * normalize_angle(235.700 +  8905.3422 * jy))
      rm_moon += 1.2740 * Math.sin(K * normalize_angle(100.738 +  4133.3536 * jy))
      rm_moon += 6.2887 * Math.sin(K * normalize_angle(134.961 +  4771.9886 * jy + am))
      rm_moon += normalize_angle(218.3161 + 4812.67881 * jy)
      return normalize_angle(rm_moon)
    rescue => e
      raise
    end
  end

  #=========================================================================
  # ΔT の計算
  #
  #   1972-01-01 以降、うるう秒挿入済みの年+αまでは、以下で算出
  #     TT - UTC = ΔT + DUT1 = TAI + 32.184 - UTC = ΔAT + 32.184
  #   [うるう秒実施日一覧](http://jjy.nict.go.jp/QandA/data/leapsec.html)
  #=========================================================================
  def calc_dt(year, month, day)
    ymd = sprintf("%04d-%02d-%02d", year, month, day)
    case
    when year < -500
      t = (year-1820) / 100.0
      dt  = -20
      dt += 32 * t ** 2
    when -500 <= year && year < 500
      t = year / 100.0
      dt  = 10583.6
      dt -= 1014.41 * t
      dt += 33.78311 * t ** 2
      dt -= 5.952053 * t ** 3
      dt -= 0.1798452 * t ** 4
      dt += 0.022174192 * t ** 5
      dt += 0.0090316521 * t ** 6
    when 500 <= year && year < 1600
      t = (year - 1000) / 100.0
      dt  = 1574.2
      dt -= 556.01 * t
      dt += 71.23472 * t ** 2
      dt += 0.319781 * t ** 3
      dt -= 0.8503463 * t ** 4
      dt -= 0.005050998 * t ** 5
      dt += 0.0083572073 * t ** 6
    when 1600 <= year && year < 1700
      t = year - 1600
      dt  = 120
      dt -= 0.9808 * t
      dt -= 0.01532 * t ** 2
      dt += t ** 3 / 7129.0
    when 1700 <= year && year < 1800
      t = year - 1700
      dt  = 8.83
      dt += 0.1603 * t
      dt -= 0.0059285 * t ** 2
      dt += 0.00013336 * t ** 3
      dt -= t ** 4 / 1174000.0
    when 1800 <= year && year < 1860
      t = year - 1800
      dt  = 13.72
      dt -= 0.332447 * t
      dt += 0.0068612 * t ** 2
      dt += 0.0041116 * t ** 3
      dt -= 0.00037436 * t ** 4
      dt += 0.0000121272 * t ** 5
      dt -= 0.0000001699 * t ** 6
      dt += 0.000000000875 * t ** 7
    when 1860 <= year && year < 1900
      t = year - 1860
      dt  = 7.62
      dt += 0.5737 * t
      dt -= 0.251754 * t ** 2
      dt += 0.01680668 * t ** 3
      dt -= 0.0004473624 * t ** 4
      dt += t ** 5 / 233174.0
    when 1900 <= year && year < 1920
      t = year - 1900
      dt  = -2.79
      dt += 1.494119 * t
      dt -= 0.0598939 * t ** 2
      dt += 0.0061966 * t ** 3
      dt -= 0.000197 * t ** 4
    when 1920 <= year && year < 1941
      t = year - 1920
      dt  = 21.20
      dt += 0.84493 * t
      dt -= 0.076100 * t ** 2
      dt += 0.0020936 * t ** 3
    when 1941 <= year && year < 1961
      t = year - 1950
      dt  = 29.07
      dt += 0.407 * t
      dt -= t ** 2 / 233.0
      dt += t ** 3 / 2547.0
    when 1961 <= year && year < 1986
      case
      when ymd < sprintf("%04d-%02d-%02d", 1972, 1, 1)
        t = year - 1975
        dt  = 45.45
        dt += 1.067 * t
        dt -= t ** 2 / 260.0
        dt -= t ** 3 / 718.0
      when ymd < sprintf("%04d-%02d-%02d", 1972, 7, 1)
        dt = 32.184 + 10
      when ymd < sprintf("%04d-%02d-%02d", 1973, 1, 1)
        dt = 32.184 + 11
      when ymd < sprintf("%04d-%02d-%02d", 1974, 1, 1)
        dt = 32.184 + 12
      when ymd < sprintf("%04d-%02d-%02d", 1975, 1, 1)
        dt = 32.184 + 13
      when ymd < sprintf("%04d-%02d-%02d", 1976, 1, 1)
        dt = 32.184 + 14
      when ymd < sprintf("%04d-%02d-%02d", 1977, 1, 1)
        dt = 32.184 + 15
      when ymd < sprintf("%04d-%02d-%02d", 1978, 1, 1)
        dt = 32.184 + 16
      when ymd < sprintf("%04d-%02d-%02d", 1979, 1, 1)
        dt = 32.184 + 17
      when ymd < sprintf("%04d-%02d-%02d", 1980, 1, 1)
        dt = 32.184 + 18
      when ymd < sprintf("%04d-%02d-%02d", 1981, 7, 1)
        dt = 32.184 + 19
      when ymd < sprintf("%04d-%02d-%02d", 1982, 7, 1)
        dt = 32.184 + 20
      when ymd < sprintf("%04d-%02d-%02d", 1983, 7, 1)
        dt = 32.184 + 21
      when ymd < sprintf("%04d-%02d-%02d", 1985, 7, 1)
        dt = 32.184 + 22
      when ymd < sprintf("%04d-%02d-%02d", 1988, 1, 1)
        dt = 32.184 + 23
      end
    when 1986 <= year && year < 2005
      # t = year - 2000
      # dt  = 63.86
      # dt += 0.3345 * t
      # dt -= 0.060374 * t ** 2
      # dt += 0.0017275 * t ** 3
      # dt += 0.000651814 * t ** 4
      # dt += 0.00002373599 * t ** 5
      case
      when ymd < sprintf("%04d-%02d-%02d", 1988, 1, 1)
        dt = 32.184 + 23
      when ymd < sprintf("%04d-%02d-%02d", 1990, 1, 1)
        dt = 32.184 + 24
      when ymd < sprintf("%04d-%02d-%02d", 1991, 1, 1)
        dt = 32.184 + 25
      when ymd < sprintf("%04d-%02d-%02d", 1992, 7, 1)
        dt = 32.184 + 26
      when ymd < sprintf("%04d-%02d-%02d", 1993, 7, 1)
        dt = 32.184 + 27
      when ymd < sprintf("%04d-%02d-%02d", 1994, 7, 1)
        dt = 32.184 + 28
      when ymd < sprintf("%04d-%02d-%02d", 1996, 1, 1)
        dt = 32.184 + 29
      when ymd < sprintf("%04d-%02d-%02d", 1997, 7, 1)
        dt = 32.184 + 30
      when ymd < sprintf("%04d-%02d-%02d", 1999, 1, 1)
        dt = 32.184 + 31
      when ymd < sprintf("%04d-%02d-%02d", 2006, 1, 1)
        dt = 32.184 + 32
      end
    when 2005 <= year && year < 2050
      case
      when ymd < sprintf("%04d-%02d-%02d", 2006, 1, 1)
        dt = 32.184 + 32
      when ymd < sprintf("%04d-%02d-%02d", 2009, 1, 1)
        dt = 32.184 + 33
      when ymd < sprintf("%04d-%02d-%02d", 2012, 7, 1)
        dt = 32.184 + 34
      when ymd < sprintf("%04d-%02d-%02d", 2015, 7, 1)
        dt = 32.184 + 35
      when ymd < sprintf("%04d-%02d-%02d", 2017, 7, 1)  # <= 第27回うるう秒実施までの暫定措置
        dt = 32.184 + 36
      else
        t = year - 2000
        dt  = 62.92
        dt += 0.32217 * t
        dt += 0.005589 * t ** 2
      end
    when 2050 <= year && year <= 2150
      dt  = -20
      dt += 32 * ((year - 1820)/100.0) ** 2
      dt -= 0.5628 * (2150 - year)
    when 2150 < year
      t = (year-1820)/100
      dt  = -20
      dt += 32 * t ** 2
    end
    return dt
  rescue => e
    raise
  end

  #=========================================================================
  # 2000年1月1日力学時正午からの経過日数(日)
  #=========================================================================
  def calc_day_progress(year, month, day)
    year -= 2000

    # 1月,2月は前年の13月,14月とする
    if month < 3
      year  -= 1
      month += 12
    end

    day_progress  = 365 * year + 30 * month + day - 33.5 - 9 / 24.0
    day_progress += (3 * (month + 1) / 5.0).truncate
    day_progress += (year / 4.0).truncate
    return day_progress
  rescue => e
    raise
  end

  #=========================================================================
  # 月齢(正午)を計算する
  #
  #   月齢は直前の朔の日時からの経過日数
  #
  #   [ 引数 ]
  #     jd : ユリウス通日
  #   [ 戻り値 ]
  #     moon_age ( 月齢 )
  #=========================================================================
  def calc_moon_age_noon(jd)
    saku_last = calc_saku(jd)  # 直前の朔を計算
    return jd + 0.5 - saku_last
  rescue => e
    raise
  end

  #=========================================================================
  # 月日(旧暦)から六曜を計算する
  #
  #   旧暦一日の六曜
  #     １・７月   : 先勝
  #     ２・８月   : 友引
  #     ３・９月   : 先負
  #     ４・１０月 : 仏滅
  #     ５・１１月 : 大安
  #     ６・１２月 : 赤口
  #   と決まっていて、あとは月末まで順番通り。
  #   よって、月と日をたした数を６で割った余りによって六曜を決定することができます。
  #   ( 旧暦の月 ＋ 旧暦の日 ) ÷ 6 ＝ ？ … 余り
  #   余り 0 : 大安
  #        1 : 赤口
  #        2 : 先勝
  #        3 : 友引
  #        4 : 先負
  #        5 : 仏滅
  #
  #   [ 引数 ]
  #     oc_month : 旧暦の月
  #     oc_day   : 旧暦の日
  #
  #   [ 戻り値 ]
  #     rokuyo ( 六曜 ( 0 - 5 ) )
  #=========================================================================
  def calc_rokuyo(oc_month, oc_day)
    return (oc_month + oc_day) % 6
  rescue => e
    raise
  end

  # 結果出力
  def display
    begin
      str_out = sprintf("%02d-%02d-%02d", @year, @month, @day)
      @option.each_char do |op|
        case op
        when "a" # 曜日
          str_out << " #{@yobi[@hash[:yobi]]}曜日"
        when "b" # 休日
          @holiday.each do |row|
            str_out << " #{row[4]}" if row[0] == @hash[:holiday]
          end unless @hash[:holiday] == 99
        when "c" # ユリウス通日
          str_out << " #{@jd + 0.5}"
        when "d" # 干支
          str_out << " #{@kanshi[ @hash[:kanshi]]}"
        when "e" # 旧暦
          str_out << sprintf(" %02d-%02d-%02d", @hash[:oc_y], @hash[:oc_m], @hash[:oc_d])
        when "f" # 六曜
          str_out << " #{@rokuyo[@hash[:rokuyo]]}"
        when "g" # 二十四節気
          str_out << " #{@sekki24[@hash[:sekki24].to_i / 15]}" unless @hash[:sekki24] == 999
        when "h" # 雑節
          ary_zassetsu = []
          @hash[:zassetsu].each do |k, v|
            ary_zassetsu << @zassetsu[v] unless v == 99
          end
          str_out << " " + ary_zassetsu.join('・') unless ary_zassetsu.empty?
        when "i" # 節句
          @sekku.each do |row|
            str_out << " #{row[3]}" if row[0] == @hash[:sekku]
          end unless @hash[:sekku] == 9
        when "j" # 黄経(太陽)
          str_out << " #{@hash[:lon_sun]}"
        when "k" # 黄経(月)
          str_out << " #{@hash[:lon_moon]}"
        when "l" # 月齢
          str_out << " #{@hash[:moon_age]}"
        end
      end
      puts str_out
    rescue => e
      raise
    end
  end
end

exit unless __FILE__ == $0
Calendar.new.exec

