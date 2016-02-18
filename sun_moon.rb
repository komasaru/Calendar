#! /usr/local/bin/ruby
# coding: utf-8
# 日の出・日の入の時刻・方位、日の南中の時刻・高度、
# 月の出・月の入の時刻・方位、月の南中の時刻・高度  の算出
#
# date          name            version
# 2011.08.31    mk-mode         1.00 新規作成
# 2012.11.07    mk-mode         1.01 Ruby らしく整形＆微修正
#                                    (アルゴリズムの変更は無し)
# 2016.01.04    mk-mode         1.02 コーディング再整形
# 2016.02.18    mk-mode         1.03 57 固定だった ΔT を計算により導出するよう変更
#                                    Ref: [NASA - Polynomial Expressions for Delta T](http://eclipse.gsfc.nasa.gov/SEhelp/deltatpoly2004.html)
#
# Copyright(C) 2011-2016 mk-mode.com All Rights Reserved.
#---------------------------------------------------------------------------------
# ※・このRubyスクリプトの計算結果は無保証です。
#   ・このRubyスクリプトはフリーソフトであり、自由に再利用・改良を行ってかまいませ
#     んが、著作権は mk-mode.comに帰属します。
#   ・再配布について一方的に拒否することはありませんが、再配布の際は念のためご一報
#     だけください。( MAIL : postmaster@mk-mode.com )
#---------------------------------------------------------------------------------
# 引数 :  第１ ( 日  付 )     [必須]   [ 99999999 ]
#             計算対象の日付(グレゴリオ暦)を半角８桁数字で指定します。
#
#         第２ ( 緯  度 )     [必須]   [ [+|-]999.99999999 | [+|-]999:99:99.99 ]
#             緯度を 度 または 度・分・秒 で指定します。
#             ( 北緯はプラス、南緯はマイナス )
#             ( 度 の小数点以下、度・分・秒 の分以下は省略可 )
#
#         第３ ( 経  度 )     [必須]   [ [+|-]999.99999999 | [+|-]999:99:99.99 ]
#             経度を 度 または 度・分・秒 で指定します。
#             ( 東経はプラス、西経はマイナス )
#             ( 度 の小数点以下、度・分・秒 の分以下は省略可 )
#
#         第４ ( 標  高 )     [必須]   [ [+]9999.99999999 ]
#             標高をメートルで指定します。
#             ( 小数点以下は省略可 )
#
#         第５ ( オプション ) [省略可] [ abcdefghijkl ]
#             出力項目を下記の半角小文字アルファベットが指定可能です。
#             ( 無指定なら全指定と判断 )
#              a : 日の出時刻
#              b : 日の出方位角
#              c : 日の入時刻
#              d : 日の入方位角
#              e : 日の南中時刻
#              f : 日の南中高度
#              g : 月の出時刻
#              h : 月の出方位角
#              i : 月の入時刻
#              j : 月の入方位角
#              k : 月の南中時刻
#              l : 月の南中高度
#---------------------------------------------------------------------------------
# 注意 : この Ruby スクリプトは Linux Mint, CentOS 等で動作確認しております。
#        Ruby の動作可能な環境であれば動作すると思いますが、他の環境で動作させるた
#        めには文字コード等の変更が必要となる場合があります。
#---------------------------------------------------------------------------------
#+
require 'date'

class SunMoon
  # 使用方法
  USAGE = <<-EOS
  使用方法 : sun_moon.rb 第１引数 第２引数 第３引数 第４引数 [ 第５引数 ]
  引数 : 第１ ( 日  付 )     [必須]   [ 99999999 ]
             計算対象の日付(グレゴリオ暦)を半角８桁数字で指定します。
         第２ ( 緯  度 )     [必須]   [ [+|-]999.99999999 | [+|-]999:99:99.99 ]
             緯度を 度 または 度・分・秒 で指定します。
             ( 北緯はプラス、南緯はマイナス )
             ( 度 の小数点以下、度・分・秒 の分以下は省略可 )
         第３ ( 経  度 )     [必須]   [ [+|-]999.99999999 | [+|-]999:99:99.99 ]
             経度を 度 または 度・分・秒 で指定します。
             ( 東経はプラス、西経はマイナス )
             ( 度 の小数点以下、度・分・秒 の分以下は省略可 )
         第４ ( 標  高 )     [必須]   [ [+]9999.99999999 ]
             標高をメートルで指定します。
             ( 小数点以下分以下は省略可 )
         第５ ( オプション ) [省略可] [ abcdefghijkl ]
             出力項目を下記の半角小文字アルファベットが指定可能です。
             ( 無指定なら全指定と判断 )
              a : 日の出時刻
              b : 日の出方位角
              c : 日の入時刻
              d : 日の入方位角
              e : 日の南中時刻
              f : 日の南中高度
              g : 月の出時刻
              h : 月の出方位角
              i : 月の入時刻
              j : 月の入方位角
              k : 月の南中時刻
              l : 月の南中高度
  EOS
  OPTION        = "abcdefghijkl"           # オプション定義
  PI            = 3.141592653589793238462  # 円周率の定義
  PI_180        = PI / 180.0               # （角度の）度からラジアンに変換する係数の定義
  JST_LON       = 135                      # 標準子午線経度
  UTC           = 9                        # UTC ( +9 )
  KETA          = 2                        # 方位角・高度算出用小数点以下桁数
  CONVERGE      = 0.00005                  # 逐次近似計算収束判定値
  ASTRO_REFRACT = 0.585556                 # 大気差

  def initialize
    @year, @month, @day = "", "", ""
    @lat, @lon, @ht     = "", ""
    @opt                = OPTION
    @hash = Hash.new    # hash定義 ( 取得データ格納用 )
  end

  # 主処理
  def exec
    begin
      # 引数チェック ( エラーなら終了 )
      err_msg = check_arg
      unless err_msg == ""
        $stderr.puts "[ERROR] #{err_msg}"
        exit 1
      end

      init_data  # データ初期化
      calc       # 各種計算
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
    begin
      # [ 第１引数 ] ( 日付 ) 存在チェック
      if ARGV[0].nil?
        return USAGE
      else
        # 正規チェック ( [99999999] )
        return USAGE unless ARGV[0].to_s =~ /^\d{8}$/
      end
      @date = ARGV[0].to_s
      # [ 第２引数 ] ( 緯度 ) 存在チェック
      if ARGV[1].nil?
        return USAGE
      else
        # 正規チェック ( [+|-]999.99999999 )
        if ARGV[1].to_s =~ /^[-+]?\d{0,3}(\.\d{0,8})?$/
          @lat = ARGV[1].to_f
        else
          # 正規チェック ( [+|-]999:99:99.99 )
          if ARGV[1].to_s =~ /^[-+]?\d{1,3}(((:[0-5]\d){0,2})|((:[0-5]\d){2}\.\d{1,2}))$/
            # 度・分・秒 => 度 変換
            ary_arg = ARGV[1].to_s.split(":")
            i = 0
            val_conv = 0
            ary_arg.each do |a|
              val_conv += a.to_f / (60 ** i)
              i += 1
            end
            @lat = val_conv
          else
            return USAGE
          end
        end
      end
      # [ 第３引数 ] ( 経度 ) 存在チェック
      if ARGV[2].nil?
        return USAGE
      else
        # 正規チェック ( [+|-]999.99999999 )
        if ARGV[2].to_s =~ /^[-+]?[0-9]{0,3}(\.[0-9]{0,8})?$/
          @lon = ARGV[2].to_f
        else
          # 正規チェック ( [+|-]999:99:99.99 )
          if ARGV[2].to_s =~ /^[-+]?\d{1,3}(((:[0-5]\d){0,2})|((:[0-5]\d){2}\.\d{1,2}))$/
            # 度・分・秒 => 度 変換
            ary_arg = ARGV[2].to_s.split(":")
            i = 0
            val_conv = 0
            ary_arg.each do |a|
              val_conv += a.to_f / (60 ** i)
              i += 1
            end
            @lon = val_conv
          else
            return USAGE
          end
        end
      end
      # [ 第４引数 ] ( 標高 ) 存在チェック
      if ARGV[3].nil?
        return USAGE
      else
        # 正規チェック ( [+|-]9999.99999999 )
        if !(ARGV[3].to_s =~ /^[+]?[0-9]{0,4}(\.[0-9]{0,8})?$/)
          return USAGE
        end
      end
      @ht = ARGV[3].to_f
      # [ 第５引数 ] ( オプション ) 存在チェック
      if ARGV[4].nil?
        # 存在しなくてもエラーではない
      else
        # 正規チェック ( [abcdefghijkl] )
        if ARGV[4].to_s =~ /^[abcdefghijkl]+$/
          @opt = ARGV[4].to_s
        else
          return USAGE
        end
      end

      # 日付妥当性チェック
      @year  = @date[0,4].to_i
      @month = @date[4,2].to_i
      @day   = @date[6,2].to_i
      unless Date.valid_date?(@year, @month, @day)
        return "妥当な日付ではありません。"
      end
      # 緯度妥当性チェック ( -90 ～ 90 度 )
      unless -90 <= @lat.to_f && @lat.to_f <= 90
        return "妥当な緯度( -90 ～ 90 度 )ではありません。"
      end
      # 経度妥当性チェック ( -180 ～ 180 度 )
      unless -180 <= @lon.to_f && @lon.to_f <= 180
        return "妥当な経度( -180 ～ 180 度 )ではありません。"
      end
      # 標高妥当性チェック ( 0 ～ 9999.99999999 ｍ )
      # ( 標高は正規チェックのみで大丈夫 )

      # 引数にエラーなし
      return ""
    rescue => e
      raise
    end
  end

  # データ初期化
  def init_data
    #@rotate_rev   = (57 + 0.8 * (@year - 1990)) / 86400  # 地球自転遅れ補正値(日)
    dt = calc_dt
    @rotate_rev   = (dt + 0.8 * (@year - 1990)) / 86400  # 地球自転遅れ補正値(日)
    @dip          = 0.0353333 * Math.sqrt(@ht)           # 地平線伏角
    @day_progress = calc_time_progress                   # 2000年1月1日力学時正午からの経過日数(日)
    @sign_lat     = @lat >= 0 ? "N" : "S"                # 緯度記号
    @sign_lon     = @lon >= 0 ? "E" : "W"                # 経度記号
  rescue => e
    raise
  end

  #=========================================================================
  # ΔT の計算
  #=========================================================================
  def calc_dt
    case
    when @year < -500
      t = (@year-1820) / 100.0
      dt  = -20
      dt += 32 * t ** 2
    when -500 <= @year && @year < 500
      t = @year / 100.0
      dt  = 10583.6
      dt -= 1014.41 * t
      dt += 33.78311 * t ** 2
      dt -= 5.952053 * t ** 3
      dt -= 0.1798452 * t ** 4
      dt += 0.022174192 * t ** 5
      dt += 0.0090316521 * t ** 6
    when 500 <= @year && @year < 1600
      t = (@year - 1000) / 100.0
      dt  = 1574.2
      dt -= 556.01 * t
      dt += 71.23472 * t ** 2
      dt += 0.319781 * t ** 3
      dt -= 0.8503463 * t ** 4
      dt -= 0.005050998 * t ** 5
      dt += 0.0083572073 * t ** 6
    when 1600 <= @year && @year < 1700
      t = @year - 1600
      dt  = 120
      dt -= 0.9808 * t
      dt -= 0.01532 * t ** 2
      dt += t ** 3 / 7129.0
    when 1700 <= @year && @year < 1800
      t = @year - 1700
      dt  = 8.83
      dt += 0.1603 * t
      dt -= 0.0059285 * t ** 2
      dt += 0.00013336 * t ** 3
      dt -= t ** 4 / 1174000.0
    when 1800 <= @year && @year < 1860
      t = @year - 1800
      dt  = 13.72
      dt -= 0.332447 * t
      dt += 0.0068612 * t ** 2
      dt += 0.0041116 * t ** 3
      dt -= 0.00037436 * t ** 4
      dt += 0.0000121272 * t ** 5
      dt -= 0.0000001699 * t ** 6
      dt += 0.000000000875 * t ** 7
    when 1860 <= @year && @year < 1900
      t = @year - 1860
      dt  = 7.62
      dt += 0.5737 * t
      dt -= 0.251754 * t ** 2
      dt += 0.01680668 * t ** 3
      dt -= 0.0004473624 * t ** 4
      dt += t ** 5 / 233174.0
    when 1900 <= @year && @year < 1920
      t = @year - 1900
      dt  = -2.79
      dt += 1.494119 * t
      dt -= 0.0598939 * t ** 2
      dt += 0.0061966 * t ** 3
      dt -= 0.000197 * t ** 4
    when 1920 <= @year && @year < 1941
      t = @year - 1920
      dt  = 21.20
      dt += 0.84493 * t
      dt -= 0.076100 * t ** 2
      dt += 0.0020936 * t ** 3
    when 1941 <= @year && @year < 1961
      t = @year - 1950
      dt  = 29.07
      dt += 0.407 * t
      dt -= t ** 2 / 233.0
      dt += t ** 3 / 2547.0
    when 1961 <= @year && @year < 1986
      t = @year - 1975
      dt  = 45.45
      dt += 1.067 * t
      dt -= t ** 2 / 260.0
      dt -= t ** 3 / 718.0
    when 1986 <= @year && @year < 2005
      t = @year - 2000
      dt  = 63.86
      dt += 0.3345 * t
      dt -= 0.060374 * t ** 2
      dt += 0.0017275 * t ** 3
      dt += 0.000651814 * t ** 4
      dt += 0.00002373599 * t ** 5
    when 2005 <= @year && @year < 2050
      t = @year - 2000
      dt  = 62.92
      dt += 0.32217 * t
      dt += 0.005589 * t ** 2
    when 2050 <= @year && @year <= 2150
      dt  = -20
      dt += 32 * ((@year - 1820)/100.0) ** 2
      dt -= 0.5628 * (2150 - @year)
    when 2150 < @year
      t = (@year-1820)/100
      dt  = -20
      dt += 32 * t ** 2
    end
    return dt
  rescue => e
    raise
  end

  #=========================================================================
  # 2000年1月1日力学時正午からの経過日数計算
  # 戻り値 .... 2000.0(2000年1月1日力学時正午)からの経過日数 (日)
  #=========================================================================
  def calc_time_progress
    year  = @year - 2000
    month = @month
    day   = @day

    begin
      # 1月,2月は前年の13月,14月とする
      if month < 3
        year  -= 1
        month += 12
      end
      time_progress  = 365 * year + 30 * month + day - 33.5 - UTC / 24.0
      time_progress += (3 * (month + 1) / 5.0).truncate
      time_progress += (year / 4.0).truncate
      return time_progress
    rescue => e
      raise
    end
  end

  # 各種計算
  def calc
    calc_sr  # 日の出
    calc_ss  # 日の入
    calc_sm  # 日の南中
    calc_mr  # 月の出
    calc_ms  # 月の入
    calc_mm  # 月の南中
  rescue => e
    raise
  end

  # 計算（日の出）
  def calc_sr
    # [ 日の出 ] 時刻計算
    num_sr = calc_time_sun(0)
    time_sr = convert_time(num_sr * 24)
    @hash[:time_sr] = time_sr
    # [ 日の出 ] 経過ユリウス年(日)計算
    jy_sr = calc_jy(num_sr)
    # [ 日の出 ] 黄経(太陽)計算
    kokei_sun = calc_lng_sun(jy_sr)
    # [ 日の出 ] 方位角計算
    ang_sr = calc_ang({
      kokei: kokei_sun, koi: 0,
      time: num_sr, jy: jy_sr
    })
    @hash[:ang_sr] = ang_sr
  rescue => e
    raise
  end

  # 計算（日の入）
  def calc_ss
    # [ 日の入 ] 時刻計算
    num_ss = calc_time_sun(1)
    time_ss = convert_time(num_ss * 24)
    @hash[:time_ss] = time_ss
    # [ 日の入 ] 経過ユリウス年(日)計算
    jy_ss = calc_jy(num_ss)
    # [ 日の入 ] 黄経(太陽)計算
    kokei_sun = calc_lng_sun(jy_ss)
    # [ 日の入 ] 方位角計算
    ang_ss = calc_ang({
      kokei: kokei_sun, koi: 0,
      time: num_ss, jy: jy_ss
    })
    @hash[:ang_ss] = ang_ss
  rescue => e
    raise
  end

  # 計算（日の南中）
  def calc_sm
    # [ 日の南中 ] 時刻計算
    num_sm = calc_time_sun(2)
    time_sm = convert_time(num_sm * 24)
    @hash[:time_sm] = time_sm
    # [ 日の南中 ] 経過ユリウス年(日)計算
    jy_sm = calc_jy(num_sm)
    # [ 日の南中 ] 黄経(太陽)計算
    kokei_sun = calc_lng_sun(jy_sm)
    # [ 日の南中 ] 高度計算
    height_sm = calc_height({
      kokei: kokei_sun, koi: 0,
      time: num_sm, jy: jy_sm
    })
    @hash[:height_sm] = height_sm
  rescue => e
    raise
  end

  # 計算（月の出）
  def calc_mr
    # [ 月の出 ] 計算
    num_mr = calc_time_moon(0)
    if num_mr == 0
      # [ 月の出 ] 時刻
      time_mr = "--:--"
      # [ 月の出 ] 方位角
      ang_mr = "---"
    else
      # [ 月の出 ] 時刻
      time_mr = convert_time(num_mr * 24)
      # [ 月の出 ] 経過ユリウス年(日)計算
      jy_mr = calc_jy(num_mr)
      # [ 月の出 ] 黄経(月)計算
      kokei_moon = calc_lng_moon(jy_mr)
      # [ 月の出 ] 黄緯(月)計算
      koi_moon = calc_lat_moon(jy_mr)
      # [ 月の出 ] 方位角計算
      ang_mr = calc_ang({
        kokei: kokei_moon, koi: koi_moon,
        time: num_mr, jy: jy_mr
      })
    end
    @hash[:time_mr] = time_mr
    @hash[:ang_mr]  = ang_mr
  rescue => e
    raise
  end

  # 計算（月の入）
  def calc_ms
    # [ 月の入 ] 時刻
    num_ms = calc_time_moon(1)
    if num_ms == 0
      # [ 月の入 ] 時刻
      time_ms = "--:--"
      # [ 月の入 ] 方位角
      ang_ms = "---"
    else
      # [ 月の入 ] 時刻
      time_ms = convert_time(num_ms * 24)
      # [ 月の入 ] 経過ユリウス年(日)計算
      jy_ms = calc_jy(num_ms)
      # [ 月の入 ] 黄経(月)計算
      kokei_moon = calc_lng_moon(jy_ms)
      # [ 月の入 ] 黄緯(月)計算
      koi_moon = calc_lat_moon(jy_ms)
      # [ 月の入 ] 方位角計算
      ang_ms = calc_ang({
        kokei: kokei_moon, koi: koi_moon,
        time: num_ms, jy: jy_ms
      })
    end
    @hash[:time_ms] = time_ms
    @hash[:ang_ms]  = ang_ms
  rescue => e
    raise
  end

  # 計算（月の南中）
  def calc_mm
    # [ 月の南中 ] 時刻計算
    num_mm = calc_time_moon(2)
    if num_mm == 0
      # [ 月の南中 ] 時刻
      time_mm = "--:--"
      # [ 月の南中 ] 方位角
      height_mm = "---"
    else
      # [ 月の南中 ] 時刻
      time_mm = convert_time(num_mm * 24)
      # [ 月の南中 ] 経過ユリウス年(日)計算
      jy_mm = calc_jy(num_mm)
      # [ 月の南中 ] 黄経(月)計算
      kokei_moon = calc_lng_moon(jy_mm)
      # [ 月の南中 ] 黄緯(月)計算
      koi_moon = calc_lat_moon(jy_mm)
      # [ 月の南中 ] 方位角計算
      height_mm = calc_height({
        kokei: kokei_moon, koi: koi_moon,
        time: num_mm, jy: jy_mm
      })
    end
    @hash[:time_mm]   = time_mm
    @hash[:height_mm] = height_mm
  rescue => e
    raise
  end

  #=========================================================================
  # 日の出/日の入/日の南中計算計算
  # 引数   .... flag : 出入フラグ ( 0 : 日の出, 1 : 日の入, 2 : 日の南中 )
  # 戻り値 .... 出入時刻 ( 0.xxxx日 )
  #=========================================================================
  def calc_time_sun(flag)
    rev       = 1    # 補正値初期値
    time_loop = 0.5  # 逐次計算時刻(日)初期設定

    begin
      # 逐次計算
      while rev.abs > CONVERGE
        # time_loopの経過ユリウス年
        jy = (@day_progress + time_loop + @rotate_rev) / 365.25
        # 太陽の黄経
        kokei_sun = calc_lng_sun(jy)
        # 太陽の距離
        dist_sun  = calc_dist_sun(jy)
        # 黄道 -> 赤道変換
        res = calc_kou2seki({kokei: kokei_sun, koi: 0, jy: jy})
        sekkei, sekii = res[:sekkei], res[:sekii]
        # 太陽の視半径
        r_sun = 0.266994 / dist_sun
        # 太陽の視差
        dif_sun = 0.0024428 / dist_sun
        # 太陽の出入高度
        height_sun = -1 * r_sun - ASTRO_REFRACT - @dip + dif_sun
        # 恒星時
        time_sidereal = calc_time_sidereal({jy: jy, t: time_loop})
        # 時角差計算
        hour_ang_dif = calc_hour_ang_dif({
          sekkei: sekkei, sekii: sekii,
          time_sidereal: time_sidereal,
          height: height_sun, flag: flag
        })
        # 仮定時刻に対する補正値
        rev = hour_ang_dif / 360.0
        time_loop = time_loop + rev
      end
      return time_loop
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 月の出/月の入/月の南中計算
  # 引数   .... flag : 出入フラグ ( 0 : 月の出, 1 : 月の入, 2 : 月の南中 )
  # 戻り値 .... 出入時刻 ( 0.xxxx日 )
  #=========================================================================
  def calc_time_moon(flag)
    rev       = 1    # 補正値初期値
    time_loop = 0.5  # 逐次計算時刻(日)初期設定

    begin
      # 逐次計算
      while rev.abs > CONVERGE
        # time_loopの経過ユリウス年
        jy = (@day_progress + time_loop + @rotate_rev) / 365.25
        # 月の黄経
        kokei_moon = calc_lng_moon(jy)
        # 月の黄緯
        koi_moon   = calc_lat_moon(jy)
        # 黄道 -> 赤道変換
        res = calc_kou2seki({kokei: kokei_moon, koi: koi_moon, jy: jy})
        sekkei, sekii = res[:sekkei], res[:sekii]
        unless flag == 2  # 南中のときは計算しない
          # 月の視差
          dif_moon = calc_dif_moon(jy)
          # 月の出入高度
          height_moon = -1 * ASTRO_REFRACT - @dip + dif_moon
        end
        # 恒星時
        time_sidereal = calc_time_sidereal({jy: jy, t: time_loop})
        # 時角差計算
        hour_ang_dif = calc_hour_ang_dif({
          sekkei: sekkei, sekii: sekii,
          time_sidereal: time_sidereal,
          height: height_moon, flag: flag
        })
        # 仮定時刻に対する補正値
        rev = hour_ang_dif / 347.8
        time_loop = time_loop + rev
      end
      # 月の出/月の入りがない場合は 0 とする
      time_loop = 0 if time_loop < 0 || time_loop >= 1
      return time_loop
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 月の視差計算
  # 引数   .... jy : 経過ユリウス年
  # 戻り値 .... 出入時刻 ( 0.xxxx日 )
  #=========================================================================
  def calc_dif_moon(jy)
    begin
      p_moon  =  0.0003 * Math.sin(PI_180 * normalize_angle(227.0  +  4412.0   * jy))
      p_moon +=  0.0004 * Math.sin(PI_180 * normalize_angle(194.0  +  3773.4   * jy))
      p_moon +=  0.0005 * Math.sin(PI_180 * normalize_angle(329.0  +  8545.4   * jy))
      p_moon +=  0.0009 * Math.sin(PI_180 * normalize_angle(100.0  + 13677.3   * jy))
      p_moon +=  0.0028 * Math.sin(PI_180 * normalize_angle(  0.0  +  9543.98  * jy))
      p_moon +=  0.0078 * Math.sin(PI_180 * normalize_angle(325.7  +  8905.34  * jy))
      p_moon +=  0.0095 * Math.sin(PI_180 * normalize_angle(190.7  +  4133.35  * jy))
      p_moon +=  0.0518 * Math.sin(PI_180 * normalize_angle(224.98 +  4771.989 * jy))
      p_moon +=  0.9507 * Math.sin(PI_180 * normalize_angle(90.0))
      return p_moon
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 経過ユリウス年(日)計算
  # 引数   .... t : 時刻 ( 0.xxxx日 )
  # 戻り値 .... 2000.0(2000年1月1日力学時正午)からの経過年数 (年)
  #=========================================================================
  def calc_jy(t)
    return (@day_progress + t + @rotate_rev) / 365.25
  rescue => e
    raise
  end

  #=========================================================================
  # 太陽の黄経 λsun(jy) を計算する
  # 引数   .... jy : 経過ユリウス年
  # 戻り値 .... 黄経
  #=========================================================================
  def calc_lng_sun(jy)
    begin
      rm_sun  = 0.0003 * Math.sin(PI_180 * normalize_angle(329.7  +   44.43  * jy))
      rm_sun += 0.0003 * Math.sin(PI_180 * normalize_angle(352.5  + 1079.97  * jy))
      rm_sun += 0.0004 * Math.sin(PI_180 * normalize_angle( 21.1  +  720.02  * jy))
      rm_sun += 0.0004 * Math.sin(PI_180 * normalize_angle(157.3  +  299.30  * jy))
      rm_sun += 0.0004 * Math.sin(PI_180 * normalize_angle(234.9  +  315.56  * jy))
      rm_sun += 0.0005 * Math.sin(PI_180 * normalize_angle(291.2  +   22.81  * jy))
      rm_sun += 0.0005 * Math.sin(PI_180 * normalize_angle(207.4  +    1.50  * jy))
      rm_sun += 0.0006 * Math.sin(PI_180 * normalize_angle( 29.8  +  337.18  * jy))
      rm_sun += 0.0007 * Math.sin(PI_180 * normalize_angle(206.8  +   30.35  * jy))
      rm_sun += 0.0007 * Math.sin(PI_180 * normalize_angle(153.3  +   90.38  * jy))
      rm_sun += 0.0008 * Math.sin(PI_180 * normalize_angle(132.5  +  659.29  * jy))
      rm_sun += 0.0013 * Math.sin(PI_180 * normalize_angle( 81.4  +  225.18  * jy))
      rm_sun += 0.0015 * Math.sin(PI_180 * normalize_angle(343.2  +  450.37  * jy))
      rm_sun += 0.0018 * Math.sin(PI_180 * normalize_angle(251.3  +    0.20  * jy))
      rm_sun += 0.0018 * Math.sin(PI_180 * normalize_angle(297.8  + 4452.67  * jy))
      rm_sun += 0.0020 * Math.sin(PI_180 * normalize_angle(247.1  +  329.64  * jy))
      rm_sun += 0.0048 * Math.sin(PI_180 * normalize_angle(234.95 +   19.341 * jy))
      rm_sun += 0.0200 * Math.sin(PI_180 * normalize_angle(355.05 +  719.981 * jy))
      rm_sun += (1.9146 - 0.00005 * jy) * Math.sin(PI_180 * normalize_angle(357.538 + 359.991 * jy))
      rm_sun += normalize_angle(280.4603 + 360.00769 * jy)
      return rm_sun
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 太陽の距離 r(jy) を計算する
  # 引数   .... jy : 経過ユリウス年
  # 戻り値 .... 距離
  #=========================================================================
  def calc_dist_sun(jy)
    begin
      r_sun  = 0.000007 * Math.sin(PI_180 * normalize_angle(156.0 +  329.6  * jy))
      r_sun += 0.000007 * Math.sin(PI_180 * normalize_angle(254.0 +  450.4  * jy))
      r_sun += 0.000013 * Math.sin(PI_180 * normalize_angle( 27.8 + 4452.67 * jy))
      r_sun += 0.000030 * Math.sin(PI_180 * normalize_angle( 90.0))
      r_sun += 0.000091 * Math.sin(PI_180 * normalize_angle(265.1 +  719.98 * jy))
      r_sun += (0.007256 - 0.0000002 * jy) * Math.sin(PI_180 * normalize_angle(267.54 + 359.991 * jy))
      r_sun  = 10.0 ** r_sun
      return r_sun
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 月の黄経 λmoon(jy) を計算する
  # 引数   .... jy : 経過ユリウス年
  # 戻り値 .... 黄経
  #=========================================================================
  def calc_lng_moon(jy)
    begin
      am       = 0.0006 * Math.sin(PI_180 * normalize_angle( 54.0   +    19.3    * jy))
      am      += 0.0006 * Math.sin(PI_180 * normalize_angle( 71.0   +     0.2    * jy))
      am      += 0.0020 * Math.sin(PI_180 * normalize_angle( 55.0   +    19.34   * jy))
      am      += 0.0040 * Math.sin(PI_180 * normalize_angle(119.5   +     1.33   * jy))
      rm_moon  = 0.0003 * Math.sin(PI_180 * normalize_angle(280.0   + 23221.3    * jy))
      rm_moon += 0.0003 * Math.sin(PI_180 * normalize_angle(161.0   +    40.7    * jy))
      rm_moon += 0.0003 * Math.sin(PI_180 * normalize_angle(311.0   +  5492.0    * jy))
      rm_moon += 0.0003 * Math.sin(PI_180 * normalize_angle(147.0   + 18089.3    * jy))
      rm_moon += 0.0003 * Math.sin(PI_180 * normalize_angle( 66.0   +  3494.7    * jy))
      rm_moon += 0.0003 * Math.sin(PI_180 * normalize_angle( 83.0   +  3814.0    * jy))
      rm_moon += 0.0004 * Math.sin(PI_180 * normalize_angle( 20.0   +   720.0    * jy))
      rm_moon += 0.0004 * Math.sin(PI_180 * normalize_angle( 71.0   +  9584.7    * jy))
      rm_moon += 0.0004 * Math.sin(PI_180 * normalize_angle(278.0   +   120.1    * jy))
      rm_moon += 0.0004 * Math.sin(PI_180 * normalize_angle(313.0   +   398.7    * jy))
      rm_moon += 0.0005 * Math.sin(PI_180 * normalize_angle(332.0   +  5091.3    * jy))
      rm_moon += 0.0005 * Math.sin(PI_180 * normalize_angle(114.0   + 17450.7    * jy))
      rm_moon += 0.0005 * Math.sin(PI_180 * normalize_angle(181.0   + 19088.0    * jy))
      rm_moon += 0.0005 * Math.sin(PI_180 * normalize_angle(247.0   + 22582.7    * jy))
      rm_moon += 0.0006 * Math.sin(PI_180 * normalize_angle(128.0   +  1118.7    * jy))
      rm_moon += 0.0007 * Math.sin(PI_180 * normalize_angle(216.0   +   278.6    * jy))
      rm_moon += 0.0007 * Math.sin(PI_180 * normalize_angle(275.0   +  4853.3    * jy))
      rm_moon += 0.0007 * Math.sin(PI_180 * normalize_angle(140.0   +  4052.0    * jy))
      rm_moon += 0.0008 * Math.sin(PI_180 * normalize_angle(204.0   +  7906.7    * jy))
      rm_moon += 0.0008 * Math.sin(PI_180 * normalize_angle(188.0   + 14037.3    * jy))
      rm_moon += 0.0009 * Math.sin(PI_180 * normalize_angle(218.0   +  8586.0    * jy))
      rm_moon += 0.0011 * Math.sin(PI_180 * normalize_angle(276.5   + 19208.02   * jy))
      rm_moon += 0.0012 * Math.sin(PI_180 * normalize_angle(339.0   + 12678.71   * jy))
      rm_moon += 0.0016 * Math.sin(PI_180 * normalize_angle(242.2   + 18569.38   * jy))
      rm_moon += 0.0018 * Math.sin(PI_180 * normalize_angle(  4.1   +  4013.29   * jy))
      rm_moon += 0.0020 * Math.sin(PI_180 * normalize_angle( 55.0   +    19.34   * jy))
      rm_moon += 0.0021 * Math.sin(PI_180 * normalize_angle(105.6   +  3413.37   * jy))
      rm_moon += 0.0021 * Math.sin(PI_180 * normalize_angle(175.1   +   719.98   * jy))
      rm_moon += 0.0021 * Math.sin(PI_180 * normalize_angle( 87.5   +  9903.97   * jy))
      rm_moon += 0.0022 * Math.sin(PI_180 * normalize_angle(240.6   +  8185.36   * jy))
      rm_moon += 0.0024 * Math.sin(PI_180 * normalize_angle(252.8   +  9224.66   * jy))
      rm_moon += 0.0024 * Math.sin(PI_180 * normalize_angle(211.9   +   988.63   * jy))
      rm_moon += 0.0026 * Math.sin(PI_180 * normalize_angle(107.2   + 13797.39   * jy))
      rm_moon += 0.0027 * Math.sin(PI_180 * normalize_angle(272.5   +  9183.99   * jy))
      rm_moon += 0.0037 * Math.sin(PI_180 * normalize_angle(349.1   +  5410.62   * jy))
      rm_moon += 0.0039 * Math.sin(PI_180 * normalize_angle(111.3   + 17810.68   * jy))
      rm_moon += 0.0040 * Math.sin(PI_180 * normalize_angle(119.5   +     1.33   * jy))
      rm_moon += 0.0040 * Math.sin(PI_180 * normalize_angle(145.6   + 18449.32   * jy))
      rm_moon += 0.0040 * Math.sin(PI_180 * normalize_angle( 13.2   + 13317.34   * jy))
      rm_moon += 0.0048 * Math.sin(PI_180 * normalize_angle(235.0   +    19.34   * jy))
      rm_moon += 0.0050 * Math.sin(PI_180 * normalize_angle(295.4   +  4812.66   * jy))
      rm_moon += 0.0052 * Math.sin(PI_180 * normalize_angle(197.2   +   319.32   * jy))
      rm_moon += 0.0068 * Math.sin(PI_180 * normalize_angle( 53.2   +  9265.33   * jy))
      rm_moon += 0.0079 * Math.sin(PI_180 * normalize_angle(278.2   +  4493.34   * jy))
      rm_moon += 0.0085 * Math.sin(PI_180 * normalize_angle(201.5   +  8266.71   * jy))
      rm_moon += 0.0100 * Math.sin(PI_180 * normalize_angle( 44.89  + 14315.966  * jy))
      rm_moon += 0.0107 * Math.sin(PI_180 * normalize_angle(336.44  + 13038.696  * jy))
      rm_moon += 0.0110 * Math.sin(PI_180 * normalize_angle(231.59  +  4892.052  * jy))
      rm_moon += 0.0125 * Math.sin(PI_180 * normalize_angle(141.51  + 14436.029  * jy))
      rm_moon += 0.0153 * Math.sin(PI_180 * normalize_angle(130.84  +   758.698  * jy))
      rm_moon += 0.0305 * Math.sin(PI_180 * normalize_angle(312.49  +  5131.979  * jy))
      rm_moon += 0.0348 * Math.sin(PI_180 * normalize_angle(117.84  +  4452.671  * jy))
      rm_moon += 0.0410 * Math.sin(PI_180 * normalize_angle(137.43  +  4411.998  * jy))
      rm_moon += 0.0459 * Math.sin(PI_180 * normalize_angle(238.18  +  8545.352  * jy))
      rm_moon += 0.0533 * Math.sin(PI_180 * normalize_angle( 10.66  + 13677.331  * jy))
      rm_moon += 0.0572 * Math.sin(PI_180 * normalize_angle(103.21  +  3773.363  * jy))
      rm_moon += 0.0588 * Math.sin(PI_180 * normalize_angle(214.22  +   638.635  * jy))
      rm_moon += 0.1143 * Math.sin(PI_180 * normalize_angle(  6.546 +  9664.0404 * jy))
      rm_moon += 0.1856 * Math.sin(PI_180 * normalize_angle(177.525 +   359.9905 * jy))
      rm_moon += 0.2136 * Math.sin(PI_180 * normalize_angle(269.926 +  9543.9773 * jy))
      rm_moon += 0.6583 * Math.sin(PI_180 * normalize_angle(235.700 +  8905.3422 * jy))
      rm_moon += 1.2740 * Math.sin(PI_180 * normalize_angle(100.738 +  4133.3536 * jy))
      rm_moon += 6.2887 * Math.sin(PI_180 * normalize_angle(134.961 +  4771.9886 * jy + am ) )
      rm_moon += normalize_angle(218.3161 + 4812.67881 * jy)
      return rm_moon
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 月の黄緯 βmoon(jy) を計算する
  # 引数　 .... jy : 経過ユリウス年
  # 戻り値 .... 黄緯
  #=========================================================================
  def calc_lat_moon( jy )
    begin
      bm       =  0.0005 * Math.sin( PI_180 * normalize_angle(307.0   +    19.4    * jy))
      bm      +=  0.0026 * Math.sin( PI_180 * normalize_angle( 55.0   +    19.34   * jy))
      bm      +=  0.0040 * Math.sin( PI_180 * normalize_angle(119.5   +     1.33   * jy))
      bm      +=  0.0043 * Math.sin( PI_180 * normalize_angle(322.1   +    19.36   * jy))
      bm      +=  0.0267 * Math.sin( PI_180 * normalize_angle(234.95  +    19.341  * jy))
      bt_moon  =  0.0003 * Math.sin( PI_180 * normalize_angle(234.0   + 19268.0    * jy))
      bt_moon +=  0.0003 * Math.sin( PI_180 * normalize_angle(146.0   +  3353.3    * jy))
      bt_moon +=  0.0003 * Math.sin( PI_180 * normalize_angle(107.0   + 18149.4    * jy))
      bt_moon +=  0.0003 * Math.sin( PI_180 * normalize_angle(205.0   + 22642.7    * jy))
      bt_moon +=  0.0004 * Math.sin( PI_180 * normalize_angle(147.0   + 14097.4    * jy))
      bt_moon +=  0.0004 * Math.sin( PI_180 * normalize_angle( 13.0   +  9325.4    * jy))
      bt_moon +=  0.0004 * Math.sin( PI_180 * normalize_angle( 81.0   + 10242.6    * jy))
      bt_moon +=  0.0004 * Math.sin( PI_180 * normalize_angle(238.0   + 23281.3    * jy))
      bt_moon +=  0.0004 * Math.sin( PI_180 * normalize_angle(311.0   +  9483.9    * jy))
      bt_moon +=  0.0005 * Math.sin( PI_180 * normalize_angle(239.0   +  4193.4    * jy))
      bt_moon +=  0.0005 * Math.sin( PI_180 * normalize_angle(280.0   +  8485.3    * jy))
      bt_moon +=  0.0006 * Math.sin( PI_180 * normalize_angle( 52.0   + 13617.3    * jy))
      bt_moon +=  0.0006 * Math.sin( PI_180 * normalize_angle(224.0   +  5590.7    * jy))
      bt_moon +=  0.0007 * Math.sin( PI_180 * normalize_angle(294.0   + 13098.7    * jy))
      bt_moon +=  0.0008 * Math.sin( PI_180 * normalize_angle(326.0   +  9724.1    * jy))
      bt_moon +=  0.0008 * Math.sin( PI_180 * normalize_angle( 70.0   + 17870.7    * jy))
      bt_moon +=  0.0010 * Math.sin( PI_180 * normalize_angle( 18.0   + 12978.66   * jy))
      bt_moon +=  0.0011 * Math.sin( PI_180 * normalize_angle(138.3   + 19147.99   * jy))
      bt_moon +=  0.0012 * Math.sin( PI_180 * normalize_angle(148.2   +  4851.36   * jy))
      bt_moon +=  0.0012 * Math.sin( PI_180 * normalize_angle( 38.4   +  4812.68   * jy))
      bt_moon +=  0.0013 * Math.sin( PI_180 * normalize_angle(155.4   +   379.35   * jy))
      bt_moon +=  0.0013 * Math.sin( PI_180 * normalize_angle( 95.8   +  4472.03   * jy))
      bt_moon +=  0.0014 * Math.sin( PI_180 * normalize_angle(219.2   +   299.96   * jy))
      bt_moon +=  0.0015 * Math.sin( PI_180 * normalize_angle( 45.8   +  9964.00   * jy))
      bt_moon +=  0.0015 * Math.sin( PI_180 * normalize_angle(211.1   +  9284.69   * jy))
      bt_moon +=  0.0016 * Math.sin( PI_180 * normalize_angle(135.7   +   420.02   * jy))
      bt_moon +=  0.0017 * Math.sin( PI_180 * normalize_angle( 99.8   + 14496.06   * jy))
      bt_moon +=  0.0018 * Math.sin( PI_180 * normalize_angle(270.8   +  5192.01   * jy))
      bt_moon +=  0.0018 * Math.sin( PI_180 * normalize_angle(243.3   +  8206.68   * jy))
      bt_moon +=  0.0019 * Math.sin( PI_180 * normalize_angle(230.7   +  9244.02   * jy))
      bt_moon +=  0.0021 * Math.sin( PI_180 * normalize_angle(170.1   +  1058.66   * jy))
      bt_moon +=  0.0022 * Math.sin( PI_180 * normalize_angle(331.4   + 13377.37   * jy))
      bt_moon +=  0.0025 * Math.sin( PI_180 * normalize_angle(196.5   +  8605.38   * jy))
      bt_moon +=  0.0034 * Math.sin( PI_180 * normalize_angle(319.9   +  4433.31   * jy))
      bt_moon +=  0.0042 * Math.sin( PI_180 * normalize_angle(103.9   + 18509.35   * jy))
      bt_moon +=  0.0043 * Math.sin( PI_180 * normalize_angle(307.6   +  5470.66   * jy))
      bt_moon +=  0.0082 * Math.sin( PI_180 * normalize_angle(144.9   +  3713.33   * jy))
      bt_moon +=  0.0088 * Math.sin( PI_180 * normalize_angle(176.7   +  4711.96   * jy))
      bt_moon +=  0.0093 * Math.sin( PI_180 * normalize_angle(277.4   +  8845.31   * jy))
      bt_moon +=  0.0172 * Math.sin( PI_180 * normalize_angle(  3.18  + 14375.997  * jy))
      bt_moon +=  0.0326 * Math.sin( PI_180 * normalize_angle(328.96  + 13737.362  * jy))
      bt_moon +=  0.0463 * Math.sin( PI_180 * normalize_angle(172.55  +   698.667  * jy))
      bt_moon +=  0.0554 * Math.sin( PI_180 * normalize_angle(194.01  +  8965.374  * jy))
      bt_moon +=  0.1732 * Math.sin( PI_180 * normalize_angle(142.427 +  4073.3220 * jy))
      bt_moon +=  0.2777 * Math.sin( PI_180 * normalize_angle(138.311 +    60.0316 * jy))
      bt_moon +=  0.2806 * Math.sin( PI_180 * normalize_angle(228.235 +  9604.0088 * jy))
      bt_moon +=  5.1282 * Math.sin( PI_180 * normalize_angle( 93.273 +  4832.0202 * jy + bm))
      return bt_moon
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 角度の正規化を行う。すなわち引数の範囲を 0≦θ＜360 にする。
  # 引数   .... ang : 角度
  # 戻り値 .... 角度 ( 度 )
  #=========================================================================
  def normalize_angle(ang)
    return ang - 360.0 * (ang / 360.0).truncate
  rescue => e
    raise
  end

  #=========================================================================
  # 観測地点の恒星時Θ(度)の計算
  # 引数   .... hash
  #             .. jy : 経過ユリウス年
  #             .. t  : 時刻 ( 0.xxxx日 )
  # 戻り値 .... 観測地点の恒星時Θ(度)
  #=========================================================================
  def calc_time_sidereal(hash = {})
    jy = hash[:jy]
    t  = hash[:t]

    begin
      val  = 325.4606
      val += 360.007700536 * jy
      val += 0.00000003879 * jy * jy
      val += 360.0 * t
      val += @lon
      return normalize_angle(val)
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 出入点(k)の時角(tk)と天体の時角(t)との差(dt=tk-t)を計算する
  # 引数   .... hash
  #             .. sekkei        : 天体の赤経 ( α(T)(度) )
  #             .. sekii         : 天体の赤緯 ( δ(T)(度) )
  #             .. time_sidereal : 恒星時Θ(度)
  #             .. height        : 観測地点の出没高度(度)
  #             .. flag          : 出入フラグ ( 0 : 出, 1 : 入, 2 : 南中 )
  # 戻り値 .... 時角の差　dt
  #=========================================================================
  def calc_hour_ang_dif(hash = {})
    sekkei        = hash[:sekkei]
    sekii         = hash[:sekii]
    time_sidereal = hash[:time_sidereal]
    height        = hash[:height]
    flag          = hash[:flag]

    begin
      # 南中の場合は天体の時角を返す
      if flag == 2
        tk = 0
      else
        tk  = Math.sin(PI_180 * height)
        tk -= Math.sin(PI_180 * sekii) * Math.sin(PI_180 * @lat)
        tk /= Math.cos(PI_180 * sekii) * Math.cos(PI_180 * @lat)
        # 出没点の時角
        tk  = Math.acos(tk) / PI_180
        # tkは出のときマイナス、入のときプラス
        tk = -tk if flag == 0 && tk > 0
        tk = -tk if flag == 1 && tk < 0
      end
      # 天体の時角
      t = time_sidereal - sekkei
      dt = tk - t
      # dtの絶対値を180°以下に調整
      if dt >  180
        while dt >  180; dt -= 360; end
      end
      if dt < -180
        while dt < -180; dt += 360; end
      end
      return dt
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 時刻(t)における黄経、黄緯(λ(jy),β(jy))の天体の方位角(ang)計算
  # 引数   .... hash
  #             .. kokei : 天体の黄経( λ(T)(度) )
  #             .. koi   : 天体の黄緯( β(T)(度) )
  #             .. jy    : 経過ユリウス年
  #             .. t     : 時刻 ( 0.xxxx日 )
  # 戻り値 .... 角度(xx.x度)
  #=========================================================================
  def calc_ang(hash = {})
    kokei = hash[:kokei]
    koi   = hash[:koi]
    t     = hash[:time]
    jy    = hash[:jy]

    begin
      # 黄道 -> 赤道変換
      res = calc_kou2seki({kokei: kokei, koi: koi, jy: jy})
      return calc_ang_e({
        sekkei: res[:sekkei], sekii: res[:sekii], time: t, jy: jy
      })
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 時刻(t)における赤経、赤緯(α(jy),δ(jy))(度)の天体の方位角(ang)計算
  # 引数   .... hash
  #             .. sekkei : 天体の赤経( α(jy)(度) )
  #             .. sekii  : 天体の赤緯( δ(jy)(度) )
  #             .. jy     : 経過ユリウス年
  #             .. t      : 時刻 ( 0.xxxx日 )
  # 戻り値 .... 角度(xx.x度)
  #=========================================================================
  def calc_ang_e(hash = {})
    sekkei = hash[:sekkei]
    sekii  = hash[:sekii]
    t      = hash[:time]
    jy     = hash[:jy]

    begin
      # 恒星時
      time_sidereal = calc_time_sidereal({jy: jy, t: t})
      # 天体の時角
      hour_ang = time_sidereal - sekkei
      # 天体の方位角
      a_0  = -1.0 * Math.cos(PI_180 * sekii) * Math.sin(PI_180 * hour_ang)
      a_1  = Math.sin(PI_180 * sekii) * Math.cos(PI_180 * @lat)
      a_1 -= Math.cos(PI_180 * sekii) * Math.sin(PI_180 * @lat) * Math.cos(PI_180 * hour_ang)
      ang  = Math.atan(a_0 / a_1) / PI_180
      # 分母がプラスのときは -90°< ang < 90°
      ang += 360.0 if a_1 > 0.0 && ang < 0.0
      # 分母がマイナスのときは 90°< ang < 270° → 180°加算する
      ang += 180.0 if a_1 < 0.0
      return ((ang * 10 ** KETA).round) / (10 ** KETA).to_f
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 時刻(t)における黄経、黄緯(λ(jy),β(jy))の天体の高度(height)計算
  # 引数   .... hash
  #             .. kokei : 天体の黄経( λ(T)(度) )
  #             .. koi   : 天体の黄緯( β(T)(度) )
  #             .. jy    : 経過ユリウス年
  #             .. t     : 時刻 ( 0.xxxx日 )
  # 戻り値 .... 高度(xx.x度)
  #=========================================================================
  def calc_height(hash = {})
    kokei = hash[:kokei]
    koi   = hash[:koi]
    t     = hash[:time]
    jy    = hash[:jy]

    begin
      # 黄道 -> 赤道変換
      res = calc_kou2seki({kokei: kokei, koi: koi, jy: jy})
      return calc_height_e({
        sekkei: res[:sekkei], sekii: res[:sekii],
        time: t, jy: jy
      })
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 時刻(t)における赤経、赤緯(α(jy),δ(jy))(度)の天体の高度(height)計算
  # 引数   .... hash
  #             .. sekkei : 天体の赤経α(jy)(度)
  #             .. sekii  : 天体の赤緯δ(jy)(度)
  #             .. jy     : 経過ユリウス年
  #             .. t      : 時刻 ( 0.xxxx日 )
  # 戻り値 .... 高度(xx.x度)
  #=========================================================================
  def calc_height_e(hash = {})
    sekkei = hash[:sekkei]
    sekii  = hash[:sekii]
    t      = hash[:time]
    jy     = hash[:jy]

    begin
      # 恒星時
      time_sidereal = calc_time_sidereal(jy: jy, t: t)
      # 天体の時角
      sidereal = time_sidereal - sekkei
      # 天体の高度
      height  = Math.sin(PI_180 * sekii) * Math.sin(PI_180 * @lat)
      height += Math.cos(PI_180 * sekii) * Math.cos(PI_180 * @lat) * Math.cos(PI_180 * sidereal)
      height  = Math.asin(height) / PI_180

      # 大気差補正
      # [ 以下の内、3-2の計算式を採用 ]
      # # 1. 日月出没計算 by「菊池さん」による計算式
      # #   [ http://kikuchisan.net/ ]
      # h = 0.0167 / Math.tan( PI_180 * ( height + 8.6 / ( height + 4.4 ) ) )

      # # 2. 中川用語集による計算式 ( 5度 - 85度用 )
      # #   [ http://www.es.ris.ac.jp/~nakagawa/term_collection/yogoshu/ll/ni.htm ]
      # h  = 58.1      / Math.tan( height )
      # h -=  0.07     / Math.tan( height ) ** 3
      # h +=  0.000086 / Math.tan( height ) ** 5
      # h *= 1 / 3600.0

      # # 3-1. フランスの天文学者ラドー(R.Radau)の平均大気差と１秒程度の差で大気差を求めることが可能
      # # ( 標準的大気(気温10ﾟC，気圧1013.25hPa)の場合 )
      # # ( 視高度30ﾟ以上 )
      # h  = ( 58.294  / 3600.0 ) * Math.tan( PI_180 * ( 90.0 - height ) )
      # h -= (  0.0668 / 3600.0 ) * Math.tan( PI_180 * ( 90.0 - height ) ) ** 3

      # 3-2. フランスの天文学者ラドー(R.Radau)の平均大気差と１秒程度の差で大気差を求めることが可能
      # ( 標準的大気(気温10ﾟC，気圧1013.25hPa)の場合 )
      # ( 視高度 4ﾟ以上 )
      h  = 58.76   * Math.tan(PI_180 * (90.0 - height))
      h -=  0.406  * Math.tan(PI_180 * (90.0 - height)) ** 2
      h -=  0.0192 * Math.tan(PI_180 * (90.0 - height)) ** 3
      h *= 1 / 3600.0

      # # 3-3. さらに、上記の大気差(3-1,3-2)を気温、気圧を考慮する
      # # ( しかし、気温・気圧を考慮してもさほど変わりはない )
      # pres = 1013.25 # <= 変更
      # temp = 30.0    # <= 変更
      # h *= pres / 1013.25
      # h *= 283.25 / ( 273.15 + temp )

      height += h
      return ((height * 10 ** KETA).round) / (10 ** KETA).to_f
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 黄道座標 -> 赤道座標変換
  # 引数   .... hash
  #             .. kokei : 黄経( λ(jy)(度) )
  #             .. koi   : 黄緯( β(jy)(度) )
  #             .. jy    : 経過ユリウス年
  # 戻り値 .... hash
  #             .. sekkei : 赤経( α(jy)(度) )
  #             .. sekii  : 赤緯( δ(jy)(度) )
  #=========================================================================
  def calc_kou2seki(hash = {})
    kokei = hash[:kokei]
    koi   = hash[:koi]
    jy    = hash[:jy]

    begin
      # 黄道傾角
      angle_kodo = (23.439291 - 0.000130042 * jy) * PI_180
      # 赤経・赤緯計算
      rambda = kokei * PI_180
      beta   = koi   * PI_180
      a  =      Math.cos(beta) * Math.cos(rambda)
      b  = -1 * Math.sin(beta) * Math.sin(angle_kodo)
      b +=      Math.cos(beta) * Math.sin(rambda) * Math.cos(angle_kodo)
      c  =      Math.sin(beta) * Math.cos(angle_kodo )
      c +=      Math.cos(beta) * Math.sin(rambda) * Math.sin(angle_kodo)
      sekkei  = b / a
      sekkei  = Math.atan(sekkei) / PI_180
      sekkei += 180 if a < 0 # aがマイナスのときは 90°< α < 270° → 180°加算する。
      # sekii   = c / Math.sqrt( a * a + b * b )
      # sekii   = Math.atan( sekii ) / PI_180
      # 上記のsekiiの計算は以下と同じ
      sekii   = Math.asin(c) / PI_180
      return {sekkei: sekkei, sekii: sekii}
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 時間：数値->時間：時分変換(xx.xxxx -> hh:mm)
  # 引数   .... num : 時刻 ( xx.xxxx日 )
  # 戻り値 .... 時刻(hh:mm:ss)
  #=========================================================================
  def convert_time(num)
    begin
      # 整数部(時)
      num_h = num.truncate
      # 小数部
      num_2 = num - num_h
      # (分)計算
      num_m = (num_2 * 60).truncate
      # (秒)計算
      num_3 = num_2 - (num_m / 60.0)
      num_s = (num_3 * 60 * 60).round
      return sprintf("%02d:%02d:%02d", num_h, num_m, num_s)
    rescue => e
      raise
    end
  end

  # 結果出力
  def display
    str_out  = sprintf("%04d-%02d-%02d", @year, @month, @day)
    str_out << "[#{@lat}#{@sign_lat}, #{@lon}#{@sign_lon}, #{@ht}m]"
    @opt.each_char do |op|
      case op
      when "a"; str_out << " #{@hash[:time_sr  ]}"  # 日の出時刻
      when "b"; str_out << " #{@hash[:ang_sr   ]}"  # 日の出方位角
      when "c"; str_out << " #{@hash[:time_ss  ]}"  # 日の入時刻
      when "d"; str_out << " #{@hash[:ang_ss   ]}"  # 日の入方位角
      when "e"; str_out << " #{@hash[:time_sm  ]}"  # 日の南中時刻
      when "f"; str_out << " #{@hash[:height_sm]}"  # 日の南中高度
      when "g"; str_out << " #{@hash[:time_mr  ]}"  # 月の出時刻
      when "h"; str_out << " #{@hash[:ang_mr   ]}"  # 月の出方位角
      when "i"; str_out << " #{@hash[:time_ms  ]}"  # 月の入時刻
      when "j"; str_out << " #{@hash[:ang_ms   ]}"  # 月の入方位角
      when "k"; str_out << " #{@hash[:time_mm  ]}"  # 月の南中時刻
      when "l"; str_out << " #{@hash[:height_mm]}"  # 月の南中高度
      end
    end
    puts str_out
  rescue => e
    raise
  end
end

exit unless __FILE__ == $0
SunMoon.new.exec

