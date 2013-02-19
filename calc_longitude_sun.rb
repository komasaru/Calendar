# -*- coding: utf-8 -*-
#=太陽黄経計算スクリプト
# （グレゴリオ暦から太陽黄経を計算する）
#
# date          name            version
# 2013.02.19    mk-mode         1.00 新規作成
#
# Copyright(C) 2013 mk-mode.com All Rights Reserved.
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
class CalcLongitudeSun
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

  # 太陽黄経取得
  def get_longitude_sun
    return @th
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

  # 計算結果出力
  str  = "#{dt[0,4]}-#{dt[4,2]}-#{dt[6,2]} #{dt[8,2]}:#{dt[10,2]}:#{dt[12,2]} "
  str << "の太陽黄経 = #{obj_calc.get_longitude_sun}°"
  puts str
rescue => e
  str_msg = "[EXCEPTION] " + e.to_s
  STDERR.puts str_msg
  exit 1
end
