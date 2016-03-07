#! /usr/local/bin/ruby
# coding: utf-8
#=月相計算スクリプト
# （グレゴリオ暦から月相を計算する）
#
# date          name            version
# 2013.03.06    mk-mode         1.00 新規作成
# 2016.03.03    mk-mode         1.01 地球自転遅れ補正値ΔTの計算機能を追加
#                                    Ref: [NASA - Polynomial Expressions for Delta T](http://eclipse.gsfc.nasa.gov/SEhelp/deltatpoly2004.html)
# 2016.03.07    mk-mode         1.02 うるう秒挿入が明確な場合の処理を追加
#
# Copyright(C) 2013-2016 mk-mode.com All Rights Reserved.
#---------------------------------------------------------------------------------
# 引数 : 計算日時(グレゴリオ暦)
#          書式：YYYYMMDD or YYYYMMDDHHMMSS
#          無指定なら現在(システム日時)と判断。
#---------------------------------------------------------------------------------
require 'date'

# 円周率の定義
PI = 3.141592653589793238462
# （角度の）度からラジアンに変換する係数の定義
K = PI / 180.0

#============
# 計算クラス
#============
class CalcMoonphase
  def initialize(dt)
    @year  = dt[ 0, 4].to_i
    @month = dt[ 4, 2].to_i
    @day   = dt[ 6, 2].to_i
    @hour  = dt[ 8, 2].to_i
    @min   = dt[10, 2].to_i
    @sec   = dt[12, 2].to_i
  end

  #=========================================================================
  # 年月日(グレゴリオ暦)からユリウス日(JD)を計算する
  #
  #   フリーゲルの公式を使用する
  #   [ JD ] = int( 365.25 × year )
  #          + int( year / 400 )
  #          - int( year / 100 )
  #          + int( 30.59 ( month - 2 ) )
  #          + day
  #          + 1721088
  #   ※上記の int( x ) は厳密には、x を超えない最大の整数
  #     ( ちなみに、[ 準JD ]を求めるなら + 1721088 が - 678912 となる )
  #=========================================================================
  def gc_to_jd
    begin
      # 1月,2月は前年の13月,14月とする
      if @month < 3
        @year -= 1
        @month += 12
      end

      # 日付(整数)部分計算
      @jd  = (365.25 * @year).truncate
      @jd += (@year / 400.0).truncate
      @jd -= (@year / 100.0).truncate
      @jd += (30.59 * (@month - 2)).truncate
      @jd += @day
      @jd += 1721088

      # 時間(小数)部分計算
      t  = @sec / 3600.0
      t += @min / 60.0
      t += @hour
      t  = t / 24.0

      @jd += t
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".gc_to_jd] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # 月相計算
  #=========================================================================
  def calc_moonphase
    begin
      # 黄経（太陽・月）計算
      long_moon = calc_longitude_moon
      long_sun  = calc_longitude_sun
      long_dev  = normalize_angle(long_moon - long_sun)
      puts "黄経・月   = #{long_moon}°"
      puts "黄経・太陽 = #{long_sun}°"
      puts "黄経差     = #{long_dev}°"

      # 月相計算
      moonphase = ((long_dev / 360.0) * 28).round
      moonphase = 0 if moonphase == 28

      return moonphase
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".calc_moonphase] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # 太陽の黄経 λsun 計算
  #=========================================================================
  def calc_longitude_sun
    begin
      # 時分秒から日計算
      t  = @hour * 60 * 60
      t += @min * 60
      t += @sec
      t /= 86400.0

      # 地球自転遅れ補正値(日)計算
      #rotate_rev = (57 + 0.8 * (year - 1990)) / 86400.0
      rotate_rev = calc_dt / 86400.0

      # 2000年1月1日力学時正午からの経過日数(日)計算
      day_progress = calc_day_progress

      # 経過ユリウス年(日)計算
      # ( 2000.0(2000年1月1日力学時正午)からの経過年数 (年) )
      jy = (day_progress + t + rotate_rev) / 365.25

      # 太陽黄経計算
      th  = 0.0003 * Math.sin(K * normalize_angle(329.7  +   44.43  * jy))
      th += 0.0003 * Math.sin(K * normalize_angle(352.5  + 1079.97  * jy))
      th += 0.0004 * Math.sin(K * normalize_angle( 21.1  +  720.02  * jy))
      th += 0.0004 * Math.sin(K * normalize_angle(157.3  +  299.30  * jy))
      th += 0.0004 * Math.sin(K * normalize_angle(234.9  +  315.56  * jy))
      th += 0.0005 * Math.sin(K * normalize_angle(291.2  +   22.81  * jy))
      th += 0.0005 * Math.sin(K * normalize_angle(207.4  +    1.50  * jy))
      th += 0.0006 * Math.sin(K * normalize_angle( 29.8  +  337.18  * jy))
      th += 0.0007 * Math.sin(K * normalize_angle(206.8  +   30.35  * jy))
      th += 0.0007 * Math.sin(K * normalize_angle(153.3  +   90.38  * jy))
      th += 0.0008 * Math.sin(K * normalize_angle(132.5  +  659.29  * jy))
      th += 0.0013 * Math.sin(K * normalize_angle( 81.4  +  225.18  * jy))
      th += 0.0015 * Math.sin(K * normalize_angle(343.2  +  450.37  * jy))
      th += 0.0018 * Math.sin(K * normalize_angle(251.3  +    0.20  * jy))
      th += 0.0018 * Math.sin(K * normalize_angle(297.8  + 4452.67  * jy))
      th += 0.0020 * Math.sin(K * normalize_angle(247.1  +  329.64  * jy))
      th += 0.0048 * Math.sin(K * normalize_angle(234.95 +   19.341 * jy))
      th += 0.0200 * Math.sin(K * normalize_angle(355.05 +  719.981 * jy))
      th += (1.9146 - 0.00005 * jy) * Math.sin(K * normalize_angle(357.538 + 359.991 * jy))
      th += normalize_angle(280.4603 + 360.00769 * jy)
      return normalize_angle(th)
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".get_longitude_sun] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # 月の黄経 λmoon 計算
  #=========================================================================
  def calc_longitude_moon
    begin
      # 時分秒から日計算
      t  = @hour * 60 * 60
      t += @min * 60
      t += @sec
      t /= 86400.0

      # 地球自転遅れ補正値(日)計算
      #rotate_rev = (57 + 0.8 * (year - 1990)) / 86400.0
      rotate_rev = calc_dt / 86400.0

      # 2000年1月1日力学時正午からの経過日数(日)計算
      day_progress = calc_day_progress

      # 経過ユリウス年(日)計算
      # ( 2000.0(2000年1月1日力学時正午)からの経過年数 (年) )
      jy = (day_progress + t + rotate_rev) / 365.25

      # 月黄経計算
      am  = 0.0006 * Math.sin(K * normalize_angle( 54.0 + 19.3  * jy))
      am += 0.0006 * Math.sin(K * normalize_angle( 71.0 +  0.2  * jy))
      am += 0.0020 * Math.sin(K * normalize_angle( 55.0 + 19.34 * jy))
      am += 0.0040 * Math.sin(K * normalize_angle(119.5 +  1.33 * jy))

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
      str_msg = "[EXCEPTION][" + self.class.name + ".get_longitude_moon] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # 角度の正規化
  # ( すなわち引数の範囲を ０≦θ＜３６０ にする )
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
      str_msg = "[EXCEPTION][" + self.class.name + ".normalize_angle] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # ユリウス日(JD)から年月日、時分秒(世界時)を計算する
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
    begin
      ymdt = Array.new(6, 0)

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
      str_msg = "[EXCEPTION][" + self.class.name + ".jd_to_ymdt] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # ΔT の計算
  #=========================================================================
  def calc_dt
    ymd = sprintf("%04d-%02d-%02d", @year, @month, @day)
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
      case
      when ymd < sprintf("%04d-%02d-%02d", 1972, 1, 1)
        t = @year - 1975
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
    when 1986 <= @year && @year < 2005
      # t = @year - 2000
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
    when 2005 <= @year && @year < 2050
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
        t = @year - 2000
        dt  = 62.92
        dt += 0.32217 * t
        dt += 0.005589 * t ** 2
      end
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
  # 2000年1月1日力学時正午からの経過日数(日)
  #=========================================================================
  def calc_day_progress
    begin
      # 年月日取得
      year  = @year - 2000
      month = @month
      day   = @day

      # 1月,2月は前年の13月,14月とする
      if month < 3
        year  -= 1
        month += 12
      end

      # 経過日数(J2000.0)
      day_progress  = 365 * year + 30 * month + day - 33.5 - 9 / 24.0
      day_progress += (3 * (month + 1) / 5.0).truncate
      day_progress += (year / 4.0).truncate

      return day_progress
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".calc_day_progress] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end
end

#============
# 引数クラス
#============
class Arg
  def initialize
    @dt = Time.now.strftime("%Y%m%d%H%M%S")
  end

  # 引数チェック
  def check
    begin
      return true if ARGV.size == 0

      # 正規チェック (  8桁の半角数字 )
      if  /^\d{8}$/ =~ ARGV[0]
        @dt = "#{ARGV[0]}000000"
      # 正規チェック ( 14桁の半角数字 )
      elsif /^\d{14}$/ =~ ARGV[0]
        @dt = ARGV[0]
      else
        puts "引数指定 : [ 半角数字(8桁) | 半角数字(14桁) ] "
        return false
      end

      # 日付妥当性チェック
      year  = @dt[0,4].to_i
      month = @dt[4,2].to_i
      day   = @dt[6,2].to_i
      if !Date.valid_date?(year, month, day)
        puts "引数指定 : 妥当な日付ではありません。"
        return false
      end

      # 時刻妥当性チェック
      unless /^([01][0-9]|2[0-3])[0-5][0-9][0-5][0-9]$/ =~@dt[8,6]
        puts "引数指定 : 妥当な時刻ではありません。"
        return false
      end

      return true
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".check] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  # 日時取得
  def get_dt
    return @dt
  end
end

################
####  MAIN  ####
################
begin
  # 引数チェック ( エラーなら終了 )
  obj_arg = Arg.new
  exit unless obj_arg.check

  # 計算対象日付設定
  dt = obj_arg.get_dt

  # 計算クラスインスタンス化
  obj_calc = CalcMoonphase.new(dt)

  # グレゴリオ暦からユリウス通日を計算
  obj_calc.gc_to_jd

  # ユリウス通日から月相を計算
  moonphase = obj_calc.calc_moonphase

  # 計算結果出力
  str  = "#{dt[0,4]}-#{dt[4,2]}-#{dt[6,2]} #{dt[8,2]}:#{dt[10,2]}:#{dt[12,2]} "
  str << "の月相 = #{moonphase}"
  puts str
rescue => e
  str_msg = "[EXCEPTION] " + e.to_s
  STDERR.puts str_msg
  exit 1
end

