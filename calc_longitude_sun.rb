#! /usr/local/bin/ruby
# coding: utf-8
#=太陽黄経計算スクリプト
# （グレゴリオ暦から太陽黄経を計算する）
#
# date          name            version
# 2013.02.19    mk-mode         1.00 新規作成
# 2013.03.20    mk-mode         1.01 補正値計算処理を追加
# 2016.02.18    mk-mode         1.02 57 固定だった ΔT を計算により導出するよう変更
#                                    Ref: [NASA - Polynomial Expressions for Delta T](http://eclipse.gsfc.nasa.gov/SEhelp/deltatpoly2004.html)
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
# UTC ( +9 )
UTC = 9

#============
# 計算クラス
#============
class CalcLongitudeSun
  def initialize(dt)
    # 年月日時分秒
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
      day_progress  = 365 * year + 30 * month + day - 33.5 - UTC / 24.0
      day_progress += (3 * (month + 1) / 5.0).truncate
      day_progress += (year / 4.0).truncate

      return day_progress
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".calc_day_progress] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # 太陽の黄経 λsun 計算
  #=========================================================================
  def calc_longitude_sun
    begin
      # 時刻引数を分解
      tm1 = @jd.truncate                # 整数部分
      tm2 = @jd - tm1                   # 小数部分
      tm2 -= 9.0/24.0                   # JST ==> DT （補正時刻=0.0sec と仮定して計算）
      t  = (tm2 + 0.5) / 36525.0        # 36525は1年365日と1/4を現す数値
      t += (tm1 - 2451545.0) / 36525.0  # 2451545は基点までのユリウス日

      # 摂動項の計算
      ang = normalize_angle( 31557.0 * t + 161.0)
      th  = 0.0004 * Math.cos(K * ang)
      ang = normalize_angle( 29930.0 * t +  48.0)
      th += 0.0004 * Math.cos(K * ang)
      ang = normalize_angle(  2281.0 * t + 221.0)
      th += 0.0005 * Math.cos(K * ang)
      ang = normalize_angle(   155.0 * t + 118.0)
      th += 0.0005 * Math.cos(K * ang)
      ang = normalize_angle( 33718.0 * t + 316.0)
      th += 0.0006 * Math.cos(K * ang)
      ang = normalize_angle(  9038.0 * t +  64.0)
      th += 0.0007 * Math.cos(K * ang)
      ang = normalize_angle(  3035.0 * t + 110.0)
      th += 0.0007 * Math.cos(K * ang)
      ang = normalize_angle( 65929.0 * t +  45.0)
      th += 0.0007 * Math.cos(K * ang)
      ang = normalize_angle( 22519.0 * t + 352.0)
      th += 0.0013 * Math.cos(K * ang)
      ang = normalize_angle( 45038.0 * t + 254.0)
      th += 0.0015 * Math.cos(K * ang)
      ang = normalize_angle(445267.0 * t + 208.0)
      th += 0.0018 * Math.cos(K * ang)
      ang = normalize_angle(    19.0 * t + 159.0)
      th += 0.0018 * Math.cos(K * ang)
      ang = normalize_angle( 32964.0 * t + 158.0)
      th += 0.0020 * Math.cos(K * ang)
      ang = normalize_angle( 71998.1 * t + 265.1)
      th += 0.0200 * Math.cos(K * ang)
      ang = normalize_angle(35999.05 * t + 267.52)
      th -= 0.0048 * t * Math.cos(K * ang)
      th += 1.9147     * Math.cos(K * ang)

      # 比例項の計算
      ang = normalize_angle(36000.7695 * t)
      ang = normalize_angle(ang + 280.4659)

      # 太陽黄経
      @th  = normalize_angle(th + ang)
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".get_longitude_sun] " + e.to_s
      STDERR.puts str_msg
      exit 1
    end
  end

  #=========================================================================
  # 太陽の黄経 λsun 計算 ( 補正 )
  #=========================================================================
  def calc_longitude_sun_new
    begin
      # 時分秒から日計算
      t  = @hour * 60 * 60
      t += @min * 60
      t += @sec
      t /= 86400.0

      # 地球自転遅れ補正値(日)計算
      #rotate_rev = (57 + 0.8 * (@year - 1990)) / 86400.0
      #rotate_rev = (calc_dt + 0.8 * (@year - 1990)) / 86400.0
      rotate_rev = (68.184 + 0.8 * (@year - 1990)) / 86400.0

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
      @th_new = normalize_angle(th)
    rescue => e
      str_msg = "[EXCEPTION][" + self.class.name + ".get_longitude_sun_new] " + e.to_s
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

  # 太陽黄経取得
  def get_longitude_sun
    return @th
  end

  # 太陽黄経(補正)取得
  def get_longitude_sun_new
    return @th_new
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
  obj_calc = CalcLongitudeSun.new(dt)

  # グレゴリオ暦からユリウス通日を計算
  obj_calc.gc_to_jd

  # ユリウス通日から黄経(太陽)を計算
  obj_calc.calc_longitude_sun

  # ユリウス通日から黄経(太陽)(補正)を計算
  obj_calc.calc_longitude_sun_new

  # 計算結果出力
  puts "[#{dt[0,4]}-#{dt[4,2]}-#{dt[6,2]} #{dt[8,2]}:#{dt[10,2]}:#{dt[12,2]}]"
  puts "\t[太陽黄経] #{obj_calc.get_longitude_sun}°"
  puts "\t[補 正 後] #{obj_calc.get_longitude_sun_new}°"
rescue => e
  str_msg = "[EXCEPTION] " + e.to_s
  STDERR.puts str_msg
  exit 1
end

