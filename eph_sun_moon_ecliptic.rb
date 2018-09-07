#! /usr/local/bin/ruby
# coding: utf-8
#---------------------------------------------------------------------------------
#= 海上保安庁の天測暦より太陽・月の視位置を計算
#  （視黄経・視黄緯の計算を追加したもの）
#
# date          name            version
# 2016.04.12    mk-mode.com     1.00 新規作成
#
# Copyright(C) 2016 mk-mode.com All Rights Reserved.
#---------------------------------------------------------------------------------
# 引数 : JST（日本標準時）
#          書式：YYYYMMDD or YYYYMMDDHHMMSS
#          無指定なら現在(システム日時)と判断。
#---------------------------------------------------------------------------------
#++
require 'date'
require './consts.rb'

class EphSunMoonEcliptic
  JST_UTC = 9  # JST - UTC
  MSG_ERR_1 = "[ERROR] Format: YYYYMMDD or YYYYMMDDHHMMSS"
  MSG_ERR_2 = "[ERROR] It should be between 20080101090000 and 20200101085959."
  DIVS = [
    "SUN_RA", "SUN_DEC","SUN_DIST",
    "MOON_RA", "MOON_DEC", "MOON_HP",
    "R", "EPS"
  ]
  DELTA_T = {
    2008 => 65, 2009 => 66, 2010 => 66, 2011 => 67, 2012 => 67,
    2013 => 67, 2014 => 67, 2015 => 68, 2016 => 68, 2017 => 68,
    2018 => 69, 2019 => 70
  }

  def initialize
    @vals = Hash.new  # 所要値格納用ハッシュ
    get_arg           # 引数取得
    utc = Time.at(@utc)
    @year, @month, @day = utc.year, utc.month, utc.day
    @hour, @min, @sec   = utc.hour, utc.min, utc.sec
  end

  def exec
    calc_t       # 通日 T の計算
    calc_f       # 世界時 UT(時・分・秒) の端数計算
    get_delta_t  # ΔT（世界時 - 地球時）の取得
    calc_tm      # 計算用時刻引数 tm の計算
    calc         # 各種計算
    display      # 結果出力
  rescue => e
    $stderr.puts "[#{e.class}] #{e.message}"
    e.backtrace.each { |tr| $stderr.puts "\t#{tr}"}
    exit 1
  end

  private

  #=========================================================================
  # 引数取得
  #
  #   * コマンドライン引数を取得して日時の妥当性チェックを行う
  #   * コマンドライン引数無指定なら、現在日時とする。
  #   * JST, UTC をインスタンス変数 @jst, @utc に格納する。
  #=========================================================================
  def get_arg
    if arg = ARGV.shift
      (puts MSG_ERR_1; exit 0) unless arg =~ /^\d{8}$|^\d{14}$/
      year, month, day = arg[ 0, 4].to_i, arg[ 4, 2].to_i, arg[ 6, 2].to_i
      hour, min,   sec = arg[ 8, 2].to_i, arg[10, 2].to_i, arg[12, 2].to_i
      (puts MSG_ERR_1; exit 0) unless Date.valid_date?(year, month, day)
      (puts MSG_ERR_1; exit 0) if hour > 23 || min > 59 || sec > 59
      if sprintf("%04d%02d%02d%02d%02d%02d", year, month, day, hour, min, sec) < "20080101090000" ||
         sprintf("%04d%02d%02d%02d%02d%02d", year, month, day, hour, min, sec) > "20200101085959"
        puts MSG_ERR_2
        exit 0
      end
      @jst = Time.new(year, month, day, hour, min, sec).to_f
      @utc = @jst - JST_UTC * 60 * 60
      return
    end
    jst = Time.now
    @jst = Time.new(
      jst.year, jst.month, jst.day,
      jst.hour, jst.min, jst.sec
    ).to_f
    @utc = @jst - JST_UTC * 60 * 60
  rescue => e
    raise
  end

  #=========================================================================
  # 通日 T の計算
  #
  #   * 通日 T は1月0日を第0日とした通算日数で、次式により求める。
  #       T = 30 * P + Q * (S - Y) + P * (1 - Q) + 日
  #     但し、
  #       P = 月 - 1, Q = [(月 + 7) / 10]
  #       Y = [(年 / 4) - [(年 / 4)] + 0.77]
  #       S = [P * 0.55 - 0.33]
  #     で、[] は整数部のみを抜き出すことを意味する。
  #   * 求めた通日 T はインスタンス変数 @t に格納する。
  #=========================================================================
  def calc_t
    p = @month - 1
    q = ((@month + 7) / 10.0).to_i
    y = ((@year / 4.0) - (@year / 4.0).to_i + 0.77).to_i
    s = (p * 0.55 - 0.33).to_i
    @t = 30 * p + q * (s - y) + p * (1 - q) + @day
  rescue => e
    raise
  end

  #=========================================================================
  # 世界時 UT(時・分・秒) の端数計算
  #
  #   * 次式により求め、インスタンス変数 @f に格納する。
  #       F = 時 / 24 + 分 / 1440 + 秒 / 86400
  #=========================================================================
  def calc_f
    utc = Time.at(@utc)
    @f = utc.hour / 24.0 + utc.min / 1440.0 + utc.sec / 86400.0
  rescue => e
    raise
  end

  #=========================================================================
  # ΔT（世界時 - 地球時）の取得
  #
  #   * あらかじめ予測されている ΔT の値を取得し、インスタンス変数 @delta_t
  #     に格納する。
  #=========================================================================
  def get_delta_t
    @delta_t = DELTA_T[@year]
  rescue => e
    raise
  end

  #=========================================================================
  # 計算用時刻引数 tm の計算
  #
  #   * 次式により求め、インスタンス変数 @tm, @tm_r に格納する。
  #     (R 計算用は tm_r, その他は tm)
  #       tm   = T + F + ΔT / 86400
  #       tm_r = T + F
  #=========================================================================
  def calc_tm
    @tm_r = @t + @f
    @tm   = @tm_r + @delta_t / 86400.0
  rescue => e
    raise
  end

  #=========================================================================
  # 各種計算
  #
  #   * 各種値を計算し、インスタンス変数 @vals に格納する。
  #=========================================================================
  def calc
    begin
      # 各種係数からの計算
      DIVS.each do |div|
        a, b, coeffs = get_coeffs(div)  # 係数値等の取得
        t = div == "R" ? @tm_r : @tm    # 計算用時刻引数
        theta = calc_theta(a, b, t)     # θ の計算
        val = calc_ft(theta, coeffs)    # 所要値の計算
        if div =~ /_RA$|^R$/
          while val >= 24.0; val -= 24.0; end
          while val <= 0.0;  val += 24.0; end
        end
        @vals[div] = val
      end
      # グリニジ時角の計算
      @vals["SUN_H" ] = calc_h(@vals["SUN_RA" ])
      @vals["MOON_H"] = calc_h(@vals["MOON_RA"])
      # 視半径の計算
      @vals["SUN_SD" ] = calc_sd_sun
      @vals["MOON_SD"] = calc_sd_moon
      # 視黄経・視黄緯の計算
      @vals["SUN_LAMBDA" ] = calc_lambda(@vals["SUN_RA"], @vals["SUN_DEC"])
      @vals["SUN_BETA"   ] = calc_beta(@vals["SUN_RA"], @vals["SUN_DEC"])
      @vals["MOON_LAMBDA"] = calc_lambda(@vals["MOON_RA"], @vals["MOON_DEC"])
      @vals["MOON_BETA"  ] = calc_beta(@vals["MOON_RA"], @vals["MOON_DEC"])
      @vals["LAMBDA_S_M" ] = calc_lambda_sun_moon  # 視黄経差（太陽 - 月）
    rescue => e
      raise
    end
  end

  #=========================================================================
  # 係数等の取得
  #
  #   * 引数の文字列の定数配列から a, b, 係数配列を取得する。
  #
  #   @params: 定数名
  #   @return: [a, b, 係数配列]
  #=========================================================================
  def get_coeffs(div)
    a, b = 0, 0
    coeffs = Array.new

    begin
      Object.const_get(div).each do |row|
        next unless row[0] == @year
        if row[1][0] <= @tm.to_i && @tm.to_i <= row[1][1]
          a, b   = row[1]
          coeffs = row[2]
          break
        end
      end
      return [a, b, coeffs]
    rescue => e
      raise
    end
  end

  #=========================================================================
  # θ の計算
  #
  #   * θ を次式により計算する。
  #       θ = cos^(-1)((2 * t - (a + b)) / (b - a))
  #     但し、0°<= θ <= 180°
  #
  #   @params: a, b, t
  #   @return: theta (単位: °)
  #=========================================================================
  def calc_theta(a, b, t)
    b = t if b < t  # 年末のΔT秒分も計算可能とするための応急処置
    theta = (2 * t - (a + b)) / (b - a).to_f
    return Math.acos(theta) * 180 / Math::PI
  rescue => e
    raise
  end

  #=========================================================================
  # 所要値の計算
  #
  #   * θ, 係数配列から次式により所要値を計算する。
  #       f(t) = C_0 + C_1 * cos(θ) + C_2 * cos(2θ) + ... + C_N * cos(Nθ)
  #
  #   @params: theta, 係数配列
  #   @return: 所要値
  #=========================================================================
  def calc_ft(theta, coeffs)
    ft = 0.0

    begin
      coeffs.each_with_index do |c, i|
        ft += c * Math.cos(theta * i * Math::PI / 180.0)
      end
      return ft
    rescue => e
      raise
    end
  end

  #=========================================================================
  # グリニジ時角の計算
  #
  #   * 次式によりグリニジ時角を計算する。
  #       h = E + UT
  #     (但し、E = R - R.A.)
  #
  #   @params: R.A.
  #   @return: h (単位: h)
  #=========================================================================
  def calc_h(ra)  # グリニジ時角の計算
    e = @vals["R"] - ra
    return e + @f * 24
  rescue => e
    raise
  end

  #=========================================================================
  # 視半径（太陽）の計算
  #
  #   * 次式により視半径を計算する。
  #       S.D.= 16.02 ′/ Dist.
  #
  #   @return: sd (単位: ′)
  #=========================================================================
  def calc_sd_sun
    return 16.02 / @vals["SUN_DIST"]
  rescue => e
    raise
  end

  #=========================================================================
  # 視半径（月）の計算
  #
  #   * 次式により視半径を計算する。
  #       S.D.= sin^(-1) (0.2725 * sin(H.P.))
  #
  #   @return: sd (単位: ′)
  #=========================================================================
  def calc_sd_moon
    sd = Math.asin(0.2725 * Math.sin(@vals["MOON_HP"] * Math::PI / 180.0))
    return sd * 60.0 * 180.0 / Math::PI
  rescue => e
    raise
  end

  #=========================================================================
  # 視黄経の計算
  #
  #   * 次式により視黄経を計算する
  #       λ = arctan(sin δ sin ε + cos δ sin α cos ε / cos δ cos α)
  #     (α : 視赤経、δ : 視赤緯、 ε : 黄道傾斜角)
  #
  #   @params: alpha(ra, 視赤経), delta(dec, 視赤緯)
  #   @return: lm(視黄経)
  #=========================================================================
  def calc_lambda(alpha, delta)
    alpha = alpha * 15   * Math::PI / 180.0
    delta = delta        * Math::PI / 180.0
    eps   = @vals["EPS"] * Math::PI / 180.0
    lm_a  = Math.sin(delta) * Math.sin(eps)
    lm_a += Math.cos(delta) * Math.sin(alpha) * Math.cos(eps)
    lm_b  = Math.cos(delta) * Math.cos(alpha)
    lm    = Math.atan2(lm_a, lm_b) * 180 / Math::PI
    lm   += 360.0 if lm < 0
    return lm
  rescue => e
    raise
  end

  #=========================================================================
  # 視黄緯の計算
  #
  #   * 次式により視黄経を計算する
  #       β  = arcsin(sin δ cos ε − cos δ sin α sin ε)
  #     (α : 視赤経、δ : 視赤緯、 ε : 黄道傾斜角)
  #
  #   @params: alpha(ra, 視赤経), delta(dec, 視赤緯)
  #   @return: bt(視黄緯)
  #=========================================================================
  def calc_beta(alpha, delta)
    alpha = alpha * 15   * Math::PI / 180.0
    delta = delta        * Math::PI / 180.0
    eps   = @vals["EPS"] * Math::PI / 180.0
    bt  = Math.sin(delta) * Math.cos(eps)
    bt -= Math.cos(delta) * Math.sin(alpha) * Math.sin(eps)
    bt  = Math.asin(bt) * 180 / Math::PI
    return bt
  rescue => e
    raise
  end

  #=========================================================================
  # 視黄経差（太陽 - 月）の計算
  #
  #   * SUN_LAMBDA - MOON_LAMBDA
  #
  #   @return: 視黄経差（太陽 - 月）
  #=========================================================================
  def calc_lambda_sun_moon
    return @vals["SUN_LAMBDA"] - @vals["MOON_LAMBDA"]
  rescue => e
    raise
  end

  #=========================================================================
  # 結果出力
  #=========================================================================
  def display
    str =  "[ JST: #{Time.at(@jst).strftime("%Y-%m-%d %H:%M:%S")},"
    str << "  UTC: #{Time.at(@utc).strftime("%Y-%m-%d %H:%M:%S")} ]\n"
    str << sprintf("  SUN    R.A. = %12.8f h",    @vals["SUN_RA"  ])
    str << sprintf("  (= %s)\n",         hour2hms(@vals["SUN_RA"  ]))
    str << sprintf("  SUN    DEC. = %12.8f °",    @vals["SUN_DEC" ])
    str << sprintf("  (= %s)\n",          deg2dms(@vals["SUN_DEC" ]))
    str << sprintf("  SUN   DIST. = %12.8f AU\n", @vals["SUN_DIST"])
    str << sprintf("  SUN     hG. = %12.8f h",    @vals["SUN_H"   ])
    str << sprintf("  (= %s)\n",         hour2hms(@vals["SUN_H"   ]))
    str << sprintf("  SUN    S.D. = %12.8f ′",    @vals["SUN_SD"  ])
    str << sprintf("  (= %s)\n",          deg2dms(@vals["SUN_SD"] / 60.0))
    str << sprintf("  MOON   R.A. = %12.8f h",    @vals["MOON_RA" ])
    str << sprintf("  (= %s)\n",         hour2hms(@vals["MOON_RA" ]))
    str << sprintf("  MOON   DEC. = %12.8f °",    @vals["MOON_DEC"])
    str << sprintf("  (= %s)\n",          deg2dms(@vals["MOON_DEC"]))
    str << sprintf("  MOON   H.P. = %12.8f °",    @vals["MOON_HP" ])
    str << sprintf("  (= %s)\n",          deg2dms(@vals["MOON_HP" ]))
    str << sprintf("  MOON    hG. = %12.8f h",    @vals["MOON_H"  ])
    str << sprintf("  (= %s)\n",         hour2hms(@vals["MOON_H"  ]))
    str << sprintf("  MOON   S.D. = %12.8f ′",    @vals["MOON_SD" ])
    str << sprintf("  (= %s)\n",          deg2dms(@vals["MOON_SD"] / 60.0))
    str << sprintf("           R  = %12.8f h",    @vals["R"       ])
    str << sprintf("  (= %s)\n",         hour2hms(@vals["R"       ]))
    str << sprintf("         EPS. = %12.8f °",    @vals["EPS"     ])
    str << sprintf("  (= %s)\n",          deg2dms(@vals["EPS"     ]))
    str << "  ---\n"
    str << sprintf("  SUN  LAMBDA =%13.8f °",    @vals["SUN_LAMBDA" ])
    str << sprintf("  (=%s)\n",          deg2dms(@vals["SUN_LAMBDA" ]))
    str << sprintf("  SUN    BETA =%13.8f °",    @vals["SUN_BETA"   ])
    str << sprintf("  (=%s)\n",          deg2dms(@vals["SUN_BETA"   ]))
    str << sprintf("  MOON LAMBDA =%13.8f °",    @vals["MOON_LAMBDA"])
    str << sprintf("  (=%s)\n",          deg2dms(@vals["MOON_LAMBDA"]))
    str << sprintf("  MOON   BETA =%13.8f °",    @vals["MOON_BETA"  ])
    str << sprintf("  (=%s)\n",          deg2dms(@vals["MOON_BETA"  ]))
    str << sprintf("  DIFF LAMBDA =%13.8f °\n",  @vals["LAMBDA_S_M" ])
    puts str
  rescue => e
    raise
  end

  #=========================================================================
  # 99.999h -> 99h99m99s 変換
  #
  #   @params: hour
  #   @return: "99 h 99 m 99.999 s"
  #=========================================================================
  def hour2hms(hour)
    h   = hour.to_i
    h_r = hour - h
    m   = (h_r * 60).to_i
    m_r = h_r * 60 - m
    s   = m_r * 60
    return sprintf(" %3d h %02d m %06.3f s", h, m, s)
  rescue => e
    raise
  end

  #=========================================================================
  # 99.999° -> 99°99′99″ 変換
  #
  #   @params: deg
  #   @return: "99 ° 99 ′ 99.999 ″"
  #=========================================================================
  def deg2dms(deg)
    pm  = deg < 0 ? "-" : " "
    deg *= -1 if deg < 0
    d   = deg.to_i
    d_r = deg - d
    m   = (d_r * 60).to_i
    m_r = d_r * 60 - m
    s   = m_r * 60
    return sprintf("%4s ° %02d ′ %06.3f ″", "#{pm}#{d}", m, s)
  rescue => e
    raise
  end
end

EphSunMoonEcliptic.new.exec

